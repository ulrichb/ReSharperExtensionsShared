function Clean {
    New-Item $BuildOutputPath -Type Directory -Force | Out-Null
    Remove-Item $BuildOutputPath\* -Recurse -Force
    if (Test-Path variable:global:RiderPluginProject) {
        if (Test-Path "$RiderPluginProject\build\distributions\") { Remove-Item "$RiderPluginProject\build\distributions\" -Recurse -Force }
    }
}

function PackageRestore {
    Write-Host ".NET SDK Version: " -NoNewLine
    Exec { & dotnet --version }

    Write-Host "Restoring packages ..."
    Exec { & dotnet restore $SolutionFilePath -f --no-cache }
    Exec { & dotnet list (Resolve-Path $SolutionFilePath) package } # Absolute path to workaround https://github.com/NuGet/Home/issues/12954
}

function Build {
    $versionParameters = "AssemblyVersion=$Version;FileVersion=$Version;InformationalVersion=$(GetFullVersion)"

    $buildProperties = "TreatWarningsAsErrors=True;$versionParameters"

    Write-Host "Running build for solution ..."
    Exec { & dotnet build $SolutionFilePath --no-restore --no-incremental -c $Configuration "-p:$buildProperties" }
}

function Test {
    Write-Host "Running tests ..."

    $testResultsPath = Join-Path $BuildOutputPath "TestResults"

    try {
        WrapGitHubStepSummaryInDetailsBlock "Test Results" {
            Exec {
                & dotnet test $SolutionFilePath `
                    --no-build -c $Configuration -m:1 -r $testResultsPath `
                    --collect:"XPlat Code Coverage" --logger GitHubActions
            }
        }
    } finally {
        if (Test-Path "$env:TEMP/JetLogs") {
            Copy-Item "$env:TEMP/JetLogs" "$testResultsPath/JetLogs" -Recurse
        }
    }

    $reportGeneratorExePath = Join-Path (GetSolutionPackagePath "ReportGenerator") tools\net47\ReportGenerator.exe
    $coverageReportPath = Join-Path $BuildOutputPath "TestCoverage"
    $reportTypes = "HTML;MarkdownSummary;Badges"
    Exec { & $reportGeneratorExePath -reports:"$testResultsPath\*\*.xml" -reporttypes:$reportTypes -targetdir:$coverageReportPath -verbosity:Info }

    WrapGitHubStepSummaryInDetailsBlock "Test Coverage" {
        AppendToGitHubStepSummary (Get-Content (Join-Path $coverageReportPath "Summary.md"))
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

function GetFullVersion() {
    if (-not $BranchName) { return "$Version-local" }
    if ($BranchName -eq "master") { return "$Version" } else { return "$Version-pre" }
}

function NugetPack {
    Write-Host "Creating NuGet packages ..."

    $PackageReleaseNotes = EscapeMSBuildProperty ([System.Net.WebUtility]::HtmlEncode((GetReleaseNotesText)))

    $NugetPackProjects |% {
        Exec { & dotnet pack $_ --no-build -c $Configuration -o $BuildOutputPath -p:Version=$(GetFullVersion) -p:PackageReleaseNotes=$PackageReleaseNotes }
    }
}

function EscapeMSBuildProperty([string] $TextToEscape) {
    return $TextToEscape -replace '%','%25' -replace ';','%3B'
}

function BuildRiderPlugin {
    Exec { & "$RiderPluginProject\gradlew" --no-daemon -p $RiderPluginProject "buildPlugin" "-Pversion=$(GetFullVersion)" "-Pconfiguration=$Configuration" }
    Copy-Item "$RiderPluginProject\build\distributions\*.zip" $BuildOutputPath
}

function GetReleaseNotesText {
    $releaseNotesText = [System.IO.File]::ReadAllText("History.md")
    $releaseNotesText = ([Regex]::Matches($releaseNotesText, '(?s)(###.+?###.+?)(?=###|$)').Captures | Select -First 10) -Join ''
    $releaseNotesText = [Regex]::Replace($releaseNotesText, "\r?\n", "<br/>`n")
    return $releaseNotesText
}

function NugetPush {
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

function AppendToGitHubStepSummary([object[]]$ContentToAppend) {
    $private:githubStepSummaryFile = $env:GITHUB_STEP_SUMMARY
    if ($private:githubStepSummaryFile) {
        Add-Content $private:githubStepSummaryFile $ContentToAppend
    }
}

function WrapGitHubStepSummaryInDetailsBlock([string] $DetailsSummary, [scriptblock] $Action) {
    AppendToGitHubStepSummary "<details><summary>$DetailsSummary</summary>"
    AppendToGitHubStepSummary ""
    try {
        & $Action
    } finally {
        AppendToGitHubStepSummary "</details>`n"
    }
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
