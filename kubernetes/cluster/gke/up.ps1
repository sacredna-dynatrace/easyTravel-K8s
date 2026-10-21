# easyTravel 데모 환경 한 번에 구성 (GKE Standard) - Windows PowerShell 5.1 / PowerShell 7
#   1) GKE 클러스터  2) Dynatrace Operator + DynaKube  3) easyTravel (L4 LoadBalancer Service)
# 다시 실행해도 안전 (이미 있는 리소스는 건너뛰거나 갱신)
#
# 필요 도구: gcloud (+ gke-gcloud-auth-plugin), kubectl, helm  (설치 방법은 README.md 참고)
# 실행 예:
#   . .\kubernetes\cluster\gke\env.local.ps1
#   powershell -ExecutionPolicy Bypass -File .\kubernetes\cluster\gke\up.ps1
# 선택:
#   -Overlay <이름>       배포할 overlay (기본 gke)
#   $env:GHCR_USER / $env:GHCR_TOKEN   GHCR 패키지가 private 일 때 (read:packages 권한 PAT)
param(
  [string]$Project     = $env:GCP_PROJECT,
  [string]$Zone        = $(if ($env:GCP_ZONE) { $env:GCP_ZONE } else { "asia-northeast3-a" }),
  [string]$Cluster     = $(if ($env:GKE_CLUSTER) { $env:GKE_CLUSTER } else { "easytravel-demo" }),
  [string]$MachineType = $(if ($env:GKE_MACHINE_TYPE) { $env:GKE_MACHINE_TYPE } else { "e2-standard-4" }),  # amd64 전용 → Arm(t2a, c4a) 금지
  [string]$NumNodes    = $(if ($env:GKE_NUM_NODES) { $env:GKE_NUM_NODES } else { "2" }),
  [string]$Overlay     = "gke"
)
$ErrorActionPreference = "Stop"
$DtClusterName = if ($env:DT_CLUSTER_NAME) { $env:DT_CLUSTER_NAME } else { "easytravel-gke" }
$DtHostGroup   = if ($env:DT_HOST_GROUP)   { $env:DT_HOST_GROUP }   else { "easytravel-gke" }

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = (Resolve-Path (Join-Path $Here "../../..")).Path
$Tmp  = Join-Path $env:TEMP "easytravel-up-gke"
New-Item -ItemType Directory -Force -Path $Tmp | Out-Null

function Log([string]$msg) { Write-Host ""; Write-Host "==> $msg" -ForegroundColor Cyan }
function Run([scriptblock]$cmd) {
  & $cmd
  if ($LASTEXITCODE -ne 0) { throw "명령 실패 (exit $LASTEXITCODE): $cmd" }
}
function Get-Out([scriptblock]$cmd) {  # stderr 무시하고 출력만 (PS 5.1 의 2>$null + Stop 예외 회피)
  $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  $out = & $cmd 2>$null
  $ErrorActionPreference = $prev
  return $out
}
function Save-Yaml([string]$path, $lines) {     # PS 5.1 의 > 는 UTF-16 으로 저장하므로 UTF-8 로 직접 기록
  [IO.File]::WriteAllText($path, ($lines -join "`n"), (New-Object Text.UTF8Encoding($false)))
}
function Try-Run([scriptblock]$cmd) {   # 실패해도 계속 (존재 여부 확인용)
  $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  & $cmd 2>$null | Out-Null
  $ok = ($LASTEXITCODE -eq 0); $ErrorActionPreference = $prev
  return $ok
}

# ---------------------------------------------------------------- 0. 사전 확인
foreach ($t in "gcloud","kubectl","helm") {
  if (-not (Get-Command $t -ErrorAction SilentlyContinue)) { throw "필요한 도구가 없습니다: $t" }
}
if (-not (Get-Command "gke-gcloud-auth-plugin" -ErrorAction SilentlyContinue)) {
  throw "gke-gcloud-auth-plugin 이 없습니다. 설치: gcloud components install gke-gcloud-auth-plugin"
}
if (-not $Project) { throw "환경 변수 GCP_PROJECT 를 설정하세요 (또는 -Project)" }
foreach ($v in "DT_API_URL","DT_OPERATOR_TOKEN","DT_INGEST_TOKEN") {
  if (-not [Environment]::GetEnvironmentVariable($v)) { throw "환경 변수 $v 를 설정하세요" }
}
foreach ($v in "DT_OPERATOR_TOKEN","DT_INGEST_TOKEN") {
  $val = [Environment]::GetEnvironmentVariable($v)
  if (-not $val.StartsWith("dt0c01.")) {
    Write-Warning "$v 가 classic token(dt0c01.) 이 아닙니다 (prefix: $($val.Substring(0, [Math]::Min(7, $val.Length)))). DynaKube 가 Error 가 될 수 있습니다."
  }
}
$Account = Get-Out { gcloud config get-value account }
if (-not $Account) { throw "gcloud 로그인이 필요합니다: gcloud auth login" }
Log "GCP 계정 $Account / 프로젝트 $Project / zone $Zone / 클러스터 $Cluster / overlay $Overlay"

