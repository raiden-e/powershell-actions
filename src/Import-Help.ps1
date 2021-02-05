function Import-Help {
    [CmdletBinding()]
    param (
        # Name of the Module
        [string]$moduleName,
        # Specifies a path to one or more locations. Wildcards are permitted.
        [Parameter(Mandatory=$true,
                   Position=1,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   HelpMessage="Name of the Module.")]
        $path
    )

    if ([string]::IsNullOrWhiteSpace($moduleName)) {
        if ($path) {
            if (!(Test-Path $path)) {
                throw "$path does not exist"
            }
            Write-Host $path
            $commandsHelp = Get-Help $path -Full
            # | Where-Object { ! $_.name.EndsWith('.ps1') }
        }
        else {
            throw "either -modulename or -path must be given"
        }
    }
    else {
        $commandsHelp = (Get-Command -module $moduleName) | Get-Help -Full | Where-Object { ! $_.name.EndsWith('.ps1') }
    }

    if ([string]::IsNullOrWhiteSpace($commandsHelp)) {
        $commandsHelp = (Get-Command $moduleName -ErrorAction SilentlyContinue) | Get-Help -Full -ErrorAction SilentlyContinue
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
    $help | Add-Member total $totalCommands
    $help.ModuleName =
    return $help
}