function Clean() {
    New-Item $BuildOutputPath -Type Directory -Force | Out-Null
    Remove-Item $BuildOutputPath\* -Recurse -Force
}

function PackageRestore() {
    Write-Host "Restoring packages ..."
    Exec { & $NugetExecutable restore $SolutionFilePath }
}

function Build() {
    Write-Host "Updating version to '$Version' in '$AssemblyVersionFilePath' ..."
    $assemblyVersionFileText = [System.IO.File]::ReadAllText($AssemblyVersionFilePath)
    $newContent = ($assemblyVersionFileText -Replace "(Assembly(?:File)?Version)\s*\(\s*`"[^`"]+`"\s*\)","`$1(`"$Version`")")
    [System.IO.File]::WriteAllText($AssemblyVersionFilePath, $newContent)

    try {
        Write-Host "Running MSBuild for solution ..."
        Exec { & $MSBuildPath $SolutionFilePath /v:m /maxcpucount /t:Build "/p:Configuration=$Configuration;TreatWarningsAsErrors=True" }

    } finally {
        [System.IO.File]::WriteAllText($AssemblyVersionFilePath, $assemblyVersionFileText)
    }
}

function Test() {
    Write-Host "Running tests ..."
    $nunitExePath = Join-Path (GetSolutionPackagePath "NUnit.Runners") tools\$NUnitExecutable
    if ($env:APPVEYOR) { $nunitExePath = $NUnitExecutable }

    $testResultsPath = Join-Path $BuildOutputPath "TestResult.xml"

    $nunitArgs = "$NUnitTestAssemblyPaths /nologo /noshadow /framework=$NUnitFrameworkVersion /domain=Multiple /labels /result=$testResultsPath"

    $openCoverExePath = Join-Path (GetSolutionPackagePath "OpenCover") tools\OpenCover.Console.exe
    $coverageResultsPath = Join-Path $BuildOutputPath "TestCoverage.xml"

    Exec { & $openCoverExePath -target:$nunitExePath "-targetargs:$nunitArgs" "-filter:$TestCoverageFilter" "-excludebyattribute:*.ExcludeFromCodeCoverage*" -returntargetcode -register:user -output:$coverageResultsPath }

    $reportGeneratorExePath = Join-Path (GetSolutionPackagePath "ReportGenerator") tools\ReportGenerator.exe
    $coverageReportPath = Join-Path $BuildOutputPath "TestCoverage"
    Exec { & $reportGeneratorExePath -reports:$coverageResultsPath -targetdir:$coverageReportPath -verbosity:Info }
}

function NugetPack() {
    Write-Host "Injecting release notes text into .nuspec ..."

    $releaseNotesText = [System.IO.File]::ReadAllText("History.md")
    $savedNuspecText = [System.IO.File]::ReadAllText($NuspecPath)

    [xml] $nuspecXml = Get-Content $NuspecPath
    $nuspecXml.package.metadata.releaseNotes = $releaseNotesText
    $nuspecXml.Save($NuspecPath)

    Write-Host "Creating NuGet packages ..."

    try {
        $NugetPackProperties | % {
            Exec { & $NugetExecutable pack $NuspecPath -Properties $_ -OutputDirectory $BuildOutputPath -NoPackageAnalysis }
        }
    } finally {
        [System.IO.File]::WriteAllText($NuspecPath, $savedNuspecText)
    }
}

function NugetPush() {
    Write-Host "Pushing NuGet packages ..."
    gci (Join-Path $BuildOutputPath "*.nupkg") | % {
        Exec { & $NugetExecutable push $_ $NugetPushKey -Source $NugetPushServer }
    }
}

function GetSolutionPackagePath([string] $packageId) {
    [xml] $xml = Get-Content "packages.config"
    $version = $xml.SelectNodes("/packages/package[@id = '$packageId']/@version") | Select -ExpandProperty Value
    return Join-Path "packages" "$packageId.$version"
}

function Exec([scriptblock] $cmd) {
    & $cmd
    if ($LastExitCode -ne 0) {
        throw "The following call failed with exit code $LastExitCode. '$cmd'"
    }
}

function StripLastPartFromVersion([string] $value) {
    return $value -replace "\.\d+$",""
}
