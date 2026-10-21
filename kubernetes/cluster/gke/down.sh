#!/usr/bin/env bash
# easyTravel 데모 환경 삭제 (GKE)
#   LoadBalancer Service 가 만든 GCP 리소스(forwarding rule, backend service, health check, 방화벽 규칙)는
#   클러스터 밖에 있으므로, namespace 를 먼저 지워 GKE 가 정리하게 한 뒤 클러스터를 삭제한다.
set -euo pipefail

PROJECT="${GCP_PROJECT:-${DEVSHELL_PROJECT_ID:-}}"
ZONE="${GCP_ZONE:-asia-northeast3-a}"
CLUSTER="${GKE_CLUSTER:-easytravel-demo}"
: "${PROJECT:?GCP_PROJECT 환경 변수를 설정하세요}"
G=(--project "$PROJECT" --zone "$ZONE")
REGION="${ZONE%-*}"
log() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

if ! gcloud container clusters describe "$CLUSTER" "${G[@]}" --format='value(name)' >/dev/null 2>&1; then
  echo "클러스터 ${CLUSTER} (${PROJECT} / ${ZONE}) 가 없습니다."; exit 0
fi
gcloud container clusters get-credentials "$CLUSTER" "${G[@]}" >/dev/null

log "1/3 easyTravel 삭제 → LoadBalancer(외부 IP) 정리"
kubectl delete namespace easytravel --ignore-not-found --wait=true --timeout=5m || true
for _ in $(seq 1 30); do
  n=$( (gcloud compute forwarding-rules list --project "$PROJECT" --filter="region:${REGION} AND description~easytravel/" \
        --format='value(name)' 2>/dev/null || true) | wc -l | tr -d ' ')
  [ "$n" = "0" ] && break
  echo "  남은 forwarding rule: $n"; sleep 10
done

log "2/3 DynaKube 삭제"
kubectl -n dynatrace delete dynakube --all --ignore-not-found --wait=true --timeout=5m || true

log "3/3 GKE 클러스터 삭제 (5~10분 소요)"
gcloud container clusters delete "$CLUSTER" "${G[@]}" --quiet

log "완료"
echo "  Dynatrace 의 호스트·클러스터 엔티티는 데이터 보존 기간이 지나면 자동으로 사라집니다."
