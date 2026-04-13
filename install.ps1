#Requires -Version 5.1
<#
.SYNOPSIS
    prompt-appender 一键安装脚本 (Windows PowerShell / PowerShell Core)

.DESCRIPTION
    自动下载并安装 prompt-appender，配置 OpenCode 插件和 Claude Code 钩子。

.PARAMETER InstallDir
    安装目录（默认: $env:LOCALAPPDATA\prompt-appender）

.PARAMETER NoOpenCode
    跳过 OpenCode 集成配置

.PARAMETER NoClaude
    跳过 Claude Code 集成配置

.PARAMETER SkipConfig
    跳过创建默认配置文件

.EXAMPLE
    # 远程一键安装
    irm https://raw.githubusercontent.com/anomalyco/prompt-appender/main/install.ps1 | iex

    # 本地运行
    .\install.ps1

    # 指定安装目录
    .\install.ps1 -InstallDir "C:\tools\prompt-appender"
#>

[CmdletBinding()]
param(
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA "prompt-appender"),
    [switch]$NoOpenCode,
    [switch]$NoClaude,
    [switch]$SkipConfig
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── 颜色输出 ──────────────────────────────────────────────────────────────────
function Write-Info    { param([string]$Msg) Write-Host "[INFO]  $Msg" -ForegroundColor Cyan }
function Write-Ok      { param([string]$Msg) Write-Host "[OK]    $Msg" -ForegroundColor Green }
function Write-Warn    { param([string]$Msg) Write-Host "[WARN]  $Msg" -ForegroundColor Yellow }
function Write-Err     { param([string]$Msg) Write-Host "[ERROR] $Msg" -ForegroundColor Red }
function Write-Section { param([string]$Msg) Write-Host "`n=== $Msg ===" -ForegroundColor Magenta }

# ── 常量 ──────────────────────────────────────────────────────────────────────
$RepoUrl        = "https://github.com/anomalyco/prompt-appender"
$RepoArchiveUrl = "https://github.com/anomalyco/prompt-appender/archive/refs/heads/main.zip"

$ConfigureOpenCode = -not $NoOpenCode
$ConfigureClaude   = -not $NoClaude

# ── 工具函数 ──────────────────────────────────────────────────────────────────

