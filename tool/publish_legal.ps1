<#
.SYNOPSIS
  doc/legal/ の 4 つの HTML を、公開ページ（akmoor25/.github の koala/）に反映して、公開内容を確かめる。

.DESCRIPTION
  1. 公開用リポジトリを一時フォルダにクローンする。
  2. doc/legal/ の内容を koala/ にコピーする。
  3. 差分があればコミットして push する（差分が無ければ、何もしない）。
  4. GitHub Pages のビルドを待ち、公開された 4 ページが手元と同じ内容かを確かめる。
  5. 一時フォルダを消す。

  koala_flutter 側の commit と push は、このスクリプトでは行わない（先に済ませておく）。

.PARAMETER DryRun
  push せずに、差分だけを表示する。

.PARAMETER NoVerify
  push のあとの、公開内容の確認を省く。

.PARAMETER Message
  公開用リポジトリのコミットメッセージ。

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tool\publish_legal.ps1
  powershell -ExecutionPolicy Bypass -File tool\publish_legal.ps1 -DryRun
#>
[CmdletBinding()]
param(
  [switch]$DryRun,
  [switch]$NoVerify,
  [string]$Message = 'Update the Trip Itinerary (koala) privacy policy and terms of use'
)

$ErrorActionPreference = 'Stop'

$PagesRepo = 'https://github.com/akmoor25/.github.git'
$PagesBranch = 'main'
$PagesFolder = 'koala'
$PagesBaseUrl = 'https://akmoor25.github.io/.github/koala'
$Pages = 'privacy.ja', 'privacy.en', 'terms.ja', 'terms.en'

$Source = Join-Path (Split-Path -Parent $PSScriptRoot) 'doc\legal'
$Work = Join-Path ([IO.Path]::GetTempPath()) "koala-pages-$([guid]::NewGuid().ToString('N').Substring(0, 8))"

# git は、進捗を標準エラーに出す。PowerShell が、それを失敗と見なさないように、終了コードで判断する。
function Invoke-Git {
  param([Parameter(ValueFromRemainingArguments)][string[]]$GitArgs)
  $previous = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    & git @GitArgs 2>&1 | ForEach-Object { "$_" } | Write-Host
    if ($LASTEXITCODE -ne 0) { throw "git $($GitArgs -join ' ') が失敗しました（終了コード $LASTEXITCODE）。" }
  } finally {
    $ErrorActionPreference = $previous
  }
}

function Read-Text([string]$Path) {
  [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8).Replace("`r`n", "`n")
}

if (-not (Test-Path $Source)) { throw "doc\legal が見つかりません: $Source" }
foreach ($name in $Pages) {
  if (-not (Test-Path (Join-Path $Source "$name.html"))) { throw "$name.html が doc\legal にありません。" }
}
if (-not (Test-Path (Join-Path $Source 'style.css'))) { throw 'style.css が doc\legal にありません。' }

try {
  Write-Host "== 公開用リポジトリをクローンします: $PagesRepo"
  Invoke-Git clone --quiet --branch $PagesBranch $PagesRepo $Work

  $target = Join-Path $Work $PagesFolder
  if (-not (Test-Path $target)) { New-Item -ItemType Directory $target | Out-Null }
  Copy-Item (Join-Path $Source '*') -Destination $target -Force

  Push-Location $Work
  try {
    Invoke-Git add $PagesFolder
    $changed = (& git status --short) -join "`n"
    if (-not $changed) {
      Write-Host '== 変更はありません。公開ページは、すでに最新です。'
    } else {
      Write-Host '== 変更されるファイル:'
      Write-Host $changed
      if ($DryRun) {
        Write-Host '== -DryRun のため、push しません。'
        return
      }
      $sourceCommit = (& git -C (Split-Path -Parent $PSScriptRoot) rev-parse --short HEAD)
      Invoke-Git commit --quiet -m "$Message`n`nSync with koala_flutter $sourceCommit.`n`nCo-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
      Invoke-Git push origin $PagesBranch
      Write-Host '== push しました。'
    }
  } finally {
    Pop-Location
  }

  if ($NoVerify -or $DryRun) { return }

  Write-Host '== 公開内容を確かめます（反映まで、1 分ほどかかることがあります）'
  $allSame = $true
  foreach ($name in $Pages) {
    $local = Read-Text (Join-Path $Source "$name.html")
    $same = $false
    $status = 0
    for ($i = 0; $i -lt 12 -and -not $same; $i++) {
      try {
        $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 20 -Uri "$PagesBaseUrl/$name.html?t=$([guid]::NewGuid())"
        $status = $r.StatusCode
        $remote = [Text.Encoding]::UTF8.GetString($r.RawContentStream.ToArray()).Replace("`r`n", "`n")
        $same = ($remote -eq $local)
      } catch {
        $status = $_.Exception.Response.StatusCode.value__
      }
      if (-not $same) { Start-Sleep -Seconds 10 }
    }
    Write-Host ("{0,-12} HTTP {1}  手元と同じ: {2}" -f $name, $status, $same)
    if (-not $same) { $allSame = $false }
  }
  if (-not $allSame) {
    Write-Warning '手元と違うページがあります。しばらくしてから、もう一度実行してください（差分が無ければ、確認だけが行われます）。'
    exit 1
  }
  Write-Host '== 完了: 4 ページとも、手元と同じ内容で公開されています。'
} finally {
  if (Test-Path $Work) { Remove-Item $Work -Recurse -Force -ErrorAction SilentlyContinue }
}
