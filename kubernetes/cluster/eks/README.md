# EKS 데모 클러스터 생성·삭제

`up` 스크립트 하나로 **EKS 클러스터 → AWS Load Balancer Controller → Dynatrace Operator·DynaKube → easyTravel(한글)** 순서로 구성합니다. 데모가 끝나면 `down` 스크립트로 모두 지우고, 필요할 때 다시 `up` 하면 됩니다.

| 파일 | 용도 |
|---|---|
| `cluster.yaml` | eksctl 클러스터 정의 (서울 `ap-northeast-2`, Kubernetes 1.35, `m5.xlarge` × 2) |
| `up.ps1` / `down.ps1` | Windows PowerShell 5.1·7 용 |
| `up.sh` / `down.sh` | bash 용 (AWS CloudShell, WSL, Git Bash, macOS/Linux) |
| `env.example.ps1` | 환경 변수 템플릿. `env.local.ps1` 로 복사해서 사용 (git 에 커밋되지 않음) |

검증된 구성 (2026-10): eksctl 0.230, Kubernetes 1.35, AWS Load Balancer Controller v3.5.0, Dynatrace Operator 1.10.x (Helm OCI), DynaKube `v1beta6` cloudNativeFullStack.

## 매일 쓰는 순서 (요약)

```powershell
cd C:\tools\easyTravel-K8s\easyTravel-Docker      # repo 루트
. .\kubernetes\cluster\eks\env.local.ps1          # 새 PowerShell 창마다 (앞의 점 + 공백)

# 생성 (25~30분)
powershell -ExecutionPolicy Bypass -File .\kubernetes\cluster\eks\up.ps1

# 삭제 (15~20분)
powershell -ExecutionPolicy Bypass -File .\kubernetes\cluster\eks\down.ps1
```

`up` 이 끝나면 접속 주소가 출력됩니다. **ALB 주소는 만들 때마다 바뀝니다.**

```
Classic : http://k8s-easytravel-xxxx.ap-northeast-2.elb.amazonaws.com/
Angular : http://k8s-easytravel-xxxx.ap-northeast-2.elb.amazonaws.com:9079/
Problem : http://k8s-easytravel-xxxx.ap-northeast-2.elb.amazonaws.com:9090/   (계정: demo)
          비밀번호(새로 생성): xxxxxxxxxxxxxxxx
```

`Problem` 은 problem pattern 웹 제어 패널입니다. 비밀번호는 클러스터를 처음 만들 때만 자동 생성되어 표시되므로 메모해 두거나 `env.local.ps1` 에 `PANEL_PASSWORD` 를 정해 두세요. 자세한 내용은 [`docs/problem-patterns.md`](../../../docs/problem-patterns.md).

## 1. 준비 (최초 1회)

### 도구 설치 (Windows)

한 줄씩 실행합니다.

```powershell
winget install Amazon.AWSCLI
winget install Kubernetes.kubectl
winget install Helm.Helm
```

eksctl 은 `choco install eksctl`, `scoop install eksctl`, 또는 GitHub release 의 `eksctl_windows_amd64.zip` 을 풀어 PATH 에 추가합니다.

설치 후 **새 PowerShell 창**에서 확인합니다.

```powershell
aws --version; eksctl version; kubectl version --client; helm version
```

### AWS 자격 증명 (EKS 용 프로필)

EKS·EC2·CloudFormation·IAM 권한이 있는 키를 별도 프로필로 등록합니다. 기본 프로필에 EKS 권한이 없으면 `eks:DescribeClusterVersions` AccessDenied 로 실패합니다.

```powershell
aws configure --profile eks-demo
$env:AWS_PROFILE = "eks-demo"
aws sts get-caller-identity
```

`$env:AWS_PROFILE` 은 **현재 PowerShell 창에만** 적용됩니다. 새 창에서는 다시 설정해야 합니다 (`env.local.ps1` 이 대신 해 줍니다). 프로필이 다르면 kubectl 이 다른 IAM 사용자로 접속해 `Unauthorized` 가 납니다.

### Dynatrace 토큰 2개 — classic access token (`dt0c01.`)

| Secret 키 | 환경 변수 | 용도 |
|---|---|---|
| `apiToken` | `DT_OPERATOR_TOKEN` | Operator token |
| `dataIngestToken` | `DT_INGEST_TOKEN` | Data Ingest token |

