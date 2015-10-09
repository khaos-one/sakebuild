## Global variables.

$Script:fileQueue = @()

## Functions.

Function Get-RandomDriveLetter {
    Return ls function:[d-z]: -n|?{!(test-path $_)}|random
}

Function Attach-Samba {
    Param(
        [string] $sambaRoot
    )

    Try {
        $Script:remoteRoot = Get-RandomDriveLetter
        $Script:driveLetter = $Script:remoteRoot -replace '.$'
        $Script:drive = New-PSDrive -Name $Script:driveLetter -PSProvider FileSystem -Root $sambaRoot -Persist
    }
    Catch {
        Write-Host "Failed to create a drive: $_" -ForegroundColor Red
        $Script:drive = $null
        Return
    }

    Try {
        $dinfo = Get-PSDrive $Script:drive
    }
    Catch {
        Write-Host "Failed to connect to drive" -ForegroundColor Red
        $Script:drive = $null
        Return
    }
}

Function Detach-Samba {
    Try {
        If ($Script:drive) {
            Remove-PSDrive $Script:drive
        }
    }
    Catch {
        Write-Host "There is no drive to disconnect" -ForegroundColor Red
    }
}

Function Set-LocalRoot {
    Param(
        [string] $localRoot
    )

    $Script:localRoot = $localRoot
}

Function Set-RemoteRoot {
    Param(
        [string] $remoteRoot
    )

    $Script:remoteRoot = $Script:remoteRoot + '\' + $remoteRoot
}

Function Enqueue-File {
    Param(
        [string] $fileName
    )

    $Script:fileQueue += ,$fileName
}

Function Clear-FileQueue {
    $Script:fileQueue = @()
}

Function Do-Transfer {
    Write-Host "Publishing to $Script:remoteRoot" -ForegroundColor Magenta

    ForEach ($file in $Script:fileQueue) {
        Write-Host "File ${file}: " -NoNewline -ForegroundColor Magenta

        If ($Script:localRoot) {
            $localFile = (Join-Path $Script:localRoot $file)
        }

        $remoteFile = (Join-Path $Script:remoteRoot $file)

        If (!(Test-Path $localFile)) {
            Write-Host "skipped" -ForegroundColor Yellow
        }
        Else {
            Copy-Item $localFile $remoteFile -Force
            Write-Host "ok" -ForegroundColor Green
        }
    }

    Clear-FileQueue
    Write-Host "File transfer completed" -ForegroundColor Green
}

Function Transfer-File {
    Param(
        [string] $localFile,
        [string] $remoteFile
    )

    Write-Host "Publishing file ${localFile}: " -NoNewline -ForegroundColor Magenta

    If ($Script:localRoot) {
        $localFile = (Join-Path $Script:localRoot $file)
    }

    $remoteFile = $Script:remoteRoot + '\' + $remoteFile

    If (!(Test-Path $localFile)) {
        Write-Host "skipped" -ForegroundColor Yellow
    }
    Else {
    Write-Host $localFile
    Write-Host $remoteFile
        Copy-Item $localFile $remoteFile -Force
        Write-Host "ok" -ForegroundColor Green
    }
}
