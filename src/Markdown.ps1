function Format-String {
    [CmdletBinding()]
    param (
        [string]$str
    )

    if ([string]::IsNullOrWhiteSpace($str)) { return '' }

    $lines = $str -split [Environment]::NewLine
    foreach ($line in $lines) {
        $line = $line.trim()
    }

    # Trim EOL.

    return ($lines | Out-String).Trim()
}
function Out-Markdown {
    [CmdletBinding()]
    param (
        [string]$in = '',
        [bool]$includeBreaks = $false
    )
    if ([string]::IsNullOrWhiteSpace($in)) { return }

    $rtn = Format-String $in

    $replacements = (
        # '`',
        '\',
        '*',
        '_',
        '{',
        '}',
        '[',
        ']',
        '(',
        ')',
        '#',
        '+',
        '!',
        '<',
        '>'
    )

    if ([string]::IsNullOrWhiteSpace($rtn)) {
        return ''
    }
    else {
        foreach ($char in $replacements) {
            $rtn = $rtn.replace($char, '\' + $char)
        }
    }

    if ($includeBreaks) {
        return ($rtn + "`n`n").Trim()
    }
    else {
        return $rtn.Replace("`n", "").Trim()
    }
}
function ConvertTo-MarkdownDoc {
    [CmdletBinding()]
    param (
        [string]$moduleName,
        $commandsHelp
    )


    $returnText = "# $moduleName Module`n`n"
    $commandsHelp | ForEach-Object {

        # Name
        try {
            if (![string]::IsNullOrWhiteSpace($_.ModuleName)) {
                $returnText += "## $(Out-Markdown($_.ModuleName))`n`n"
            }
            elseif (![string]::IsNullOrWhiteSpace($commandsHelp.ModuleName)) {
                $returnText += "## $(Out-Markdown($commandsHelp.ModuleName))`n`n"
            }
            else {
                $returnText += "## $(Out-Markdown($_.Name))`n`n"
            }
        }
        catch {
            $returnText += "## $(Out-Markdown($_.Name))`n`n"
        }

        # Synopsis
        $synopsis = $_.synopsis.Trim()
        $syntax = $_.syntax | Out-String
        if ($synopsis -inotlike "$($_.Name.Trim())*") {
            $tmp = $synopsis
            $synopsis = $syntax
            $syntax = $tmp
            $returnText += "### Synopsis`n`n$(Out-Markdown($syntax))`n`n"
        }

        # Syntax
        $returnText += "### Syntax"
        $returnText += "`n`n"
        $returnText += '```powershell'
        $returnText += "`n"
        $returnText += "$($synopsis.Trim())"
        $returnText += "`n```````n`n"


        # # Aliases
        if (!($_.alias.Length -eq 0)) {
            $returnText += "`n### $($_.Name) Aliases`n"

            $_.alias | ForEach-Object {
                $returnText += "`n- $($_.Name)`n`n"
            }
        }

        # Parameters
        if ($_.parameters) {
            $returnText += "`n`n### Parameters`n`n"

            $_.parameters.parameter | ForEach-Object {
                $returnText += "`n``-$(Out-Markdown($_.Name))```n`n"

                $returnText += "$(Out-Markdown(($_.Description | Out-String).Trim()))`n"
                $returnText += "`nName | Value`n"
                $returnText += "--- | ---`n"
                $returnText += "Type | $(Out-Markdown($_.type.name))`n"
                $returnText += "Position | $(Out-Markdown($_.position))`n"
                $returnText += "Default value | $(Out-Markdown($_.DefaultValue))`n"
                $returnText += "Accept pipeline input | $(Out-Markdown($_.PipelineInput))`n"
                $returnText += "Aliases | $(Out-Markdown($_.Aliases))`n"
                $returnText += "Required | $(Out-Markdown($_.Required))`n"
            }
        }

        # Inputs
        $inputTypes = $(Out-Markdown($_.inputTypes | Out-String))
        if ($inputTypes.Length -gt 0 -and -not $inputTypes.Contains('inputType')) {
            $returnText += "`n### Inputs`n`n- $inputTypes`n"
        }

        # Outputs
        $returnValues = $(Out-Markdown($_.returnValues | Out-String))
        if ($returnValues.Length -gt 0 -and -not $returnValues.StartsWith("returnValue")) {
            $returnText += "`n### Outputs`n`n- $returnValues`n"
        }

        # Note
        $notes = $(($_.alertSet | Out-String))
        $notes = Format-String $notes
        if ($notes -and $notes.Trim().Length -gt 0) {
            $returnText += "`n### Notes`n"
            $returnText += "`n$notes"
            $returnText += "`n"
        }

        # Examples
        if (($_.examples.example.Length -gt 0)) {
            $returnText += "`n### Examples`n`n"
            foreach ($ex in $_.examples.example) {
                $returnText += "`n#### $(Out-Markdown($ex.title.Trim('-', ' ')))`n`n"
                $returnText += '```powershell'
                $returnText += "`n$($ex.code | Out-String)"
                $returnText += "```````n"
            }
        }

        # Related Links
        if (($_.relatedLinks | Out-String).Trim().Length -gt 0) {
            $returnText += "`n### Links`n"
            $_.links | ForEach-Object {
                $returnText += "`n- [$($_.name)]($($_.link))"
            }
        }
    }
    $returnText = $returnText | Out-String
    $returnText = $returnText -replace '(\n|\r|\s){3,}', "`n`n"
    return $returnText
}