- 두 토큰 모두 **classic access token(`dt0c01.`)** 을 사용합니다. Platform token(`dt0s16.`)을 넣으면 Operator 가 공용 레지스트리 이미지 목록에서 ActiveGate 이미지를 찾지 못해 DynaKube 가 `Error` 가 됩니다.
- 쉬운 방법은 Dynatrace **Kubernetes** 앱의 **Add cluster** 화면에서 토큰을 생성하는 것입니다. 필요한 권한은 공식 문서 [Tokens and permissions](https://docs.dynatrace.com/docs/ingest-from/setup-on-k8s/deployment/tokens-permissions)를 참고하세요.
- `up` 은 실행할 때마다 Secret `dynakube` 를 환경 변수 값으로 **덮어씁니다**. 클러스터에서 토큰을 고쳐도 환경 변수가 틀리면 다음 `up` 에서 다시 틀린 값이 들어갑니다.
- 토큰이 `dt0c01.` 로 시작하지 않으면 `up` 이 경고를 출력합니다.

### 환경 변수 파일 만들기

```powershell
Copy-Item .\kubernetes\cluster\eks\env.example.ps1 .\kubernetes\cluster\eks\env.local.ps1
notepad .\kubernetes\cluster\eks\env.local.ps1
```

- `[CUSTOMIZE]` 표시된 값(AWS 프로필, 테넌트 URL, 토큰 2개)을 채웁니다.
- `env.local.ps1` 은 `.gitignore` 에 등록되어 있어 커밋되지 않습니다.
- 토큰 값은 채팅·이슈·커밋에 붙여 넣지 마세요.

## 2. 생성 (약 25~30분)

```powershell
. .\kubernetes\cluster\eks\env.local.ps1
powershell -ExecutionPolicy Bypass -File .\kubernetes\cluster\eks\up.ps1
```

- 실행 정책 설정을 바꾸지 않고 이번 실행에만 `Bypass` 를 적용합니다.
- 한글/영문 UI 는 `kubernetes/overlays/eks/kustomization.yaml` 의 `../../components/korean` 줄로 정합니다 (현재 한글). 영문으로 띄우려면 그 줄을 주석 처리하세요.
- 중간에 실패해도 같은 명령으로 다시 실행하면 이미 만들어진 부분은 건너뜁니다.

| 단계 | 내용 | 소요 |
|---|---|---|
| 1/4 | EKS 클러스터 + 관리형 노드그룹 생성, kubeconfig 등록 | 15~20분 |
| 2/4 | IAM 정책·IRSA 생성, AWS Load Balancer Controller v3.5.0 설치 | 2분 |
| 3/4 | Dynatrace Operator 설치(Helm OCI), 토큰 Secret·DynaKube 적용, `Running` 대기 | 3~5분 |
| 4/4 | easyTravel 배포 (`overlays/eks`), ALB 주소 출력 | 5분 |

참고:

- Helm OCI pull 은 Windows 자격 증명 관리자를 거치지 않도록 임시 레지스트리 설정으로 익명 pull 합니다. "A specified logon session does not exist" 오류를 피하기 위한 처리입니다.
- ALB 는 기본적으로 인터넷에 공개됩니다(`internet-facing`). 접속 IP 를 제한하려면 `kubernetes/overlays/eks/ingress.yaml` 의 `inbound-cidrs` 주석을 풀고 사무실 IP 를 넣으세요.
- 출력된 주소가 비어 있으면(`http:///`) 1~2분 뒤 `kubectl -n easytravel get ingress` 로 ADDRESS 를 다시 확인하세요. 두 Ingress 는 같은 ALB 를 공유하므로 주소가 같습니다.

## 3. 확인

```powershell
kubectl -n dynatrace get dynakube           # PHASE = Running
kubectl -n dynatrace get pods               # oneagent (노드 수만큼), activegate, operator, webhook, csi-driver
kubectl -n easytravel get pods              # 모두 Running / READY 1/1
kubectl -n easytravel get ingress           # ADDRESS = ALB 주소
kubectl -n easytravel logs deploy/loadgen-classic --tail=50
```

Dynatrace 에서 5~10분 안에 다음이 보이면 정상입니다.

- [ ] Kubernetes 앱에 `easytravel` 클러스터 (이름은 `dynatrace/dynakube.yaml` 의 `automatic-kubernetes-api-monitoring-cluster-name` annotation)
- [ ] Hosts 에 노드 2대 (host group `easytravel-demo`)
- [ ] Services 에 easyTravel 서비스 (frontend, backend, angular-frontend 등)
- [ ] Frontend RUM 애플리케이션에 loadgen 세션
- [ ] `http://<ALB>:9090/` 패널에서 `CPULoad` 를 켜고 몇 분 뒤 Problems 에 Davis problem 이 열리는지, 끈 뒤 닫히는지

Problem pattern 은 기본이 웹 패널 모드라 **켜기 전에는 장애가 발생하지 않습니다.** 명령줄로는 `.\kubernetes\problem.ps1 list / on <이름> / off <이름> / reset` 을 씁니다.

클러스터를 새로 만들 때마다 노드(호스트)와 Pod 엔티티는 새 ID 로 생깁니다. 이전 엔티티는 보존 기간이 지나면 사라집니다.

## 4. 삭제 (약 15~20분)

```powershell
. .\kubernetes\cluster\eks\env.local.ps1
powershell -ExecutionPolicy Bypass -File .\kubernetes\cluster\eks\down.ps1
```

1. Ingress 를 먼저 지워 Load Balancer Controller 가 ALB 를 정리하게 합니다. 이 순서를 건너뛰면 ALB·보안그룹이 남아 VPC 삭제가 실패할 수 있습니다.
2. easyTravel namespace 와 DynaKube 를 지웁니다.
3. `eksctl delete cluster` 로 노드그룹, 클러스터, VPC, IAM 역할(CloudFormation 스택)을 지웁니다.

IAM 정책 `AWSLoadBalancerControllerIAMPolicy-v3_5_0` 은 다음 `up` 에서 재사용하도록 남겨 둡니다 (요금 없음).

삭제가 끝났는지 확인합니다. 아래 세 명령이 모두 비어 있으면 요금이 나오는 리소스가 남지 않은 것입니다.

```powershell
eksctl get cluster --region ap-northeast-2
aws cloudformation list-stacks --region ap-northeast-2 --stack-status-filter DELETE_FAILED CREATE_COMPLETE UPDATE_COMPLETE --query "StackSummaries[?starts_with(StackName,'eksctl-easytravel-demo')].StackName"
aws elbv2 describe-load-balancers --region ap-northeast-2 --query "LoadBalancers[?starts_with(LoadBalancerName,'k8s-easytravel')].LoadBalancerName"
```

## 비용

클러스터가 떠 있는 동안 EKS 컨트롤 플레인, EC2 노드 2대, NAT Gateway, ALB, EBS 볼륨 요금이 시간 단위로 나옵니다. 데모가 끝나면 바로 `down` 하세요. 노드 비용을 줄이려면 `cluster.yaml` 의 `spot: true` 주석을 풀 수 있습니다 (데모 중 노드가 회수될 수 있음).

## 문제 해결

| 증상 | 원인 / 조치 |
|---|---|
| `eksctl` AccessDenied (`eks:DescribeClusterVersions` 등) | 현재 프로필에 EKS 권한 없음. `$env:AWS_PROFILE = "eks-demo"` 설정 후 `aws sts get-caller-identity` 로 사용자 확인 |
| `eksctl create cluster` 실패 | CloudFormation 콘솔에서 `eksctl-easytravel-demo-*` 스택 이벤트 확인. 실패한 스택은 `eksctl delete cluster -f cluster.yaml` 로 정리 후 재시도 |
| kubectl `Unauthorized` / 다른 클러스터가 보임 | 새 창에서 `AWS_PROFILE` 미설정. `env.local.ps1` 다시 적용, `kubectl config current-context` 확인 |
| Helm "A specified logon session does not exist" | Windows 자격 증명 관리자 문제. 현재 `up.ps1` 은 우회 처리되어 있음. 직접 helm 을 실행할 때는 `up.ps1` 3단계의 `--registry-config` 방식 참고 |
| DynaKube `Error` — `image discovery failed for activegate` | Operator token 이 platform token(`dt0s16.`). classic token(`dt0c01.`)으로 바꾸고 Secret 재생성 후 `kubectl -n dynatrace rollout restart deploy/dynatrace-operator` |
| DynaKube `Error` — `get token scopes: HTTP 404: Token does not exist` | Data Ingest token 이 classic token 이 아니거나 오타. 위와 같이 Secret 재생성 후 operator 재시작 |
| DynaKube 가 `Running` 이 안 됨 (기타) | `kubectl -n dynatrace describe dynakube dynakube`, `kubectl -n dynatrace logs deploy/dynatrace-operator --tail=50`. apiUrl 끝의 `/api` 와 토큰 권한 확인 |
| Pod 가 `ImagePullBackOff` | GHCR 패키지가 private. Public 으로 바꾸거나 `GHCR_USER`/`GHCR_TOKEN` 을 설정하고 `up` 재실행 |
| `kubectl -n easytravel get ingress` 가 비어 있음 | overlay 에 `namespace: easytravel` 이 없던 이전 버전에서는 Ingress 가 `default` 에 생성됨. `kubectl -n default delete ingress --all` 후 최신 overlay 로 재적용 |
| Ingress ADDRESS 가 안 생김 | `kubectl -n easytravel describe ingress easytravel-classic`, `kubectl -n kube-system logs deploy/aws-load-balancer-controller --tail=50` |
| 패널(:9090) 접속 시 계속 로그인 창 | 계정 확인: `docs/problem-patterns.md` 의 "비밀번호 확인" 명령 |
| 패널에 "상태 조회 실패 (HTTP 502)" | backend 가 아직 기동 중. `kubectl -n easytravel get pods` 로 `backend` Ready 확인 |
| 패널에서 켠 pattern 이 몇 초 뒤 꺼짐 | 자동 순환 모드. overlay 에 `problem-panel` component 가 켜져 있는지 확인 후 `kubectl apply -k .\kubernetes\overlays\eks` |
| 접속 시 503 | ALB target 이 아직 unhealthy. 2~3분 대기, `kubectl -n easytravel get pods` 로 `www`·`frontend` Ready 확인 |
| 같은 이름으로 다시 만들 때 실패 | 이전 `down` 이 끝까지 됐는지, CloudFormation 스택이 `DELETE_FAILED` 로 남아 있는지 확인 후 콘솔에서 삭제 |
