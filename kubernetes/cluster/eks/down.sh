#!/usr/bin/env bash
# easyTravel 데모 환경 삭제 (EKS)
#   ALB 는 클러스터 밖(AWS 리소스)에 만들어지므로, Ingress 를 먼저 지워 컨트롤러가 ALB 를 정리하게 한 뒤
#   클러스터를 삭제한다. 순서를 지키지 않으면 ALB·보안그룹이 남아 VPC 삭제가 실패할 수 있다.
set -euo pipefail

CLUSTER="${CLUSTER:-easytravel-demo}"
REGION="${REGION:-ap-northeast-2}"
HERE="$(cd "$(dirname "$0")" && pwd)"
log() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

if ! eksctl get cluster --name "$CLUSTER" --region "$REGION" >/dev/null 2>&1; then
  echo "클러스터 ${CLUSTER} (${REGION}) 가 없습니다."; exit 0
fi
aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION" >/dev/null

log "1/3 Ingress 삭제 → ALB 정리"
kubectl -n easytravel delete ingress --all --ignore-not-found --wait=true --timeout=5m || true
for _ in $(seq 1 30); do
  n=$(aws resourcegroupstaggingapi get-resources --region "$REGION" \
        --resource-type-filters elasticloadbalancing:loadbalancer \
        --tag-filters "Key=elbv2.k8s.aws/cluster,Values=${CLUSTER}" \
        --query "length(ResourceTagMappingList)" --output text 2>/dev/null || echo 0)
  [ "${n:-0}" = "0" ] && break
  echo "  남은 ALB: $n"; sleep 10
done

log "2/3 easyTravel / DynaKube 삭제"
kubectl delete namespace easytravel --ignore-not-found --wait=true --timeout=5m || true
kubectl -n dynatrace delete dynakube --all --ignore-not-found --wait=true --timeout=5m || true

log "3/3 EKS 클러스터 삭제 (10~15분 소요)"
eksctl delete cluster -f "$HERE/cluster.yaml" --wait --disable-nodegroup-eviction

log "완료"
echo "  IAM 정책 AWSLoadBalancerControllerIAMPolicy-* 는 재사용을 위해 남겨 둡니다."
echo "  Dynatrace 의 호스트·클러스터 엔티티는 데이터 보존 기간이 지나면 자동으로 사라집니다."
