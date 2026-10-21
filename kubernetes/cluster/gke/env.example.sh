# up/down 실행 전에 필요한 환경 변수 (bash) — GKE
#   1) cp kubernetes/cluster/gke/env.example.sh kubernetes/cluster/gke/env.local.sh
#   2) env.local.sh 에 실제 값을 넣기 (.gitignore 에 등록되어 커밋되지 않음)
#   3) 새 셸마다:  source kubernetes/cluster/gke/env.local.sh
# 토큰 값은 채팅·이슈·커밋에 붙여 넣지 마세요.

export GCP_PROJECT="<gcp-project-id>"                              # [CUSTOMIZE] GCP 프로젝트 ID (Cloud Shell 이면 $DEVSHELL_PROJECT_ID)
export GCP_ZONE="asia-northeast3-a"                                # [CUSTOMIZE] 서울 리전 zone
# export GKE_CLUSTER="easytravel-demo"                             # [CUSTOMIZE] 클러스터 이름
# export GKE_MACHINE_TYPE="e2-standard-4"                          # [CUSTOMIZE] amd64 머신 타입만 사용
# export GKE_NUM_NODES="2"

export DT_API_URL="https://<environment-id>.live.dynatrace.com/api"  # [CUSTOMIZE] 테넌트 URL (끝에 /api)
export DT_OPERATOR_TOKEN="dt0c01.<...>"                            # [CUSTOMIZE] classic access token
export DT_INGEST_TOKEN="dt0c01.<...>"                              # [CUSTOMIZE] classic access token, Data Ingest 용

# export DT_CLUSTER_NAME="easytravel-gke"                          # [CUSTOMIZE] Dynatrace 에 표시될 클러스터 이름
# export DT_HOST_GROUP="easytravel-gke"                            # [CUSTOMIZE] host group

# export PANEL_USER="demo"
# export PANEL_PASSWORD="<데모용 비밀번호>"                       # [CUSTOMIZE]

# export GHCR_USER="sacredna-dynatrace"
# export GHCR_TOKEN="<PAT>"

echo "GCP_PROJECT=${GCP_PROJECT} / GCP_ZONE=${GCP_ZONE} / DT_API_URL=${DT_API_URL} / operator token prefix=${DT_OPERATOR_TOKEN:0:7} / ingest token prefix=${DT_INGEST_TOKEN:0:7}"
