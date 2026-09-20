<#
.SYNOPSIS
  囍签 · 打包发布包（在开发机上执行）

.DESCRIPTION
  依次构建 player-web、admin-web 和 server，并打成一个可上传的 tar.gz：

      deploy\out\xiqian-<yyyyMMdd-HHmmss>.tar.gz

  包内结构（server-release.sh 依赖这个结构，请勿改动）：

      draw-server.jar
      player\   （玩家端静态文件）
      admin\    （管理端静态文件）

.PARAMETER JavaHome
  JDK 21 根目录，默认读取环境变量 JAVA_HOME。本项目要求 JDK 21，JDK 17 会编译失败。

.PARAMETER MavenRepo
  可选：显式指定 Maven 本地仓库目录，等价于 -Dmaven.repo.local=<目录>。

.PARAMETER OutDir
  发布包输出目录，默认 deploy\out。

.PARAMETER SkipTests
  跳过后端单元测试。

.PARAMETER ForceNpmInstall
  强制重新执行 npm ci（默认只在 node_modules 不存在时才安装）。

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File deploy\build.ps1 -JavaHome 'E:\environment\jdk-21.0.1'

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File deploy\build.ps1 -MavenRepo 'E:\Develop\maven_repos' -SkipTests
#>
[CmdletBinding()]
param(
    [string]$JavaHome = $env:JAVA_HOME,
    [string]$MavenRepo,
    [string]$OutDir,
    [switch]$SkipTests,
    [switch]$ForceNpmInstall
)

$ErrorActionPreference = 'Stop'

# 注意：Windows PowerShell 5.1 在执行 param() 默认值表达式时 $PSScriptRoot 还是空的，
# 因此脚本目录必须在脚本体内解析，否则 Join-Path 会因为空路径直接报错。
$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition }
if (-not $OutDir) { $OutDir = Join-Path $scriptDir 'out' }
$repoRoot = Split-Path -Parent $scriptDir

function Write-Step($message) {
    Write-Host ''
    Write-Host "==> $message" -ForegroundColor Cyan
}

function Get-NativeText {
    param(
        [string]$Command,
        [string[]]$Arguments
    )
    # Windows PowerShell 5.1 在 $ErrorActionPreference='Stop' 时，会把原生命令写到
    # stderr 的正常信息当成终止性错误（java -version 就永远写 stderr），故这里临时放宽。
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        return (& $Command @Arguments 2>&1 | Out-String)
    }
    finally {
        $ErrorActionPreference = $previous
    }
}

function Invoke-External {
    param(
        [string]$Command,
        [string[]]$Arguments,
        [string]$WorkingDirectory
    )
    Push-Location $WorkingDirectory
    $previous = $ErrorActionPreference
    try {
        # 同上：npm / mvnw 也会往 stderr 写进度信息，改为手工检查退出码。
        $ErrorActionPreference = 'Continue'
        & $Command @Arguments | Out-Host
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previous
        Pop-Location
    }
    if ($exitCode -ne 0) {
        throw "命令执行失败（退出码 $exitCode）：$Command $($Arguments -join ' ')"
    }
}

function Resolve-Tool($name) {
    $command = Get-Command $name -ErrorAction SilentlyContinue
    if (-not $command) { return $null }
    return $command.Source
}

# ---------------------------------------------------------------- 前置检查
Write-Step '检查打包环境'

if (-not $JavaHome -or -not (Test-Path (Join-Path $JavaHome 'bin\java.exe'))) {
    throw "找不到 JDK。请用 -JavaHome 指定 JDK 21 根目录，例如：-JavaHome 'E:\environment\jdk-21.0.1'"
}

$javaVersionOutput = Get-NativeText -Command (Join-Path $JavaHome 'bin\java.exe') -Arguments @('-version')
$javaMajor = 0
$javaMatch = [regex]::Match($javaVersionOutput, 'version "(\d+)')
if ($javaMatch.Success) { $javaMajor = [int]$javaMatch.Groups[1].Value }
if ($javaMajor -lt 21) {
    throw "当前 JDK 主版本为 $javaMajor，本项目要求 JDK 21。请用 -JavaHome 指向 JDK 21。"
}
Write-Host "    JDK: $JavaHome (Java $javaMajor)"

