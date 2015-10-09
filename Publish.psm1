## Global variables.

$Script:fileQueue = @()

## Functions.

Function Attach-Samba {
    Param(
        [string] $sambaRoot
    )

    $Script:drive = Get-Random
    New-PSDrive -Name $Script:drive -PSProvider FileSystem -Root $sambaRoot *> $null
}

Function Detach-Samba {
    If ($Script:drive) {
        Remove-PSDrive $Script:drive
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

    $Script:remoteRoot = $remoteRoot
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
    Param(
        [switch] $Verbose
    )

    If ($Script:remoteRoot -and $Script:localRoot) {
        If ($Verbose) {
            Write-Host "Publishing to $Script:remoteRoot"
        }

        ForEach ($file in $Script:fileQueue) {
            If ($Verbose) {
                Write-Host "File $file : " -NoNewline
            }

            $localFile = (Join-Path $Script:localRoot $file)
            $remoteFile = (Join-Path $Script:remoteRoot $file)

            If (!(Test-Path $localFile)) {
                If ($Verbose) {
                    Write-Host "skipped"
                }
            }
            Else {
                Copy-Item $localFile $remoteFile -Force
                
                If ($Verbose) {
                    Write-Host "ok"
                }
            }
        }

        Clear-FileQueue
    }
}