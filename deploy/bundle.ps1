<#
.SYNOPSIS
  囍签 · 生成本地打包好的上传包（一个文件搞定）

.DESCRIPTION
  先调用 build.ps1 打出发布包，再把发布包和整套部署脚本一起装进一个 tar.gz：

      deploy\out\xiqian-bundle-<时间戳>.tar.gz
        ├── deploy\                        部署脚本、nginx/systemd 配置、手册
        └── release\
            └── xiqian-<时间戳>.tar.gz     应用发布包（jar + 玩家端 + 管理端）

  只需把这一个文件传到服务器 /root，然后在服务器上执行：

      cd /root
      tar -xzf xiqian-bundle-*.tar.gz
      bash deploy/server-install.sh              # 第 1 次：生成配置模板后中止
      vi /etc/xiqian/draw.env                    # 填两个口令
      bash deploy/server-install.sh --init-db     # 正式安装 + 建库
      bash deploy/server-release.sh release/xiqian-*.tar.gz

.PARAMETER JavaHome
  JDK 21 根目录，默认读取 JAVA_HOME。JDK 17 无法编译本项目。

.PARAMETER MavenRepo
  可选：Maven 本地仓库目录。

.PARAMETER SkipTests
  跳过后端单元测试。

.PARAMETER SkipBuild
  跳过编译，直接把 deploy\out 下最新的发布包打进上传包
  （适合只改了部署脚本、或复用已经打好的包）。

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File deploy\bundle.ps1 -JavaHome 'E:\environment\jdk-21.0.1'
#>
[CmdletBinding()]
param(
    [string]$JavaHome = $env:JAVA_HOME,
    [string]$MavenRepo,
    [switch]$SkipTests,
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'

# Windows PowerShell 5.1 在执行 param() 默认值表达式时 $PSScriptRoot 还是空的
$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition }
$outDir = Join-Path $scriptDir 'out'

function Write-Step($message) {
    Write-Host ''
    Write-Host "==> $message" -ForegroundColor Cyan
}

function Get-Tool($name) {
    $command = Get-Command $name -ErrorAction SilentlyContinue
    if (-not $command) { return $null }
    return $command.Source
}

$tarExe = Get-Tool 'tar.exe'
if (-not $tarExe) { $tarExe = Get-Tool 'tar' }
if (-not $tarExe) { throw '找不到 tar.exe（Windows 10 1803+ 自带），无法打包。' }

# ---------------------------------------------------------------- 打包应用
if (-not $SkipBuild) {
    Write-Step '调用 build.ps1 打包应用（前端 + 后端）'
    $buildArgs = @{}
    if ($JavaHome) { $buildArgs['JavaHome'] = $JavaHome }
    if ($MavenRepo) { $buildArgs['MavenRepo'] = $MavenRepo }
    if ($SkipTests) { $buildArgs['SkipTests'] = $true }
    & (Join-Path $scriptDir 'build.ps1') @buildArgs
}
else {
    Write-Step '跳过编译，复用已有的发布包'
}

$release = Get-ChildItem -Path $outDir -Filter 'xiqian-*.tar.gz' -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notlike 'xiqian-bundle-*' } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
if (-not $release) {
    throw "在 $outDir 下找不到发布包，请先执行 deploy\build.ps1。"
}
Write-Host "    使用发布包: $($release.Name)"

# ---------------------------------------------------------------- 组装上传包
Write-Step '组装上传包'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$stage = Join-Path $outDir ".bundle-$stamp"
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory -Path (Join-Path $stage 'deploy') | Out-Null
New-Item -ItemType Directory -Path (Join-Path $stage 'release') | Out-Null

# 部署脚本与配置（排除本脚本自身与 out 目录）
Get-ChildItem -Path $scriptDir -File |
    Where-Object { $_.Name -ne 'bundle.ps1' } |
    ForEach-Object { Copy-Item $_.FullName (Join-Path $stage 'deploy') }
Copy-Item $release.FullName (Join-Path $stage 'release')

$bundle = Join-Path $outDir "xiqian-bundle-$stamp.tar.gz"
if (Test-Path $bundle) { Remove-Item -Force $bundle }
& $tarExe -czf $bundle -C $stage deploy release
if ($LASTEXITCODE -ne 0) { throw '打包失败。' }
Remove-Item -Recurse -Force $stage

# ---------------------------------------------------------------- 结果
$sizeMb = [math]::Round((Get-Item $bundle).Length / 1MB, 2)
Write-Host ''
Write-Host "上传包已生成：$bundle ($sizeMb MB)" -ForegroundColor Green
Write-Host '包含内容：'
& $tarExe -tzf $bundle | Where-Object { $_ -notmatch '/$' } | Select-Object -First 14 | ForEach-Object { Write-Host "    $_" }
Write-Host ''
Write-Host '接下来（把上面这个文件传到服务器 /root，方式任选）：' -ForegroundColor Yellow
Write-Host '  A) WinSCP 图形界面：主机=公网IP 端口=22 用户=root，把文件拖到 /root/'
Write-Host "  B) 命令行：scp `"$bundle`" root@公网IP:/root/"
Write-Host '  C) 腾讯云 COS：控制台上传后生成临时下载链接，服务器上 curl -o /root/包名 "链接"'
Write-Host ''
Write-Host '然后在服务器上执行：'
Write-Host '    cd /root && tar -xzf xiqian-bundle-*.tar.gz'
Write-Host '    bash deploy/server-install.sh'
Write-Host '    vi /etc/xiqian/draw.env'
Write-Host '    bash deploy/server-install.sh --init-db'
Write-Host '    bash deploy/server-release.sh release/xiqian-*.tar.gz'
