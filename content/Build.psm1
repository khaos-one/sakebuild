Import-Module $PSScriptRoot/psake/psake.psm1

## Module variables.

$Script:projects = @{}
$Script:configuration = 'Debug'
$Script:commonOutDir = ''

$Script:pathes = @{}
$Script:pathes['vstest'] = 'C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\CommonExtensions\Microsoft\TestWindow\vstest.console.exe'

## Functions.

Function IIf($If, $IfTrue, $IfFalse) {
    If ($If) {If ($IfTrue -is "ScriptBlock") {&$IfTrue} Else {$IfTrue}}
    Else {If ($IfFalse) {If ($IfFalse -is "ScriptBlock") {&$IfFalse} Else {$IfFalse}}}
}

Function Project {
    Param(
        [string] $projectName,
        [string] $projectFile,

        [string] $OutDir = '',

        [switch] $Clean,
        [switch] $Build,
        [switch] $UpdateBuildNumber,
        [switch] $ProjectFilePath,
        [switch] $ProjectDirectory,
        [switch] $DisableDebugInfo,
        [switch] $DisableXmlDocs,
        [switch] $PureBuild
        #[switch] $Test
    )

    If ($projectName -and $projectFile) {
        $Script:projects[$projectName] = @($projectFile, $outDir)
    }
    ElseIf ($Script:projects.ContainsKey($projectName)) {
        $projectFile = $Script:projects[$projectName][0]
        $outDir = $Script:projects[$projectName][1]

        If (!$outDir) {
            $outDir = $Script:commonOutDir
        }
        
        If ($outDir) {
            $outDir = Resolve-Path $outDir
        }

        If ($PureBuild) {
            $DisableDebugInfo = $true
            $DisableXmlDocs = $true
        }

        If ($Clean) {
            Write-Host "Cleaning project $projectName" -ForegroundColor Magenta
            Exec { msbuild $projectFile /t:Clean ("/p:Configuration=$Script:configuration") /v:quiet | Out-Null }
            
            If ($outDir) {
                If (Test-Path $outDir) {
                    Remove-Item $outDir\* -Recurse -Force | Out-Null
                }
                Else {
                    New-Item -Path $outDir -ItemType Directory -Force
                }
            }

            Write-Host "Project $projectName cleaned out." -ForegroundColor Green
        }
        ElseIf ($Build) {
            Write-Host "Building project $projectName" -ForegroundColor Magenta

            Exec { msbuild $projectFile /t:Build /v:quiet ("/p:Configuration=$Script:configuration") (IIf $outDir "/p:OutDir=$outDir") (IIf $DisableDebugInfo ("/p:DebugSymbols=false", "/p:DebugType=none")) (IIf $DisableXmlDocs "/p:AllowedReferenceRelatedFileExtensions=none") | Out-Null }

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
        ElseIf ($ProjectDirectory) {
            Return Resolve-Path(Split-Path $projectFile)
        }
    }
}

Function ProjectConfiguration {
    Param(
        [string] $config
    )

    $Script:configuration = $config
}

Function Get-ProjectConfiguration {
    Return $Script:configuration
}

Function CommonOutputDir {
    Param(
        [string] $outputDir
    )

    $Script:commonOutDir = $outputDir
}

Function VsTest {
    Exec { &$Script:pathes['vstest'] $args }
}
