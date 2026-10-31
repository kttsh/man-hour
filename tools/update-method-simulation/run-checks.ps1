<#
.SYNOPSIS
    確認SQL（V-01〜V-08）を順に実行し、結果をCSVに保存する。

.DESCRIPTION
    接続設定は .env から読む。追加のインストールは要らない（Windows PowerShell 5.1で動く）。
    結果は results\<実行日時>\ に保存する。使い方は README.md を参照。

.PARAMETER Only
    実行するIDを指定する（例: -Only v01,v06）。指定すると重いSQLも実行できる。

.PARAMETER IncludeHeavy
    既定では実行しない重いSQL（V-05、V-08）も含めて実行する。

.PARAMETER Force
    同じ日に成功済みのSQLも、もう一度実行する。

.PARAMETER EnvFile
    接続設定のファイル。既定はこのスクリプトと同じフォルダの .env。

.PARAMETER OutDir
    結果の保存先。既定はこのスクリプトと同じフォルダの results。
#>
[CmdletBinding()]
param(
    [string[]]$Only,
    [switch]$IncludeHeavy,
    [switch]$Force,
    [string]$EnvFile = (Join-Path $PSScriptRoot '.env'),
    [string]$OutDir = (Join-Path $PSScriptRoot 'results')
)

Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'

# 実行する順番。軽いものから流し、重いものは既定で外す。
$Checks = @(
    @{ Id = 'v01'; File = 'v01-freshness.sql';              Heavy = $false }
    @{ Id = 'v06'; File = 'v06-update-date-by-day.sql';     Heavy = $false }
    @{ Id = 'v02'; File = 'v02-status-mix.sql';             Heavy = $false }
    @{ Id = 'v03'; File = 'v03-insert-date-uniformity.sql'; Heavy = $false }
    @{ Id = 'v04'; File = 'v04-oks02-missing-days.sql';     Heavy = $false }
    @{ Id = 'v07'; File = 'v07-row-bytes.sql';              Heavy = $false }
    @{ Id = 'v05'; File = 'v05-full-row-duplicates.sql';    Heavy = $true }
    @{ Id = 'v08'; File = 'v08-read-timing.sql';            Heavy = $true }
)

$Invariant = [System.Globalization.CultureInfo]::InvariantCulture
$script:ConnectionInfo = @()
$Utf8Bom = New-Object System.Text.UTF8Encoding($true)

function Read-EnvFile([string]$Path) {
    # 値に # や = を含むパスワードがありうるので、最初の = でだけ分け、行内コメントは扱わない。
    $values = @{}
    $lineNo = 0
    foreach ($line in [System.IO.File]::ReadAllLines($Path, [System.Text.Encoding]::UTF8)) {
        $lineNo++
        $text = $line.Trim()
        if ($text -eq '' -or $text.StartsWith('#')) { continue }
        $pos = $text.IndexOf('=')
        if ($pos -lt 1) {
            # 内容はパスワードかもしれないので画面に出さない。
            Write-Warning ".env の $lineNo 行目を読み飛ばしました（名前=値 の形ではありません）。"
            continue
        }
        $value = $text.Substring($pos + 1).Trim()
        if ($value.Length -ge 2 -and
            (($value[0] -eq '"' -and $value[-1] -eq '"') -or ($value[0] -eq "'" -and $value[-1] -eq "'"))) {
            $value = $value.Substring(1, $value.Length - 2)
        }
        $values[$text.Substring(0, $pos).Trim()] = $value
    }
    return $values
}

function Get-Setting([hashtable]$FileValues, [string]$Name, [string]$Default = '') {
    # 環境変数を .env より優先する。
    $fromProcess = [Environment]::GetEnvironmentVariable($Name)
    if (-not [string]::IsNullOrEmpty($fromProcess)) { return $fromProcess }
    if ($FileValues.ContainsKey($Name) -and $FileValues[$Name] -ne '') { return $FileValues[$Name] }
    return $Default
}

function ConvertTo-Bool([string]$Name, [string]$Value) {
    switch ($Value.ToLowerInvariant()) {
        'true'  { return $true }
        'false' { return $false }
        default { throw "$Name は true か false で指定してください。" }
    }
}

