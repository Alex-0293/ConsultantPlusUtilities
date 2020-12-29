# Rename this file to Settings.ps1
######################### value replacement #####################
[string] $Global:ConsPath           = ""         
[string] $Global:ConsUserDataFolder = ""         
[string] $Global:RemoteComputer     = ""         

######################### no replacement ########################
[string] $Global:gsStateFilePath    = "$($Global:ProjectRoot)\$($Global:gsLOGSFolder)\States.xml"
[string] $Global:ConsErrorFile    = "CONS_ERR.TXT"
[string] $Global:ConsInetFileList = "CONS_INET_LISTFILES.TXT"
[string] $Global:ConsInetFile     = "CONS_INET.TXT"
[int16]  $Global:ReadLastLines    = 300

[string] $Global:UpdateArguments   = "/adm /receive_inet /base* /yes /process=1"
[string] $Global:ShrinkArguments   = "/COMPRESS /BASE* /YES /ADM"
[string] $Global:BaseTestArguments = "/ADM /BASETEST /BASE* /YES"
[string] $Global:TestArguments     = "/TEST /YES"

. $Global:gsPlugins.telegram

[bool]  $Global:LocalSettingsSuccessfullyLoaded  = $true
# Error trap
    trap {
        $Global:LocalSettingsSuccessfullyLoaded = $False
        exit 1
    }

