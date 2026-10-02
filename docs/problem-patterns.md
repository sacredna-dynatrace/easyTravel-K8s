# Problem pattern 제어

easyTravel 은 backend 의 `ConfigurationService` 로 problem pattern(장애 시나리오 plugin)을 켜고 끕니다. 이 repo 는 세 가지 제어 방식을 제공합니다.

| 모드 | `overlays/eks/kustomization.yaml` 의 components | 제어 방법 |
|---|---|---|
| **웹 패널** (기본) | `problem-panel` | 브라우저 `http://<ALB>:9090/` + `problem.ps1` |
| 수동 | `problem-patterns-manual` | `kubernetes/problem.ps1` (또는 `problem.sh`) |
| 자동 순환 | 위 둘 다 주석 처리 | `loadgen-classic` 이 `ET_PROBLEMS` 를 10분마다 하나씩 순환 (`problem-patterns-delayed` 로 시작 지연 가능) |

**왜 모드를 나누나요?** 자동 순환 스크립트는 10분 동안 **5초마다** 현재 pattern 을 다시 켜고 직전 pattern 을 다시 끕니다. 그래서 자동 모드에서 손으로 바꾼 상태는 5초 안에 덮어써집니다. 웹 패널과 수동 모드는 `loadgen-classic` 의 `ET_BACKEND_URL` 을 비워 자동 순환만 끕니다. 부하 발생은 그대로 계속됩니다.

## 1. 웹 패널

```
http://<ALB 주소>:9090/
```

`up` 이 끝날 때 주소와 계정이 출력됩니다.

- 각 pattern 카드의 **켜기 / 끄기**, 상단의 **데모 pattern 모두 끄기**, 5초 자동 갱신
- `LargeMemoryLeak` 은 켤 때 확인 창이 뜹니다 (backend OOM 재시작 위험)
- `DatabaseCleanup` 은 "유지 관리" 로 분리되어 있습니다. 켜 두기를 권장하고, 끌 때 확인 창이 뜹니다. "모두 끄기" 대상에서도 빠집니다

### 계정과 보안

| 항목 | 내용 |
|---|---|
| 사용자 | `PANEL_USER` (기본 `demo`) |
| 비밀번호 | `PANEL_PASSWORD`. 비워 두면 클러스터를 처음 만들 때 16자로 자동 생성되어 `up` 출력에 한 번 표시됨 |
| 저장 위치 | Secret `easytravel/problem-panel-auth` (`up` 이 생성) |
| 통신 | ALB HTTP(:9090) + Basic 인증. **암호화되지 않으므로** 데모 전용 비밀번호를 쓰세요 |
| 접근 범위 | nginx 가 허용 목록의 pattern 이름과 `true`/`false` 만 backend 로 전달. backend(8080) 자체는 외부에 노출되지 않음 |
| 접속 IP 제한 | `kubernetes/components/problem-panel/ingress.yaml` 의 `inbound-cidrs` 주석을 풀고 사무실 IP 입력 (권장) |

비밀번호 확인 (PowerShell):

```powershell
[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String((kubectl -n easytravel get secret problem-panel-auth -o "jsonpath={.data.htpasswd}")))
```

출력은 `demo:{PLAIN}<비밀번호>` 형식입니다.

비밀번호 바꾸기: `env.local.ps1` 에 `$env:PANEL_PASSWORD` 를 넣고 `up.ps1` 을 다시 실행합니다. 이미 있는 리소스는 건너뛰므로 금방 끝납니다. Secret 변경이 Pod 에 반영되기까지 1분 정도 걸립니다.

## 2. 명령줄 (`problem.ps1` / `problem.sh`)

클러스터 안의 `loadgen-classic` Pod 에서 backend 를 호출합니다. port-forward 가 필요 없습니다. 웹 패널 모드와 수동 모드에서 모두 쓸 수 있습니다.

