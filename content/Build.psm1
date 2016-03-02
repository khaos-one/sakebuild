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

Function CallerInfo {
    Param(
        [switch] $File,
        [switch] $Path
    )

    $cs = Get-PSCallStack
    Write-Host $cs -ForegroundColor Blue

    If ($File) {
        Return $cs[2].ScriptName
    }
    ElseIf ($Path) {
        Return (Split-Path $cs[2].ScriptName)
    }
}

Function Get-FilePathInSomeCallerDir {
    Param(
        [string] $fileName
    )

    $callers = Get-PSCallStack

    ForEach ($caller in $callers) {
        $dir = $caller.ScriptName

        If ($dir -eq $null) {
            Continue
        }

        $dir = Split-Path $dir
        $filePath = Join-Path $dir $fileName

        #Write-Host $filePath -ForegroundColor Blue

        If (Test-Path $filePath) {
            Return $filePath
        }
    }

    $filePath = (Join-Path (Get-Location) $fileName)
    
    If (Test-Path $filePath) {
        Return $filePath
    }

    Return (Join-Path .. $fileName)
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

            Exec { 
                msbuild $projectFile /t:Build /v:quiet ("/p:Configuration=$Script:configuration") (IIf $outDir "/p:OutDir=$outDir") (IIf $DisableDebugInfo ("/p:DebugSymbols=false", "/p:DebugType=none")) (IIf $DisableXmlDocs "/p:AllowedReferenceRelatedFileExtensions=none") | Out-Null
            }

            If ($LASTEXITCODE -ne 0) {
                Write-Error "Build failed for project $projectName"
            }
            Else {
                Write-Host "Build succeded for project $projectName" -ForegroundColor Green
            }
        }
        ElseIf ($UpdateBuildNumber) {
            $dir = Project $projectName -ProjectDirectory
            $aiFile = Join-Path $dir Properties\AssemblyInfo.cs
            $aiFile = IIf (Test-Path $aiFile) { $aiFile } { Join-Path $dir Src\Properties\AssemblyInfo.cs }

            If (Test-Path $aiFile) {
                Write-Host "Updating build number for project $projectName" -ForegroundColor Magenta
                $assemblyInfo = [IO.File]::ReadAllText($aiFile)

                If ($assemblyInfo -cmatch 'AssemblyVersion\("(\d+)\.(\d+)\.(\d+)\.(\d+)"\)\]') {
                    $newBuildNumber = ($Matches[4] -as [int]) + 1
                    Write-Host "Project $projectName build number now is $newBuildNumber" -ForegroundColor Magenta
                    $assemblyInfo = $assemblyInfo -creplace 'AssemblyVersion\("(\d+)\.(\d+)\.(\d+)\.(\d+)"\)\]', ('AssemblyVersion("{0}.{1}.{2}.{3}")]' -f $matches[1], $matches[2], $matches[3], $newBuildNumber)
                    $assemblyInfo = $assemblyInfo.TrimEnd(" `r`n`t")
                    $assemblyInfo > $aiFile
                }
            }
        }
        ElseIf ($ProjectFilePath) {
            Return (Resolve-Path $projectFile)
        }
        ElseIf ($ProjectDirectory) {
            Return Split-Path (Project $projectName -ProjectFilePath)
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

Function Build-ProtoBufTypeModel {
    Param(
        $typeSpec,
        $typeName,
        $OutputDirectory = ''
    )

    Write-Host "Compiling ProtoBuf type model" -ForegroundColor Magenta

    # This hackery needs to be done because protobuf's `Compile` does not accept pathes.
    #$invocationPath = CallerInfo -Path
    
    $tdest = IIf $OutputDirectory { Join-Path $OutputDirectory "$typeName.dll" } "$typeName.dll"
    IIf (Test-Path $tdest) { Remove-Item $tdest -Force }

    $tm = [ProtoBuf.Meta.TypeModel]::Create()

    For ($i = 0; $i -lt $typeSpec.Length; $i++) {
        if ($typeSpec[$i] -is [hashtable]) {
            $a = $tm.Add($typeSpec[$i].type, $true);

            if ($typeSpec[$i].ContainsKey('include') -and $typeSpec[$i].include -ne $null) {
                for ($j = 1; $j -lt $typeSpec[$i].include.Length; $j++) {
                    $a.AddSubType($typeSpec[$i].include[$j].offset, $typeSpec[$i].include[$j].type) | Out-Null
                }
            }

            if ($typeSpec[$i].ContainsKey('surrogate') -and $typeSpec[$i].surrogate -ne $null) {
                $a.SetSurrogate($typeSpec[$i].surrogate) | Out-Null
            }
        }
        else {
            $tm.Add($typeSpec[$i], $true) | Out-Null
        }

        # If ($typeSpec[$i] -is [array]) {
        #     $a = $tm.Add($typeSpec[$i][0], $true)
        #     For ($j = 1; $j -lt $typeSpec[$i].Length; $j++) {
        #         $a.AddSubType($typeSpec[$i][$j][0], $typeSpec[$i][$j][1]) | Out-Null
        #     }
        # }
        # Else {
        #     $tm.Add($typeSpec[$i], $true) | Out-Null
        # }
    }

    $tm.Compile($typeName, "$typeName.dll") | Out-Null

    $tsource = Get-FilePathInSomeCallerDir "$typeName.dll"
    #Write-Host $tsource -ForegroundColor Blue
    #IIf (Test-Path $tsource) { Remove-Item $tsource -Force }

    Move-Item $tsource $tdest -Force
    Write-Host "Type model compiled" -ForegroundColor Green
}


Export-ModuleMember -Function IIf, CallerInfo, Project, ProjectConfiguration, Get-ProjectConfiguration, CommonOutputDir, VsTest, Build-ProtoBufTypeModel
