#!/usr/bin/env bash
# easyTravel 데모 환경 한 번에 구성 (GKE Standard)
#   1) GKE 클러스터  2) Dynatrace Operator + DynaKube  3) easyTravel (L4 LoadBalancer Service)
# 다시 실행해도 안전 (이미 있는 리소스는 건너뛰거나 갱신)
#
# 필요 도구: gcloud (+ gke-gcloud-auth-plugin), kubectl, helm   (Google Cloud Shell 에는 모두 설치되어 있음)
# 필요 환경 변수:
#   GCP_PROJECT          GCP 프로젝트 ID
#   DT_API_URL           예) https://abc12345.live.dynatrace.com/api
#   DT_OPERATOR_TOKEN    Operator token (classic dt0c01.)
#   DT_INGEST_TOKEN      Data Ingest token (classic dt0c01.)
# 선택 환경 변수:
#   GCP_ZONE=asia-northeast3-a  GKE_CLUSTER=easytravel-demo  GKE_MACHINE_TYPE=e2-standard-4  GKE_NUM_NODES=2
#   DT_CLUSTER_NAME=easytravel-gke  DT_HOST_GROUP=easytravel-gke
#   OVERLAY=gke          배포할 overlay
#   GHCR_USER / GHCR_TOKEN   GHCR 패키지가 private 일 때
set -euo pipefail

PROJECT="${GCP_PROJECT:-${DEVSHELL_PROJECT_ID:-}}"
ZONE="${GCP_ZONE:-asia-northeast3-a}"
CLUSTER="${GKE_CLUSTER:-easytravel-demo}"
MACHINE_TYPE="${GKE_MACHINE_TYPE:-e2-standard-4}"   # amd64 전용 이미지 → Arm(t2a, c4a) 금지
NUM_NODES="${GKE_NUM_NODES:-2}"
DT_CLUSTER_NAME="${DT_CLUSTER_NAME:-easytravel-gke}"
DT_HOST_GROUP="${DT_HOST_GROUP:-easytravel-gke}"
OVERLAY="${OVERLAY:-gke}"

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
log() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
G=(--project "$PROJECT" --zone "$ZONE")

# ---------------------------------------------------------------- 0. 사전 확인
for t in gcloud kubectl helm; do command -v "$t" >/dev/null || { echo "필요한 도구가 없습니다: $t"; exit 1; }; done
command -v gke-gcloud-auth-plugin >/dev/null || {
  echo "gke-gcloud-auth-plugin 이 없습니다. 설치: gcloud components install gke-gcloud-auth-plugin"; exit 1; }
: "${PROJECT:?GCP_PROJECT 환경 변수를 설정하세요}"
: "${DT_API_URL:?DT_API_URL 환경 변수를 설정하세요 (예: https://abc12345.live.dynatrace.com/api)}"
: "${DT_OPERATOR_TOKEN:?DT_OPERATOR_TOKEN 환경 변수를 설정하세요}"
: "${DT_INGEST_TOKEN:?DT_INGEST_TOKEN 환경 변수를 설정하세요}"
for v in DT_OPERATOR_TOKEN DT_INGEST_TOKEN; do
  case "${!v}" in dt0c01.*) ;; *) echo "경고: $v 가 classic token(dt0c01.) 이 아닙니다 (prefix: ${!v:0:7}). DynaKube 가 Error 가 될 수 있습니다." >&2 ;; esac
done
ACCOUNT=$(gcloud config get-value account 2>/dev/null || true)
[ -n "$ACCOUNT" ] || { echo "gcloud 로그인이 필요합니다: gcloud auth login"; exit 1; }
log "GCP 계정 ${ACCOUNT} / 프로젝트 ${PROJECT} / zone ${ZONE} / 클러스터 ${CLUSTER} / overlay ${OVERLAY}"

# ---------------------------------------------------------------- 1. GKE 클러스터 (약 5~10분)
if gcloud container clusters describe "$CLUSTER" "${G[@]}" --format='value(name)' >/dev/null 2>&1; then
  log "1/3 클러스터가 이미 있습니다 → kubeconfig 갱신"
else
  log "1/3 GKE Standard 클러스터 생성 (5~10분 소요)"
  gcloud services enable container.googleapis.com compute.googleapis.com --project "$PROJECT"
  # - Standard 모드: Dynatrace cloudNativeFullStack 은 GKE Autopilot 미지원 (Autopilot 은 applicationMonitoring 만)
  # - COS_CONTAINERD: GKE 기본 노드 이미지. CSI driver 기반 cloudNativeFullStack 은 별도 설정 없이 동작
  # - Cloud Logging/Monitoring 은 SYSTEM 만, Managed Prometheus 끔 (데모 비용 절감, 관측은 Dynatrace 로)
  gcloud container clusters create "$CLUSTER" "${G[@]}" \
    --release-channel regular \
    --machine-type "$MACHINE_TYPE" --num-nodes "$NUM_NODES" \
    --image-type COS_CONTAINERD \
    --disk-type pd-balanced --disk-size 50 \
    --enable-ip-alias \
    --logging SYSTEM --monitoring SYSTEM --no-enable-managed-prometheus \
    --node-labels workload=easytravel \
    --labels project=easytravel-demo,owner=sacredna      # [CUSTOMIZE] 비용 추적용 라벨
