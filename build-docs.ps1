[CmdletBinding()]
param(
    [parameter(Mandatory = $true, Position = 0)]  [string] $path,
    [ValidateNotNullOrEmpty()]
    [parameter(Mandatory = $false, Position = 1)] [string] $docDir,
    # if your modules are in e.g. repo/src
    [parameter(Mandatory = $false, Position = 2)] [string] $subdir,
    [ValidateSet("Confluence", "HTML", "Markdown", IgnoreCase = $true)]
    [parameter(Mandatory = $false, Position = 3)] [string] $template = "Markdown",
    [ValidatePattern('^([\w,+\(\)\.\-]|[ ](?! ))+[^\.]$')]
    [parameter(Mandatory = $false, Position = 4)] [string]$log
)
$ErrorActionPreference = "Stop"

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
        $logPath =  $pwd | Join-Path -ChildPath "$log.log"
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

$whereFilter = { (".ps1", ".psm1") -contains $_.extension -and $_.Directory -notlike "*[\\\/]src" }
# The -filter is quicker than powershells post filter methods
$scripts = Get-ChildItem -Recurse -Force -Path $path -Filter "*.ps*1" | Where-Object $whereFilter
Write-Host "Found scripts: $scripts"

foreach ($script in $scripts) {
    $outString = $script.FullName | Import-Help | ConvertTo-MarkdownDoc -moduleName $script.BaseName
    $RelativeDir = (Get-Item $script.Directory.Fullname | Resolve-Path -Relative).Replace("\.+\\$([Regex]::Escape($script.directory.name))\.*", "")
    # TODO keep directorial structure
    # if($RelativeDir.Directory.name -ne $this){ $RelativeDir =  "\.+\\$([Regex]::Escape($script.directory.name))\.*", "" }
    $DocFile = $docDir | Join-Path -ChildPath $RelativeDir | Join-Path -ChildPath "$($script.basename).$extension"
    "Writing: $DocFile"
    if (-not $docDir | Join-Path -ChildPath $RelativeDir | Test-Path) {
        $docDir | Join-Path -ChildPath $RelativeDir | New-item -ItemType Directory -Force
    }
    $outString | Out-File $DocFile -Encoding utf8 -Force
}
