function Import-Help {
    [CmdletBinding()]
    param (
        # Specifies a path to one location. Wildcards are permitted.
        [Parameter(Mandatory = $true,
            Position = 1,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "Full path to module")]
        $path,
        # Name of the Module
        [Parameter(Mandatory = $false,
            Position = 2,
            ValueFromPipeline = $false,
            ValueFromPipelineByPropertyName = $false,
            HelpMessage = "Name of the Module.")]
        [string]$moduleName
    )


    if (!(Test-Path $path)) {
        throw "$path does not exist"
    }
    Write-Host $path
    try {
        $commandsHelp = Get-Help -Name $path -Full
        $commandsHelp
    }
    catch {
        throw "Could not find $path", $_
    }

    foreach ($help in $commandsHelp) {
        try{
            $cmdHelp = Get-Command $help.Name}
            catch{
                Get-Command $help | Get-Member
                throw
            }

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
        Write-Information "nothin"
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