# ---------------------------------------------------------------- 1. GKE 클러스터 (약 5~10분)
if (Try-Run { gcloud container clusters describe $Cluster --project $Project --zone $Zone --format "value(name)" }) {
  Log "1/3 클러스터가 이미 있습니다 -> kubeconfig 갱신"
} else {
  Log "1/3 GKE Standard 클러스터 생성 (5~10분 소요)"
  Run { gcloud services enable container.googleapis.com compute.googleapis.com --project $Project }
  # Standard 모드 (Autopilot 은 cloudNativeFullStack 미지원), COS_CONTAINERD, Cloud Logging/Monitoring SYSTEM 만
  Run { gcloud container clusters create $Cluster --project $Project --zone $Zone `
          --release-channel regular `
          --machine-type $MachineType --num-nodes $NumNodes `
          --image-type COS_CONTAINERD `
          --disk-type pd-balanced --disk-size 50 `
          --enable-ip-alias `
          --logging SYSTEM --monitoring SYSTEM --no-enable-managed-prometheus `
          --node-labels workload=easytravel `
          --labels "project=easytravel-demo,owner=sacredna" }      # [CUSTOMIZE] 비용 추적용 라벨
}
Run { gcloud container clusters get-credentials $Cluster --project $Project --zone $Zone }
Run { kubectl get nodes -o wide }