function Get-Password([string]$FromSetting) {
    if ($FromSetting -ne '') {
        $secure = New-Object System.Security.SecureString
        foreach ($ch in $FromSetting.ToCharArray()) { $secure.AppendChar($ch) }
    } else {
        $secure = Read-Host 'パスワード' -AsSecureString
    }
    $secure.MakeReadOnly()
    return $secure
}

function Hide-ConnectionInfo([string]$Text) {
    # 結果はAIや他者に渡すことがあるので、ログにサーバー名とユーザーIDを残さない。
    foreach ($secret in $script:ConnectionInfo) {
        if ($secret -ne '') { $Text = $Text.Replace($secret, '***') }
    }
    return $Text
}

function Get-ErrorText($ErrorRecord) {
    # タイムアウトなどの説明は、内側の例外ではなくSqlExceptionにある。
    $found = $ErrorRecord.Exception
    while ($found -isnot [System.Data.SqlClient.SqlException] -and $null -ne $found.InnerException) {
        $found = $found.InnerException
    }
    return Hide-ConnectionInfo $found.Message
}

function New-Connection {
    # パスワードは接続文字列に入れず、SqlCredentialで渡す。
    $connection = New-Object System.Data.SqlClient.SqlConnection(
        $script:ConnectionString, $script:Credential)
    $connection.add_InfoMessage([System.Data.SqlClient.SqlInfoMessageEventHandler] {
        param($source, $e)
        foreach ($item in $e.Errors) {
            # 5701、5703は USE や言語の切替の通知で、結果と関係ない。
            if ($item.Number -eq 5701 -or $item.Number -eq 5703) { continue }
            $message = Hide-ConnectionInfo $item.Message
            [void]$script:ServerMessages.Add($message)
            Write-Host "    $message"
        }
    })
    $connection.Open()
    return $connection
}

function ConvertTo-CsvField($Reader, [int]$Index) {
    if ($Reader.IsDBNull($Index)) { return '' }
    # 桁の多いdecimalは .NET のDecimalに収まらないことがあるので、SqlDecimalのまま文字にする。
    if ($Reader.GetFieldType($Index) -eq [decimal]) {
        $text = $Reader.GetSqlDecimal($Index).ToString()
    } else {
        $value = $Reader.GetValue($Index)
        if ($value -is [datetime]) {
            switch ($Reader.GetDataTypeName($Index)) {
                'date'      { $format = 'yyyy-MM-dd' }
                'datetime2' { $format = 'yyyy-MM-dd HH:mm:ss.fffffff' }
                default     { $format = 'yyyy-MM-dd HH:mm:ss.fff' }
            }
            $text = $value.ToString($format, $Invariant)
        } elseif ($value -is [byte[]]) {
            $text = '0x' + [System.BitConverter]::ToString($value).Replace('-', '')
        } elseif ($value -is [System.IFormattable]) {
            $text = $value.ToString($null, $Invariant)
        } else {
            $text = [string]$value
        }
    }
    return ConvertTo-CsvText $text
}

function ConvertTo-CsvText([string]$Text) {
    if ($Text.IndexOfAny([char[]]@(',', '"', "`r", "`n")) -ge 0) {
        return '"' + $Text.Replace('"', '""') + '"'
    }
    return $Text
}

function Write-ResultSet($Reader, [string]$Path) {
    $writer = New-Object System.IO.StreamWriter($Path, $false, $Utf8Bom)
    $writer.NewLine = "`r`n"
    try {
        $last = $Reader.FieldCount - 1
        $writer.WriteLine((@(0..$last | ForEach-Object { ConvertTo-CsvText $Reader.GetName($_) }) -join ','))
        $rows = 0
        while ($Reader.Read()) {
            $fields = New-Object 'string[]' $Reader.FieldCount
            for ($i = 0; $i -le $last; $i++) { $fields[$i] = ConvertTo-CsvField $Reader $i }
            $writer.WriteLine(($fields -join ','))
            $rows++
        }
        return $rows
    } finally {
        $writer.Dispose()
    }
}

function Get-Views([string]$SqlText) {
    $names = [regex]::Matches($SqlText, 'V_T_OKS\d+') | ForEach-Object { $_.Value }
    return (@($names | Sort-Object -Unique) -join ' ')
}

