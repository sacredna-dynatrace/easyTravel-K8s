# GKE 데모 클러스터 생성·삭제

`up` 스크립트 하나로 **GKE Standard 클러스터 → Dynatrace Operator·DynaKube → easyTravel(한글)** 순서로 구성합니다. 데모가 끝나면 `down` 스크립트로 모두 지웁니다. EKS 버전([`../eks/README.md`](../eks/README.md))과 같은 매니페스트(`kubernetes/base`, `components`)를 쓰고, 외부 노출 방식만 다릅니다.

| 파일 | 용도 |
|---|---|
| `up.ps1` / `down.ps1` | Windows PowerShell 5.1·7 용 |
| `up.sh` / `down.sh` | bash 용 (**Google Cloud Shell** 권장, WSL, macOS/Linux) |
| `env.example.ps1` / `env.example.sh` | 환경 변수 템플릿. `env.local.*` 로 복사해서 사용 (git 에 커밋되지 않음) |
| `../../overlays/gke/` | Kustomize overlay (L4 LoadBalancer Service 2개) |

기본 구성: 서울 zone `asia-northeast3-a`, GKE Standard (release channel `regular`), `e2-standard-4` × 2, 노드 이미지 `COS_CONTAINERD`, Dynatrace Operator (Helm OCI), DynaKube `v1beta6` cloudNativeFullStack.

## EKS 와 다른 점

| 항목 | EKS | GKE |
|---|---|---|
| 클러스터 생성 | `eksctl` + `cluster.yaml` | `gcloud container clusters create` (옵션은 `up` 스크립트 안) |
| 외부 노출 | ALB 1개 (AWS Load Balancer Controller 설치) | **L4 Network Load Balancer** (`Service type: LoadBalancer`), 추가 컨트롤러 없음 |
| 접속 주소 | ALB DNS 이름 1개 (`:80`, `:9079`, `:9090`) | **외부 IP 2개** — `www-lb`(`:80`, `:9079`), `problem-panel-lb`(`:9090`) |
| 접속 IP 제한 | Ingress `inbound-cidrs` | Service `loadBalancerSourceRanges` (`overlays/gke/*.yaml`) |
| Dynatrace 클러스터 이름 / host group | `easytravel` / `easytravel-demo` | `easytravel-gke` / `easytravel-gke` (같은 테넌트에서 구분, `DT_CLUSTER_NAME`·`DT_HOST_GROUP` 로 변경) |
| 소요 시간 | 생성 25~30분 / 삭제 15~20분 | 생성 약 15분 / 삭제 약 10분 |

GKE Ingress(GCE L7 Load Balancer)는 80/443 포트만 열 수 있어 EKS 처럼 포트로 Classic / Angular / 패널을 나눌 수 없습니다. 그래서 L4 LoadBalancer Service 를 씁니다. 패널은 다른 Deployment 라 IP 가 하나 더 생깁니다.

