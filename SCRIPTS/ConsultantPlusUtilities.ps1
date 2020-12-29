<#
    .SYNOPSIS 
        AUTHOR AlexK
        DATE   08.05.2020
        VER    1
        LANG   En   
    .DESCRIPTION
        Script for managing consultant plus software, like update, DB shrink, get statistics and etc.
   
    .EXAMPLE
        ConsultantPlusUtilities.ps1
#>
Param (
    [Parameter( Mandatory = $false, Position = 1, HelpMessage = "Initialize global settings." )]
    [bool] $InitGlobal = $true,
    [Parameter( Mandatory = $false, Position = 2, HelpMessage = "Initialize local settings." )]
    [bool] $InitLocal  = $true, 
    [Parameter( Mandatory = $false, Position = 3, HelpMessage = "Select service utility." )]
    [ValidateSet("Update", "Shrink", "BaseTest", "Test")]
    [string] $Service,
    [Parameter( Mandatory = $false, Position = 4, HelpMessage = "Log cut date and time." )]
    [datetime] $LogCutDate
)

$Global:ScriptInvocation = $MyInvocation
if ($env:AlexKFrameworkInitScript){. "$env:AlexKFrameworkInitScript" -MyScriptRoot (Split-Path $PSCommandPath -Parent) -InitGlobal $InitGlobal -InitLocal $InitLocal} Else {Write-host "Environmental variable [AlexKFrameworkInitScript] does not exist!" -ForegroundColor Red; exit 1}
if ($LastExitCode) { exit 1 }

# Error trap
trap {
    if (get-module -FullyQualifiedName AlexkUtils) {
        Get-ErrorReporting $_        
        . "$($Global:gsGlobalSettingsPath)\$($Global:gsSCRIPTSFolder)\Finish.ps1" 
    }
    Else {
        Write-Host "[$($MyInvocation.MyCommand.path)] There is error before logging initialized. Error: $_" -ForegroundColor Red
    }  
    $Global:gsGlobalSettingsSuccessfullyLoaded = $false
    exit 1
}
################################# Script start here #################################
$Login       = Get-VarToString(Get-VarFromAESFile $Global:gsGlobalKey1 $Global:gsAPP_SCRIPT_ADMIN_LoginFilePath)
$Pass        = Get-VarFromAESFile $Global:gsGlobalKey1 $Global:gsAPP_SCRIPT_ADMIN_PassFilePath
$Credentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Login, $Pass

$WorkDir = Split-Path -path $ConsPath -Parent

& ipconfig /flushdns

# if ( !$Service -and !$LogCutDate ) {
#     $Service = "UPDATE"
# }