function Get-Conditions([string]$SqlText) {
    # 冒頭のDECLAREのうち、値が定数のものを抽出条件として記録する。全文は実行時のコピーに残る。
    $pattern = '(?m)^\s*DECLARE\s+@(\w+)\s+[^=;\r\n]+=\s*(''[^'']*''|\d+|NULL)\s*;'
    $found = [regex]::Matches($SqlText, $pattern) |
        ForEach-Object { '{0}={1}' -f $_.Groups[1].Value, $_.Groups[2].Value }
    return (@($found) -join ' ')
}

function Invoke-Check([hashtable]$Check, [string]$SqlPath, [string]$RunDir) {
    $script:ServerMessages = New-Object System.Collections.ArrayList
    $sqlText = [System.IO.File]::ReadAllText($SqlPath, [System.Text.Encoding]::UTF8)
    Copy-Item -LiteralPath $SqlPath -Destination (Join-Path $RunDir 'sql')

    $startedAt = Get-Date
    $status = 'OK'
    $errorText = ''
    $sets = 0
    $rows = 0
    $connection = $null
    $reader = $null
    try {
        $connection = New-Connection
        $command = $connection.CreateCommand()
        $command.CommandText = $sqlText
        $command.CommandTimeout = $script:CommandTimeout
        $reader = $command.ExecuteReader()
        do {
            if ($reader.FieldCount -gt 0) {
                $sets++
                $csvPath = Join-Path $RunDir ('{0}_r{1}.csv' -f $Check.Id, $sets)
                $rows += Write-ResultSet $reader $csvPath
            }
        } while ($reader.NextResult())
    } catch {
        $status = 'ERROR'
        $errorText = Get-ErrorText $_
    } finally {
        if ($null -ne $reader) { $reader.Dispose() }
        if ($null -ne $connection) { $connection.Dispose() }
    }
    $finishedAt = Get-Date

    $notes = @($script:ServerMessages)
    if ($errorText -ne '') { $notes += $errorText }
    return [pscustomobject]@{
        id          = $Check.Id
        sql_file    = $Check.File
        views       = Get-Views $sqlText
        conditions  = Get-Conditions $sqlText
        started_at  = $startedAt.ToString('yyyy-MM-ddTHH:mm:sszzz', $Invariant)
        finished_at = $finishedAt.ToString('yyyy-MM-ddTHH:mm:sszzz', $Invariant)
        seconds     = [math]::Round(($finishedAt - $startedAt).TotalSeconds, 1).ToString($Invariant)
        result_sets = $sets
        rows        = $rows
        status      = $status
        message     = ($notes -join ' | ')
    }
}

function Add-RunLog([string]$Path, $Entry) {
    # 途中で止まっても残るよう、1本ごとに書き足す。
    $names = @($Entry.PSObject.Properties | ForEach-Object { $_.Name })
    $line = @($names | ForEach-Object { ConvertTo-CsvText ([string]$Entry.$_) }) -join ','
    $content = ''
    if (-not (Test-Path -LiteralPath $Path)) {
        $content = ($names -join ',') + "`r`n"
    }
    [System.IO.File]::AppendAllText($Path, $content + $line + "`r`n", $Utf8Bom)
}

function Get-DoneToday([string]$Root) {
    # R-18（全行の読取は1日1回まで）のため、今日成功したIDを集める。
    $done = @{}
    if (-not (Test-Path -LiteralPath $Root)) { return $done }
    $prefix = (Get-Date).ToString('yyyyMMdd', $Invariant) + '_*'
    foreach ($folder in Get-ChildItem -LiteralPath $Root -Directory -Filter $prefix) {
        $logPath = Join-Path $folder.FullName 'run-log.csv'
        if (-not (Test-Path -LiteralPath $logPath)) { continue }
        foreach ($entry in Import-Csv -LiteralPath $logPath -Encoding UTF8) {
            if ($entry.status -eq 'OK') { $done[$entry.id] = $true }
        }
    }
    return $done
}

function Select-Checks {
    if ($Only) {
        # cmd から渡すと v01,v06 が1つの文字列で届くので、ここで分ける。
        $wanted = @($Only | ForEach-Object { $_ -split ',' } |
            ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ -ne '' })
        $known = @($Checks | ForEach-Object { $_.Id })
        foreach ($id in $wanted) {
            if ($known -notcontains $id) {
                throw "-Only の $id は存在しません。指定できるID: $($known -join ', ')"
            }
        }
        return @($Checks | Where-Object { $wanted -contains $_.Id })
    }
    if ($IncludeHeavy) { return $Checks }
    return @($Checks | Where-Object { -not $_.Heavy })
}

