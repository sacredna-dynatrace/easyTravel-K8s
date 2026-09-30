# easyTravel 한글화

easyTravel 화면 문구는 이 repo가 아니라 Docker Hub 이미지 안의 WAR·JAR에 들어 있습니다. 그래서 원본 이미지에서 WAR를 꺼내 **한글 리소스로 교체하고 Java 문자열 상수를 패치한 `-ko` 이미지**를 만듭니다. 영문 이미지와 한글 이미지를 둘 다 쓸 수 있습니다.

## 진행 절차

| 단계 | 방법 | 결과 |
|---|---|---|
| 1 | Actions → **i18n 1) Extract UI resources** (완료) | `i18n-source` 브랜치에 원문 리소스 |
| 2 | `i18n/ko/**` 번역 파일 (완료) | 이 디렉터리 |
| 3 | Actions → **i18n 2) Build Korean images** | `ghcr.io/<owner>/easytravel-*-ko` 이미지 4종 + 스모크 테스트 |
| 4 | overlay의 `components`에 `../../components/korean` 추가 후 `kubectl apply -k` | 한글 데모 |

## 구조

```
i18n/
├── tools/patch_archive.py        # WAR/JAR 패처: overlay 파일 교체 + .class 문자열 상수 교체
├── docker/
│   ├── war.Dockerfile            # 패치된 ROOT.war 로 교체 + JVM UTF-8
│   ├── loadgen.Dockerfile        # 패치된 uemload.jar 로 교체
│   └── mongodb.Dockerfile        # translate.js 가 적용된 DB tarball 로 교체
└── ko/
    ├── frontend/                 # Classic (JSF)
    │   ├── overlay/              #   번역된 xhtml·jsp·js (WAR 루트 기준 경로)
    │   └── class-strings.json    #   Java bean 문자열 (검증 메시지, 인원 옵션, 추천 영역)
    ├── angular-frontend/
    │   ├── overlay/              #   번역된 main-es2015/es5 번들, index.html(lang=ko)
    │   └── class-strings.json    #   REST 오류 메시지
    ├── headless-loadgen/
    │   └── class-strings.json    #   화면 텍스트 기반 selector 를 한글에 맞춤
    └── mongodb/translate.js      #   여행상품 이름·여행사 설명
```

`patch_archive.py`는 지정한 영문 문자열이 원본에 하나라도 없으면 실패합니다. 원본 이미지가 바뀌면 빌드 단계에서 바로 드러납니다.

## 번역 범위

| 구분 | 한글화 | 영문 유지 (이유) |
|---|---|---|
| Classic frontend | 메뉴, 검색, 결과, 여행 상세, 예약 4단계, 로그인·회원가입, 로그아웃, 회사 소개, 문의, 이용약관, 개인정보처리방침, 특가 상품, 운임 약관, 입력 검증 메시지, 인원 옵션, 추천 영역, AMP 마이크로사이트 | 주소·회사명(고유명사), 카드사 이름, 날짜 입력 형식과 통화($) |
| Angular frontend | 헤더·푸터, 검색 영역, 특가·추천·최근 예약, 여행 상세, 예약 5단계, 결제, 로그인, 회원가입, 문의, 오류 페이지, REST 오류 메시지 | 주소·회사명, 날짜 pipe 형식, **bizevent·dtrum 으로 보내는 문자열** (DQL·대시보드 호환) |
| MongoDB | 대표 여행상품 15종 이름, 여행사 설명 | 도시·지역명, `도시 - 도시` 형태의 자동 생성 여행명, 여행사 ID |
| 이미지 속 글자 | – | 배너·헤더 이미지에 그려진 영문 (이미지 파일) |
| Backend | – | 화면이 없음 (Axis2 관리 콘솔만 존재) |

## loadgen 과의 호환

headless loadgen 은 대부분 `id`/`name` 으로 요소를 찾지만, 아래는 **화면 텍스트**로 찾습니다. 한글 UI 와 일치하도록 `easytravel-headless-loadgen-ko` 이미지의 `uemload.jar` 를 함께 패치합니다.

| 요소 | 영문 | 한글 |
|---|---|---|
| Classic 링크 (linkText) | About / Contact / Terms of Use / Privacy Policy / Book Now / [Clear] | 회사 소개 / 문의 / 이용약관 / 개인정보처리방침 / 지금 예약 / [초기화] |
| Classic 결제 월 (selectByVisibleText) | January … December | 1월 … 12월 (서버로 가는 값은 영문 유지) |
| Angular 회원가입 버튼 (xpath text()) | Sign Up | 회원가입 |

따라서 **한글 frontend 를 쓸 때는 loadgen 도 반드시 `-ko` 이미지**를 써야 합니다. `components/korean` 이 둘을 함께 교체합니다.

## Dynatrace 관점에서 달라지는 점

- **RUM user action 이름:** 버튼·링크 텍스트로 정해지므로 한글로 바뀝니다 (예: `click on "지금 예약"`). 영문판으로 만든 key user action, conversion goal, 대시보드 필터는 다시 지정해야 합니다.
- **페이지 제목:** `easyTravel - 나의 여행` 처럼 한글로 바뀝니다.
- **Business events:** Angular 가 보내는 bizevent 필드는 영문 그대로라 기존 DQL 을 그대로 쓸 수 있습니다.
- **Release 구분:** `components/korean`이 `app.kubernetes.io/version`을 `2.0.0-ko`로 바꿔서 Release 화면에서 영문판과 구분됩니다.

## GHCR 이미지 접근

GHCR 패키지는 처음에 **private**로 만들어집니다. 둘 중 하나를 하세요.

- GitHub → Packages → 패키지별 *Package settings* → **Change visibility → Public**
- 또는 `imagePullSecret`을 만들어 연결:

  ```bash
  kubectl -n easytravel create secret docker-registry ghcr \
    --docker-server=ghcr.io --docker-username=<GitHub ID> --docker-password=<PAT(read:packages)>
  kubectl -n easytravel patch serviceaccount default -p '{"imagePullSecrets":[{"name":"ghcr"}]}'
  ```

## 번역 수정 방법

- 화면 문구: `ko/<component>/overlay/` 의 파일을 직접 고친 뒤 3단계를 다시 실행합니다.
- Java 문자열: `class-strings.json` 에 `"영문": "한글"` 을 추가합니다. 영문은 원본 class 의 문자열 상수와 정확히 같아야 합니다.
- loadgen 이 텍스트로 찾는 요소(위 표)를 바꾸면 `ko/headless-loadgen/class-strings.json` 도 같은 값으로 바꿔야 합니다.
