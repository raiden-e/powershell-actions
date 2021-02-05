[CmdletBinding()]
param ()
# git config --global user.name %GITLAB_USER_NAME%
# git config --global user.email %GITLAB_USER_EMAIL%
Get-ChildItem env:
Get-ChildItem -Force -Path $env:temp | Where-Object { $_.Name -like '*%docs%*' } | Remove-Item -Recurse -Force
# git clone %gitwiki% %temp%\%docs%
# Get-ChildItem -Recurse -Force -Path "$env:temp/$env:docs" | Where-Object { $_.fullname -notlike '*[\/].git*' } | Remove-Item -Recurse -Force