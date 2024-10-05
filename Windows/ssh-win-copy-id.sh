#!/bin/bash
# Copies ssh key to Windows
authorizedKey=$(cat ~/.ssh/id_rsa.pub)
remotePowershell="powershell Add-Content -Force -Path C:\\ProgramData\\ssh\\administrators_authorized_keys -Value '$authorizedKey';icacls.exe \"C:\\ProgramData\\ssh\\administrators_authorized_keys\" /inheritance:r /grant \"*S-1-5-32-544:F\" /grant \"SYSTEM:F\""
ssh Administrator@192.168.122.2 "$remotePowershell"
