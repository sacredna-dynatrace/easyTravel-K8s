# easyTravel-Docker 원본 문서 (참고용)

> **이 문서는 upstream [Dynatrace/easyTravel-Docker](https://github.com/Dynatrace/easyTravel-Docker) README 의 한글 번역본을 보존한 것입니다.**
> 이 repo 의 데모 실행 경로는 **Amazon EKS** 입니다 → [루트 README](../README.md).
> 아래의 `docker-compose`·빌드 스크립트는 원본 그대로이며 영문 이미지, Dynatrace 연동 없음, 한글 UI 미적용 상태입니다. 이 repo 에서 유지·검증하지 않습니다.
> 단, 환경 변수와 problem pattern 설명은 Kubernetes 배포에도 그대로 적용됩니다.

이 프로젝트는 [Dynatrace easyTravel](https://community.dynatrace.com/community/display/DL/Demo+Applications+-+easyTravel) 데모 애플리케이션을 [Docker](https://www.docker.com/)로 빌드하고 배포합니다. 모든 컴포넌트 이미지는 [Docker Hub](https://hub.docker.com/u/dynatrace/)에 공개되어 있습니다.

## 애플리케이션 구성 요소

| 컴포넌트                | 설명
|:------------------------|:-----------
| mongodb                 | 여행 데이터가 미리 적재된 데이터베이스 (MongoDB)
| backend                 | easyTravel Business Backend (Java)
| frontend                | easyTravel Customer Frontend (Java)
| nginx                   | easyTravel Customer Frontend 앞단의 reverse proxy (NGINX)
| angularfrontend         | easyTravel Customer Frontend (Java, Angular)
| headlessloadgen         | headless Chrome 기반 부하 발생기 (Java)
| pluginservice           | plugin 상태를 보관하는 선택 컴포넌트. backend가 여러 개일 때 사용 (Java)
| mongodb-content-creator | 비어 있는 MongoDB에 easyTravel 데이터를 생성
| loadgen (deprecated)    | 합성 부하 발생기 (Java)

## Docker로 easyTravel 실행

제공되는 `docker-compose.yml` 파일로 [Docker Compose](https://docs.docker.com/compose/)를 실행합니다.

```
docker-compose up
```

참고: 메모리 사용량을 줄이려면 `docker-compose.yml`에서 loadgen 컴포넌트를 빼세요.

## Docker에서 easyTravel 설정

[12factor app](http://12factor.net/config) 원칙(설정과 코드의 엄격한 분리)에 따라, easyTravel은 기동 시점에 아래 환경 변수로 설정합니다.

| 컴포넌트                         | 환경 변수             | 기본값                        | 설명
|:---------------------------------|:----------------------|:------------------------------|:-----------
| backend                          | ET_DATABASE_LOCATION  | easytravel-mongodb:27017      | Business Backend가 연결할 데이터베이스 위치
| backend                          | ET_MONGO_AUTH_DB      | admin                         | MongoDB 인증 데이터베이스 이름
| backend                          | ET_DATABASE_USER      | etAdmin                       | MongoDB 사용자 이름
| backend                          | ET_DATABASE_PASSWORD  | adminadmin                    | MongoDB 사용자 비밀번호
| frontend                         | ET_BACKEND_URL        | http://easytravel-backend:8080| Business Backend URL
| nginx                            | ET_FRONTEND_LOCATION  | easytravel-frontend:8080      | WWW 서버가 80 포트로 제공할 Customer Frontend 위치
| nginx                            | ET_BACKEND_LOCATION   | easytravel-backend:8080       | WWW 서버가 8080 포트로 제공할 Business Backend 위치
| backend<br/>frontend             | ET_APM_SERVER_DEFAULT | APM                           | 사용하는 서버 종류. Dynatrace는 "APM", AppMon은 "Classic"
| angularfrontend                  | ET_BACKEND_URL        | http://easytravel-backend:8080| Business Backend URL
| headlessloadgen                  | ET_FRONTEND_URL       | http://easytravel-www:9079    | Frontend URL
| headlessloadgen                  | ET_VISIT_NUMBER       | 1                             | 분당 생성할 방문(visit) 수
| headlessloadgen                  | MAX_CHROME_DRIVERS    | 1                             | 최대 Chrome driver 수
| headlessloadgen                  | REUSE_CHROME_DRIVER_FREQUENCY | 1                     | Chrome 인스턴스 하나로 방문을 몇 번 생성할지. 값을 올리면 성능은 좋아지지만 생성되는 user session이 이상하게 보일 수 있음
| headlessloadgen                  | SCENARIO_NAME         | Headless Scenario             | 시나리오 이름
| headlessloadgen                  | ET_PROBLEMS           | BadCacheSynchronization,<br/>CPULoad,<br/>DatabaseCleanup,<br/>FetchSizeTooSmall,<br/>JourneySearchError404,<br/>JourneySearchError500,<br/>LoginProblems,<br/>MobileErrors,<br/>TravellersOptionBox | 지원하는 problem pattern 목록. 활성화 방법은 아래 참고
| headlessloadgen                  | ET_PROBLEMS_DELAY     | 0                             | 지연 시간(초). Dynatrace와 함께 쓸 때는 7500(2시간 조금 넘음)을 권장합니다. Dynatrace가 먼저 정상 상태를 학습할 수 있습니다.
| loadgen                          | ET_WWW_URL            | http://easytravel-www:80      | Customer Frontend URL
| loadgen                          | ET_BACKEND_URL        | http://easytravel-www:8080    | Business Backend URL (선택). 지정하면 `ET_PROBLEMS`의 problem pattern을 10분씩 차례로 적용
| loadgen                          | ET_PROBLEMS           | BadCacheSynchronization,<br/>CPULoad,<br/>DatabaseCleanup,<br/>FetchSizeTooSmall,<br/>JourneySearchError404,<br/>JourneySearchError500,<br/>LoginProblems,<br/>MobileErrors,<br/>TravellersOptionBox | 지원하는 problem pattern 목록. 활성화 방법은 아래 참고
| loadgen                          | ET_PROBLEMS_DELAY     | 0                             | 지연 시간(초). Dynatrace와 함께 쓸 때는 7500(2시간 조금 넘음)을 권장합니다. Dynatrace가 먼저 정상 상태를 학습할 수 있습니다.
| loadgen                          | ET_VISIT_NUMBER       | 2                             | 분당 생성할 방문(visit) 수

## easyTravel Problem Pattern 활성화

아래 problem pattern을 지원하며, 위에서 설명한 대로 *loadgen* 컴포넌트가 켜고 끕니다.

| Pattern                 | 설명
|:------------------------|:------------
| BadCacheSynchronization | Customer Frontend에 동기화 문제를 일으키고, 비효율적인 cache lookup으로 CPU를 많이 씁니다. 활성화하면 'CacheLookup' 클래스가 동기화를 과도하게 수행하는 것으로 보입니다.
| CPULoad                 | Business Backend 프로세스의 CPU 사용률을 높여 host health를 unhealthy 상태로 만듭니다. 검색·예약 활동과 무관하게 별도 스레드 8개에서 CPU 시간을 소모합니다.
| DatabaseCleanup         | Booking, LoginHistory처럼 데이터베이스에 계속 쌓이는 항목을 정리하고 최근 5000건만 남깁니다. Journey 검색 시점에 5분마다 실행됩니다. 보통 기본으로 켜져 있으며, 끄면 특히 자동 트래픽이 있을 때 데이터베이스가 계속 커집니다.
| FetchSizeTooSmall       | Hibernate persistence layer의 fetch size를 1로 설정합니다. Hibernate가 원래 묶어서 가져오던 조회가 비효율적인 select 문으로 데이터베이스에 나타납니다.
| JourneySearchError404   | Customer Frontend에서 journey 검색 시 존재하지 않는 이미지 이름을 반환해 HTTP 404 오류를 일으킵니다.
| JourneySearchError500   | journey 검색 조건이 잘못된 경우(예: toDate가 fromDate보다 앞선 경우) HTTP 500 서버 오류를 발생시킵니다.
| LargeMemoryLeak         | Customer Frontend 검색창의 자동 완성으로 location을 조회할 때 Business Backend에 큰 메모리 누수를 일으킵니다. 주의: out-of-memory 오류로 Java backend가 금방 동작하지 않게 됩니다.
| LoginProblems           | Customer Frontend에서 로그인할 때 exception을 발생시킵니다.
| MobileErrors            | 모바일 기기에서의 journey 검색·예약에서 오류가 발생합니다. (태블릿은 제외)
| TravellersOptionBox     | Customer Frontend 예약 흐름의 review 단계에서 'travellers' 콤보박스의 마지막 옵션('2 adults+2 kids')을 선택하면 'InvalidTravellerCostItemException'으로 감싼 'ArrayIndexOutOfBoundsException'이 발생합니다.

## easyTravel Docker 이미지 빌드

이미지를 직접 빌드하려면 `build.sh`를 사용하세요.

## easyTravel 배포 산출물 빌드

### 방법 A: 'build-et.sh'

`build-et.sh`는 기본적으로 현재 작업 디렉터리 아래 `deploy` 디렉터리에 배포 산출물을 만듭니다. 아래 *환경 변수*로 기본 동작을 바꿀 수 있습니다.

| 환경 변수             | 기본값                      | 설명
|:----------------------|:----------------------------|:-----------
| ET_SRC_URL            | http://etinstallers.demoability.dynatracelabs.com/latest/dynatrace-easytravel-src.zip | easyTravel 소스 배포본 .zip 파일 URL
| ET_DEPLOY_HOME        | ./deploy                    | 배포 산출물을 담을 디렉터리
| ET_BB_DEPLOY_HOME     | ./backend                   | `${ET_DEPLOY_HOME}` 아래 Business Backend 산출물 디렉터리 (`${ET_DEPLOY_HOME}/${ET_BB_DEPLOY_HOME}`)
| ET_CF_DEPLOY_HOME     | ./frontend                  | `${ET_DEPLOY_HOME}` 아래 Customer Frontend 산출물 디렉터리 (`${ET_DEPLOY_HOME}/${ET_CF_DEPLOY_HOME}`)
| ET_ACF_DEPLOY_HOME    | ./angularfrontend           | `${ET_DEPLOY_HOME}` 아래 Customer Frontend (Angular) 산출물 디렉터리 (`${ET_DEPLOY_HOME}/${ET_ACF_DEPLOY_HOME}`)
| ET_LG_DEPLOY_HOME     | ./loadgen                   | `${ET_DEPLOY_HOME}` 아래 UEM load generator 산출물 디렉터리 (`${ET_DEPLOY_HOME}/${ET_LG_DEPLOY_HOME}`)
| ET_HLG_DEPLOY_HOME    | ./headlessloadgen           | `${ET_DEPLOY_HOME}` 아래 headless Angular load generator (Java) 산출물 디렉터리 (`${ET_DEPLOY_HOME}/${ET_HLG_DEPLOY_HOME}`)
| ET_MG_DEPLOY_HOME     | ./mongodb                   | `${ET_DEPLOY_HOME}` 아래 사전 적재 여행 데이터베이스 디렉터리 (`${ET_DEPLOY_HOME}/${ET_MG_DEPLOY_HOME}`)
| ET_MGC_DEPLOY_HOME    | ./mongodb-content-creator   | `${ET_DEPLOY_HOME}` 아래 MongoDB Content Creator 산출물 디렉터리 (`${ET_DEPLOY_HOME}/${ET_MGC_DEPLOY_HOME}`)
| ET_PS_DEPLOY_HOME     | ./pluginservice             | `${ET_DEPLOY_HOME}` 아래 Plugin Service 산출물 디렉터리 (`${ET_DEPLOY_HOME}/${ET_PS_DEPLOY_HOME}`)

#### 예시: `./deploy`에 배포 산출물 생성

```
./build-et.sh
```

#### 예시: 하위 폴더 없이 `./deploy`에 바로 생성

```
export ET_BB_DEPLOY_HOME=. \
export ET_CF_DEPLOY_HOME=. \
export ET_ACF_DEPLOY_HOME=. \
export ET_LG_DEPLOY_HOME=. \
export ET_HLG_DEPLOY_HOME=. \
export ET_MG_DEPLOY_HOME=. \
export ET_MGC_DEPLOY_HOME=. \
export ET_PS_DEPLOY_HOME=. \
./build-et.sh
```

### 방법 B: 'build-in-docker.sh'

빌드 환경을 직접 준비하지 않고 Docker 안에서 배포 산출물을 빌드하려면 `build-in-docker.sh`를 사용하세요. 산출물은 현재 작업 디렉터리 아래 `deploy`에 생성됩니다. 방법 A와 같은 *환경 변수*로 기본 동작을 바꿀 수 있습니다.

## 문제·질문·제안

이 프로젝트는 [Dynatrace Community Supported](https://community.dynatrace.com/community/display/DL/Support+Levels#SupportLevels-Communitysupported/NotSupportedbyDynatrace(providedbyacommunitymember)) 대상입니다. 문제나 질문, 제안은 Dynatrace Community의 [Application Monitoring & UEM Forum](https://answers.dynatrace.com/spaces/146/index.html)에서 공유해 주세요.

## 라이선스

MIT License로 배포됩니다. 자세한 내용은 [LICENSE](https://github.com/dynatrace-innovationlab/easyTravel-Docker/blob/master/LICENSE) 파일을 참고하세요.
