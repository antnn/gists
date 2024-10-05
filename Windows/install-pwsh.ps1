# Function to get the latest PowerShell release info from GitHub API
function Get-LatestPowerShellRelease {
    $uri = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
    $response = Invoke-RestMethod -Uri $uri -Method Get
    return $response
}

$latestRelease = Get-LatestPowerShellRelease
$msiAsset = $latestRelease.assets | Where-Object { $_.name -like "*win-x64.msi" }

if (-not $msiAsset) {
    Write-Error "Could not find Windows x64 MSI in the latest release."
    exit 1
}

$downloadPath = Join-Path $env:TEMP $msiAsset.name
Invoke-WebRequest -Uri $msiAsset.browser_download_url -OutFile $downloadPath

$installArgs = @(
    "/i",
    $downloadPath,
    "/passive",
    "/qb",
    "ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1",
    "ENABLE_PSREMOTING=1",
    "REGISTER_MANIFEST=1",
    "USE_MU=1",
    "ENABLE_MU=1"
)

Start-Process msiexec.exe -ArgumentList $installArgs -Wait

Remove-Item $downloadPath -Force
Write-Host "PowerShell $($latestRelease.tag_name) has been installed successfully."
