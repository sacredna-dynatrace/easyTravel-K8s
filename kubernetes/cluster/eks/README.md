# EKS 데모 클러스터 생성·삭제

`up` 스크립트 하나로 **EKS 클러스터 → AWS Load Balancer Controller → Dynatrace Operator·DynaKube → easyTravel(한글)** 순서로 구성합니다. 데모가 끝나면 `down` 스크립트로 모두 지우고, 필요할 때 다시 `up` 하면 됩니다.

| 파일 | 용도 |
|---|---|
| `cluster.yaml` | eksctl 클러스터 정의 (서울 `ap-northeast-2`, Kubernetes 1.35, `m5.xlarge` × 2) |
| `up.ps1` / `down.ps1` | Windows PowerShell 5.1·7 용 |
| `up.sh` / `down.sh` | bash 용 (AWS CloudShell, WSL, Git Bash, macOS/Linux) |

## 1. 준비 (최초 1회)

### 도구 설치 (Windows)

```powershell
winget install Amazon.AWSCLI
winget install Kubernetes.kubectl
winget install Helm.Helm
choco install eksctl          # 또는 scoop install eksctl, 또는 GitHub release 의 eksctl_windows_amd64.zip
```

설치 후 새 PowerShell 창에서 `aws --version; eksctl version; kubectl version --client; helm version` 으로 확인합니다.

### AWS 자격 증명

```powershell
aws configure          # 또는 aws sso login --profile <프로필>
aws sts get-caller-identity
```

eksctl 은 CloudFormation, EC2(VPC·서브넷·NAT), EKS, IAM(역할·OIDC provider·정책) 리소스를 만듭니다. 해당 권한이 있는 계정이어야 합니다.

### Dynatrace 토큰 2개

- **Operator token** (`apiToken`)
- **Data Ingest token** (`dataIngestToken`)

가장 쉬운 방법은 Dynatrace **Kubernetes** 앱의 **Add cluster** 화면에서 토큰을 생성하는 것입니다. 필요한 권한은 공식 문서 [Tokens and permissions](https://docs.dynatrace.com/docs/ingest-from/setup-on-k8s/deployment/tokens-permissions)를 참고하세요.

## 2. 생성 (약 25~30분)

PowerShell 에서 repo 루트(`easyTravel-Docker`)로 이동한 뒤:

```powershell
$env:DT_API_URL        = "https://<environment-id>.live.dynatrace.com/api"
$env:DT_OPERATOR_TOKEN = "<Operator token>"
$env:DT_INGEST_TOKEN   = "<Data Ingest token>"

# GHCR 패키지를 private 로 둔 경우에만 (read:packages 권한 PAT)
# $env:GHCR_USER  = "sacredna-dynatrace"
# $env:GHCR_TOKEN = "<PAT>"

powershell -ExecutionPolicy Bypass -File .\kubernetes\cluster\eks\up.ps1
```

- 실행 정책 설정을 바꾸지 않고 이번 실행에만 `Bypass` 를 적용합니다.
- 한글/영문 UI 는 `kubernetes/overlays/eks/kustomization.yaml` 의 `../../components/korean` 줄로 정합니다 (현재 한글). 영문으로 띄우려면 그 줄을 주석 처리하세요.
- 중간에 실패해도 같은 명령으로 다시 실행하면 이미 만들어진 부분은 건너뜁니다.

| 단계 | 내용 | 소요 |
|---|---|---|
| 1/4 | EKS 클러스터 + 관리형 노드그룹 생성, kubeconfig 등록 | 15~20분 |
| 2/4 | IAM 정책·IRSA 생성, AWS Load Balancer Controller v3.5.0 설치 | 2분 |
| 3/4 | Dynatrace Operator 설치, 토큰 Secret·DynaKube 적용, `Running` 대기 | 3~5분 |
| 4/4 | easyTravel 배포 (`overlays/eks`), ALB 주소 출력 | 5분 |

완료되면 접속 주소가 출력됩니다.

```
Classic : http://k8s-easytravel-xxxx.ap-northeast-2.elb.amazonaws.com/
Angular : http://k8s-easytravel-xxxx.ap-northeast-2.elb.amazonaws.com:9079/
```

ALB 는 기본적으로 인터넷에 공개됩니다(`internet-facing`). 접속 IP 를 제한하려면 `kubernetes/overlays/eks/ingress.yaml` 의 `inbound-cidrs` 주석을 풀고 사무실 IP 를 넣으세요.

## 3. 확인

```powershell
kubectl -n dynatrace get dynakube           # PHASE = Running
kubectl -n dynatrace get pods               # oneagent (노드 수만큼), activegate, operator, webhook, csi-driver
kubectl -n easytravel get pods              # 모두 Running / READY 1/1
kubectl -n easytravel logs deploy/loadgen-classic --tail=50
```

Dynatrace 에서는 Kubernetes 앱에 `easytravel-demo` 클러스터가, Services 에 easyTravel 서비스가 몇 분 안에 나타납니다. loadgen 이 만든 RUM 세션은 frontend 애플리케이션에서 볼 수 있습니다.

## 4. 삭제

```powershell
powershell -ExecutionPolicy Bypass -File .\kubernetes\cluster\eks\down.ps1
```

1. Ingress 를 먼저 지워 Load Balancer Controller 가 ALB 를 정리하게 합니다. 이 순서를 건너뛰면 ALB·보안그룹이 남아 VPC 삭제가 실패할 수 있습니다.
2. easyTravel namespace 와 DynaKube 를 지웁니다.
3. `eksctl delete cluster` 로 노드그룹, 클러스터, VPC, IAM 역할(CloudFormation 스택)을 지웁니다 (10~15분).

IAM 정책 `AWSLoadBalancerControllerIAMPolicy-v3_5_0` 은 다음 `up` 에서 재사용하도록 남겨 둡니다.

## 비용

클러스터가 떠 있는 동안 EKS 컨트롤 플레인, EC2 노드 2대, NAT Gateway, ALB, EBS 볼륨 요금이 시간 단위로 나옵니다. 데모가 끝나면 바로 `down` 하세요. 노드 비용을 줄이려면 `cluster.yaml` 의 `spot: true` 주석을 풀 수 있습니다 (데모 중 노드가 회수될 수 있음).

## 문제 해결

| 증상 | 확인 |
|---|---|
| `eksctl create cluster` 실패 | AWS CloudFormation 콘솔에서 `eksctl-easytravel-demo-*` 스택의 이벤트 확인. 실패한 스택은 `eksctl delete cluster -f cluster.yaml` 로 정리 후 재시도 |
| DynaKube 가 `Running` 이 안 됨 | `kubectl -n dynatrace describe dynakube dynakube`, `kubectl -n dynatrace logs deploy/dynatrace-operator`. 대부분 apiUrl 오타나 토큰 권한 문제 |
| Pod 가 `ImagePullBackOff` | GHCR 패키지가 private. Public 으로 바꾸거나 `GHCR_USER`/`GHCR_TOKEN` 을 설정하고 `up` 재실행 |
| Ingress 에 ADDRESS 가 안 생김 | `kubectl -n kube-system logs deploy/aws-load-balancer-controller` |
| 같은 이름으로 다시 만들 때 실패 | 이전 `down` 이 끝까지 됐는지 CloudFormation 스택이 남아 있는지 확인 |
