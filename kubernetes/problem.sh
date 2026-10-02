#!/usr/bin/env bash
# easyTravel problem pattern 수동 제어 (bash). 사용법은 problem.ps1 과 같음
#   ./kubernetes/problem.sh list | on <Pattern> | off <Pattern> | reset
set -euo pipefail
NS=easytravel
RUNNER=deploy/loadgen-classic
SVC=http://backend:8080/services/ConfigurationService
PROBLEMS=(BadCacheSynchronization CPULoad DatabaseSlowdown FetchSizeTooSmall JourneySearchError404
          JourneySearchError500 LargeMemoryLeak LoginProblems MobileErrors TravellersOptionBox)
MAINT=(DatabaseCleanup)

call() { kubectl -n "$NS" exec "$RUNNER" -c loadgen -- wget -qO- "$SVC/$1"; }
enabled() { call getEnabledPluginNames | grep -oE '<([a-z0-9]+:)?return[^>]*>[^<]+' | sed 's/.*>//'; }
set_pattern() {
  [ "$2" = true ] && call "registerPlugins?pluginData=$1" >/dev/null
  call "setPluginEnabled?name=$1&enabled=$2" >/dev/null
}
show() {
  local en; en=$(enabled || true)
  echo "장애 시나리오"
  for p in "${PROBLEMS[@]}"; do grep -qx "$p" <<<"$en" && echo "  [켜짐] $p" || echo "  [꺼짐] $p"; done
  echo "유지 관리 (켜 두기 권장)"
  for p in "${MAINT[@]}"; do grep -qx "$p" <<<"$en" && echo "  [켜짐] $p" || echo "  [꺼짐] $p"; done
}
manual_check() {
  local v; v=$(kubectl -n "$NS" get "$RUNNER" -o jsonpath="{.spec.template.spec.containers[0].env[?(@.name=='ET_BACKEND_URL')]}" 2>/dev/null || true)
  if grep -qE 'valueFrom|"value":"[^"]' <<<"$v"; then
    echo "경고: 자동 순환 모드입니다. 변경한 상태가 5초 안에 덮어써질 수 있습니다 (problem-panel 또는 problem-patterns-manual component 필요)." >&2
  fi
}

ACTION="${1:-list}"; NAME="${2:-}"
case "$ACTION" in
  list) show ;;
  reset)
    manual_check; en=$(enabled || true)
    for p in "${PROBLEMS[@]}"; do grep -qx "$p" <<<"$en" && { echo "끄기: $p"; set_pattern "$p" false; }; done
    show ;;
  on|off)
    [ -n "$NAME" ] || { echo "pattern 이름을 지정하세요. 예) $0 $ACTION CPULoad"; exit 1; }
    match=""
    for p in "${PROBLEMS[@]}" "${MAINT[@]}"; do [ "${p,,}" = "${NAME,,}" ] && match=$p; done
    [ -n "$match" ] || { echo "알 수 없는 pattern: $NAME"; echo "사용 가능: ${PROBLEMS[*]} ${MAINT[*]}"; exit 1; }
    manual_check
    [ "$ACTION" = on ] && [ "$match" = LargeMemoryLeak ] && echo "경고: LargeMemoryLeak 은 backend 를 OOM 으로 재시작시킬 수 있습니다." >&2
    set_pattern "$match" "$([ "$ACTION" = on ] && echo true || echo false)"
    echo "$match → $([ "$ACTION" = on ] && echo 켜짐 || echo 꺼짐)"
    show ;;
  *) echo "사용법: $0 list | on <Pattern> | off <Pattern> | reset"; exit 1 ;;
esac
