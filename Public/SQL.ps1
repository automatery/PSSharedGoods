function Send-SqlInsert {
    [CmdletBinding()]
    param(
        [Object] $Object,
        [hashtable] $SqlSettings
    )
    $Queries = New-ArrayList
    $ReturnData = @()
    if ($SqlSettings.SqlTableTranspose) {
        $Object = Format-TransposeTable -Object $Object
    }
    $TableMapping = New-SqlTableMapping -SqlTableMapping $SqlSettings.SqlTableMapping -Object $Object

    if ($SqlSettings.SqlTableCreate) {
        $CreateTableSQL = New-SqlQueryCreateTable -SqlSettings $SqlSettings -Object $Object -TableMapping $TableMapping
        Add-ToArray -List $Queries -Element $CreateTableSQL
    }
    $Queries += New-SqlQuery -Object $Object -SqlSettings $SqlSettings -TableMapping $TableMapping
    foreach ($Query in $Queries) {
        $ReturnData += $Query
        try {
            if ($Query) {
                $ReturnData += Invoke-Sqlcmd2 -SqlInstance $SqlSettings.SqlServer -Database $SqlSettings.SqlDatabase -Query $Query -ErrorAction Stop
            }
        } catch {
            $ErrorMessage = $_.Exception.Message -replace "`n", " " -replace "`r", " "
            #Write-Color @script:WriteParameters -Text '[e] ', 'SQL Error: ', $ErrorMessage -Color White, White, Yellow
            $ReturnData += "Error occured: $ErrorMessage"
        }
    }
    return $ReturnData
}

function New-SqlQuery {
    [CmdletBinding()]
    param (
        [hashtable ]$SqlSettings,
        [Object] $Object,
        $TableMapping
    )

    $ArraySQLQueries = New-ArrayList
    if ($Object -ne $null) {
        ## Added fields to know when event was added to SQL and by WHO (in this case TaskS Scheduler User)
        ## Only adding when $Object exists

        foreach ($O in $Object) {
            $ArrayMain = New-ArrayList
            $ArrayKeys = New-ArrayList
            $ArrayValues = New-ArrayList

            if (-not $O.AddedWhen) {
                Add-Member -InputObject $O -MemberType NoteProperty -Name "AddedWhen" -Value (Get-Date)
            }
            if (-not $O.AddedWho) {
                Add-Member -InputObject $O -MemberType NoteProperty -Name "AddedWho" -Value ($Env:USERNAME)
            }
            foreach ($E in $O.PSObject.Properties) {
                $FieldName = $E.Name
                $FieldValue = $E.Value

                foreach ($MapKey in $TableMapping.Keys) {
                    if ($FieldName -eq $MapKey) {
                        $MapValue = $TableMapping.$MapKey
                        if ($FieldValue -is [DateTime]) { $FieldValue = Get-Date $FieldValue -Format "yyyy-MM-dd HH:mm:ss" }
                        if ($FieldValue -like "*'*") { $FieldValue = $FieldValue -Replace "'", "''" }
                        #if ($FieldValue -eq '') { $FieldValue = 'NULL' }
                        Add-ToArray -List $ArrayKeys -Element "[$MapValue]"
                        Add-ToArray -List $ArrayValues -Element "'$FieldValue'"
                    }
                }
            }
            if ($ArrayKeys) {
                Add-ToArray -List $ArrayMain -Element "INSERT INTO  $($SqlSettings.SqlTable) ("
                Add-ToArray -List $ArrayMain -Element ($ArrayKeys -join ',')
                Add-ToArray -List $ArrayMain -Element ') VALUES ('
                Add-ToArray -List $ArrayMain -Element ($ArrayValues -join ',')
                Add-ToArray -List $ArrayMain -Element ')'

                Add-ToArray -List $ArraySQLQueries -Element ([string] ($ArrayMain) -replace "`n", "" -replace "`r", "")
            }
        }
    }
    # Write-Verbose "SQLQuery: $SqlQuery"
    return $ArraySQLQueries
}

function New-SqlTableMapping {
    [CmdletBinding()]
    param(
        [hashtable] $SqlTableMapping,
        [Object] $Object
    )
    if ($SqlTableMapping) {
        #Write-Verbose "Test $($SqlTableMapping.'Record ID')"
        $TableMapping = $SqlTableMapping
    } else {
        $TableMapping = @{}
        foreach ($O in $Object) {
            if (-not $O.AddedWhen) {
                Add-Member -InputObject $O -MemberType NoteProperty -Name "AddedWhen" -Value (Get-Date)
            }
            if (-not $O.AddedWho) {
                Add-Member -InputObject $O -MemberType NoteProperty -Name "AddedWho" -Value ($Env:USERNAME)
            }
            foreach ($E in $O.PSObject.Properties) {
                $FieldName = $E.Name
                $FieldNameSQL = $($E.Name).Replace(' ', '')
                $TableMapping.$FieldName = $FieldNameSQL
            }
            break
        }
    }
    return $TableMapping
}



function New-SqlQueryCreateTable {
    [CmdletBinding()]
    param (
        [hashtable ]$SqlSettings,
        [Object] $Object,
        $TableMapping
    )

    $ArraySQLQueries = New-ArrayList
    if ($Object) {

        foreach ($O in $Object) {
            #Get-ObjectType -Object $O -Verbose -VerboseOnly
            $ArrayMain = New-ArrayList
            $ArrayKeys = New-ArrayList
            $ArrayValues = New-ArrayList

            foreach ($E in $O.PSObject.Properties) {
                $FieldName = $E.Name
                $FieldValue = $E.Value

                #Write-Verbose "Test1 - Value1: $FieldName Value2: $FieldValue"
                foreach ($MapKey in $TableMapping.Keys) {
                    if ($FieldName -eq $MapKey) {
                        $MapValue = $TableMapping.$MapKey
                        #Write-Verbose "Test2 - Value1: $FieldName Value2: $FieldValue MapKey: $MapKey"
                        if ($FieldValue -is [DateTime]) {
                            Add-ToArray -List $ArrayKeys -Element "[$MapValue] [DateTime] NULL"
                        } elseif ($FieldValue -is [int] -or $FieldValue -is [Int64]) {
                            Add-ToArray -List $ArrayKeys -Element "[$MapValue] [int] NULL"
                        } elseif ($FieldValue -is [bool]) {
                            Add-ToArray -List $ArrayKeys -Element "[$MapValue] [bit] NULL"
                        } else {
                            Add-ToArray -List $ArrayKeys -Element "[$MapValue] [nvarchar](max) NULL"
                        }
                    }
                }
            }
            if ($ArrayKeys) {
                Add-ToArray -List $ArrayMain -Element "CREATE TABLE $($SqlSettings.SqlTable) ("
                Add-ToArray -List $ArrayMain -Element "ID int IDENTITY(1,1) PRIMARY KEY,"
                Add-ToArray -List $ArrayMain -Element ($ArrayKeys -join ',')


                Add-ToArray -List $ArrayMain -Element ')'
                Add-ToArray -List $ArraySQLQueries -Element ([string] ($ArrayMain) -replace "`n", "" -replace "`r", "")
            }
            break
        }
    }
    return $ArraySQLQueries
}