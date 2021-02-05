[CmdletBinding()]
param(
    [parameter(Mandatory = $true, Position = 0)]  [string] $path,
    [ValidateNotNullOrEmpty()]
    [parameter(Mandatory = $false, Position = 1)] [string] $docDir,
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
    $docDir = & { if ($env:TEMP) { return $env:Temp }else { return $pwd.Path } } | Join-Path -ChildPath "docs"
    Write-Warning "$docDir"
}

if ($log) {
    if ($log.Substring($log.Length - 4) -eq ".log") {
        $path = Join-Path $pwd -ChildPath $log
    }
    else {
        $path = Join-Path $pwd -ChildPath "$log.log"
    }
    try {
        Start-Transcript -Path $path -Force
    }
    catch {
        Write-Warning "Could'nt Start Transcript:"
        Write-Host $_
    }
}

# $gitBase = "$env:CI_PROJECT_URL.git"
$gitBase = "https://mips-git.materna.de/mips/dx-union/dev/ci-test"
$gitUrl = "$gitBase.git"
$wikiUrl = "$gitBase.wiki.git"
Write-Host "--- Starting script ---"
Write-Host "Test Path docDir `'$docDir`': $(Test-Path "$docdir")"
Write-Host "$env:CI_PROJECT_URL`n$gitUrl`n$wikiUrl`n$env:CI_PROJECT_DIR"
# Get-ChildItem $env:CI_PROJECT_DIR

if (Test-Path $docDir) {
    Remove-Item -Path $docDir -Force -Recurse
}

# Load template functions
try {
    $tplPath = $env:CI_PROJECT_DIR
    if (-not $tplPath) { $tplPath = $pwd }
    switch ($template) {
        "Markdown" {
            $extension = "md"
            Join-Path -Path "$tplPath/src" -ChildPath "tpl_Markdown.ps1"   | Import-Module -Force
        }
        "Confluence" {
            $extension = "md"
            Join-Path -Path "$tplPath/src" -ChildPath "tpl_Confluence.ps1" | Import-Module -Force
        }
        "HTML" {
            $extension = "html"
            Join-Path -Path "$tplPath/src" -ChildPath "tpl_HTML.ps1"       | Import-Module -Force
        }
    }
}
catch {
    throw "Could not find template`n$_"
}
try {
    Join-Path -Path $PSScriptRoot -ChildPath "Import-Help.ps1" | Import-Module -Force
}
catch {
    throw "Could not find importer`n$_"
}


# Create subdirectory if given

if ($path.Contains('$')) {
    $path2 = Invoke-Expression $path
    if (Test-Path $path2) {
        $path = $path2
    }
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

Test-Git
Initialize-Wiki -url $wikiUrl -path $docDir

foreach ($script in $scripts) {
    $outFile = Import-Help -path $script.FullName | ConvertTo-MarkdownDoc -moduleName "$($script.BaseName)"
    $RelativeDir = (Get-Item $script.Directory.Fullname | Resolve-Path -Relative) -replace "..\\$([Regex]::Escape($script.directory.name))", ''
    $DocFile = $docDir | Join-Path -ChildPath $RelativeDir | Join-Path -ChildPath "$($script.basename).$extension"
    if (!($docDir | Join-Path -ChildPath $RelativeDir | Test-Path)) {
        New-item -Path ($docDir | Join-Path -ChildPath $RelativeDir) -ItemType Directory -Force
    }
    Out-File $DocFile -InputObject $outFile -Encoding utf8 -Force
}

Push-Wiki -url $wikiUrl -path $docDir
