# easyTravel on Kubernetes (EKS / AKS)

Kustomize로 easyTravel 전체 스택을 배포합니다. Classic frontend와 Angular frontend를 함께 올리고, Dynatrace Operator(cloudNativeFullStack)로 모니터링합니다.

## 구조

```
kubernetes/
├── base/                         # 공통 (namespace: easytravel)
│   ├── namespace.yaml            #   monitoring=dynatrace 라벨 → DynaKube 주입 대상
│   ├── configmap.yaml            #   서비스 주소, problem pattern, Mongo 계정(Secret)
│   ├── mongodb.yaml
│   ├── backend.yaml
│   ├── frontend.yaml             #   Classic JSF frontend (원본 K8s 매니페스트엔 없던 것)
│   ├── angular-frontend.yaml
│   ├── nginx.yaml                #   www: 80(Classic) / 9079(Angular) / 8080(Backend)
│   ├── loadgen-classic.yaml      #   headless Chrome + problem pattern 순환 담당
│   └── loadgen-angular.yaml
├── components/                   # 필요할 때만 켜는 옵션
│   ├── problem-patterns-delayed/ #   problem pattern 시작을 7500초 늦춤 (Davis baseline 학습용)
│   └── mongodb-content-creator/  #   빈 MongoDB에 데이터 넣는 Job
└── overlays/
    ├── eks/                      # ALB Ingress (AWS Load Balancer Controller)
    └── aks/                      # App Routing(NGINX) Ingress
dynatrace/
└── dynakube.yaml                 # DynaKube v1beta6 (cloudNativeFullStack)
```

```
 Ingress ─▶ www(nginx) ─┬─:80───▶ frontend ─────────┐
                        ├─:9079─▶ angular-frontend ─┼─▶ backend ─▶ mongodb
                        └─:8080─▶ backend ──────────┘
 loadgen-classic ─▶ www:80   (+ backend ConfigurationService로 problem pattern on/off)
 loadgen-angular ─▶ www:9079
```

## 배포 순서

### 1. Dynatrace Operator + DynaKube (먼저 설치)

cloudNativeFullStack은 Pod가 **생성될 때** code module을 주입합니다. 그래서 앱보다 먼저 설치해야 합니다.

```bash
# Operator 설치 (Helm)
helm install dynatrace-operator oci://public.ecr.aws/dynatrace/dynatrace-operator \
  --create-namespace --namespace dynatrace --atomic

# 토큰 Secret (Secret 이름 = DynaKube 이름)
kubectl -n dynatrace create secret generic dynakube \
  --from-literal=apiToken=<OPERATOR_TOKEN> \
  --from-literal=dataIngestToken=<DATA_INGEST_TOKEN>

# dynatrace/dynakube.yaml 의 apiUrl 을 수정한 뒤 적용
kubectl apply -f dynatrace/dynakube.yaml
kubectl -n dynatrace get dynakube -w      # Running 이 될 때까지 대기
```

설치 명령과 토큰 권한은 버전마다 달라질 수 있습니다. 공식 문서 기준으로 확인하세요: [Kubernetes platform monitoring + Full-Stack observability](https://docs.dynatrace.com/docs/ingest-from/setup-on-k8s/deployment/full-stack-observability), [DynaKube parameters](https://docs.dynatrace.com/docs/ingest-from/setup-on-k8s/reference/dynakube-parameters).

### 2. easyTravel

```bash
# EKS (AWS Load Balancer Controller 사전 설치 필요)
kubectl apply -k kubernetes/overlays/eks

# AKS (az aks approuting enable -g <RG> -n <CLUSTER>)
kubectl apply -k kubernetes/overlays/aks

kubectl -n easytravel get pods -w
```

Backend와 frontend는 MongoDB가 뜰 때까지 기다린 뒤 Tomcat을 시작합니다. 그래서 모두 Ready 되는 데 3~5분 정도 걸립니다.

### 3. 접속

| 환경 | Classic | Angular |
|---|---|---|
| EKS | `http://<ALB-DNS>/` | `http://<ALB-DNS>:9079/` |
| AKS | `http://easytravel.<IP>.nip.io/` | `http://angular.easytravel.<IP>.nip.io/` |

- EKS: ALB 하나를 공유(`group.name`)하고 리스너 포트로 Classic과 Angular를 나눕니다. `kubectl -n easytravel get ingress`로 ALB 주소를 확인하세요.
- AKS: Ingress가 host 기반입니다. `ingress.yaml`의 host를 실제 도메인이나 nip.io 주소로 바꾸세요.
- Ingress 없이 빠르게 확인: `kubectl -n easytravel port-forward svc/www 8080:80 9079:9079`

## 커스터마이즈 포인트 (`[CUSTOMIZE]` 주석)

| 항목 | 파일 |
|---|---|
| 테넌트 URL, host group | `dynatrace/dynakube.yaml` |
| ALB scheme / 접속 허용 IP | `overlays/eks/ingress.yaml` |
| Ingress class / host | `overlays/aks/ingress.yaml` |
| Problem pattern 목록 | `base/configmap.yaml` → `ET_PROBLEMS` |
| Problem pattern 시작 지연 | overlay의 `components`에서 `problem-patterns-delayed` 주석 해제 |
| 이미지 태그, 사설 레지스트리 | `base/kustomization.yaml` → `images` |
| Release 버전 표기 | `base/kustomization.yaml` → `app.kubernetes.io/version` |

## 원본(`kubernetes-manifests/`) 대비 변경점

| 항목 | 원본 | 변경 |
|---|---|---|
| Classic frontend | 없음 | `frontend` + `loadgen-classic` 추가 (docker-compose와 동일한 구성) |
| Problem pattern | loadgen에 `ET_BACKEND_URL`이 없어 **동작 안 함** | `loadgen-classic`이 순환 담당, `loadgen-angular`는 부하만 발생 (중복 토글 방지) |
| MongoDB 메모리 | 100Mi (OOM 위험) | 512Mi |
| Backend replicas | 2 | 1 (plugin 상태가 인스턴스별이라 데모 재현성 우선) |
| Probe | 없음 | startup / readiness / liveness (TCP) |
| CPU 아키텍처 | 미지정 | `kubernetes.io/arch: amd64` (Graviton/ARM 노드에 뜨지 않게) |
| 노출 | nginx LoadBalancer (Angular만) | Ingress (EKS ALB / AKS App Routing) |
| Content creator | 일반 Pod | 옵션 Job (component) |
| 설정 | 매니페스트마다 하드코딩 | ConfigMap / Secret으로 모음 |
| Service link 환경변수 | 주입됨 | `enableServiceLinks: false` (`*_PORT` 환경변수 충돌 방지) |
| Dynatrace | 없음 | DynaKube, namespace selector, loadgen 주입 제외(`oneagent.dynatrace.com/inject: "false"`) |

## 정리

```bash
kubectl delete -k kubernetes/overlays/eks     # 또는 aks
```
