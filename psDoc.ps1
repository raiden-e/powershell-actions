[CmdletBinding()]
param(
    [parameter(Mandatory = $true, Position = 0)] [string] $path,
    [ValidateSet("Confluence", "HTML", "Markdown", IgnoreCase = $true)]
    [parameter(Mandatory = $false, Position = 1)] [string] $template = "Markdown",
    [parameter(Mandatory = $false, Position = 2)] [string] $outputDir = './help'
)
function Repair-String ($in = '', [bool]$includeBreaks = $false) {
    if ($in -eq $null) { return }

    $rtn = $in.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Trim()

    if ($includeBreaks) {
        $rtn = $rtn.Replace([Environment]::NewLine, '<br>')
    }
    return $rtn
}

$commandsHelp = (Get-Command -module $moduleName) | Get-Help -Full | Where-Object { ! $_.name.EndsWith('.ps1') }

if ([string]::IsNullOrWhiteSpace($commandsHelp)) {
    $commandsHelp = (Get-Command $moduleName -ErrorAction SilentlyContinue) | Get-Help -Full
    if ([string]::IsNullOrWhiteSpace($commandsHelp)) {
        try {
            $commandsHelp = Get-Help .\$moduleName -Full
            # $commandsHelp.details.name = (Resolve-Path .\$moduleName -ErrorAction SilentlyContinue).basename
        }
        catch {
            try {
                Get-Help .\$moduleName.ps1 -Full
                # $commandsHelp.details.name = (Resolve-Path .\$moduleName.ps1 -ErrorAction Stop).basename
            }
            catch {
                throw "ERROR: Command's help file is empty"
            }
        }
    }
}

foreach ($help in $commandsHelp) {
    $cmdHelp = (Get-Command $help.Name)

    # Get any aliases associated with the method
    $alias = Get-Alias -Definition $help.Name -ErrorAction SilentlyContinue
    if ($alias) {
        $help | Add-Member Alias $alias
    }

    # Parse the related links and assign them to a links hashtable.
    if (($help.relatedLinks | Out-String).Trim().Length -gt 0) {
        $links = $help.relatedLinks.navigationLink | ForEach-Object {
            if ($_.uri) { @{name = $_.uri; link = $_.uri; target = '_blank' } }
            if ($_.linkText) { @{name = $_.linkText; link = "#$($_.linkText)"; cssClass = 'psLink'; target = '_top' } }
        }
        $help | Add-Member Links $links
    }

    # Add parameter aliases to the object.
    foreach ($p in $help.parameters.parameter ) {
        $paramAliases = ($cmdHelp.parameters.values | Where-Object name -like $p.name | Select-Object aliases).Aliases
        if ($paramAliases) {
            $p | Add-Member Aliases "$($paramAliases -Join ', ')" -Force
        }
    }
}

# Create the output directory if it does not exist
if (!(Test-Path $outputDir)) {
    New-Item -Path $outputDir -ItemType Directory | Out-Null
}

$totalCommands = $commandsHelp.Count
if (!$totalCommands) {
    $totalCommands = 1
}

try {
    Import-Module $template -Force
}
catch {
    throw "Could not find template"
}

switch ($template) {
    "Markdown" { 
        $extension = "md"
    }
    "Confluence" { 
        $extension = "md"
    }
    "HTML" { 
        $extension = "html"
    }
}

foreach ($script in Get-ChildItem -Path $patch) {
    $MarkdownText = ConvertTo-MarkdownDoc -moduleName $moduleName -commandsHelp $commandsHelp
    $DocFile = Join-Path $script.Directory.FullName, $script.basename, ".$extension"
    $MarkdownText | Out-File $DocFile -Encoding utf8 -Force
}
