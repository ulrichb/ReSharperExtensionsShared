function Clean() {
    New-Item $BuildOutputPath -Type Directory -Force | Out-Null
    Remove-Item $BuildOutputPath\* -Recurse -Force
}

function PackageRestore() {
    Write-Host "Restoring packages ..."
    Exec { & $NugetExecutable restore $SolutionFile }
}

function UpdateAssemblyVersion() {
    Write-Host "Updating assembly version in `"$AssemblyVersionFilePath`" ..."
    $assemblyVersionFileContent = [System.IO.File]::ReadAllText($AssemblyVersionFilePath)
    $newContent = ($assemblyVersionFileContent -Replace "(Assembly(?:File)?Version)\s*\(\s*`"[^`"]+`"\s*\)","`$1(`"$Version`")")
    [System.IO.File]::WriteAllText($AssemblyVersionFilePath, $newContent)
}

function Build() {
    Write-Host "Starting build ..."
    Exec { & $MSBuildPath $SolutionFile /v:m /t:Build "/p:Configuration=$Configuration" }
}

function Test() {
    Write-Host "Running tests ..."
    $nunitExePath = Join-Path (GetSolutionPackagePath "NUnit.Runners") tools\$NUnitExecutable
    if ($env:APPVEYOR) { $nunitExePath = $NUnitExecutable }

    $testResultsPath = Join-Path $BuildOutputPath "TestResult.xml"

    Exec { & $nunitExePath $NUnitTestAssemblyPaths /nologo /framework=$NUnitFrameworkVersion /domain=Multiple /result=$testResultsPath }
}

function NugetPack() {
    Write-Host "Creating NuGet packages ..."
    $NugetPackProperties | % {
        Exec { & $NugetExecutable pack $NuspecPath -Version $Version -Properties $_ -OutputDirectory $BuildOutputPath -NoPackageAnalysis }
    }
}

function NugetPush() {
    Write-Host "Pushing NuGet packages ..."
    gci (Join-Path $BuildOutputPath "*.nupkg") | % {
        Exec { & $NugetExecutable push $_ $NugetPushKey -Source $NugetPushServer }
    }
}

function GetSolutionPackagePath([string] $packageId) {
    [xml] $xml = Get-Content (Join-Path ".nuget" "packages.config")
    $version = $xml.SelectNodes("/packages/package[@id = '$packageId']/@version") | Select -ExpandProperty Value
    return Join-Path "packages" "$packageId.$version"
}

function Exec([scriptblock] $cmd) {
    & $cmd
    if ($LastExitCode -ne 0) {
        throw "The following call failed with exit code $LastExitCode. '$cmd'"
    }
}
