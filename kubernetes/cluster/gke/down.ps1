# easyTravel 데모 환경 삭제 (GKE) - Windows PowerShell 5.1 / PowerShell 7
#   LoadBalancer Service 가 만든 GCP 리소스(forwarding rule, backend service, health check, 방화벽 규칙)는
#   클러스터 밖에 있으므로, namespace 를 먼저 지워 GKE 가 정리하게 한 뒤 클러스터를 삭제한다.
param(
  [string]$Project = $env:GCP_PROJECT,
  [string]$Zone    = $(if ($env:GCP_ZONE) { $env:GCP_ZONE } else { "asia-northeast3-a" }),
  [string]$Cluster = $(if ($env:GKE_CLUSTER) { $env:GKE_CLUSTER } else { "easytravel-demo" })
)
$ErrorActionPreference = "Stop"
function Log([string]$msg) { Write-Host ""; Write-Host "==> $msg" -ForegroundColor Cyan }
if (-not $Project) { throw "환경 변수 GCP_PROJECT 를 설정하세요 (또는 -Project)" }
$Region = $Zone.Substring(0, $Zone.LastIndexOf("-"))

$prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
gcloud container clusters describe $Cluster --project $Project --zone $Zone --format "value(name)" 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Host "클러스터 $Cluster ($Project / $Zone) 가 없습니다."; exit 0 }
gcloud container clusters get-credentials $Cluster --project $Project --zone $Zone 2>$null | Out-Null

Log "1/3 easyTravel 삭제 -> LoadBalancer(외부 IP) 정리"
kubectl delete namespace easytravel --ignore-not-found --wait=true --timeout=5m
for ($i = 0; $i -lt 30; $i++) {
  $rules = @(gcloud compute forwarding-rules list --project $Project --filter "region:$Region AND description~easytravel/" --format "value(name)" 2>$null | Where-Object { $_ })
  if ($rules.Count -eq 0) { break }
  Write-Host "  남은 forwarding rule: $($rules.Count)"; Start-Sleep -Seconds 10
}

Log "2/3 DynaKube 삭제"
kubectl -n dynatrace delete dynakube --all --ignore-not-found --wait=true --timeout=5m
$ErrorActionPreference = $prev

Log "3/3 GKE 클러스터 삭제 (5~10분 소요)"
gcloud container clusters delete $Cluster --project $Project --zone $Zone --quiet
if ($LASTEXITCODE -ne 0) { throw "클러스터 삭제 실패. GCP 콘솔 Kubernetes Engine 에서 상태를 확인하세요." }

Log "완료"
Write-Host "  Dynatrace 의 호스트·클러스터 엔티티는 데이터 보존 기간이 지나면 자동으로 사라집니다."