$npm = Resolve-Tool 'npm.cmd'
if (-not $npm) { $npm = Resolve-Tool 'npm' }
if (-not $npm) { throw '找不到 npm，请确认 Node.js 已安装并在 PATH 中。' }
Write-Host "    npm: $npm"

$tar = Resolve-Tool 'tar.exe'
if (-not $tar) { $tar = Resolve-Tool 'tar' }
if (-not $tar) { throw '找不到 tar.exe（Windows 10 1803+ 自带），无法生成发布包。' }
Write-Host "    tar: $tar"

# ---------------------------------------------------------------- 前端构建
foreach ($web in @('player-web', 'admin-web')) {
    Write-Step "构建 $web"
    $webDir = Join-Path $repoRoot $web
    if (-not (Test-Path $webDir)) { throw "目录不存在：$webDir" }

    $nodeModules = Join-Path $webDir 'node_modules'
    if ($ForceNpmInstall -or -not (Test-Path $nodeModules)) {
        Invoke-External -Command $npm -Arguments @('ci') -WorkingDirectory $webDir
    }
    else {
        Write-Host '    已存在 node_modules，跳过 npm ci（需要重装请加 -ForceNpmInstall）'
    }
    Invoke-External -Command $npm -Arguments @('run', 'build') -WorkingDirectory $webDir

    $distIndex = Join-Path $webDir 'dist\index.html'
    if (-not (Test-Path $distIndex)) { throw "$web 构建未产出 dist\index.html" }
    Write-Host "    产物: $web\dist"
}

# ---------------------------------------------------------------- 后端构建
Write-Step '构建 server'
$serverDir = Join-Path $repoRoot 'server'
$mavenArguments = @('clean', 'package')
if ($SkipTests) { $mavenArguments += '-DskipTests' }
if ($MavenRepo) {
    $mavenArguments += "-Dmaven.repo.local=$MavenRepo"
    Write-Host "    Maven 本地仓库: $MavenRepo"
}

$previousJavaHome = $env:JAVA_HOME
$env:JAVA_HOME = $JavaHome
try {
    Invoke-External -Command (Join-Path $serverDir 'mvnw.cmd') -Arguments $mavenArguments -WorkingDirectory $serverDir
}
finally {
    $env:JAVA_HOME = $previousJavaHome
}

$jarFile = Get-ChildItem -Path (Join-Path $serverDir 'target') -Filter 'draw-server-*.jar' -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notlike '*.original' } |
    Select-Object -First 1
if (-not $jarFile) { throw '未找到 target\draw-server-*.jar，后端构建可能失败。' }
Write-Host "    产物: $($jarFile.FullName)"

# ---------------------------------------------------------------- 组装发布包
Write-Step '组装发布包'
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$stageDir = Join-Path $OutDir ".stage-$stamp"
if (Test-Path $stageDir) { Remove-Item -Recurse -Force $stageDir }
New-Item -ItemType Directory -Path $stageDir | Out-Null

Copy-Item $jarFile.FullName (Join-Path $stageDir 'draw-server.jar')
Copy-Item (Join-Path $repoRoot 'player-web\dist') (Join-Path $stageDir 'player') -Recurse
Copy-Item (Join-Path $repoRoot 'admin-web\dist') (Join-Path $stageDir 'admin') -Recurse

$package = Join-Path $OutDir "xiqian-$stamp.tar.gz"
if (Test-Path $package) { Remove-Item -Force $package }
& $tar -czf $package -C $stageDir draw-server.jar player admin
if ($LASTEXITCODE -ne 0) { throw '打包失败。' }
Remove-Item -Recurse -Force $stageDir

# ---------------------------------------------------------------- 结果
$sizeMb = [math]::Round((Get-Item $package).Length / 1MB, 2)
Write-Host ''
Write-Host "发布包已生成：$package ($sizeMb MB)" -ForegroundColor Green
Write-Host '包含内容：'
& $tar -tzf $package | Where-Object { $_ -notmatch '/$' } | Select-Object -First 8 | ForEach-Object { Write-Host "    $_" }
Write-Host ''
Write-Host '下一步（二选一）：'
Write-Host '  1) 直接发布：powershell -ExecutionPolicy Bypass -File deploy\release.ps1 -Server root@你的服务器IP'
Write-Host '  2) 手动上传：scp <发布包> root@服务器:/tmp/  然后'
Write-Host '     ssh root@服务器 "sudo /opt/xiqian/bin/server-release.sh /tmp/xiqian-...tar.gz"'
