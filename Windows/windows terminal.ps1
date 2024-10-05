# From Microsoft.VCLibs redirect
$MsftVc_Link = 'https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx'
$MsftVc_Name = 'Microsoft.VCLibs.x64.14.00.Desktop.appx'
Invoke-WebRequest -Uri $MsftVc_Link -OutFile .\$MsftVc_Name -Verbose
Add-AppPackage -Path .\$MsftVc_Name -Verbose

# From github Microsoft.UI.Xaml https://github.com/microsoft/microsoft-ui-xaml/releases
$MsftUi_Link = 'https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.x64.appx'
$MsftUi_Name = 'Microsoft.UI.Xaml.2.8.x64.appx'
Invoke-WebRequest -Uri $MsftUi_Link -OutFile .\$MsftUi_Name -Verbose
Add-AppPackage -Path .\$MsftUi_Name -Verbose

# MSFT Terminal from https://api.github.com/repos/microsoft/terminal/releases/latest
$term_Repo = "https://api.github.com/repos/microsoft/terminal/releases/latest"
$term_Link = (Invoke-WebRequest -Uri $term_Repo).Content | 
    ConvertFrom-Json |
    Select-Object -ExpandProperty "assets" |
    Where-Object "browser_download_url" -NotMatch '.zip' |
    Select-Object -ExpandProperty "browser_download_url"
$term_Name = 'WindowsTerminal.msixbundle'
Invoke-WebRequest -Uri $term_Link -OutFile .\$term_Name -Verbose
Unblock-File .\$term_Name
Add-AppPackage -Path .\$term_Name -Verbose
