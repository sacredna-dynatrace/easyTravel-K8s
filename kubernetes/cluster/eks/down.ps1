# easyTravel 데모 환경 삭제 (EKS) - Windows PowerShell 5.1 / PowerShell 7
#   ALB 는 클러스터 밖(AWS 리소스)에 만들어지므로, Ingress 를 먼저 지워 컨트롤러가 ALB 를 정리하게 한 뒤
#   클러스터를 삭제한다. 순서를 지키지 않으면 ALB·보안그룹이 남아 VPC 삭제가 실패할 수 있다.
param(
  [string]$Cluster = "easytravel-demo",
  [string]$Region  = "ap-northeast-2"
)
$ErrorActionPreference = "Stop"
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
function Log([string]$msg) { Write-Host ""; Write-Host "==> $msg" -ForegroundColor Cyan }

$prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
eksctl get cluster --name $Cluster --region $Region 2>$null | Out-Null
$exists = ($LASTEXITCODE -eq 0)
if (-not $exists) { Write-Host "클러스터 $Cluster ($Region) 가 없습니다."; exit 0 }
aws eks update-kubeconfig --name $Cluster --region $Region | Out-Null

Log "1/3 Ingress 삭제 -> ALB 정리"
kubectl -n easytravel delete ingress --all --ignore-not-found --wait=true --timeout=5m
for ($i = 0; $i -lt 30; $i++) {
  $n = (aws resourcegroupstaggingapi get-resources --region $Region `
          --resource-type-filters elasticloadbalancing:loadbalancer `
          --tag-filters "Key=elbv2.k8s.aws/cluster,Values=$Cluster" `
          --query "length(ResourceTagMappingList)" --output text 2>$null)
  if (-not $n -or $n -eq "0") { break }
  Write-Host "  남은 ALB: $n"; Start-Sleep -Seconds 10
}

Log "2/3 easyTravel / DynaKube 삭제"
kubectl delete namespace easytravel --ignore-not-found --wait=true --timeout=5m
kubectl -n dynatrace delete dynakube --all --ignore-not-found --wait=true --timeout=5m
$ErrorActionPreference = $prev

Log "3/3 EKS 클러스터 삭제 (10~15분 소요)"
eksctl delete cluster -f (Join-Path $Here "cluster.yaml") --wait --disable-nodegroup-eviction
if ($LASTEXITCODE -ne 0) { throw "클러스터 삭제 실패. AWS CloudFormation 콘솔에서 eksctl-$Cluster-* 스택을 확인하세요." }

Log "완료"
Write-Host "  IAM 정책 AWSLoadBalancerControllerIAMPolicy-* 는 재사용을 위해 남겨 둡니다."
Write-Host "  Dynatrace 의 호스트·클러스터 엔티티는 데이터 보존 기간이 지나면 자동으로 사라집니다."