```powershell
.\kubernetes\problem.ps1 list              # 켜짐/꺼짐 목록
.\kubernetes\problem.ps1 on  CPULoad       # 대소문자 무관
.\kubernetes\problem.ps1 off CPULoad
.\kubernetes\problem.ps1 reset             # 장애 시나리오 모두 끄기 (DatabaseCleanup 유지)
```

자동 순환 모드에서 실행하면 "상태가 5초 안에 덮어써질 수 있다" 는 경고를 출력합니다.

## 3. 모드 바꾸기 (실행 중인 클러스터)

`kubernetes/overlays/eks/kustomization.yaml` 의 components 를 고친 뒤:

```powershell
kubectl apply -k .\kubernetes\overlays\eks
```

- `loadgen-classic` 은 환경 변수가 바뀌어 자동으로 재시작됩니다.
- **자동 → 패널/수동**: 자동 순환이 마지막으로 켠 pattern 이 남아 있을 수 있습니다. `.\kubernetes\problem.ps1 reset` 으로 정리하세요.
- **패널 → 자동**: `kubectl apply` 는 지운 리소스를 삭제하지 않습니다. 패널을 직접 지우세요.
  ```powershell
  kubectl -n easytravel delete ingress easytravel-panel
  kubectl -n easytravel delete deploy,svc problem-panel
  ```

## 4. Pattern 목록

| Pattern | 위치 | 증상 |
|---|---|---|
| CPULoad | Backend | 스레드 8개가 CPU 소모 → 호스트·프로세스 CPU 포화 |
| DatabaseSlowdown | Backend → DB | 데이터베이스 호출 지연 → 응답 시간 증가 |
| FetchSizeTooSmall | Backend → DB | Hibernate fetch size 1 → 작은 select 대량 발생 |
| BadCacheSynchronization | Frontend | `CacheLookup` 과도한 동기화 → CPU·응답 시간 증가 |
| JourneySearchError404 | Frontend | 검색 시 없는 이미지 → HTTP 404 |
| JourneySearchError500 | Backend | 잘못된 검색 조건 → HTTP 500 |
| LoginProblems | Backend | 로그인 시 exception |
| MobileErrors | Frontend | 모바일 기기 검색·예약 오류 (태블릿 제외) |
| TravellersOptionBox | Frontend | 예약 review 단계 '2 adults+2 kids' 선택 시 exception |
| LargeMemoryLeak | Backend | 위치 자동완성 시 큰 메모리 누수 → backend OOM 재시작 (자동 순환 목록에는 없음) |
| DatabaseCleanup | Backend → DB | 장애가 아닌 정리 기능. 최근 5000건 유지 (켜 두기 권장) |

- 상태는 backend 메모리에 있습니다. backend Pod 가 재시작되면 초기화됩니다.
- Pattern 을 켜면 loadgen 트래픽에 바로 반영됩니다. Davis problem 은 보통 수 분 안에 열립니다. baseline 이 짧은 새 클러스터에서는 더 걸릴 수 있습니다.

## 동작 구조

```
브라우저 ──:9090──▶ ALB ──▶ problem-panel (nginx, Basic 인증, 허용 목록 검사)
                                 │  POST /api/register?name=X → GET registerPlugins?pluginData=X
                                 │  POST /api/set?name=X&enabled=Y → GET setPluginEnabled?name=X&enabled=Y
                                 │  GET  /api/enabled → GET getEnabledPluginNames
                                 ▼
problem.ps1 ── kubectl exec ──▶ loadgen-classic (wget) ──▶ backend:8080/services/ConfigurationService
```

| 파일 | 내용 |
|---|---|
| `kubernetes/components/problem-panel/` | 패널 Deployment·Service·Ingress(:9090), nginx 설정, 화면(index.html), 자동 순환 끄기 패치 |
| `kubernetes/components/problem-patterns-manual/` | 자동 순환 끄기 패치만 |
| `kubernetes/problem.ps1`, `problem.sh` | 명령줄 제어 |