fi
gcloud container clusters get-credentials "$CLUSTER" "${G[@]}"
kubectl get nodes -o wide

# ---------------------------------------------------------------- 2. Dynatrace Operator + DynaKube
log "2/3 Dynatrace Operator + DynaKube"
REG_DIR=$(mktemp -d); echo '{"auths":{"none.invalid":{}}}' > "$REG_DIR/config.json"
DOCKER_CONFIG="$REG_DIR" helm upgrade --install dynatrace-operator oci://public.ecr.aws/dynatrace/dynatrace-operator \
  --registry-config "$REG_DIR/config.json" \
  --create-namespace --namespace dynatrace --wait --timeout 10m
kubectl -n dynatrace create secret generic dynakube \
  --from-literal="apiToken=${DT_OPERATOR_TOKEN}" \
  --from-literal="dataIngestToken=${DT_INGEST_TOKEN}" \
  --dry-run=client -o yaml | kubectl apply -f -
# 공통 dynakube.yaml 을 GKE 용으로 치환: apiUrl, Dynatrace 클러스터 이름, host group
sed -e "s#https://ENVIRONMENTID.live.dynatrace.com/api#${DT_API_URL}#" \
    -e "s#\(automatic-kubernetes-api-monitoring-cluster-name: \)\"easytravel\"#\1\"${DT_CLUSTER_NAME}\"#" \
    -e "s#hostGroup: easytravel-demo#hostGroup: ${DT_HOST_GROUP}#" \
    "$ROOT/dynatrace/dynakube.yaml" | kubectl apply -f -
echo "DynaKube 가 Running 이 될 때까지 대기 (최대 10분)..."
for _ in $(seq 1 60); do
  phase=$(kubectl -n dynatrace get dynakube dynakube -o jsonpath='{.status.phase}' 2>/dev/null || true)
  echo "  phase=${phase:-<pending>}"
  [ "$phase" = "Running" ] && break
  sleep 10
done
[ "$phase" = "Running" ] || { echo "DynaKube 가 Running 이 아닙니다. kubectl -n dynatrace describe dynakube dynakube 로 확인하세요."; exit 1; }

# ---------------------------------------------------------------- 3. easyTravel
log "3/3 easyTravel 배포 (overlay: ${OVERLAY})"
kubectl apply -f "$ROOT/kubernetes/base/namespace.yaml"
if [ -n "${GHCR_TOKEN:-}" ]; then
  kubectl -n easytravel create secret docker-registry ghcr \
    --docker-server=ghcr.io --docker-username="${GHCR_USER:?GHCR_USER 를 설정하세요}" --docker-password="$GHCR_TOKEN" \
    --dry-run=client -o yaml | kubectl apply -f -
  kubectl -n easytravel patch serviceaccount default -p '{"imagePullSecrets":[{"name":"ghcr"}]}'
fi
PANEL_USER="${PANEL_USER:-demo}"
PANEL_PASS="${PANEL_PASSWORD:-}"
PANEL_NEW=false
if [ -z "$PANEL_PASS" ] && ! kubectl -n easytravel get secret problem-panel-auth >/dev/null 2>&1; then
  PANEL_PASS=$(LC_ALL=C tr -dc 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789' </dev/urandom | head -c 16 || true)
  PANEL_NEW=true
fi
if [ -n "$PANEL_PASS" ]; then
  kubectl -n easytravel create secret generic problem-panel-auth \
    --from-literal="htpasswd=${PANEL_USER}:{PLAIN}${PANEL_PASS}" --dry-run=client -o yaml | kubectl apply -f -
fi
kubectl apply -k "$ROOT/kubernetes/overlays/${OVERLAY}"
kubectl -n easytravel wait --for=condition=Available deploy --all --timeout=15m

echo "외부 IP 할당 대기..."
lb_ip() { kubectl -n easytravel get svc "$1" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true; }
HAS_PANEL=false; kubectl -n easytravel get svc problem-panel-lb >/dev/null 2>&1 && HAS_PANEL=true
for _ in $(seq 1 30); do
  IP=$(lb_ip www-lb); PIP=$($HAS_PANEL && lb_ip problem-panel-lb || echo skip)
  [ -n "$IP" ] && [ -n "$PIP" ] && break
  sleep 10
done
log "완료"
echo "  Classic : http://${IP:-<pending>}/"
echo "  Angular : http://${IP:-<pending>}:9079/"
if $HAS_PANEL; then
  echo "  Problem : http://${PIP:-<pending>}:9090/   (계정: ${PANEL_USER})"
  if $PANEL_NEW; then echo "            비밀번호(새로 생성): ${PANEL_PASS}"
  elif [ -z "${PANEL_PASSWORD:-}" ]; then echo "            비밀번호: 기존 값 유지 (docs/problem-patterns.md 의 '비밀번호 확인' 참고)"; fi
fi
echo "  (LB 헬스체크 통과까지 1~2분 더 걸릴 수 있습니다. 주소 확인: kubectl -n easytravel get svc www-lb problem-panel-lb)"
