# Maps the NAS share as a persistent Z: drive for the local administrator.
# Runs during the Packer build (templates/windows-base.pkr.hcl), elevated as that
# user, with SMB_SERVER / SMB_SHARE / SMB_USERNAME / SMB_PASSWORD taken from the
# Packer variables. Nothing to do when smb_server is empty.
#
# Two Windows built-ins and nothing else: cmdkey stores the NAS login in the
# user's Credential Manager, `net use /persistent:yes` records the mapping in the
# profile (HKCU\Network\Z). Windows reconnects Z: at every logon by itself, so
# clones get the share without any script of their own.

$ErrorActionPreference = 'Stop'

if (-not $env:SMB_SERVER) {
    Write-Host 'smb_server not set; no NAS share mapped'
    exit 0
}
foreach ($name in 'SMB_SHARE', 'SMB_USERNAME', 'SMB_PASSWORD') {
    if (-not (Get-Item "env:$name" -ErrorAction SilentlyContinue).Value) {
        throw "smb_server is set but $($name.ToLower()) is empty (smb_share / smb_username: environment var file; smb_password: credentials.pkrvars.hcl)"
    }
}

$unc = "\\$env:SMB_SERVER\$env:SMB_SHARE"
Write-Host "Mapping $unc as Z: for $env:USERNAME (NAS user $env:SMB_USERNAME)"

$out = cmdkey "/add:$env:SMB_SERVER" "/user:$env:SMB_USERNAME" "/pass:$env:SMB_PASSWORD"
if ($LASTEXITCODE -ne 0) { throw "cmdkey failed: $out" }

net use Z: $unc /persistent:yes
if ($LASTEXITCODE -ne 0) { throw "net use failed with exit code $LASTEXITCODE (is $unc reachable from the build VM and the NAS login correct?)" }

# Make drives mapped at logon visible to the elevated (UAC) half of an administrator's session too.
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name EnableLinkedConnections -Value 1 -Type DWord

Write-Host "Z: -> $unc mapped persistently"