function Test-CommandExists {
    param([string]$Name)
    $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

# 读取 JSON 文件，返回 PSCustomObject；文件不存在则返回空对象
function Read-JsonFile {
    param([string]$Path)
    if (Test-Path $Path) {
        try {
            return Get-Content $Path -Raw -Encoding UTF8 | ConvertFrom-Json
        } catch {
            Write-Warn "无法解析 JSON 文件: $Path，将重新创建"
            return [PSCustomObject]@{}
        }
    }
    return [PSCustomObject]@{}
}

# 将 PSCustomObject 写入 JSON 文件（UTF-8，2空格缩进）
function Write-JsonFile {
    param([string]$Path, [object]$Data)
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    # ConvertTo-Json depth=10，避免嵌套被截断
    $json = $Data | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($Path, $json + "`n", [System.Text.Encoding]::UTF8)
}

# 确保 JSON 对象的某个属性（数组）中包含指定字符串值
function Add-ToJsonArray {
    param([string]$FilePath, [string]$PropertyName, [string]$Value)

    $obj = Read-JsonFile $FilePath

    # 获取或初始化数组属性
    if ($obj.PSObject.Properties[$PropertyName]) {
        $arr = @($obj.$PropertyName)
    } else {
        $arr = @()
    }

    if ($arr -contains $Value) {
        Write-Info "已存在，跳过: $PropertyName = $Value"
        return
    }

    $arr += $Value
    # 重新设置属性
    if ($obj.PSObject.Properties[$PropertyName]) {
        $obj.$PropertyName = $arr
    } else {
        $obj | Add-Member -NotePropertyName $PropertyName -NotePropertyValue $arr
    }

    Write-JsonFile $FilePath $obj
}

# 向 settings.json 注入 Claude Code hook（幂等操作）
function Add-ClaudeHook {
    param([string]$SettingsPath, [string]$HookCommand)

    $settings = Read-JsonFile $SettingsPath

    # 确保 hooks 属性存在
    if (-not $settings.PSObject.Properties["hooks"]) {
        $settings | Add-Member -NotePropertyName "hooks" -NotePropertyValue ([PSCustomObject]@{})
    }

    # 确保 hooks.UserPromptSubmit 存在
    if (-not $settings.hooks.PSObject.Properties["UserPromptSubmit"]) {
        $settings.hooks | Add-Member -NotePropertyName "UserPromptSubmit" -NotePropertyValue @()
    }

    # 检查是否已注册（通过 command 字段判断）
    $submitHooks = @($settings.hooks.UserPromptSubmit)
    foreach ($group in $submitHooks) {
        if ($group -and $group.PSObject.Properties["hooks"]) {
            foreach ($h in @($group.hooks)) {
                if ($h -and $h.PSObject.Properties["command"] -and $h.command -eq $HookCommand) {
                    Write-Info "Claude Code hook 已注册，跳过"
                    return
                }
            }
        }
    }

    $newHookEntry = [PSCustomObject]@{
        type    = "command"
        command = $HookCommand
        timeout = 5
    }

    # 查找 matcher="" 的分组
    $targetGroup = $null
    foreach ($group in $submitHooks) {
        if ($group -and $group.PSObject.Properties["matcher"] -and $group.matcher -eq "") {
            $targetGroup = $group
            break
        }
    }

    if ($null -eq $targetGroup) {
        $targetGroup = [PSCustomObject]@{
            matcher = ""
            hooks   = @($newHookEntry)
        }
        $settings.hooks.UserPromptSubmit = @($submitHooks) + @($targetGroup)
    } else {
        if (-not $targetGroup.PSObject.Properties["hooks"]) {
            $targetGroup | Add-Member -NotePropertyName "hooks" -NotePropertyValue @($newHookEntry)
        } else {
            $targetGroup.hooks = @($targetGroup.hooks) + @($newHookEntry)
        }
    }

    Write-JsonFile $SettingsPath $settings
}

# ── 步骤 1：检查依赖 ──────────────────────────────────────────────────────────
Write-Section "检查依赖"

# 检查 bun
$BunInstalled = Test-CommandExists "bun"
if (-not $BunInstalled) {
    Write-Warn "未找到 bun，尝试自动安装..."
    try {
        # 官方 bun Windows 安装方式
        Invoke-RestMethod "https://bun.sh/install.ps1" | Invoke-Expression
        # 刷新 PATH
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "User") + ";" +
                    [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
        if (-not (Test-CommandExists "bun")) {
            # bun 默认安装到 %USERPROFILE%\.bun\bin
            $bunBin = Join-Path $env:USERPROFILE ".bun\bin"
            if (Test-Path $bunBin) {
                $env:PATH = "$bunBin;$env:PATH"
            }
        }
    } catch {
        Write-Err "bun 安装失败: $_"
        Write-Err "请手动安装 bun: https://bun.sh"
        exit 1
    }
}

if (-not (Test-CommandExists "bun")) {
    Write-Err "bun 未找到，请手动安装后重试: https://bun.sh"
    exit 1
}

$BunVersion = (bun --version 2>&1)
Write-Ok "bun 已就绪: $BunVersion"

# 检查 node（Claude Code hook 运行时）
$NodeInstalled = Test-CommandExists "node"
if (-not $NodeInstalled) {
    Write-Warn "未找到 node。Claude Code 集成需要 node >= 18。"
    Write-Warn "请安装 Node.js: https://nodejs.org"
    $ConfigureClaude = $false
} else {
    $NodeVersion = (node --version 2>&1)
    Write-Ok "node 已就绪: $NodeVersion"
}

# 检查 git
$HasGit = Test-CommandExists "git"

# ── 步骤 2：下载源码 ──────────────────────────────────────────────────────────
Write-Section "下载 prompt-appender"

if ((Test-Path $InstallDir) -and (Test-Path (Join-Path $InstallDir "package.json"))) {
    Write-Info "目录已存在: $InstallDir"
    if ($HasGit -and (Test-Path (Join-Path $InstallDir ".git"))) {
        Write-Info "检测到 git 仓库，执行 git pull 更新..."
        try {
            git -C $InstallDir pull --ff-only 2>&1 | Out-Null
            Write-Ok "已更新到最新版本"
        } catch {
            Write-Warn "git pull 失败，将使用现有代码继续"
        }
    } else {
        Write-Info "跳过下载，使用现有代码"
    }
} else {
    $ParentDir = Split-Path $InstallDir -Parent
    if (-not (Test-Path $ParentDir)) {
        New-Item -ItemType Directory -Path $ParentDir -Force | Out-Null
    }

    if ($HasGit) {
        Write-Info "使用 git clone 下载..."
        git clone --depth=1 "$RepoUrl.git" $InstallDir
    } else {
        Write-Info "使用 Invoke-WebRequest 下载压缩包..."
        $TempDir = Join-Path $env:TEMP "prompt-appender-install-$(Get-Random)"
        New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

        try {
            $ZipPath = Join-Path $TempDir "prompt-appender.zip"
            # 兼容 TLS 1.2+
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
            Invoke-WebRequest -Uri $RepoArchiveUrl -OutFile $ZipPath -UseBasicParsing

            Write-Info "解压文件..."
            Expand-Archive -Path $ZipPath -DestinationPath $TempDir -Force

            # 找到解压后的子目录
            $ExtractedDir = Get-ChildItem $TempDir -Directory | Where-Object { $_.Name -like "prompt-appender-*" } | Select-Object -First 1
            if ($null -eq $ExtractedDir) {
                # 如果没有子目录前缀，找任意子目录
                $ExtractedDir = Get-ChildItem $TempDir -Directory | Select-Object -First 1
            }
            if ($null -eq $ExtractedDir) {
                throw "解压后未找到源码目录"
            }

            Move-Item $ExtractedDir.FullName $InstallDir
            Write-Ok "解压完成"
        } finally {
            if (Test-Path $TempDir) {
                Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

Write-Ok "源码位置: $InstallDir"

# ── 步骤 3：构建 ──────────────────────────────────────────────────────────────
Write-Section "构建项目"

Write-Info "安装依赖..."
Push-Location $InstallDir
try {
    # 将 stderr 重定向到 stdout，避免 PowerShell 将其视为错误流
    $installOut = & cmd /c "bun install 2>&1"
    $installOut | ForEach-Object { Write-Host "  $_" }
    if ($LASTEXITCODE -ne 0) {
        throw "bun install 失败（退出码: $LASTEXITCODE）"
    }

    Write-Info "编译 TypeScript..."
    $buildOut = & cmd /c "bun run build 2>&1"
    $buildOut | ForEach-Object { Write-Host "  $_" }
    if ($LASTEXITCODE -ne 0) {
        throw "bun run build 失败（退出码: $LASTEXITCODE）"
    }
} finally {
    Pop-Location
}

$IndexJs  = Join-Path $InstallDir "dist\index.js"
$HookJs   = Join-Path $InstallDir "dist\claude-hook.js"

if (-not (Test-Path $IndexJs) -or -not (Test-Path $HookJs)) {
    Write-Err "构建产物缺失，请检查构建输出"
    exit 1
}

Write-Ok "构建成功: dist\index.js, dist\claude-hook.js"

# ── 步骤 4：配置 OpenCode ─────────────────────────────────────────────────────
if ($ConfigureOpenCode) {
    Write-Section "配置 OpenCode 集成"

    $OpenCodeConfigDir  = Join-Path $env:USERPROFILE ".config\opencode"
    $OpenCodeConfigFile = Join-Path $OpenCodeConfigDir "opencode.json"

    if (-not (Test-Path $OpenCodeConfigDir)) {
        New-Item -ItemType Directory -Path $OpenCodeConfigDir -Force | Out-Null
    }
    if (-not (Test-Path $OpenCodeConfigFile)) {
        '{}' | Set-Content $OpenCodeConfigFile -Encoding UTF8
    }

    # 使用 file:/// URI，Windows 路径需要正斜杠
    $PluginPath = "file:///" + ($InstallDir -replace "\\", "/")
    Add-ToJsonArray $OpenCodeConfigFile "plugin" $PluginPath
    Write-Ok "已注册插件到 $OpenCodeConfigFile"

    # 创建 OpenCode 提示语配置
    if (-not $SkipConfig) {
        $OcPromptConfig = Join-Path $OpenCodeConfigDir "prompt-appender.jsonc"
        if (-not (Test-Path $OcPromptConfig)) {
            $ConfigContent = @'
{
  // 是否启用插件（全局开关）
  "enabled": true,

  // 提示语列表（每条可单独开关）
  "prompts": [
    {
      "name": "ask-before-end",
      "enabled": true,
      "content": "当你完成工作时，请调用提问工具（askQuestions）来获取进一步的指示，而不是直接结束对话。\nWhen you finish the task, call the askQuestions tool to request further instructions instead of ending the conversation."
    }
  ]
}
'@
            [System.IO.File]::WriteAllText($OcPromptConfig, $ConfigContent, [System.Text.Encoding]::UTF8)
            Write-Ok "已创建配置文件: $OcPromptConfig"
        } else {
            Write-Info "配置文件已存在，跳过: $OcPromptConfig"
        }
    }
}

# ── 步骤 5：配置 Claude Code ──────────────────────────────────────────────────
if ($ConfigureClaude) {
    Write-Section "配置 Claude Code 集成"

    $ClaudeConfigDir    = Join-Path $env:USERPROFILE ".claude"
    $ClaudeSettingsFile = Join-Path $ClaudeConfigDir "settings.json"

    if (-not (Test-Path $ClaudeConfigDir)) {
        New-Item -ItemType Directory -Path $ClaudeConfigDir -Force | Out-Null
    }
    if (-not (Test-Path $ClaudeSettingsFile)) {
        '{}' | Set-Content $ClaudeSettingsFile -Encoding UTF8
    }

    # Windows 路径在 command 中需用反斜杠，node 命令兼容两种
    $HookCommand = "node `"$HookJs`""
    Add-ClaudeHook $ClaudeSettingsFile $HookCommand
    Write-Ok "已注册 Claude Code hook 到 $ClaudeSettingsFile"

    # 创建 Claude Code 提示语配置
    if (-not $SkipConfig) {
        $CcPromptConfig = Join-Path $ClaudeConfigDir "prompt-appender.jsonc"
        if (-not (Test-Path $CcPromptConfig)) {
            $ConfigContent = @'
{
  "enabled": true,
  "prompts": [
    {
      "name": "ask-before-end",
      "enabled": true,
      "content": "当你完成工作时，请调用提问工具（askQuestions）来获取进一步的指示，而不是直接结束对话。\nWhen you finish the task, call the askQuestions tool to request further instructions instead of ending the conversation."
    }
  ]
}
'@
            [System.IO.File]::WriteAllText($CcPromptConfig, $ConfigContent, [System.Text.Encoding]::UTF8)
            Write-Ok "已创建配置文件: $CcPromptConfig"
        } else {
            Write-Info "配置文件已存在，跳过: $CcPromptConfig"
        }
    }
}

# ── 完成 ──────────────────────────────────────────────────────────────────────
Write-Section "安装完成"

Write-Host ""
Write-Host "prompt-appender 安装成功！" -ForegroundColor Green -NoNewline
Write-Host ""
Write-Host ""
Write-Host "  安装目录: " -NoNewline; Write-Host $InstallDir -ForegroundColor Cyan

if ($ConfigureOpenCode) {
    Write-Host "  OpenCode 配置: " -NoNewline
    Write-Host (Join-Path $env:USERPROFILE ".config\opencode\opencode.json") -ForegroundColor Cyan
    Write-Host "  OpenCode 提示语: " -NoNewline
    Write-Host (Join-Path $env:USERPROFILE ".config\opencode\prompt-appender.jsonc") -ForegroundColor Cyan
}

if ($ConfigureClaude) {
    Write-Host "  Claude Code 配置: " -NoNewline
    Write-Host (Join-Path $env:USERPROFILE ".claude\settings.json") -ForegroundColor Cyan
    Write-Host "  Claude Code 提示语: " -NoNewline
    Write-Host (Join-Path $env:USERPROFILE ".claude\prompt-appender.jsonc") -ForegroundColor Cyan
}

Write-Host ""
Write-Host "后续步骤:" -ForegroundColor Yellow
Write-Host "  1. 编辑提示语配置文件，添加你想自动注入的提示"
Write-Host "  2. 重启 OpenCode / Claude Code 使配置生效"

if ($ConfigureClaude) {
    Write-Host ""
    Write-Host "  验证 Claude Code hook（可选）:" -ForegroundColor Yellow
    Write-Host "  echo '{`"session_id`":`"test`",`"cwd`":`"$($PWD.Path -replace '\\','\\')`",`"hook_event_name`":`"UserPromptSubmit`",`"prompt`":`"hello`"}' | node `"$HookJs`"" -ForegroundColor Cyan
}

Write-Host ""
