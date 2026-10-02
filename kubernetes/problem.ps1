# easyTravel problem pattern 수동 제어 (Windows PowerShell 5.1 / 7)
#   클러스터 안의 loadgen-classic Pod 에서 backend ConfigurationService 를 호출한다 (port-forward 불필요).
#   자동 순환이 켜져 있으면 5초 안에 원래대로 돌아가므로, overlay 에 problem-patterns-manual 또는 problem-panel component 가 필요하다.
#
# 사용 예:
#   .\kubernetes\problem.ps1 list
#   .\kubernetes\problem.ps1 on  CPULoad
#   .\kubernetes\problem.ps1 off CPULoad
#   .\kubernetes\problem.ps1 reset            # 장애 시나리오 pattern 모두 끄기 (DatabaseCleanup 은 유지)
param(
  [Parameter(Position = 0)][ValidateSet("list", "on", "off", "reset")][string]$Action = "list",
  [Parameter(Position = 1)][string]$Name
)
$ErrorActionPreference = "Continue"
$Ns      = "easytravel"
$Runner  = "deploy/loadgen-classic"
$Svc     = "http://backend:8080/services/ConfigurationService"
$Problems = @("BadCacheSynchronization","CPULoad","DatabaseSlowdown","FetchSizeTooSmall","JourneySearchError404",
              "JourneySearchError500","LargeMemoryLeak","LoginProblems","MobileErrors","TravellersOptionBox")
$Maint    = @("DatabaseCleanup")

function Call([string]$path) {
  $out = kubectl -n $Ns exec $Runner -c loadgen -- wget -qO- "$Svc/$path" 2>&1
  if ($LASTEXITCODE -ne 0) { throw "호출 실패 ($path): $out" }
  return ($out -join "`n")
}
function Get-Enabled {
  $xml = Call "getEnabledPluginNames"
  return @([regex]::Matches($xml, '<(?:\w+:)?return[^>]*>([^<]+)</') | ForEach-Object { $_.Groups[1].Value.Trim() })
}
function Set-Pattern([string]$n, [bool]$on) {
  if ($on) { Call "registerPlugins?pluginData=$n" | Out-Null }
  Call ("setPluginEnabled?name=$n&enabled=" + $(if ($on) { "true" } else { "false" })) | Out-Null
}
function Show {
  $en = Get-Enabled
  Write-Host ""
  Write-Host "장애 시나리오" -ForegroundColor Cyan
  foreach ($p in $Problems) {
    if ($en -contains $p) { Write-Host ("  [켜짐] " + $p) -ForegroundColor Red } else { Write-Host ("  [꺼짐] " + $p) -ForegroundColor DarkGray }
  }
  Write-Host "유지 관리 (켜 두기 권장)" -ForegroundColor Cyan
  foreach ($p in $Maint) {
    if ($en -contains $p) { Write-Host ("  [켜짐] " + $p) -ForegroundColor Green } else { Write-Host ("  [꺼짐] " + $p) -ForegroundColor Yellow }
  }
  $others = $en | Where-Object { ($Problems + $Maint) -notcontains $_ }
  if ($others) { Write-Host ("그 외 켜진 plugin: " + ($others -join ", ")) -ForegroundColor DarkGray }
}
function Assert-Manual {
  $v = kubectl -n $Ns get $Runner -o "jsonpath={.spec.template.spec.containers[0].env[?(@.name=='ET_BACKEND_URL')].value}" 2>$null
  $vf = kubectl -n $Ns get $Runner -o "jsonpath={.spec.template.spec.containers[0].env[?(@.name=='ET_BACKEND_URL')].valueFrom}" 2>$null
  if ($vf -or $v) {
    Write-Warning "자동 순환 모드입니다. 변경한 상태가 5초 안에 덮어써질 수 있습니다. overlay 에 problem-panel 또는 problem-patterns-manual component 를 켜세요."
  }
}

switch ($Action) {
  "list"  { Show }
  "reset" {
    Assert-Manual
    $en = Get-Enabled
    foreach ($p in $Problems) { if ($en -contains $p) { Write-Host "끄기: $p"; Set-Pattern $p $false } }
    Show
  }
  default {
    if (-not $Name) { throw "pattern 이름을 지정하세요. 예) .\kubernetes\problem.ps1 $Action CPULoad" }
    $all = $Problems + $Maint
    $match = $all | Where-Object { $_ -ieq $Name }
    if (-not $match) { throw "알 수 없는 pattern: $Name`n사용 가능: $($all -join ', ')" }
    Assert-Manual
    if ($Action -eq "on" -and $match -eq "LargeMemoryLeak") { Write-Warning "LargeMemoryLeak 은 backend 를 OOM 으로 재시작시킬 수 있습니다." }
    Set-Pattern $match ($Action -eq "on")
    Write-Host ("{0} → {1}" -f $match, $(if ($Action -eq "on") { "켜짐" } else { "꺼짐" }))
    Show
  }
}
