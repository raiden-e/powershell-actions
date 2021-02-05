[CmdletBinding()]
param(
    [parameter(Mandatory = $true, Position = 0)]  [string] $path,
    [ValidateNotNullOrEmpty()]
    [parameter(Mandatory = $false, Position = 1)] [string] $docDir,
    # if your modules are in e.g. repo/src
    [parameter(Mandatory = $false, Position = 2)] [string] $subdir,
    [parameter(Mandatory = $false, Position = 3)]
    [ValidateSet("Confluence", "HTML", "Markdown", IgnoreCase = $true)] [string] $template = "Markdown",
    [parameter(Mandatory = $false, Position = 4)]
    [ValidatePattern('^([\w,+\(\)\.\-]|[ ](?! ))+[^\.]$')][string]$log
)
$ErrorActionPreference = "Stop"
Get-ChildItem env:
function Initialize-Wiki {
    [CmdletBinding()]
    param (
        [string]$actionName,
        [string]$actionMail
    )
    if ($env:gitWiki -and $actionName -and $actionMail) {
        git config --global user.name $actionName
        git config --global user.email $actionMail
        clone $env:gitWiki $docDir
        Get-ChildItem -Recurse -Force -Path $docDir | Where-Object { $_.fullname -notlike '*[\/].git*' } | Remove-Item -Recurse -Force
    }
    else {
        Write-Warning "Cannot Initialize Wiki"
    }
}
function Push-Wiki {
    [CmdletBinding()]
    param (
        $docDir
    )
    if ($env:gitWiki) {
        $local:oldLocation
        Set-Location $docDir
        git add -A
        git commit -m "Auto-updated Wiki"
        git push origin "HEAD:master"
        Set-Location $local:oldLocation
    }
    else {
        Write-Warning "Not pushing Wiki"
    }
}


if ((!(Test-Path variable:IsWindows)) -or ($IsWindows)) {
    #IsWindows does not exist in Windows PowerShell (first check above) and is $True on PowerShell Core / 7 on Windows
    $CurrentUser = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent())
    $IsAdmin = $CurrentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    Write-Host "isAdmin: $IsAdmin"
}
else {
    Write-Host "Not running on Windows."
}

if ([string]::IsNullOrWhiteSpace($docDir)) {
    $docDir = & { if ($env:temp) { return $env:temp }else { return $pwd.Path } } | Join-Path -ChildPath "docs"
    Write-Warning "$docDir"
}

if ($log) {
    if ($log.Substring($log.Length - 4) -eq ".log") {
        $logPath = $pwd | Join-Path -ChildPath $log
    }
    else {
        $logPath = $pwd | Join-Path -ChildPath "$log.log"
    }
    try {
        Start-Transcript -Path $logPath -Force
    }
    catch {
        Write-Warning "Could'nt Start Transcript:"
        Write-Host $_
    }
}

try {
    $tplPath = Join-Path $PSScriptRoot -ChildPath "src"
    if (-not $tplPath) { $tplPath = $pwd }
    switch ($template) {
        "Markdown" {
            $extension = "md"
            $tplPath | Join-Path -ChildPath "tpl_Markdown.ps1"   | Import-Module -Force
        }
        "Confluence" {
            $extension = "md"
            $tplPath | Join-Path -ChildPath "tpl_Confluence.ps1" | Import-Module -Force
        }
        "HTML" {
            $extension = "html"
            $tplPath | Join-Path -ChildPath "tpl_HTML.ps1"       | Import-Module -Force
        }
    }
}
catch {
    throw "Could not find template`n$_"
}

try {
    $PSScriptRoot | Join-Path -ChildPath "src" | Join-Path -ChildPath "Import-Help.ps1" | Import-Module -Force
}
catch {
    throw "Could not find importer`n$_"
}

if ($subdir) {
    $testPath = Join-Path -Path $path -ChildPath $subdir
    if (Test-Path $testPath) {
        $path = $testPath
    }
    else {
        Write-Warning "Path does not exist: $testpath"
    }
}

$whereFilter = { (".ps1", ".psm1") -contains $_.extension }
# The -filter is quicker than powershells post filter methods
$scripts = Get-ChildItem -Recurse -Force -Path $path -Filter "*.ps*1" | Where-Object $whereFilter
Write-Host "Found scripts: $scripts"

$oldLocation = $pwd
Set-Location $path
Initialize-Wiki
foreach ($script in $scripts) {
    $outString = $script.FullName | Import-Help | ConvertTo-MarkdownDoc -moduleName $script.Name
    $RelativeDir = (Get-Item $script.Directory.Fullname | Resolve-Path -Relative).Substring(2)
    # $RelativeDir = "$RelativeDir" -replace "\.*\\.+\\", ''
    $scriptDocDir = $docDir | Join-Path -ChildPath $RelativeDir
    $DocFile = $scriptDocDir | Join-Path -ChildPath "$($script.basename).$extension"
    "Writing: $DocFile"
    if (-not ($scriptDocDir | Test-Path)) {
        New-item -Path $scriptDocDir -ItemType Directory -Force | Out-Null
    }
    $outString | Out-File $DocFile -Encoding utf8 -Force
}
Set-Location $oldLocation
Push-Wiki -docDir $docDir