> **GKE Autopilot 은 사용하지 않습니다.** Dynatrace 공식 문서 기준 Autopilot 은 `applicationMonitoring` 만 지원하고 `cloudNativeFullStack` 은 지원 대상이 아닙니다 → [Supported distributions](https://docs.dynatrace.com/docs/ingest-from/setup-on-k8s/deployment/supported-technologies). GKE Standard 는 별도 설정 없이 cloudNativeFullStack 을 지원합니다.

## 매일 쓰는 순서 (요약)

**PowerShell (Windows)** — repo 루트에서

```powershell
. .\kubernetes\cluster\gke\env.local.ps1                                   # 새 창마다 (앞의 점 + 공백)
powershell -ExecutionPolicy Bypass -File .\kubernetes\cluster\gke\up.ps1   # 생성 (약 15분)
powershell -ExecutionPolicy Bypass -File .\kubernetes\cluster\gke\down.ps1 # 삭제 (약 10분)
```

**bash (Cloud Shell 등)** — repo 루트에서

```bash
source kubernetes/cluster/gke/env.local.sh
./kubernetes/cluster/gke/up.sh
./kubernetes/cluster/gke/down.sh
```

`up` 이 끝나면 접속 주소가 출력됩니다. **외부 IP 는 만들 때마다 바뀝니다.**

```
Classic : http://34.64.x.x/
Angular : http://34.64.x.x:9079/
Problem : http://34.64.y.y:9090/   (계정: demo)
          비밀번호(새로 생성): xxxxxxxxxxxxxxxx
```

## 1. 준비 (최초 1회)

### 도구 설치

**Google Cloud Shell** 에는 `gcloud`, `kubectl`, `helm`, `gke-gcloud-auth-plugin` 이 모두 들어 있어 바로 `up.sh` 를 실행할 수 있습니다 (repo 를 `git clone` 한 뒤).

Windows 에서는 한 줄씩 실행합니다.

```powershell
winget install Google.CloudSDK
winget install Kubernetes.kubectl
winget install Helm.Helm
```

새 PowerShell 창에서 GKE 인증 플러그인을 설치하고 확인합니다.

```powershell
gcloud components install gke-gcloud-auth-plugin
gcloud --version; kubectl version --client; helm version; gke-gcloud-auth-plugin --version
```

### GCP 로그인과 프로젝트

```powershell
gcloud auth login
gcloud config set project <gcp-project-id>
gcloud projects describe <gcp-project-id>
```

- 프로젝트에 **결제 계정**이 연결되어 있어야 합니다.
- 필요한 권한: Kubernetes Engine Admin, Compute Admin(또는 Compute Network Admin), Service Account User, Service Usage Admin (API 활성화). 프로젝트 Owner/Editor 면 충분합니다.
- `up` 이 처음 실행될 때 `container.googleapis.com`, `compute.googleapis.com` API 를 활성화합니다 (1~2분).

### Dynatrace 토큰 2개 — classic access token (`dt0c01.`)

EKS 와 같습니다 → [`../eks/README.md` 1장 "Dynatrace 토큰 2개"](../eks/README.md#dynatrace-토큰-2개--classic-access-token-dt0c01). 필요한 권한은 공식 문서 [Tokens and permissions](https://docs.dynatrace.com/docs/ingest-from/setup-on-k8s/deployment/tokens-permissions)를 참고하세요.

### 환경 변수 파일 만들기

```powershell
Copy-Item .\kubernetes\cluster\gke\env.example.ps1 .\kubernetes\cluster\gke\env.local.ps1
notepad .\kubernetes\cluster\gke\env.local.ps1
```

```bash
cp kubernetes/cluster/gke/env.example.sh kubernetes/cluster/gke/env.local.sh
vi kubernetes/cluster/gke/env.local.sh
```

`[CUSTOMIZE]` 표시된 값(`GCP_PROJECT`, 테넌트 URL, 토큰 2개)을 채웁니다. `env.local.*` 은 `.gitignore` 에 등록되어 커밋되지 않습니다.

| 환경 변수 | 기본값 | 설명 |
|---|---|---|
| `GCP_PROJECT` | (필수) | GCP 프로젝트 ID. Cloud Shell 에서는 `DEVSHELL_PROJECT_ID` 를 대신 사용 |
| `GCP_ZONE` | `asia-northeast3-a` | 서울 zone. zonal 클러스터는 결제 계정당 1개까지 컨트롤 플레인 관리비 무료 크레딧 적용 |
| `GKE_CLUSTER` | `easytravel-demo` | 클러스터 이름 |
| `GKE_MACHINE_TYPE` | `e2-standard-4` | 4 vCPU / 16 GiB. easyTravel 이미지는 amd64 전용 → **Arm(t2a, c4a) 사용 금지** |
| `GKE_NUM_NODES` | `2` | 노드 수 |
| `DT_CLUSTER_NAME` | `easytravel-gke` | Dynatrace Kubernetes 앱에 표시될 클러스터 이름 |
| `DT_HOST_GROUP` | `easytravel-gke` | OneAgent host group |
| `PANEL_USER` / `PANEL_PASSWORD` | `demo` / 자동 생성 | Problem pattern 패널 계정 |

## 2. 생성 (약 15분)

| 단계 | 내용 | 소요 |
|---|---|---|
| 1/3 | API 활성화, GKE Standard 클러스터 생성, kubeconfig 등록 | 5~10분 |
| 2/3 | Dynatrace Operator 설치(Helm OCI), 토큰 Secret·DynaKube 적용(클러스터 이름·host group 치환), `Running` 대기 | 3~5분 |
| 3/3 | easyTravel 배포 (`overlays/gke`), 외부 IP 출력 | 3~5분 |

- 중간에 실패해도 같은 명령으로 다시 실행하면 이미 만들어진 부분은 건너뜁니다.
- 클러스터 옵션: Cloud Logging/Monitoring 은 `SYSTEM` 만, Managed Service for Prometheus 는 끔 (데모 비용 절감, 관측은 Dynatrace 로). 필요하면 `up` 스크립트의 `gcloud container clusters create` 줄을 고치세요.
- LoadBalancer 는 기본적으로 인터넷에 공개됩니다. 접속 IP 를 제한하려면 `kubernetes/overlays/gke/service-lb.yaml`, `panel-lb.yaml` 의 `loadBalancerSourceRanges` 주석을 풀고 사무실 IP 를 넣은 뒤 `kubectl apply -k kubernetes/overlays/gke`.
- 한글/영문 UI, problem pattern 모드는 `kubernetes/overlays/gke/kustomization.yaml` 의 components 로 정합니다 (EKS 와 같은 방식). `problem-panel` 을 끄면 같은 파일의 `panel-lb.yaml` 줄도 주석 처리하세요.

## 3. 확인

```bash
kubectl -n dynatrace get dynakube           # PHASE = Running
kubectl -n dynatrace get pods               # oneagent (노드 수만큼), activegate, operator, webhook, csi-driver
kubectl -n easytravel get pods              # 모두 Running / READY 1/1
kubectl -n easytravel get svc www-lb problem-panel-lb   # EXTERNAL-IP
```

Dynatrace 에서 5~10분 안에 다음이 보이면 정상입니다.

- [ ] Kubernetes 앱에 `easytravel-gke` 클러스터
- [ ] Hosts 에 GKE 노드 2대 (host group `easytravel-gke`, 클라우드 정보 Google Cloud)
- [ ] Services 에 frontend, angular-frontend, backend 및 MongoDB 호출
- [ ] Frontend RUM 애플리케이션에 loadgen 세션
- [ ] `http://<PANEL-IP>:9090/` 패널에서 `CPULoad` 를 켜고 몇 분 뒤 Problems 에 Davis problem 이 열리는지

Problem pattern 명령줄 제어(`kubernetes/problem.ps1` / `problem.sh`)는 `kubectl exec` 방식이라 GKE 에서도 그대로 동작합니다.

## 4. 삭제 (약 10분)

1. `easytravel` namespace 를 지워 GKE 가 LoadBalancer 용 GCP 리소스(forwarding rule, backend service, health check, 방화벽 규칙)를 정리하게 합니다. 남은 forwarding rule 이 0 이 될 때까지 기다립니다.
2. DynaKube 를 지웁니다.
3. `gcloud container clusters delete` 로 클러스터와 노드를 지웁니다.

삭제 확인 — 아래 두 명령이 모두 비어 있으면 요금이 나오는 리소스가 남지 않은 것입니다.

```bash
gcloud container clusters list --project <gcp-project-id>
gcloud compute forwarding-rules list --project <gcp-project-id> --filter="description~easytravel/"
```

## 비용

클러스터가 떠 있는 동안 GKE 클러스터 관리비(zonal 1개는 무료 크레딧으로 상쇄), Compute Engine 노드 2대, Persistent Disk, 외부 IP·Network Load Balancer 요금이 시간 단위로 나옵니다. 데모가 끝나면 바로 `down` 하세요. 노드 비용을 더 줄이려면 `up` 스크립트의 create 옵션에 `--spot` 을 추가할 수 있습니다 (데모 중 노드가 회수될 수 있음).

## 문제 해결

| 증상 | 원인 / 조치 |
|---|---|
| `gke-gcloud-auth-plugin 이 없습니다` / kubectl `executable gke-gcloud-auth-plugin not found` | `gcloud components install gke-gcloud-auth-plugin` 후 새 창. winget 설치본에서 components 명령이 막히면 관리자 PowerShell 에서 실행 |
| `Kubernetes Engine API has not been used in project` | API 미활성화. `gcloud services enable container.googleapis.com --project <id>` (`up` 이 자동 실행하지만 권한이 없으면 실패) |
| `ZONE_RESOURCE_POOL_EXHAUSTED` / 쿼터 부족 | `GCP_ZONE` 을 `asia-northeast3-b`/`-c` 로 바꾸거나 `GKE_MACHINE_TYPE` 을 `n2-standard-4` 로 변경. 쿼터는 IAM 및 관리자 → 할당량 에서 `CPUS` 확인 |
| `Insufficient regional quota ... IN_USE_ADDRESSES` | 외부 IP 쿼터 부족. 다른 프로젝트 리소스 정리 또는 쿼터 증가 요청 |
| DynaKube `Error` | EKS 문서의 같은 항목과 동일 (token 이 classic `dt0c01.` 인지, apiUrl 끝 `/api`) → [`../eks/README.md` 문제 해결](../eks/README.md#문제-해결) |
| `kubectl get svc www-lb` EXTERNAL-IP 가 계속 `<pending>` | `kubectl -n easytravel describe svc www-lb` 의 Events 확인. 외부 IP 쿼터, 조직 정책(`constraints/compute.restrictLoadBalancerCreationForTypes`) 여부 확인 |
| 외부 IP 로 접속이 안 됨 (timeout) | `loadBalancerSourceRanges` 에 내 IP 가 빠졌는지 확인. LB 헬스체크 통과까지 1~2분 대기 |
| Pod 가 `ImagePullBackOff` | GHCR 패키지가 private. Public 으로 바꾸거나 `GHCR_USER`/`GHCR_TOKEN` 설정 후 `up` 재실행 |
| 패널 관련 증상 (로그인 반복, HTTP 502, pattern 이 꺼짐) | EKS 문서의 문제 해결 표와 같음. 모드 변경 후 적용은 `kubectl apply -k kubernetes/overlays/gke` |
| `down` 후 forwarding rule 이 남음 | `gcloud compute forwarding-rules list --filter="description~easytravel/"` 로 확인 후 `gcloud compute forwarding-rules delete <name> --region asia-northeast3` |
