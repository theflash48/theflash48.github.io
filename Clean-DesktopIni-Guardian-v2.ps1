$ErrorActionPreference = 'Stop'

Write-Host ""
Write-Host "=========================================="
Write-Host "  Project Agent desktop.ini Guardian v2"
Write-Host "=========================================="
Write-Host ""

$Root = $PSScriptRoot

if ([string]::IsNullOrWhiteSpace($Root)) {
    Write-Host "ERROR: PSScriptRoot is empty." -ForegroundColor Red
    exit 1
}

if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
    Write-Host "ERROR: Guardian root is not a valid folder:" -ForegroundColor Red
    Write-Host "'$Root'"
    exit 1
}

$Root = (Get-Item -LiteralPath $Root -Force).FullName

function Remove-DesktopIniTarget {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $name = [System.IO.Path]::GetFileName($Path)

    if ($name -ine 'desktop.ini' -and $name -ine 'desktop.ini.meta') {
        return
    }

    for ($attempt = 1; $attempt -le 8; $attempt++) {
        try {
            if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
                return
            }

            & attrib.exe -r -h -s "$Path" 2>$null | Out-Null
            Remove-Item -LiteralPath $Path -Force -ErrorAction Stop

            if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
                Write-Host "[DELETED] $Path"
                return
            }
        }
        catch {
            if ($attempt -eq 8) {
                Write-Host "[FAILED]  $Path :: $($_.Exception.Message)" -ForegroundColor Red
                return
            }
        }

        Start-Sleep -Milliseconds (75 * $attempt)
    }
}

Write-Host "Root:"
Write-Host "'$Root'"
Write-Host ""
Write-Host "Cleaning existing desktop.ini files..."

foreach ($filter in @('desktop.ini', 'desktop.ini.meta')) {
    Get-ChildItem -LiteralPath $Root -Recurse -Force -File -Filter $filter -ErrorAction SilentlyContinue |
        ForEach-Object { Remove-DesktopIniTarget -Path $_.FullName }
}

$watchers = New-Object System.Collections.Generic.List[System.IO.FileSystemWatcher]
$subscriptions = New-Object System.Collections.Generic.List[object]

try {
    foreach ($filter in @('desktop.ini', 'desktop.ini.meta')) {
        $watcher = New-Object System.IO.FileSystemWatcher
        $watcher.Path = $Root
        $watcher.Filter = $filter
        $watcher.IncludeSubdirectories = $true
        $watcher.NotifyFilter = [System.IO.NotifyFilters]'FileName, CreationTime, LastWrite'
        $watcher.InternalBufferSize = 65536

        foreach ($eventName in @('Created', 'Changed', 'Renamed')) {
            $subscription = Register-ObjectEvent -InputObject $watcher -EventName $eventName -Action {
                $path = $Event.SourceEventArgs.FullPath
                $name = [System.IO.Path]::GetFileName($path)

                if ($name -ine 'desktop.ini' -and $name -ine 'desktop.ini.meta') {
                    return
                }

                for ($attempt = 1; $attempt -le 8; $attempt++) {
                    try {
                        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
                            return
                        }

                        & attrib.exe -r -h -s "$path" 2>$null | Out-Null
                        Remove-Item -LiteralPath $path -Force -ErrorAction Stop

                        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
                            Write-Host "[DELETED] $path"
                            return
                        }
                    }
                    catch {
                        if ($attempt -eq 8) {
                            Write-Host "[FAILED]  $path :: $($_.Exception.Message)" -ForegroundColor Red
                            return
                        }
                    }

                    Start-Sleep -Milliseconds (75 * $attempt)
                }
            }

            $subscriptions.Add($subscription)
        }

        $watcher.EnableRaisingEvents = $true
        $watchers.Add($watcher)
    }

    Write-Host ""
    Write-Host "Guardian v2 active."
    Write-Host "Any new desktop.ini or desktop.ini.meta below this folder will be deleted."
    Write-Host "Keep this window open. Press Ctrl+C to stop."
    Write-Host ""

    while ($true) {
        Wait-Event -Timeout 1 | Out-Null
    }
}
finally {
    foreach ($subscription in $subscriptions) {
        Unregister-Event -SubscriptionId $subscription.Id -ErrorAction SilentlyContinue
        Remove-Job -Id $subscription.Id -Force -ErrorAction SilentlyContinue
    }

    foreach ($watcher in $watchers) {
        $watcher.EnableRaisingEvents = $false
        $watcher.Dispose()
    }
}
