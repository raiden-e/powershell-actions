[CmdletBinding()]
param (
    [string]$path = $PWD
)
if (Test-Path (Join-Path -Path $path -Childpath 'requirements.txt')) {
    Get-Content 'requirements.txt' | ForEach-Object {
        $module = $_ -split "="
        try {
            for ($i = 0; $i -le $module.count; $i++) {
                $module[$i] = ($module[$i] | Out-String).Trim()
            }
        }
        catch {
            Write-Host "Only one Module"
        }
        if ($module.count -gt 1) {
            Install-Module -Name $module[0] -MinimumVersion $module[1] -Force -SkipPublisherCheck
        }
        else {
            Install-Module -Name $module[0] -Force -SkipPublisherCheck
        }
    }
}
else {
    Write-Host "requirements.txt not found"
}
