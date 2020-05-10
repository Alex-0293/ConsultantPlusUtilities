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
Clear-Host
$Global:ScriptName = $MyInvocation.MyCommand.Name
$InitScript        = "C:\DATA\Projects\GlobalSettings\SCRIPTS\Init.ps1"
if (. "$InitScript" -MyScriptRoot (Split-Path $PSCommandPath -Parent) -force ) { exit 1 }

# Error trap
trap {
    if ($Global:Logger) {
        Get-ErrorReporting $_
        . "$GlobalSettings\$SCRIPTSFolder\Finish.ps1" 
    }
    Else {
        Write-Host "There is error before logging initialized." -ForegroundColor Red
    }   
    exit 1
}
################################# Script start here #################################
$WorkDir = Split-Path -path $ConsPath -Parent

#$Service = "SHRINK"
switch ($Service.ToUpper()) {
    "UPDATE"    { 
        $ScriptBlock = {
            $Res = [PSCustomObject]@{
                Data      = $Null
                LogBuffer = $Null
            }

            $ConsPath          = $Using:ConsPath
            $UpdateArguments   = $Using:UpdateArguments
            $WorkDir           = $Using:WorkDir
            $ScriptLogFilePath = $Using:ScriptLogFilePath

            $Process = Start-Program  -Program $ConsPath -LogFilePath $ScriptLogFilePath -Arguments $UpdateArguments -WorkDir $WorkDir -Wait -Evaluate

            $Res.Data      = $Process
            $Res.LogBuffer = $Global:LogBuffer

            return  $Res
        }
        Add-ToLog -Message "Starting update." -logFilePath $ScriptLogFilePath -Display -Status "Info" -Level ($ParentLevel + 1)
        $Res = Invoke-PSScriptBlock -ScriptBlock $Scriptblock -Computer $RemoteComputer -ImportLocalModule "AlexkUtils"
        if ($res) {
            foreach ($item in $Res.LogBuffer) {
                Add-ToLog @item
            }
        }
        . "$PSCommandPath\$ScriptName" -LogCutDate $Global:ScriptStartTime
    }
    "SHRINK" { 
        $ScriptBlock = {
            $Res = [PSCustomObject]@{
                Data      = $Null
                LogBuffer = $Null
            }

            $ConsPath          = $Using:ConsPath
            $ShrinkArguments   = $Using:ShrinkArguments
            $WorkDir           = $Using:WorkDir
            $ScriptLogFilePath = $Using:ScriptLogFilePath

            $Process = Start-Program  -Program $ConsPath -LogFilePath $ScriptLogFilePath -Arguments $ShrinkArguments -WorkDir $WorkDir -Wait -Evaluate

            $Res.Data      = $Process
            $Res.LogBuffer = $Global:LogBuffer

            return  $Res
        }
        Add-ToLog -Message "Starting database shrink." -logFilePath $ScriptLogFilePath -Display -Status "Info" -Level ($ParentLevel + 1)
        $Res = Invoke-PSScriptBlock -ScriptBlock $Scriptblock -Computer $RemoteComputer -ImportLocalModule "AlexkUtils"
        if ($res) {
            foreach ($item in $Res.LogBuffer) {
                Add-ToLog @item
            }
        }
        . "$PSCommandPath\$ScriptName" -LogCutDate $Global:ScriptStartTime
    }
    Default {
        $Scriptblock = {
            $Res = [PSCustomObject]@{
                ConsErrorFile    = $Null
                ConsInetFileList = $Null
                ConsInetFile     = $Null
                LogBuffer        = $Null
            }

            $LogCutDate         = $using:LogCutDate
            $ConsUserDataFolder = $using:ConsUserDataFolder
            $ConsErrorFile      = $using:ConsErrorFile
            $ReadLastLines      = $using:ReadLastLines
            $ConsErrorFile      = $using:ConsErrorFile
            $ConsInetFileList   = $using:ConsInetFileList
            $ConsInetFile       = $using:ConsInetFile
            $ParentLevel        = $using:ParentLevel
            Function Convert-InetFileListContentToCSV ($TodayInetFileListContent) {
                $SpeedStat = $TodayInetFileListContent | Select-Object -last 1 
                $TodayInetFileListContent = $TodayInetFileListContent | Select-Object -last ($TodayInetFileListContent.count - 2) 
                $TodayInetFileListContent = $TodayInetFileListContent | Select-Object -first ($TodayInetFileListContent.count - 1) 
                $TodayInetFileListContent = $TodayInetFileListContent | Where-Object { $_ -notlike "*-------*" }
                [array] $Res = @()

                foreach ($Line in $TodayInetFileListContent) {
            
            
                    [datetime] $LineDate = Get-Date $line.Substring(0, 18)
                    $Line = $line.Substring(23, ($line.Length - 23))
                    $Array1 = $Line.split(":")
            
                    if ($Array1[0].contains("Получен файл")) {
                        $Operation = "Receive"
                    }
                    ElseIf ($Array1[0].contains("Отправлен файл")) {
                        $Operation = "Send"
                    }
                    Else {
                        $Operation = "Unknown"
                    }

                    $Id = ($Array1[0].trim()).split(" ")[0]

                    $Array2 = ($Array1[1].trim()).split(" ")
                    $FileName = $Array2[0]
                    $Size = $Array2[1].remove(0, 1)

                    $PSO = [PSCustomObject]@{
                        Date      = $LineDate
                        Operation = $Operation
                        Id        = $Id
                        FileName  = $FileName
                        Size      = $Size
                    }
                    $Res += $PSO
                }    
                Return $Res
            }

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
                [array] $TodayInetFileListContent = @()
                foreach ($line in $Content) {
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
                $res.ConsInetFile = $TodayInetFileContent
            }
            Else {
                        Add-ToLog -Message "Error file ["$ConsUserDataFolder\$ConsInetFile"] not found!" -logFilePath $ScriptLogFilePath -Display -Status "Error" -Level ($ParentLevel + 1)
            } 
            
            Return $Res
        }        
        
        Add-ToLog -Message "Starting statistic." -logFilePath $ScriptLogFilePath -Display -Status "Info" -Level ($ParentLevel + 1)
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
            if ($Res.LogBuffer){
                foreach ($item in $Res.LogBuffer) {
                    Add-ToLog @item
                }
            }
        }
    }    
}

################################# Script end here ###################################
. "$GlobalSettings\$SCRIPTSFolder\Finish.ps1"
