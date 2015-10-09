Import-Module $PSScriptRoot/psake/psake.psm1

## Module variables.

$Script:projects = @{}
$Script:configuration = 'Debug'
$Script:commonOutDir = ''

## Functions.

Function Project {
    Param(
        [string] $projectName,
        [string] $projectFile,

        [string] $OutDir = '',

        [switch] $Clean,
        [switch] $Build,
        [switch] $UpdateBuildNumber,
        [switch] $ProjectFilePath,
        [switch] $ProjectDirPath
    )

    If ($projectName -and $projectFile) {
        $Script:projects[$projectName] = @($projectFile, $outDir)
    }
    ElseIf ($Script:projects.ContainsKey($projectName)) {
        $projectFile = $Script:projects[$projectName][0]
        $outDir = $Script:projects[$projectName][1]
        If ($Clean) {
            Write-Host "Cleaning project $projectName" -ForegroundColor Magenta
            msbuild $projectFile /t:Clean ("/p:Configuration=$Script:configuration") /v:quiet | Out-Null
        }
        ElseIf ($Build) {
            Write-Host "Building project $projectName" -ForegroundColor Magenta

            If ($outDir -ne '') {
                msbuild $projectFile /t:Build ("/p:Configuration=$Script:configuration") /v:quiet ("/p:OutDir=$outDir") | Out-Null
            } 
            Else {
                msbuild $projectFile /t:Build ("/p:Configuration=$Script:configuration") /v:quiet | Out-Null
            }

            If ($LASTEXITCODE -ne 0) {
                Write-Host "Build failed for project $projectName" -ForegroundColor Red
            }
            Else {
                Write-Host "Build succeded for project $projectName" -ForegroundColor Green
            }
        }
        ElseIf ($UpdateBuildNumber) {
            $dir = Resolve-Path(Split-Path $projectFile)
            $aiFile = Join-Path $dir Properties\AssemblyInfo.cs

            If (Test-Path $aiFile) {
                Write-Host "Updating build number for project $projectName" -ForegroundColor Magenta
                $assemblyInfo = [IO.File]::ReadAllText($aiFile)

                If ($assemblyInfo -cmatch 'AssemblyVersion\("(\d+)\.(\d+)\.(\d+)\.(\d+)"\)\]') {
                    $newBuildNumber = ($Matches[4] -as [int]) + 1
                    Write-Host "Project $projectName build number now is $newBuildNumber" -ForegroundColor Magenta
                    $assemblyInfo = $assemblyInfo -creplace 'AssemblyVersion\("(\d+)\.(\d+)\.(\d+)\.(\d+)"\)\]', ('AssemblyVersion("{0}.{1}.{2}.{3}")]' -f $matches[1], $matches[2], $matches[3], $newBuildNumber)
                    $assemblyInfo > $aiFile
                }
            }
        }
        ElseIf ($ProjectFilePath) {
            Return (Resolve-Path $projectFile)
        }
        ElseIf ($ProjectDirPath) {
            Return Resolve-Path(Split-Path $projectFile)
        }
    }
}

Function Set-ProjectConfiguration {
    Param(
    [string] $config
    )

    $Script:configuration = $config
}
