<#
.SYNOPSIS
  囍签 · 上传并发布（在开发机上执行）

.DESCRIPTION
  把 deploy\out 下的发布包上传到服务器 /tmp，并调用服务器上的
  /opt/xiqian/bin/server-release.sh 完成原子替换、重启与健康检查（失败会自动回滚）。

  前提：服务器已完成 deploy\README.md 里的首次部署（server-install.sh 已执行）。

.PARAMETER Server
  服务器地址，形如 root@1.2.3.4 或 deploy@example.com。

.PARAMETER Package
  发布包路径；默认取 deploy\out 下最新的 xiqian-*.tar.gz。

.PARAMETER Port
  SSH 端口，默认 22。

.PARAMETER IdentityFile
  可选：私钥文件路径（默认使用 ssh 自身配置）。

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File deploy\release.ps1 -Server root@1.2.3.4

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File deploy\release.ps1 -Server deploy@example.com -Port 2222 -IdentityFile "$env:USERPROFILE\.ssh\id_ed25519"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Server,
    [string]$Package,
    [int]$Port = 22,
    [string]$IdentityFile
)

$ErrorActionPreference = 'Stop'

# 注意：Windows PowerShell 5.1 在执行 param() 默认值表达式时 $PSScriptRoot 还是空的，
# 因此脚本目录必须在脚本体内解析。
$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition }

function Write-Step($message) {
    Write-Host ''
    Write-Host "==> $message" -ForegroundColor Cyan
}

function Resolve-Tool($name) {
    $command = Get-Command $name -ErrorAction SilentlyContinue
    if (-not $command) { return $null }
    return $command.Source
}

function Invoke-Native {
    param(
        [string]$Command,
        [string[]]$Arguments
    )
    # Windows PowerShell 5.1 在 $ErrorActionPreference='Stop' 时，会把原生命令写到
    # stderr 的正常信息（如 ssh 的提示、scp 的进度）当成终止性错误，故临时放宽。
    $previous = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $Command @Arguments | Out-Host
        return $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previous
    }
}

$ssh = Resolve-Tool 'ssh.exe'
if (-not $ssh) { $ssh = Resolve-Tool 'ssh' }
$scp = Resolve-Tool 'scp.exe'
if (-not $scp) { $scp = Resolve-Tool 'scp' }
if (-not $ssh -or -not $scp) { throw '找不到 ssh/scp，请确认 Windows OpenSSH 客户端已安装。' }

if (-not $Package) {
    $outDir = Join-Path $scriptDir 'out'
    $latest = Get-ChildItem -Path $outDir -Filter 'xiqian-*.tar.gz' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if (-not $latest) {
        throw "在 $outDir 下找不到发布包，请先执行 deploy\build.ps1。"
    }
    $Package = $latest.FullName
}
if (-not (Test-Path $Package)) { throw "发布包不存在：$Package" }

$packageName = Split-Path -Leaf $Package
$sizeMb = [math]::Round((Get-Item $Package).Length / 1MB, 2)
Write-Host "发布包: $Package ($sizeMb MB)"
Write-Host "目标服务器: $Server (端口 $Port)"

$commonOptions = @()
if ($IdentityFile) { $commonOptions += @('-i', $IdentityFile) }

# ---------------------------------------------------------------- 上传
Write-Step '上传发布包到 /tmp'
$scpArguments = @('-P', "$Port") + $commonOptions + @($Package, "${Server}:/tmp/$packageName")
$scpExitCode = Invoke-Native -Command $scp -Arguments $scpArguments
if ($scpExitCode -ne 0) { throw '上传失败。' }

# ---------------------------------------------------------------- 发布
Write-Step '在服务器上执行发布脚本（替换 + 重启 + 健康检查）'
# 单引号字符串：里面的 $(...) 与 $SUDO 原样传给远端 shell
$remoteScript = 'set -e; if [ "$(id -u)" -eq 0 ]; then SUDO=""; elif command -v sudo >/dev/null 2>&1; then SUDO="sudo"; else echo "需要 root 或可用的 sudo" >&2; exit 1; fi; $SUDO /opt/xiqian/bin/server-release.sh /tmp/' + $packageName

$sshArguments = @('-p', "$Port") + $commonOptions + @($Server, $remoteScript)
$sshExitCode = Invoke-Native -Command $ssh -Arguments $sshArguments
if ($sshExitCode -ne 0) {
    Write-Host ''
    Write-Host '发布失败：服务器已自动回滚到上一个版本，请查看上面的输出与：' -ForegroundColor Red
    Write-Host "    ssh $Server `"journalctl -u xiqian-draw -n 100 --no-pager`"" -ForegroundColor Red
    exit 1
}

Write-Host ''
Write-Host '发布完成。请在浏览器里做一次冒烟验证：' -ForegroundColor Green
Write-Host '    1) 打开玩家端首页，输入 6 位组局码能进入'
Write-Host '    2) 打开管理后台登录，并"新建组局"成功（验证写接口与 CSRF 正常）'
Write-Host '    3) 开一轮、手机抽签，后台进度实时刷新（验证 SSE 穿透 nginx）'