#$SessionOptions = New-PSSessionOption -OperationTimeout 60*60*1000 
switch ($Service.ToUpper()) {
    "UPDATE"    { 
        $ScriptBlock = {
            $Res = [PSCustomObject]@{
                Data         = $Null
                LogBuffer    = @()
                DiskSpace    = 0
                NewDiskSpace = 0
            }

            #Write-host "ParentLevel = $ParentLevel"
            $ConsPath          = $Using:ConsPath
            $UpdateArguments   = $Using:UpdateArguments
            $WorkDir           = $Using:WorkDir
            $Global:gsScriptLogFilePath = $Using:gsScriptLogFilePath
            $Res.DiskSpace     = [math]::Round((Get-ChildItem -path $ConsPath -File -Recurse | measure-object -Property length -Sum).Sum / 1gb, 2)
            
            Unblock-File -Path $ConsPath
            $Process = Start-Program  -Program $ConsPath -LogFilePath $Global:gsScriptLogFilePath -Arguments $UpdateArguments -WorkDir $WorkDir -Wait -Evaluate

            $Res.Data         = $Process
            $Res.LogBuffer    = $Global:gsLogBuffer
            $Res.NewDiskSpace = [math]::Round((Get-ChildItem -path $ConsPath -File -Recurse | measure-object -Property length -Sum).Sum / 1gb, 2)

            return  $Res
        }
        Add-ToLog -Message "Starting update." -logFilePath $Global:gsScriptLogFilePath -Display -Status "Info" -Level ($Global:gsParentLevel + 1)
        try {
            $Res = Invoke-PSScriptBlock -ScriptBlock $Scriptblock -Computer $RemoteComputer -ImportLocalModule "AlexkUtils" -Credentials $Credentials -TestComputer
            if ($res.LogBuffer) {
                foreach ($item in $Res.LogBuffer) {
                    Add-ToLog @item
                }            
            }
            if (($Res.NewDiskSpace) -and ($Res.DiskSpace)) {
                Add-ToLog -Message "Folder [$ConsPath] size changed on [$RemoteComputer] from [$($Res.DiskSpace) GB] to [$($Res.NewDiskSpace) GB], difference [$([math]::round(($Res.NewDiskSpace - $Res.DiskSpace),2)) GB]" -logFilePath $Global:gsScriptLogFilePath -Display -Status "Info" -Level ($Global:gsParentLevel + 1)
            }
            
            $Res = . "$PSCommandPath" -LogCutDate $Global:ScriptStartTime -InitLocal $false -InitGlobal $false

            if ($Res) {
                $Global:gsStateObject.Data        = $Res
                $Global:gsStateObject.Action      = "Update"
                $Global:gsStateObject.State       = "Errors while update on [$($Global:RemoteComputer)]"
                $Global:gsStateObject.GlobalState = $false
                Set-State -StateObject $Global:gsStateObject -StateFilePath $Global:gsStateFilePath -AlertType "telegram"
            }
            Else {
                $Global:gsStateObject.Action      = "Update"
                $Global:gsStateObject.State       = "Completed udate on [$($Global:RemoteComputer)]"
                $Global:gsStateObject.GlobalState = $True
                Set-State -StateObject $Global:gsStateObject -StateFilePath $Global:gsStateFilePath -AlertType "telegram"
            }
        }
        Catch {
            $Global:gsStateObject.Action      = "Update"
            $Global:gsStateObject.State       = "Errors while update on [$($Global:RemoteComputer)]. $_"
            $Global:gsStateObject.GlobalState = $false
            Set-State -StateObject $Global:gsStateObject -StateFilePath $Global:gsStateFilePath -AlertType "telegram"
        }
    }
    "BASETEST" { 
        $ScriptBlock = {
            $Res = [PSCustomObject]@{
                Data         = $Null
                LogBuffer    = @()
                DiskSpace    = 0
                NewDiskSpace = 0
            }

            #Write-host "ParentLevel = $ParentLevel"
            $ConsPath          = $Using:ConsPath
            $UpdateArguments   = $Global:BaseTestArguments
            $WorkDir           = $Using:WorkDir
            $Global:gsScriptLogFilePath = $Using:gsScriptLogFilePath
            $Res.DiskSpace = [math]::Round((Get-ChildItem -Path $ConsPath -File -Recurse | Measure-Object -Property length -Sum).Sum / 1gb, 2)
            
            $Process = Start-Program  -Program $ConsPath -LogFilePath $Global:gsScriptLogFilePath -Arguments $UpdateArguments -WorkDir $WorkDir -Wait -Evaluate

            $Res.Data             = $Process
            $Res.LogBuffer        = $Global:gsLogBuffer
            $Res.NewDiskSpace = [math]::Round((Get-ChildItem -Path $ConsPath -File -Recurse | Measure-Object -Property length -Sum).Sum / 1gb, 2)

            return  $Res
        }
        Add-ToLog -Message "Starting base test." -logFilePath $Global:gsScriptLogFilePath -Display -Status "Info" -Level ($Global:gsParentLevel + 1)
        try {
            $Res = Invoke-PSScriptBlock -ScriptBlock $Scriptblock -Computer $RemoteComputer -ImportLocalModule "AlexkUtils" -Credentials $Credentials -TestComputer -SessionTimeOut $Global:gsSessionTimeout
            if ($res.LogBuffer) {
                foreach ($item in $Res.LogBuffer) {
                    Add-ToLog @item
                }            
            }
            if (($Res.NewDiskSpace) -and ($Res.DiskSpace)) {
                Add-ToLog -Message "Folder [$ConsPath] size changed on [$RemoteComputer] from [$($Res.DiskSpace) GB] to [$($Res.NewDiskSpace) GB], difference [$([math]::round(($Res.NewDiskSpace - $Res.DiskSpace),2)) GB]" -logFilePath $Global:gsScriptLogFilePath -Display -Status "Info" -Level ($Global:gsParentLevel + 1)
            }           

            $res = . "$PSCommandPath" -LogCutDate $Global:ScriptStartTime -InitLocal $false -InitGlobal $false
            if ($res) {
                $Global:gsStateObject.Data        = $Res
                $Global:gsStateObject.Action      = "Update"
                $Global:gsStateObject.State       = "Errors while base test on [$($Global:RemoteComputer)]"
                $Global:gsStateObject.GlobalState = $false
                Set-State -StateObject $Global:gsStateObject -StateFilePath $Global:gsStateFilePath -AlertType "telegram"
            }
            Else {
                $Global:gsStateObject.Action      = "Base test"
                $Global:gsStateObject.State       = "Completed base test on [$($Global:RemoteComputer)]"
                $Global:gsStateObject.GlobalState = $True
                Set-State -StateObject $Global:gsStateObject -StateFilePath $Global:gsStateFilePath -AlertType "telegram"
            }

        }
        Catch {
            $Global:gsStateObject.Action      = "Base test"
            $Global:gsStateObject.State       = "Errors while base test on [$($Global:RemoteComputer)]"
            $Global:gsStateObject.GlobalState = $false
            Set-State -StateObject $Global:gsStateObject -StateFilePath $Global:gsStateFilePath -AlertType "telegram"
        }
    }
    "TEST" { 
        $ScriptBlock = {
            $Res = [PSCustomObject]@{
                Data         = $Null
                LogBuffer    = @()
                DiskSpace    = 0
                NewDiskSpace = 0
            }

            #Write-host "ParentLevel = $ParentLevel"
            $ConsPath          = $Using:ConsPath
            $UpdateArguments   = $Global:TestArguments
            $WorkDir           = $Using:WorkDir
            $Global:gsScriptLogFilePath = $Using:gsScriptLogFilePath
            $Res.DiskSpace     = [math]::Round((Get-ChildItem -Path $ConsPath -File -Recurse | Measure-Object -Property length -Sum).Sum / 1gb, 2)
            
            $Process = Start-Program  -Program $ConsPath -LogFilePath $Global:gsScriptLogFilePath -Arguments $UpdateArguments -WorkDir $WorkDir -Wait -Evaluate

            $Res.Data         = $Process
            $Res.LogBuffer    = $Global:gsLogBuffer
            $Res.NewDiskSpace = [math]::Round((Get-ChildItem -Path $ConsPath -File -Recurse | Measure-Object -Property length -Sum).Sum / 1gb, 2)

            return  $Res
        }
        Add-ToLog -Message "Starting resource test." -logFilePath $Global:gsScriptLogFilePath -Display -Status "Info" -Level ($Global:gsParentLevel + 1)
        try {
            $Res = Invoke-PSScriptBlock -ScriptBlock $Scriptblock -Computer $RemoteComputer -ImportLocalModule "AlexkUtils" -Credentials $Credentials -TestComputer -SessionTimeOut $Global:gsSessionTimeout
            if ($res.LogBuffer) {
                foreach ($item in $Res.LogBuffer) {
                    Add-ToLog @item
                }            
            }
            if (($Res.NewDiskSpace) -and ($Res.DiskSpace)) {
                Add-ToLog -Message "Folder [$ConsPath] size changed on [$RemoteComputer] from [$($Res.DiskSpace) GB] to [$($Res.NewDiskSpace) GB], difference [$([math]::round(($Res.NewDiskSpace - $Res.DiskSpace),2)) GB]" -logFilePath $Global:gsScriptLogFilePath -Display -Status "Info" -Level ($Global:gsParentLevel + 1)
            }
            
            $res = . "$PSCommandPath" -LogCutDate $Global:ScriptStartTime -InitLocal $false -InitGlobal $false

            if ($res) {
                $Global:gsStateObject.Data        = $Res
                $Global:gsStateObject.Action      = "Resource test"
                $Global:gsStateObject.State       = "Completed resource test on [$($Global:RemoteComputer)]"
                $Global:gsStateObject.GlobalState = $True
                Set-State -StateObject $Global:gsStateObject -StateFilePath $Global:gsStateFilePath -AlertType "telegram"
            }
            Else {
                $Global:gsStateObject.Action      = "Resource test"
                $Global:gsStateObject.State       = "Errors while resource test on [$($Global:RemoteComputer)]"
                $Global:gsStateObject.GlobalState = $false
                Set-State -StateObject $Global:gsStateObject -StateFilePath $Global:gsStateFilePath -AlertType "telegram"
            } 
        }
        Catch {
            $Global:gsStateObject.Action = "Resource test"
            $Global:gsStateObject.State = "Errors while resource test on [$($Global:RemoteComputer)]"
            $Global:gsStateObject.GlobalState = $false
            Set-State -StateObject $Global:gsStateObject -StateFilePath $Global:gsStateFilePath -AlertType "telegram"
        }
    }
    "SHRINK" { 
        $ScriptBlock = {
            $Res = [PSCustomObject]@{
                Data         = $Null
                LogBuffer    = @()
                DiskSpace    = 0
                NewDiskSpace = 0
            }

            $ConsPath            = $Using:ConsPath
            $ShrinkArguments     = $Using:ShrinkArguments
            $WorkDir             = $Using:WorkDir
            $Global:gsScriptLogFilePath   = $Using:gsScriptLogFilePath
            $Res.DiskSpace   = [math]::Round((Get-ChildItem -path $ConsPath -File -Recurse | measure-object -Property length -Sum).Sum / 1gb, 2)

            $Process = Start-Program  -Program $ConsPath -LogFilePath $Global:gsScriptLogFilePath -Arguments $ShrinkArguments -WorkDir $WorkDir -Wait -Evaluate

            $Res.Data         = $Process
            $Res.LogBuffer    = $Global:gsLogBuffer
            $Res.NewDiskSpace = [math]::Round((Get-ChildItem -path $ConsPath -File -Recurse | measure-object -Property length -Sum).Sum / 1gb, 2)

            return  $Res
        }
        Add-ToLog -Message "Starting database shrink." -logFilePath $Global:gsScriptLogFilePath -Display -Status "Info" -Level ($Global:gsParentLevel + 1)
        try {
            $Res = Invoke-PSScriptBlock -ScriptBlock $Scriptblock -Computer $RemoteComputer -ImportLocalModule "AlexkUtils" -Credentials $Credentials -TestComputer -SessionTimeOut $Global:gsSessionTimeout
            if ($Res.LogBuffer) {
                foreach ($item in $Res.LogBuffer) {
                    Add-ToLog @item
                }            
            }
            if (($Res.NewDiskSpace) -and ($Res.DiskSpace)) {
                Add-ToLog -Message "Folder [$ConsPath] size changed on [$RemoteComputer] from [$($Res.DiskSpace) GB] to [$($Res.NewDiskSpace) GB], difference [$([math]::round(($Res.NewDiskSpace - $Res.DiskSpace),2)) GB]" -logFilePath $Global:gsScriptLogFilePath -Display -Status "Info" -Level ($Global:gsParentLevel + 1)
            }

            $res = . "$PSCommandPath" -LogCutDate $Global:ScriptStartTime -InitLocal $false -InitGlobal $false
            if ($res) {
                $Global:gsStateObject.Data        = $Res
                $Global:gsStateObject.Action      = "Shrink"
                $Global:gsStateObject.State       = "Errors while shrink on [$($Global:RemoteComputer)]"
                $Global:gsStateObject.GlobalState = $false
                Set-State -StateObject $Global:gsStateObject -StateFilePath $Global:gsStateFilePath -AlertType "telegram"
            }
            Else {
                $Global:gsStateObject.Action      = "Shrink"
                $Global:gsStateObject.State       = "Completed shrink on [$($Global:RemoteComputer)]"
                $Global:gsStateObject.GlobalState = $True
                Set-State -StateObject $Global:gsStateObject -StateFilePath $Global:gsStateFilePath -AlertType "telegram"
            } 
        }
        Catch {
            $Global:gsStateObject.Action      = "Shrink"
            $Global:gsStateObject.State       = "Errors while shrink on [$($Global:RemoteComputer)]"
            $Global:gsStateObject.GlobalState = $false
            Set-State -StateObject $Global:gsStateObject -StateFilePath $Global:gsStateFilePath -AlertType "telegram"
        }
    }
    Default {
        $Scriptblock = {
            $Res = [PSCustomObject]@{
                ConsErrorFile      = ""
                ConsInetFileList   = ""
                ConsInetFile       = ""
                LogBuffer          = @()
                AvgDlSpeed         = ""
            }

            $LogCutDate         = $using:LogCutDate
            $ConsUserDataFolder = $using:ConsUserDataFolder
            $ConsErrorFile      = $using:ConsErrorFile
            $ReadLastLines      = $using:ReadLastLines
            $ConsErrorFile      = $using:ConsErrorFile
            $ConsInetFileList   = $using:ConsInetFileList
            $ConsInetFile       = $using:ConsInetFile
            
            if ( $LogCutDate ) {
                $Date = $LogCutDate
            }
            Else {
                $Date = (Get-Date).Date  
            }
            

            if (Test-path "$ConsUserDataFolder\$ConsErrorFile") {
                $Content = Get-Content -Path "$ConsUserDataFolder\$ConsErrorFile" -Encoding Default -Tail $ReadLastLines  
                [array] $TodayErrorContent  = @()
                [array] $TodayErrorContent1 = @()
                foreach ($line in $Content) { 
                    if ($line.Length -gt 18) {
                        try {
                            [datetime] $ProbablyDate = Get-Date $line.Substring(0, 18) 
                        }
                        Catch {
                        }
                    }
                    if ($ProbablyDate) {
                        if (($ProbablyDate -ge $Date) -and ($line)) {
                            $TodayErrorContent += $line
                        }
                    }
                }
                $NewLine = ""
                foreach ($line in $TodayErrorContent){
                    try {
                            [datetime] $ProbablyDate = Get-Date $line.Substring(0, 18) 
                        }
                    Catch {
                            [string] $ProbablyDate = ""
                        }
                    if ($ProbablyDate) {
                        if( $NewLine ) {
                            $TodayErrorContent1 += $NewLine
                            $NewLine = ""
                        }
                        $NewLine += "$line" 
                    }
                    else {
                        $NewLine += " $line"
                    }
                }
                if ( $NewLine ) {
                    $TodayErrorContent1 += $NewLine
                }

                $Res.ConsErrorFile = $TodayErrorContent1
            }
            else {
                Add-ToLog -Message "Error file ["$ConsUserDataFolder\$ConsErrorFile"] not found!" -logFilePath $Global:gsScriptLogFilePath -Display -Status "Error" -Level ($Global:gsParentLevel + 1)
            }
           
            if (Test-Path "$ConsUserDataFolder\$ConsInetFileList") {
                $Content = Get-Content -Path "$ConsUserDataFolder\$ConsInetFileList" -Encoding Default -Tail $ReadLastLines
                [string] $LastLine = $Content | Select-Object -Last 1
                
                if ($lastLine.Contains("Средняя скорость скачивания файлов с сервера ИП")) {
                    $Res.AvgDlSpeed = ($LastLine.Split("-"))[1].Trim()  
                    $Content = $Content | Select-Object -First (@($Content).count-1)
                }
                
                [array] $TodayInetFileListContent = @()
                foreach ($line in $Content) {
                    if ($line -notlike "*------*"){
                        if ($line.Length -gt 18) {
                            try {
                                [datetime] $ProbablyDate = Get-Date  $line.Substring(0, 18) 
                            }
                            Catch {
                            }
                        }
                        if ($ProbablyDate) {
                            if ($ProbablyDate -ge $Date) {
                                $TodayInetFileListContent += $line
                            }
                        }   
                    }                 
                }
                #Convert-InetFileListContentToCSV 
                $res.ConsInetFileList = $TodayInetFileListContent
            }
            Else {
                Add-ToLog -Message "Error file ["$ConsUserDataFolder\$ConsInetFileList"] not found!" -logFilePath $Global:gsScriptLogFilePath -Display -Status "Error" -Level ($Global:gsParentLevel + 1)
            }
            
            if (Test-Path "$ConsUserDataFolder\$ConsInetFile") {
                $Content = Get-Content -Path "$ConsUserDataFolder\$ConsInetFile" -Encoding Default -Tail $ReadLastLines
                [array] $TodayInetFileContent = @()
                foreach ($line in $Content) {
                    if ($line -notlike "*------*") {
                        if ($line.Length -gt 18) {
                            try {
                                [datetime] $ProbablyDate = Get-Date  $line.Substring(0, 18) 
                            }
                            Catch {
                            }
                        }
                        if ($ProbablyDate) {
                            if ($ProbablyDate -ge $Date) {
                                $TodayInetFileContent += $line
                            }
                        }
                    }                    
                }
                $res.ConsInetFile = $TodayInetFileContent
            }
            Else {
                        Add-ToLog -Message "Error file ["$ConsUserDataFolder\$ConsInetFile"] not found!" -logFilePath $Global:gsScriptLogFilePath -Display -Status "Error" -Level ($Global:gsParentLevel + 1)
            } 
            $Res.LogBuffer = $Global:gsLogBuffer
            Return $Res
        }        
        
        Add-ToLog -Message "Starting statistic on computer [$RemoteComputer]." -logFilePath $Global:gsScriptLogFilePath -Display -Status "Info" -Level ($Global:gsParentLevel + 1) 
        try {
            $Res = Invoke-PSScriptBlock -ScriptBlock $Scriptblock -Computer $RemoteComputer -ImportLocalModule "AlexkUtils"  -Credentials $Credentials -TestComputer
            if ($res) {                
                $Data = $res.ConsInetFileList
                if ($Data) {
                    foreach ($item in $Data) {
                        Add-ToLog -Message $item -logFilePath $Global:gsScriptLogFilePath -Display -Status "Info" -Level ($Global:gsParentLevel + 1)
                    }                
                }
                $Data = $res.ConsInetFile
                if ($Data) {
                    foreach ($item in $Data) {
                        Add-ToLog -Message $item -logFilePath $Global:gsScriptLogFilePath -Display -Status "Info" -Level ($Global:gsParentLevel + 1)
                    }                
                }  
                $Data = $res.ConsErrorFile
                if ($Data) {
                    foreach ($item in $Data) {
                        Add-ToLog -Message $item -logFilePath $Global:gsScriptLogFilePath -Display -Status "Error" -Level ($Global:gsParentLevel + 1)
                    }                
                }
                $Data = $res.AvgDlSpeed
                if ($Data) {     
                    Add-ToLog -Message "Average download speed [$Data]." -logFilePath $Global:gsScriptLogFilePath -Display -Status "Info" -Level ($Global:gsParentLevel + 1)
                }      

                if ($res.LogBuffer) {
                    foreach ($item in $Res.LogBuffer) {
                        Add-ToLog @item
                    }            
                }
            }
            $Global:gsStateObject.Action      = "Statistic"
            $Global:gsStateObject.State       = "Completed statistic on [$($Global:RemoteComputer)]"
            $Global:gsStateObject.GlobalState = $True
            Set-State -StateObject $Global:gsStateObject -StateFilePath $Global:gsStateFilePath -AlertType "telegram"
        }
        Catch {
            $Global:gsStateObject.Action      = "Statistic"
            $Global:gsStateObject.State       = "Errors while statistic on [$($Global:RemoteComputer)]"
            $Global:gsStateObject.GlobalState = $false
            Set-State -StateObject $Global:gsStateObject -StateFilePath $Global:gsStateFilePath -AlertType "telegram"
        }
        if ( $res.ConsErrorFile ) {
            $Global:Return = $res.ConsErrorFile
        }        
    }    
}

################################# Script end here ###################################
. "$($Global:gsGlobalSettingsPath)\$($Global:gsSCRIPTSFolder)\Finish.ps1" -return $Global:Return