# ---------------------------------------------------------------- 2. Dynatrace Operator + DynaKube
Log "2/3 Dynatrace Operator + DynaKube"
# helm(ORAS) 이 Windows 자격 증명 관리자를 찾다 실패하지 않도록 빈 레지스트리 설정으로 익명 pull (EKS up.ps1 과 동일)
$RegDir  = Join-Path $Tmp "registry"
New-Item -ItemType Directory -Force -Path $RegDir | Out-Null
$RegFile = Join-Path $RegDir "config.json"
[IO.File]::WriteAllText($RegFile, '{"auths":{"none.invalid":{}}}', (New-Object Text.UTF8Encoding($false)))
$prevDockerConfig = $env:DOCKER_CONFIG
$env:DOCKER_CONFIG = $RegDir
try {
  Run { helm upgrade --install dynatrace-operator oci://public.ecr.aws/dynatrace/dynatrace-operator `
          --registry-config $RegFile `
          --create-namespace --namespace dynatrace --wait --timeout 10m }
} finally {
  $env:DOCKER_CONFIG = $prevDockerConfig
}
$SecretFile = Join-Path $Tmp "dynakube-secret.yaml"
$y = kubectl -n dynatrace create secret generic dynakube `
        "--from-literal=apiToken=$env:DT_OPERATOR_TOKEN" `
        "--from-literal=dataIngestToken=$env:DT_INGEST_TOKEN" `
        --dry-run=client -o yaml
if ($LASTEXITCODE -ne 0) { throw "secret 생성 실패" }
Save-Yaml $SecretFile $y
Run { kubectl apply -f $SecretFile }
Remove-Item $SecretFile -Force
# 공통 dynakube.yaml 을 GKE 용으로 치환: apiUrl, Dynatrace 클러스터 이름, host group
$DkFile = Join-Path $Tmp "dynakube.yaml"
$dk = [IO.File]::ReadAllText((Join-Path $Root "dynatrace/dynakube.yaml"), [Text.Encoding]::UTF8)
$dk = $dk.Replace("https://ENVIRONMENTID.live.dynatrace.com/api", $env:DT_API_URL)
$dk = $dk.Replace('automatic-kubernetes-api-monitoring-cluster-name: "easytravel"', "automatic-kubernetes-api-monitoring-cluster-name: `"$DtClusterName`"")
$dk = $dk.Replace("hostGroup: easytravel-demo", "hostGroup: $DtHostGroup")
[IO.File]::WriteAllText($DkFile, $dk, (New-Object Text.UTF8Encoding($false)))
Run { kubectl apply -f $DkFile }
Write-Host "DynaKube 가 Running 이 될 때까지 대기 (최대 10분)..."
$phase = ""
for ($i = 0; $i -lt 60; $i++) {
  $phase = Get-Out { kubectl -n dynatrace get dynakube dynakube -o "jsonpath={.status.phase}" }
  Write-Host "  phase=$phase"
  if ($phase -eq "Running") { break }
  Start-Sleep -Seconds 10
}
if ($phase -ne "Running") { throw "DynaKube 가 Running 이 아닙니다. kubectl -n dynatrace describe dynakube dynakube 로 확인하세요." }

# ---------------------------------------------------------------- 3. easyTravel
Log "3/3 easyTravel 배포 (overlay: $Overlay)"
Run { kubectl apply -f (Join-Path $Root "kubernetes/base/namespace.yaml") }
if ($env:GHCR_TOKEN) {
  if (-not $env:GHCR_USER) { throw "GHCR_USER 를 설정하세요" }
  $PullFile = Join-Path $Tmp "ghcr-secret.yaml"
  $y = kubectl -n easytravel create secret docker-registry ghcr --docker-server=ghcr.io `
          "--docker-username=$env:GHCR_USER" "--docker-password=$env:GHCR_TOKEN" `
          --dry-run=client -o yaml
  if ($LASTEXITCODE -ne 0) { throw "GHCR secret 생성 실패" }
  Save-Yaml $PullFile $y
  Run { kubectl apply -f $PullFile }
  Remove-Item $PullFile -Force
  $PatchFile = Join-Path $Tmp "sa-patch.yaml"
  [IO.File]::WriteAllText($PatchFile, "imagePullSecrets:`n- name: ghcr`n")
  Run { kubectl -n easytravel patch serviceaccount default --patch-file $PatchFile }
}
$PanelUser = if ($env:PANEL_USER) { $env:PANEL_USER } else { "demo" }
$PanelPass = $env:PANEL_PASSWORD
$PanelNew  = $false
if (-not $PanelPass) {
  if (-not (Try-Run { kubectl -n easytravel get secret problem-panel-auth })) {
    $chars = "abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789".ToCharArray()
    $PanelPass = -join (1..16 | ForEach-Object { $chars | Get-Random })
    $PanelNew = $true
  }
}
if ($PanelPass) {
  $AuthFile = Join-Path $Tmp "panel-auth.yaml"
  $y = kubectl -n easytravel create secret generic problem-panel-auth "--from-literal=htpasswd=${PanelUser}:{PLAIN}${PanelPass}" --dry-run=client -o yaml
  if ($LASTEXITCODE -ne 0) { throw "problem-panel-auth secret 생성 실패" }
  Save-Yaml $AuthFile $y
  Run { kubectl apply -f $AuthFile }
  Remove-Item $AuthFile -Force
}
Run { kubectl apply -k (Join-Path $Root "kubernetes/overlays/$Overlay") }
Run { kubectl -n easytravel wait --for=condition=Available deploy --all --timeout=15m }

Write-Host "외부 IP 할당 대기..."
$HasPanel = Try-Run { kubectl -n easytravel get svc problem-panel-lb }
$Ip = ""; $PanelIp = ""
for ($i = 0; $i -lt 30; $i++) {
  $Ip = Get-Out { kubectl -n easytravel get svc www-lb -o "jsonpath={.status.loadBalancer.ingress[0].ip}" }
  if ($HasPanel) { $PanelIp = Get-Out { kubectl -n easytravel get svc problem-panel-lb -o "jsonpath={.status.loadBalancer.ingress[0].ip}" } }
  if ($Ip -and ($PanelIp -or -not $HasPanel)) { break }
  Start-Sleep -Seconds 10
}
Log "완료"
Write-Host "  Classic : http://$Ip/"
Write-Host "  Angular : http://${Ip}:9079/"
if ($HasPanel) {
  Write-Host "  Problem : http://${PanelIp}:9090/   (계정: $PanelUser)"
  if ($PanelNew) { Write-Host "            비밀번호(새로 생성): $PanelPass" -ForegroundColor Yellow }
  elseif (-not $env:PANEL_PASSWORD) { Write-Host "            비밀번호: 기존 값 유지 (docs/problem-patterns.md 의 '비밀번호 확인' 참고)" }
}
Write-Host "  (LB 헬스체크 통과까지 1~2분 더 걸릴 수 있습니다. 주소 확인: kubectl -n easytravel get svc www-lb problem-panel-lb)"
