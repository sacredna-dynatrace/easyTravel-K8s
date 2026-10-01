# easyTravel 데모 환경 한 번에 구성 (EKS) - Windows PowerShell 5.1 / PowerShell 7
#   1) EKS 클러스터  2) AWS Load Balancer Controller  3) Dynatrace Operator + DynaKube  4) easyTravel
# 다시 실행해도 안전 (이미 있는 리소스는 건너뛰거나 갱신)
#
# 필요 도구: aws, eksctl, kubectl, helm  (winget 설치 방법은 README.md 참고)
# 실행 예:
#   $env:DT_API_URL        = "https://abc12345.live.dynatrace.com/api"
#   $env:DT_OPERATOR_TOKEN = "dt0c01...."
#   $env:DT_INGEST_TOKEN   = "dt0c01...."
#   .\kubernetes\cluster\eks\up.ps1
# 선택:
#   -Overlay <이름>       배포할 overlay (기본 eks. 한글/영문은 overlays/eks/kustomization.yaml 의 components/korean 로 결정)
#   $env:GHCR_USER / $env:GHCR_TOKEN   GHCR 패키지가 private 일 때 (read:packages 권한 PAT)
param(
  [string]$Cluster = "easytravel-demo",   # cluster.yaml 의 metadata.name 과 같아야 함
  [string]$Region  = "ap-northeast-2",
  [string]$Overlay = "eks"
)
$ErrorActionPreference = "Stop"
$LbcVersion      = "v3.5.0"     # AWS Load Balancer Controller
$LbcChartVersion = "3.5.0"

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = (Resolve-Path (Join-Path $Here "../../..")).Path
$Tmp  = Join-Path $env:TEMP "easytravel-up"
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
foreach ($t in "aws","eksctl","kubectl","helm") {
  if (-not (Get-Command $t -ErrorAction SilentlyContinue)) { throw "필요한 도구가 없습니다: $t" }
}
foreach ($v in "DT_API_URL","DT_OPERATOR_TOKEN","DT_INGEST_TOKEN") {
  if (-not [Environment]::GetEnvironmentVariable($v)) { throw "환경 변수 $v 를 설정하세요" }
}
$AccountId = (aws sts get-caller-identity --query Account --output text)
if ($LASTEXITCODE -ne 0) { throw "AWS 자격 증명을 확인하세요 (aws configure 또는 aws sso login)" }
Log "AWS 계정 $AccountId / 리전 $Region / 클러스터 $Cluster / overlay $Overlay"

# ---------------------------------------------------------------- 1. EKS 클러스터 (약 15~20분)
if (Try-Run { eksctl get cluster --name $Cluster --region $Region }) {
  Log "1/4 클러스터가 이미 있습니다 -> kubeconfig 갱신"
  Run { aws eks update-kubeconfig --name $Cluster --region $Region }
} else {
  Log "1/4 EKS 클러스터 생성 (15~20분 소요)"
  Run { eksctl create cluster -f (Join-Path $Here "cluster.yaml") }
}
Run { kubectl get nodes -o wide }

# ---------------------------------------------------------------- 2. AWS Load Balancer Controller
Log "2/4 AWS Load Balancer Controller $LbcVersion"
$PolicyName = "AWSLoadBalancerControllerIAMPolicy-" + $LbcVersion.Replace(".", "_")
$PolicyArn  = "arn:aws:iam::${AccountId}:policy/$PolicyName"
if (-not (Try-Run { aws iam get-policy --policy-arn $PolicyArn })) {
  $PolicyFile = Join-Path $Tmp "lbc-iam-policy.json"
  Invoke-WebRequest -UseBasicParsing -OutFile $PolicyFile `
    -Uri "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/$LbcVersion/docs/install/iam_policy.json"
  $PolicyUri = "file://" + ($PolicyFile -replace "\\", "/")
  Run { aws iam create-policy --policy-name $PolicyName --policy-document $PolicyUri | Out-Null }
}
Run { eksctl create iamserviceaccount --cluster $Cluster --region $Region `
        --namespace kube-system --name aws-load-balancer-controller `
        --attach-policy-arn $PolicyArn --override-existing-serviceaccounts --approve }
$VpcId = (aws eks describe-cluster --name $Cluster --region $Region --query cluster.resourcesVpcConfig.vpcId --output text)
Try-Run { helm repo add eks https://aws.github.io/eks-charts } | Out-Null
Run { helm repo update eks }
Run { helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller `
        -n kube-system --version $LbcChartVersion `
        --set "clusterName=$Cluster" --set "region=$Region" --set "vpcId=$VpcId" `
        --set serviceAccount.create=false --set serviceAccount.name=aws-load-balancer-controller `
        --wait }
Run { kubectl -n kube-system rollout status deploy/aws-load-balancer-controller --timeout=5m }

# ---------------------------------------------------------------- 3. Dynatrace Operator + DynaKube
Log "3/4 Dynatrace Operator + DynaKube"
# public.ecr.aws 는 익명 pull 이 가능하지만, helm(ORAS) 은 자격 증명 저장소가 비어 있으면 Windows 자격 증명
# 관리자(wincred)를 자동으로 찾다가 "A specified logon session does not exist" 로 실패할 수 있다.
# → 이 호출에서만 빈 레지스트리 설정을 지정해 credential helper 를 쓰지 않게 한다.
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
$DkFile = Join-Path $Tmp "dynakube.yaml"
$dk = [IO.File]::ReadAllText((Join-Path $Root "dynatrace/dynakube.yaml"), [Text.Encoding]::UTF8)
[IO.File]::WriteAllText($DkFile, $dk.Replace("https://ENVIRONMENTID.live.dynatrace.com/api", $env:DT_API_URL), (New-Object Text.UTF8Encoding($false)))
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

# ---------------------------------------------------------------- 4. easyTravel
Log "4/4 easyTravel 배포 (overlay: $Overlay)"
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
Run { kubectl apply -k (Join-Path $Root "kubernetes/overlays/$Overlay") }
Run { kubectl -n easytravel wait --for=condition=Available deploy --all --timeout=15m }

Write-Host "ALB 주소 할당 대기..."
$Alb = ""
for ($i = 0; $i -lt 30; $i++) {
  $Alb = Get-Out { kubectl -n easytravel get ingress easytravel-classic -o "jsonpath={.status.loadBalancer.ingress[0].hostname}" }
  if ($Alb) { break }
  Start-Sleep -Seconds 10
}
Log "완료"
Write-Host "  Classic : http://$Alb/"
Write-Host "  Angular : http://${Alb}:9079/"
Write-Host "  (ALB DNS 전파와 target 등록에 2~3분 더 걸릴 수 있습니다)"
