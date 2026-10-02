# up/down 실행 전에 필요한 환경 변수 (PowerShell)
#   1) 이 파일을 env.local.ps1 로 복사:  Copy-Item .\kubernetes\cluster\eks\env.example.ps1 .\kubernetes\cluster\eks\env.local.ps1
#   2) env.local.ps1 에 실제 값을 넣기 (env.local.ps1 은 .gitignore 에 등록되어 커밋되지 않음)
#   3) 새 PowerShell 창마다:  . .\kubernetes\cluster\eks\env.local.ps1    (앞의 점과 공백 주의: 현재 세션에 적용)
# 토큰 값은 채팅·이슈·커밋에 붙여 넣지 마세요.

$env:AWS_PROFILE       = "eks-demo"                                   # [CUSTOMIZE] aws configure --profile 로 만든 EKS 용 프로필
$env:DT_API_URL        = "https://<environment-id>.live.dynatrace.com/api"   # [CUSTOMIZE] 테넌트 URL (끝에 /api)
$env:DT_OPERATOR_TOKEN = "dt0c01.<...>"                               # [CUSTOMIZE] classic access token (dt0s16 platform token 아님)
$env:DT_INGEST_TOKEN   = "dt0c01.<...>"                               # [CUSTOMIZE] classic access token, Data Ingest 용

# Problem pattern 제어 패널(http://<ALB>:9090/) 로그인 계정. 비워 두면 user=demo, 비밀번호는 최초 생성 시 자동 생성되어 up 출력에 표시
# $env:PANEL_USER     = "demo"
# $env:PANEL_PASSWORD = "<데모용 비밀번호>"                       # [CUSTOMIZE] 다른 서비스와 같은 비밀번호 사용 금지

# GHCR 패키지를 private 로 둔 경우에만 (read:packages 권한 PAT)
# $env:GHCR_USER  = "sacredna-dynatrace"
# $env:GHCR_TOKEN = "<PAT>"

Write-Host "AWS_PROFILE=$env:AWS_PROFILE / DT_API_URL=$env:DT_API_URL / operator token prefix=$($env:DT_OPERATOR_TOKEN.Substring(0,7)) / ingest token prefix=$($env:DT_INGEST_TOKEN.Substring(0,7))"
