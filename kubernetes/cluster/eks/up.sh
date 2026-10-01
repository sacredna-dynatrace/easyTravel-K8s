#!/usr/bin/env bash
# easyTravel 데모 환경 한 번에 구성 (EKS)
#   1) EKS 클러스터  2) AWS Load Balancer Controller  3) Dynatrace Operator + DynaKube  4) easyTravel
# 다시 실행해도 안전 (이미 있는 리소스는 건너뛰거나 갱신)
#
# 필요 도구: aws, eksctl, kubectl, helm   (AWS CloudShell / WSL / Git Bash)
# 필요 환경 변수:
#   DT_API_URL           예) https://abc12345.live.dynatrace.com/api
#   DT_OPERATOR_TOKEN    Operator token
#   DT_INGEST_TOKEN      Data Ingest token
# 선택 환경 변수:
#   OVERLAY=eks          배포할 overlay (기본 eks. 한글/영문은 overlays/eks/kustomization.yaml 의 components/korean 로 결정)
#   GHCR_USER / GHCR_TOKEN   GHCR 패키지가 private 일 때 (read:packages 권한 PAT)
set -euo pipefail

CLUSTER="${CLUSTER:-easytravel-demo}"          # cluster.yaml 의 metadata.name 과 같아야 함
REGION="${REGION:-ap-northeast-2}"
OVERLAY="${OVERLAY:-eks}"
LBC_VERSION="v3.5.0"                           # AWS Load Balancer Controller (helm chart 3.5.0)
LBC_CHART_VERSION="3.5.0"

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
log() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

# ---------------------------------------------------------------- 0. 사전 확인
for t in aws eksctl kubectl helm; do command -v "$t" >/dev/null || { echo "필요한 도구가 없습니다: $t"; exit 1; }; done
: "${DT_API_URL:?DT_API_URL 환경 변수를 설정하세요 (예: https://abc12345.live.dynatrace.com/api)}"
: "${DT_OPERATOR_TOKEN:?DT_OPERATOR_TOKEN 환경 변수를 설정하세요}"
: "${DT_INGEST_TOKEN:?DT_INGEST_TOKEN 환경 변수를 설정하세요}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
log "AWS 계정 ${ACCOUNT_ID} / 리전 ${REGION} / 클러스터 ${CLUSTER} / overlay ${OVERLAY}"

# ---------------------------------------------------------------- 1. EKS 클러스터 (약 15~20분)
if eksctl get cluster --name "$CLUSTER" --region "$REGION" >/dev/null 2>&1; then
  log "1/4 클러스터가 이미 있습니다 → kubeconfig 갱신"
  aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION"
else
  log "1/4 EKS 클러스터 생성 (15~20분 소요)"
  eksctl create cluster -f "$HERE/cluster.yaml"
fi
kubectl get nodes -o wide

# ---------------------------------------------------------------- 2. AWS Load Balancer Controller
log "2/4 AWS Load Balancer Controller ${LBC_VERSION}"
POLICY_NAME="AWSLoadBalancerControllerIAMPolicy-${LBC_VERSION//./_}"
POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"
if ! aws iam get-policy --policy-arn "$POLICY_ARN" >/dev/null 2>&1; then
  curl -sSfL -o /tmp/lbc-iam-policy.json \
    "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/${LBC_VERSION}/docs/install/iam_policy.json"
  aws iam create-policy --policy-name "$POLICY_NAME" --policy-document file:///tmp/lbc-iam-policy.json >/dev/null
fi
eksctl create iamserviceaccount --cluster "$CLUSTER" --region "$REGION" \
  --namespace kube-system --name aws-load-balancer-controller \
  --attach-policy-arn "$POLICY_ARN" --override-existing-serviceaccounts --approve
VPC_ID=$(aws eks describe-cluster --name "$CLUSTER" --region "$REGION" --query cluster.resourcesVpcConfig.vpcId --output text)
helm repo add eks https://aws.github.io/eks-charts >/dev/null 2>&1 || true
helm repo update eks >/dev/null
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system --version "$LBC_CHART_VERSION" \
  --set clusterName="$CLUSTER" --set region="$REGION" --set vpcId="$VPC_ID" \
  --set serviceAccount.create=false --set serviceAccount.name=aws-load-balancer-controller \
  --wait
kubectl -n kube-system rollout status deploy/aws-load-balancer-controller --timeout=5m

# ---------------------------------------------------------------- 3. Dynatrace Operator + DynaKube
log "3/4 Dynatrace Operator + DynaKube"
# 빈 레지스트리 설정으로 credential helper 를 쓰지 않고 익명 pull (up.ps1 주석 참고)
REG_DIR=$(mktemp -d); echo '{"auths":{"none.invalid":{}}}' > "$REG_DIR/config.json"
DOCKER_CONFIG="$REG_DIR" helm upgrade --install dynatrace-operator oci://public.ecr.aws/dynatrace/dynatrace-operator \
  --registry-config "$REG_DIR/config.json" \
  --create-namespace --namespace dynatrace --wait --timeout 10m
kubectl -n dynatrace create secret generic dynakube \
  --from-literal="apiToken=${DT_OPERATOR_TOKEN}" \
  --from-literal="dataIngestToken=${DT_INGEST_TOKEN}" \
  --dry-run=client -o yaml | kubectl apply -f -
sed "s#https://ENVIRONMENTID.live.dynatrace.com/api#${DT_API_URL}#" "$ROOT/dynatrace/dynakube.yaml" | kubectl apply -f -
echo "DynaKube 가 Running 이 될 때까지 대기 (최대 10분)..."
for _ in $(seq 1 60); do
  phase=$(kubectl -n dynatrace get dynakube dynakube -o jsonpath='{.status.phase}' 2>/dev/null || true)
  echo "  phase=${phase:-<pending>}"
  [ "$phase" = "Running" ] && break
  sleep 10
done
[ "$phase" = "Running" ] || { echo "DynaKube 가 Running 이 아닙니다. kubectl -n dynatrace describe dynakube dynakube 로 확인하세요."; exit 1; }

# ---------------------------------------------------------------- 4. easyTravel
log "4/4 easyTravel 배포 (overlay: ${OVERLAY})"
kubectl apply -f "$ROOT/kubernetes/base/namespace.yaml"
if [ -n "${GHCR_TOKEN:-}" ]; then
  kubectl -n easytravel create secret docker-registry ghcr \
    --docker-server=ghcr.io --docker-username="${GHCR_USER:?GHCR_USER 를 설정하세요}" --docker-password="$GHCR_TOKEN" \
    --dry-run=client -o yaml | kubectl apply -f -
  kubectl -n easytravel patch serviceaccount default -p '{"imagePullSecrets":[{"name":"ghcr"}]}'
fi
kubectl apply -k "$ROOT/kubernetes/overlays/${OVERLAY}"
kubectl -n easytravel wait --for=condition=Available deploy --all --timeout=15m

echo "ALB 주소 할당 대기..."
for _ in $(seq 1 30); do
  ALB=$(kubectl -n easytravel get ingress easytravel-classic -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
  [ -n "$ALB" ] && break
  sleep 10
done
log "완료"
echo "  Classic : http://${ALB:-<pending>}/"
echo "  Angular : http://${ALB:-<pending>}:9079/"
echo "  (ALB DNS 전파와 target 등록에 2~3분 더 걸릴 수 있습니다)"
