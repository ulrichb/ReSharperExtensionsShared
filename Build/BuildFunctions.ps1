function Clean() {
    New-Item $BuildOutputPath -Type Directory -Force | Out-Null
    Remove-Item $BuildOutputPath\* -Recurse -Force
    if (Test-Path variable:global:RiderPluginProject) {
        if (Test-Path "$RiderPluginProject\build\distributions\") { Remove-Item "$RiderPluginProject\build\distributions\" -Recurse -Force }
    }
}

function PackageRestore() {
    Write-Host "Restoring packages ..."
    Exec { & dotnet restore $SolutionFilePath -f --no-cache }
    Exec { & dotnet list $SolutionFilePath package }
}

function Build() {
    Write-Host "Full version: '$(GetFullVersion)'"

    $versionParameters = "AssemblyVersion=$Version;FileVersion=$Version;InformationalVersion=$(GetFullVersion)"

    $buildProperties = "TreatWarningsAsErrors=True;$versionParameters"

    Write-Host "Running build for solution ..."
    Exec { & dotnet build $SolutionFilePath --no-restore --no-incremental -c $Configuration "-p:$buildProperties" }
}

function Test() {
    Write-Host "Running tests ..."

    $testResultsPath = Join-Path $BuildOutputPath "TestResults"

    Exec { & dotnet test $SolutionFilePath --no-build -c $Configuration -m:1 -r $testResultsPath --collect:"XPlat Code Coverage" --logger GitHubActions }

    $reportGeneratorExePath = Join-Path (GetSolutionPackagePath "ReportGenerator") tools\net47\ReportGenerator.exe
    $coverageReportPath = Join-Path $BuildOutputPath "TestCoverage"
    $reportTypes = "HTML;MarkdownSummary;Badges"
    Exec { & $reportGeneratorExePath -reports:"$testResultsPath\*\*.xml" -reporttypes:$reportTypes -targetdir:$coverageReportPath -verbosity:Info }

    $githubStepSummaryFile = $env:GITHUB_STEP_SUMMARY
    if ($githubStepSummaryFile) {
        Write-Host "Adding coverage summary to step summary..."
        Add-Content $githubStepSummaryFile "`n`n"
        Add-Content $githubStepSummaryFile (Get-Content (Join-Path $coverageReportPath "Summary.md"))
    }

    if ($CoverageBadgeUploadToken) {
        Write-Host "Uploading coverage badges ..."

        $escapedBranchName = $BranchName -replace "\W","_"
        $badgeDirName = [System.IO.Path]::GetFileNameWithoutExtension($SolutionFilePath)

        UploadToDropbox $CoverageBadgeUploadToken (Join-Path $coverageReportPath "badge_linecoverage.svg")   "/$badgeDirName/$escapedBranchName-linecoverage.svg"
        UploadToDropbox $CoverageBadgeUploadToken (Join-Path $coverageReportPath "badge_branchcoverage.svg") "/$badgeDirName/$escapedBranchName-branchcoverage.svg"
    }
}

function UploadToDropbox([string] $authToken, [string] $localFilePath, [string] $dropboxFilePath) {
    Add-Type -AssemblyName "System.Net.Http"
    $httpClient = New-Object System.Net.Http.HttpClient
    $fileStream = [System.IO.File]::Open($localFilePath, [System.IO.FileMode]::Open)
    
    $content = New-Object System.Net.Http.StreamContent -ArgumentList $fileStream
    
    $httpClient.DefaultRequestHeaders.Authorization = `
        New-Object System.Net.Http.Headers.AuthenticationHeaderValue -ArgumentList "Bearer", $authToken
    
    $content.Headers.ContentType = New-Object System.Net.Http.Headers.MediaTypeHeaderValue -ArgumentList "application/octet-stream"
    $content.Headers.Add("Dropbox-API-Arg", "{ ""path"":""$dropboxFilePath"", ""mode"" : {"".tag"" : ""overwrite""} }")

    Write-Host "Uploading '$localFilePath' to '$dropboxFilePath' ..."
    $response = $httpClient.PostAsync("https://content.dropboxapi.com/2/files/upload", $content).Result
    [void] $response.EnsureSuccessStatusCode()
    
    $response.Dispose()
    $content.Dispose()
    $fileStream.Dispose()
    $httpClient.Dispose()
}

function CalcNuGetPackageVersion([string] $reSharperVersion) {
    $reSharperVersionInNuGetVersion = $reSharperVersion.Substring($reSharperVersion.Length - 4)
    return (GetFullVersion) -Replace "^(\d+\.\d+\.\d+\.\d+)","`${1}$reSharperVersionInNuGetVersion"
}

function GetFullVersion() {
    if (-not $BranchName) { return "$Version-local" }
    if ($BranchName -eq "master") { return "$Version" } else { return "$Version-pre" }
}

function NugetPack() {
    Write-Host "Injecting release notes text into .nuspec ..."

    $savedNuspecContent = [System.IO.File]::ReadAllText($NuspecPath)

    [xml] $nuspecXml = Get-Content $NuspecPath
    $nuspecXml.package.metadata.releaseNotes = GetReleaseNotesText
    $nuspecXml.Save($NuspecPath)

    Write-Host "Creating NuGet packages ..."

    try {
        $NugetPackProperties | % {
            Exec { & $NugetExecutable pack $NuspecPath -Properties $_ -OutputDirectory $BuildOutputPath -NoPackageAnalysis }
        }
    } finally {
        [System.IO.File]::WriteAllText($NuspecPath, $savedNuspecContent)
    }
}

function BuildRiderPlugin() {
    Exec { & "$RiderPluginProject\gradlew" --no-daemon -p $RiderPluginProject "buildPlugin" "-Pversion=$(GetFullVersion)" "-Pconfiguration=$Configuration" }
    Copy-Item "$RiderPluginProject\build\distributions\*.zip" $BuildOutputPath
}

function GetReleaseNotesText() {
    $releaseNotesText = [System.IO.File]::ReadAllText("History.md")
    $releaseNotesText = ([Regex]::Matches($releaseNotesText, '(?s)(###.+?###.+?)(?=###|$)').Captures | Select -First 10) -Join ''
    $releaseNotesText = [Regex]::Replace($releaseNotesText, "\r?\n", "<br/>`n")
    return $releaseNotesText
}

function NugetPush() {
    Write-Host "Pushing NuGet packages ..."
    Get-ChildItem (Join-Path $BuildOutputPath "*.nupkg") | % {
        Exec { & $NugetExecutable push $_ $NugetPushKey -Source $NugetPushServer }
    }
}

function GetSolutionPackagePath([string] $packageId) {
    [xml] $xml = Get-Content "SolutionItems.csproj"
    $version = $xml.SelectNodes("/Project/ItemGroup/PackageReference[@Include = '$packageId']/@Version") | Select -ExpandProperty Value
    return [System.IO.Path]::Combine(${env:USERPROFILE}, ".nuget", "packages", "$packageId", "$version")
}

function Exec {
    # Modified version of https://mnaoumov.wordpress.com/2015/01/11/execution-of-external-commands-in-powershell-done-right/

    param
    (
        [ScriptBlock] $ScriptBlock,
        [string] $StderrPrefix = "STDERR: ",
        [int[]] $AllowedExitCodes = @(0)
    )

    $backupErrorActionPreference = $script:ErrorActionPreference

    $script:ErrorActionPreference = "Continue"
    try {
        & $ScriptBlock 2>&1 | % { if ($_ -is [System.Management.Automation.ErrorRecord]) { "$StderrPrefix$_" } else { "$_" } }

        if ($AllowedExitCodes -notcontains $LASTEXITCODE) {
            throw "The following call failed with exit code $LastExitCode. '$ScriptBlock'"
        }
    }
    finally {
        $script:ErrorActionPreference = $backupErrorActionPreference
    }
}
