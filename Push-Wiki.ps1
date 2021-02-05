[CmdletBinding()]
param ()

Set-Location (Join-Path -Path $env:temp -ChildPath $env:docs)
git add -A
git commit -m "Auto-updated Wiki"
git push origin "HEAD:master"