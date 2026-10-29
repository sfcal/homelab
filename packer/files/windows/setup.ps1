# Windows template bootstrap. Runs once, at the first (automatic) logon of the
# Packer build VM, from the FirstLogonCommands in autounattend.xml.pkrtpl.
# Order matters: Packer can only discover the VM's IP once the QEMU guest agent
# is running, so WinRM has to be ready before the agent starts.
# Logs: C:\Windows\Temp\packer-setup.log and virtio-win-guest-tools.log (kept on the template).

$ErrorActionPreference = 'Stop'
Start-Transcript -Path "$env:SystemRoot\Temp\packer-setup.log" -Force

# --- WinRM for Packer (HTTP, basic auth; same role as ssh_password on the Linux templates) ---
# A fresh install lands on the Public network profile, where WinRM refuses to open
# its firewall rule. Switch to Private and skip the check as well, then open the
# rule to any remote address so the build works from another VLAN.
Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private -ErrorAction SilentlyContinue
Enable-PSRemoting -SkipNetworkProfileCheck -Force
Set-Item -Path WSMan:\localhost\Service\AllowUnencrypted -Value $true
Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $true
Get-NetFirewallRule -Name 'WINRM-HTTP-In-TCP*' | Set-NetFirewallRule -RemoteAddress Any -Enabled True
Set-Service -Name WinRM -StartupType Automatic

# --- VirtIO drivers, QEMU guest agent and SPICE agent from the virtio-win ISO (drive letter varies) ---
# virtio-win-guest-tools.exe is a WiX Burn bundle chaining the driver MSI, qemu-ga and the SPICE
# vdagent; the vdagent is what gives the Proxmox console (clipboard=vnc) a working clipboard.
$virtio = Get-PSDrive -PSProvider FileSystem |
    ForEach-Object { $_.Root } |
    Where-Object { Test-Path (Join-Path $_ 'virtio-win-guest-tools.exe') } |
    Select-Object -First 1
if (-not $virtio) { throw 'virtio-win ISO not found on any attached drive' }
$tools = Join-Path $virtio 'virtio-win-guest-tools.exe'
Write-Host "Installing $tools"
$p = Start-Process -FilePath $tools -ArgumentList '/install', '/quiet', '/norestart', '/log', "$env:SystemRoot\Temp\virtio-win-guest-tools.log" -Wait -PassThru
# 3010 = success, reboot pending (the template reboots when cloned anyway)
if ($p.ExitCode -notin 0, 3010) { throw "virtio-win-guest-tools exited with $($p.ExitCode), see $env:SystemRoot\Temp\virtio-win-guest-tools.log" }
Set-Service -Name QEMU-GA -StartupType Automatic
Start-Service -Name QEMU-GA

# --- The answer file's one-time autologon must not carry over to clones ---
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name AutoLogonCount -Value 0

Write-Host 'setup.ps1 finished; waiting for Packer over WinRM'
Stop-Transcript
