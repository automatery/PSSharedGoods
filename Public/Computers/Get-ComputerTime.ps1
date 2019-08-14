﻿function Get-ComputerTime {
    <#
    .SYNOPSIS
    #

    .DESCRIPTION
    Long description

    .PARAMETER TimeSource
    Parameter description

    .PARAMETER Domain
    Parameter description

    .PARAMETER TimeTarget
    Parameter description

    .EXAMPLE

    Get-ComputerTime -TimeTarget AD2, AD3, EVOWin | Format-Table

    Output

    Name   LocalDateTime       RemoteDateTime      InstallTime         LastBootUpTime      TimeDifferenceMinutes TimeDifferenceSeconds TimeDifferenceMilliseconds TimeSourceName
    ----   -------------       --------------      -----------         --------------      --------------------- --------------------- -------------------------- --------------
    AD2    13.08.2019 23:40:26 13.08.2019 23:40:26 30.05.2018 18:30:48 09.08.2019 18:40:31  8,33333333333333E-05                 0,005                          5 AD1.ad.evotec.xyz
    AD3    13.08.2019 23:40:26 13.08.2019 17:40:26 26.05.2019 17:30:17 09.08.2019 18:40:30  0,000266666666666667                 0,016                         16 AD1.ad.evotec.xyz
    EVOWin 13.08.2019 23:40:26 13.08.2019 23:40:26 24.05.2019 22:46:45 09.08.2019 18:40:06  6,66666666666667E-05                 0,004                          4 AD1.ad.evotec.xyz

    .NOTES
    General notes
    #>

    [CmdletBinding()]
    param(
        [string] $TimeSource,
        [string] $Domain = $Env:USERDNSDOMAIN,
        [alias('ComputerName')][string[]] $TimeTarget = $ENV:COMPUTERNAME
    )
    if (-not $TimeSource) {
        $TimeSource = (Get-ADDomainController -Discover -Service PrimaryDC -DomainName $Domain).HostName
    }

    $TimeSourceInformation = Get-CimData -ComputerName $TimeSource -Class 'win32_operatingsystem'

    $TimeTargetInformationCache = @{ }
    $TimeTargetInformation = Get-CimData -ComputerName $TimeTarget -Class 'win32_operatingsystem'
    foreach ($_ in $TimeTargetInformation) {
        $TimeTargetInformationCache[$_.PSComputerName] = $_
    }
    $TimeLocalCache = @{ }
    $TimeLocal = Get-CimData -ComputerName $TimeTarget -Class 'Win32_LocalTime'
    foreach ($_ in $TimeLocal) {
        $TimeLocalCache[$_.PSComputerName] = $_
    }
    #$Information | ft PSComputerName, Name, LocalDateTime, LastBootUpTime
    #$InformationPDC | ft PSComputerName, Name, LocalDateTime, LastBootUpTime


    $AllResults = foreach ($Computer in $TimeTarget) {
        $WMIComputerTime = $TimeLocalCache[$Computer]
        $WMIComputerTarget = $TimeTargetInformationCache[$Computer]

        if ($WMIComputerTarget.LocalDateTime -and $TimeSourceInformation.LocalDateTime) {
            $Result = New-TimeSpan -Start $TimeSourceInformation.LocalDateTime -End $WMIComputerTarget.LocalDateTime
            [PSCustomObject] @{
                Name                       = $Computer
                LocalDateTime              = $WMIComputerTarget.LocalDateTime
                RemoteDateTime             = Get-WMILocalDateTime -WMILocalTime $WMIComputerTime
                InstallTime                = $WMIComputerTarget.InstallDate
                LastBootUpTime             = $WMIComputerTarget.LastBootUpTime
                TimeDifferenceMinutes      = if ($Result.TotalMinutes -lt 0) { ($Result.TotalMinutes * -1) } else { $Result.TotalMinutes }
                TimeDifferenceSeconds      = if ($Result.TotalSeconds -lt 0) { ($Result.TotalSeconds * -1) } else { $Result.TotalSeconds }
                TimeDifferenceMilliseconds = if ($Result.TotalMilliseconds -lt 0) { ($Result.TotalMilliseconds * -1) } else { $Result.TotalMilliseconds }
                TimeSourceName             = $TimeSource
                Status                     = ''
            }
        } else {
            [PSCustomObject] @{
                Name                       = $Computer
                LocalDateTime              = $WMIComputerTarget.LocalDateTime
                RemoteDateTime             = Get-WMILocalDateTime -WMILocalTime $WMIComputerTime
                InstallTime                = $WMIComputerTarget.InstallDate
                LastBootUpTime             = $WMIComputerTarget.LastBootUpTime
                TimeDifferenceMinutes      = $null
                TimeDifferenceSeconds      = $null
                TimeDifferenceMilliseconds = $null
                TimeSourceName             = $TimeSource
                Status                     = 'Unable to get time difference.'
            }
        }

    }
    $AllResults
}