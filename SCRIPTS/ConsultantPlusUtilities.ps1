<#
    .SYNOPSIS 
        .AUTHOR AlexK
        .DATE   08.05.2020
        .VER    1
        .LANG   En   
    .DESCRIPTION
        Script for managing consultant plus software, like update, DB shrink, get statistics and etc.
    .PARAMETER
    .EXAMPLE
        ConsultantPlusUtilities.ps1
#>
Param (
    [Parameter( Mandatory = $false, Position = 0, HelpMessage = "Select service utility." )]
    [ValidateSet("Update", "Shrink")]
    [string] $Service,
    [Parameter( Mandatory = $false, Position = 1, HelpMessage = "Log cut date and time." )]
    [datetime] $LogCutDate
)
$Global:ScriptInvocation = $MyInvocation
$InitScript        = "C:\DATA\Projects\GlobalSettings\SCRIPTS\Init.ps1"
. "$InitScript" -MyScriptRoot (Split-Path $PSCommandPath -Parent)
if ($LastExitCode) { exit 1 }

# Error trap
trap {
    if (get-module -FullyQualifiedName AlexkUtils) {
        Get-ErrorReporting $_        
        . "$GlobalSettings\$SCRIPTSFolder\Finish.ps1" 
    }
    Else {
        Write-Host "[$($MyInvocation.MyCommand.path)] There is error before logging initialized. Error: $_" -ForegroundColor Red
    }  
    $Global:GlobalSettingsSuccessfullyLoaded = $false
    exit 1
}
################################# Script start here #################################
$WorkDir = Split-Path -path $ConsPath -Parent

