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
    $assemblyVersionFileContent = [System.IO.File]::ReadAllText($AssemblyVersionFilePath)
    $newContent = ($assemblyVersionFileContent -Replace "(Assembly(?:File)?Version)\s*\(\s*`"[^`"]+`"\s*\)","`$1(`"$Version`")")
    [System.IO.File]::WriteAllText($AssemblyVersionFilePath, $newContent)

    try {
        Write-Host "Running MSBuild for solution ..."
        Exec { & $MSBuildPath $SolutionFilePath /v:m /maxcpucount /t:Build "/p:Configuration=$Configuration;TreatWarningsAsErrors=True" }

    } finally {
        [System.IO.File]::WriteAllText($AssemblyVersionFilePath, $assemblyVersionFileContent)
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
    Write-Host "Creating NuGet packages ..."

    $releaseNotes = "<![CDATA[" + [System.IO.File]::ReadAllText("History.md") + "]]>"

    $NugetPackProperties | % {
        Exec { & $NugetExecutable pack $NuspecPath -Properties $_ -Properties ReleaseNotes=$releaseNotes -OutputDirectory $BuildOutputPath -NoPackageAnalysis }
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