function Main {
    # .NETのファイル操作はPowerShellの現在位置を見ないので、絶対パスにしておく。
    $envPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($EnvFile)
    $outRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutDir)
    if (-not (Test-Path -LiteralPath $envPath)) {
        throw "接続設定が見つかりません: $envPath （.env.example を .env にコピーして値を入れてください）"
    }

    $selected = @(Select-Checks)
    if (-not $Force) {
        $doneToday = Get-DoneToday $outRoot
        foreach ($check in $selected) {
            if ($doneToday.ContainsKey($check.Id)) {
                Write-Warning "$($check.Id) は今日すでに成功しているので飛ばします。もう一度流すなら -Force を付けてください。"
            }
        }
        $selected = @($selected | Where-Object { -not $doneToday.ContainsKey($_.Id) })
    }
    if ($selected.Count -eq 0) {
        Write-Host '実行するSQLはありません。'
        return 0
    }

    $values = Read-EnvFile $envPath
    $server = Get-Setting $values 'MSSQL_SERVER'
    $user = Get-Setting $values 'MSSQL_USER'
    if ($server -eq '' -or $user -eq '') {
        throw '.env に MSSQL_SERVER と MSSQL_USER を指定してください。'
    }
    $script:ConnectionInfo = @($server, $user)

    # PowerShellではビルダーのプロパティを直接設定できないので、キー名で指定する。
    $builder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
    $builder['Data Source'] = $server
    $builder['Initial Catalog'] = Get-Setting $values 'MSSQL_DATABASE' 'GEMS_DM_S'
    $builder['Encrypt'] = ConvertTo-Bool 'MSSQL_ENCRYPT' (Get-Setting $values 'MSSQL_ENCRYPT' 'true')
    $builder['TrustServerCertificate'] = ConvertTo-Bool 'MSSQL_TRUST_SERVER_CERTIFICATE' `
        (Get-Setting $values 'MSSQL_TRUST_SERVER_CERTIFICATE' 'false')
    $builder['Application Name'] = 'man-hour-update-method-checks'
    $builder['Pooling'] = $false
    $script:ConnectionString = $builder.ConnectionString
    $script:CommandTimeout = [int](Get-Setting $values 'MSSQL_COMMAND_TIMEOUT_SEC' '3600')

    $password = Get-Password (Get-Setting $values 'MSSQL_PASSWORD')
    $script:Credential = New-Object System.Data.SqlClient.SqlCredential($user, $password)

    # SQLを流す前に接続を確かめる。失敗したら結果フォルダを作らずに終わる。
    $script:ServerMessages = New-Object System.Collections.ArrayList
    try {
        (New-Connection).Dispose()
    } catch {
        throw "接続できませんでした: $(Get-ErrorText $_)"
    }

    $runDir = Join-Path $outRoot (Get-Date).ToString('yyyyMMdd_HHmmss', $Invariant)
    [void](New-Item -ItemType Directory -Path (Join-Path $runDir 'sql') -Force)
    $logPath = Join-Path $runDir 'run-log.csv'

    $failed = 0
    foreach ($check in $selected) {
        $sqlPath = Join-Path (Join-Path $PSScriptRoot 'sql') $check.File
        Write-Host "[$($check.Id)] 実行中: $($check.File)"
        $entry = Invoke-Check $check $sqlPath $runDir
        Add-RunLog $logPath $entry
        if ($entry.status -eq 'OK') {
            Write-Host "[$($check.Id)] 完了: $($entry.seconds) 秒、結果 $($entry.result_sets) 個、$($entry.rows) 行"
        } else {
            $failed++
            Write-Warning "[$($check.Id)] 失敗: $($entry.message)"
        }
    }

    Write-Host ''
    Write-Host "保存先: $runDir"
    if ($failed -gt 0) {
        Write-Warning "$failed 本が失敗しました。run-log.csv を確認してください。"
        return 1
    }
    return 0
}

try {
    $exitCode = Main
} catch {
    Write-Host "エラー: $($_.Exception.GetBaseException().Message)" -ForegroundColor Red
    $exitCode = 2
}
exit $exitCode
