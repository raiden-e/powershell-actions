function Install-Dependencies {
    [CmdletBinding()]
    param (
        [string]$path = $PWD
    )
    if (Test-Path (Join-Path -Path $path -Childpath 'requirements.txt')) {
        Get-Content 'requirements.txt' | ForEach-Object {
            $module = $_ -split "="
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
}