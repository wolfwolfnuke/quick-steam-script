# Run this script in PowerShell
 
# Allow locally created scripts and scripts downloaded from the internet
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
 
# Install Scoop
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
irm get.scoop.sh | iex
 
# Make sure Scoop is available in this session
$env:Path += ";$env:USERPROFILE\scoop\shims"
 
# Install Git using Scoop
scoop install git
 
# Install Steam using Scoop
scoop bucket add extras
scoop install steam