#$Service = "UPDATE"
switch ($Service.ToUpper()) {
    "UPDATE"    { 
        $ScriptBlock = {
            $Res = [PSCustomObject]@{
                Data               = $Null
                LogBuffer          = @()
                FreeDiskSpace      = 0
                NewFreeDiskSpace   = 0
            }

            #Write-host "ParentLevel = $ParentLevel"
            $ConsPath            = $Using:ConsPath
            $UpdateArguments     = $Using:UpdateArguments
            $WorkDir             = $Using:WorkDir
            $ScriptLogFilePath   = $Using:ScriptLogFilePath
            $Res.FreeDiskSpace   = [math]::Round((Get-PSDrive ((Get-Item $WorkDir).PSDrive.Name)).Free / 1gb, 2)
            
            $Process = Start-Program  -Program $ConsPath -LogFilePath $ScriptLogFilePath -Arguments $UpdateArguments -WorkDir $WorkDir -Wait -Evaluate

            $Res.Data               = $Process
            $Res.LogBuffer          = $Global:LogBuffer
            $Res.NewFreeDiskSpace   = [math]::Round((Get-PSDrive ((Get-Item $WorkDir).PSDrive.Name)).Free / 1gb, 2)

            return  $Res
        }
        Add-ToLog -Message "Starting update." -logFilePath $ScriptLogFilePath -Display -Status "Info" -Level ($ParentLevel + 1)
        $Res = Invoke-PSScriptBlock -ScriptBlock $Scriptblock -Computer $RemoteComputer -ImportLocalModule "AlexkUtils"
        if ($res.LogBuffer) {
            foreach ($item in $Res.LogBuffer) {
                Add-ToLog @item
            }            
        }
        if (($Res.NewFreeDiskSpace) -and ($Res.FreeDiskSpace)) {
            Add-ToLog -Message "Free disk [$($ConsPath.Substring(0, 1)):] space changed on [$RemoteComputer] from [$($Res.FreeDiskSpace) GB] to [$($Res.NewFreeDiskSpace) GB], difference [$([math]::round(($Res.NewFreeDiskSpace - $Res.FreeDiskSpace),2)) GB]" -logFilePath $ScriptLogFilePath -Display -Status "Info" -Level ($ParentLevel + 1)
        }

        . "$PSCommandPath" -LogCutDate $Global:ScriptStartTime
    }
    "SHRINK" { 
        $ScriptBlock = {
            $Res = [PSCustomObject]@{
                Data             = $Null
                LogBuffer        = @()
                FreeDiskSpace    = 0
                NewFreeDiskSpace = 0
            }

            $ConsPath            = $Using:ConsPath
            $ShrinkArguments     = $Using:ShrinkArguments
            $WorkDir             = $Using:WorkDir
            $ScriptLogFilePath   = $Using:ScriptLogFilePath
            $Res.FreeDiskSpace   = [math]::Round((Get-PSDrive ((Get-Item $WorkDir).PSDrive.Name)).Free / 1gb, 2)

            $Process = Start-Program  -Program $ConsPath -LogFilePath $ScriptLogFilePath -Arguments $ShrinkArguments -WorkDir $WorkDir -Wait -Evaluate

            $Res.Data               = $Process
            $Res.LogBuffer          = $Global:LogBuffer
            $Res.NewFreeDiskSpace   = [math]::Round((Get-PSDrive ((Get-Item $WorkDir).PSDrive.Name)).Free / 1gb, 2)

            return  $Res
        }
        Add-ToLog -Message "Starting database shrink." -logFilePath $ScriptLogFilePath -Display -Status "Info" -Level ($ParentLevel + 1)
        $Res = Invoke-PSScriptBlock -ScriptBlock $Scriptblock -Computer $RemoteComputer -ImportLocalModule "AlexkUtils"
        if ($res.LogBuffer) {
            foreach ($item in $Res.LogBuffer) {
                Add-ToLog @item
            }            
        }
        if (($Res.NewFreeDiskSpace) -and ($Res.FreeDiskSpace)) {
            Add-ToLog -Message "Free disk [$($ConsPath.Substring(0, 1)):] space changed on [$RemoteComputer] from [$($Res.FreeDiskSpace) GB] to [$($Res.NewFreeDiskSpace) GB], difference [$([math]::round(($Res.NewFreeDiskSpace - $Res.FreeDiskSpace),2)) GB]" -logFilePath $ScriptLogFilePath -Display -Status "Info" -Level ($ParentLevel + 1)
        }
        
        . "$PSCommandPath" -LogCutDate $Global:ScriptStartTime
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
                Add-ToLog -Message "Error file ["$ConsUserDataFolder\$ConsErrorFile"] not found!" -logFilePath $ScriptLogFilePath -Display -Status "Error" -Level ($ParentLevel + 1)
            }
           
            if (Test-Path "$ConsUserDataFolder\$ConsInetFileList") {
                $Content = Get-Content -Path "$ConsUserDataFolder\$ConsInetFileList" -Encoding Default -Tail $ReadLastLines
                [string] $LastLine = $Content | Select-Object -Last 1
                if ($lastLine.Contains("Средняя скорость скачивания файлов с сервера ИП")) {
                    $Res.AvgDlSpeed = ($LastLine.Split("-"))[1].Trim()  
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
                Add-ToLog -Message "Error file ["$ConsUserDataFolder\$ConsInetFileList"] not found!" -logFilePath $ScriptLogFilePath -Display -Status "Error" -Level ($ParentLevel + 1)
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
                        Add-ToLog -Message "Error file ["$ConsUserDataFolder\$ConsInetFile"] not found!" -logFilePath $ScriptLogFilePath -Display -Status "Error" -Level ($ParentLevel + 1)
            } 
            $Res.LogBuffer = $Global:LogBuffer
            Return $Res
        }        
        
        Add-ToLog -Message "Starting statistic on computer [$RemoteComputer]." -logFilePath $ScriptLogFilePath -Display -Status "Info" -Level ($ParentLevel + 1)
        $Res = Invoke-PSScriptBlock -ScriptBlock $Scriptblock -Computer $RemoteComputer -ImportLocalModule "AlexkUtils"
        if ($res) {
            $Data = $res.ConsErrorFile
            if ($Data){
                foreach ($item in $Data) {
                    Add-ToLog -Message $item -logFilePath $ScriptLogFilePath -Display -Status "Error" -Level ($ParentLevel + 1)
                }                
            }
            $Data = $res.ConsInetFileList
            if ($Data) {
                foreach ($item in $Data) {
                    Add-ToLog -Message $item -logFilePath $ScriptLogFilePath -Display -Status "Info" -Level ($ParentLevel + 1)
                }                
            }
            $Data = $res.ConsInetFile
            if ($Data) {
                foreach ($item in $Data) {
                    Add-ToLog -Message $item -logFilePath $ScriptLogFilePath -Display -Status "Info" -Level ($ParentLevel + 1)
                }                
            }  
            $Data = $res.AvgDlSpeed
            if ($Data) {     
                Add-ToLog -Message "Average download speed [$Data]." -logFilePath $ScriptLogFilePath -Display -Status "Info" -Level ($ParentLevel + 1)
            }      

            if ($res.LogBuffer) {
                foreach ($item in $Res.LogBuffer) {
                    Add-ToLog @item
                }            
            }
        }
    }    
}

################################# Script end here ###################################
. "$GlobalSettings\$SCRIPTSFolder\Finish.ps1"
