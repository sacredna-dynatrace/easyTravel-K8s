# easyTravel 한글화

easyTravel 화면 문구는 이 repo가 아니라 Docker Hub 이미지 안의 WAR에 들어 있습니다 (JSF `.xhtml`, Angular 번들 `.js`, `WEB-INF/classes` 리소스). 그래서 **원본 이미지 위에 한글 리소스를 덮어쓴 `-ko` 이미지**를 만드는 방식으로 한글화합니다. 영문 이미지와 한글 이미지를 둘 다 쓸 수 있습니다.

## 진행 절차

| 단계 | 누가 | 무엇을 | 결과 |
|---|---|---|---|
| 1 | 사용자 | Actions → **i18n 1) Extract UI resources** 실행 | `i18n-source` 브랜치에 WAR 텍스트 리소스, loadgen, MongoDB 샘플 커밋 |
| 2 | Claude | `i18n-source` 분석 → `i18n/ko/**`에 번역 overlay와 `translate.js` 작성 | master에 번역 커밋 |
| 3 | 사용자 | Actions → **i18n 2) Build Korean images** 실행 | `ghcr.io/<owner>/easytravel-*-ko` 이미지 |
| 4 | 사용자 | overlay에 `components/korean` 추가 후 `kubectl apply -k` | 한글 데모 |

## 구조

```
i18n/
├── docker/
│   ├── war-overlay.Dockerfile   # FROM 원본 이미지 → ROOT.war 에 overlay 반영 + UTF-8/ko_KR 설정
│   └── mongodb.Dockerfile       # translate.js 가 적용된 DB tarball 로 교체
└── ko/
    ├── frontend/overlay/         # WAR 루트 기준 경로로 번역 파일 배치
    ├── angular-frontend/overlay/
    ├── backend/overlay/
    └── mongodb/translate.js      # 여행상품 설명 등 표시 텍스트 번역 (도시명은 유지)
```

## 번역 원칙

- **번역:** 메뉴, 버튼, 라벨, 안내문, 오류 메시지, 여행상품 설명, 회사명 같은 표시 텍스트.
- **영문 유지:**
  - 도시·지역명(location). loadgen 검색 시나리오가 영문으로 입력하므로 바꾸면 검색 결과가 0건이 됩니다.
  - HTML `id`·`name`, CSS class, URL 경로. loadgen selector와 Dynatrace RUM 설정이 이 값에 의존합니다.
  - 제품명과 표준 기술 용어 (easyTravel, Dynatrace 등).
- **UI 텍스트로 요소를 찾는 selector:** loadgen이 이런 selector를 쓰면 해당 문구는 번역하지 않거나 번역에서 뺍니다. 1단계 결과의 uemload 시나리오를 보고 판단합니다.

## Dynatrace 관점에서 달라지는 점

- **RUM user action 이름:** 버튼 텍스트로 이름이 정해지므로 한글로 바뀝니다 (예: `click on "검색"`). 영문판으로 만든 key user action, conversion goal, 대시보드 필터는 다시 지정해야 합니다.
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
