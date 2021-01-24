[CmdletBinding()]
param(
    [parameter(Mandatory = $true, Position = 0)]  [string] $path,
    [ValidateSet("Confluence", "HTML", "Markdown", IgnoreCase = $true)]
    [parameter(Mandatory = $false, Position = 1)] [string] $subdir,
    [parameter(Mandatory = $true, Position = 2)]  [string] $outputDir,
    [parameter(Mandatory = $false, Position = 3)] [string] $template = "Markdown"
)

function Import-Help {
    param (
        $moduleName
    )
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

    $totalCommands = $commandsHelp.Count
    if (!$totalCommands) {
        $totalCommands = 1
    }
}

# Create the output directory if it does not exist
if (!$outputDir) {
    throw "No output directory provided"
}
if (!(Test-Path $outputDir)) {
    New-Item -Path $outputDir -ItemType Directory | Out-Null
}

# Load template functions
try {
    switch ($template) {
        "Markdown" {
            $extension = "md"
            Join-Path -Path "$PSScriptRoot/src" -ChildPath "Markdown.ps1"   | Import-Module -Force
        }
        "Confluence" {
            $extension = "md"
            Join-Path -Path "$PSScriptRoot/src" -ChildPath "Confluence.ps1" | Import-Module -Force
        }
        "HTML" {
            $extension = "html"
            Join-Path -Path "$PSScriptRoot/src" -ChildPath "HTML.ps1"       | Import-Module -Force
        }
    }
}
catch {
    throw "Could not find template"
}

# Create subdirectory if given
if ($subdir) {
    $testPath = Join-Path -Path $path -ChildPath $subdir
    if (Test-Path $testPath) {
        $path = $testPath
    }
    else {
        Write-Warning "Path does not exist: $testpath"
    }
}


foreach ($script in Get-ChildItem -Path "$path/*" -Include "*.ps1", "*.psm1" -Recurse) {
    $outFile = Import-Help $script | ConvertTo-MarkdownDoc -moduleName $moduleName -commandsHelp $_
    $DocFile = Join-Path $script.Directory.FullName, $script.basename, ".$extension"
    Out-File $DocFile -InputObject $outFile -Encoding utf8 -Force
}
