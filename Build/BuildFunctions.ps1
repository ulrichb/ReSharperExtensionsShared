function Clean() {
    New-Item $BuildOutputPath -Type Directory -Force | Out-Null
    Remove-Item $BuildOutputPath\* -Recurse -Force
}

function PackageRestore() {
    Write-Host "Restoring packages ..."
    Exec { & $NugetExecutable restore $SolutionFilePath }
    Exec { & $MSBuildPath $SolutionFilePath /v:m /maxcpucount /t:Restore }
}

function Build() {
    Write-Host "Updating version to '$Version' in '$AssemblyVersionFilePath' ..."
    $versionWithoutPostfix = $Version -Replace "-\w+$",""
    $assemblyVersionFileText = [System.IO.File]::ReadAllText($AssemblyVersionFilePath)
    $savedAssemblyVersionFileText = $assemblyVersionFileText
    $assemblyVersionFileText = _ReplaceVersionAtributeValue $assemblyVersionFileText "AssemblyVersion" $versionWithoutPostfix
    $assemblyVersionFileText = _ReplaceVersionAtributeValue $assemblyVersionFileText "AssemblyFileVersion" $versionWithoutPostfix
    $assemblyVersionFileText = _ReplaceVersionAtributeValue $assemblyVersionFileText "AssemblyInformationalVersion" $Version
    [System.IO.File]::WriteAllText($AssemblyVersionFilePath, $assemblyVersionFileText)

    try {
        Write-Host "Running MSBuild for solution ..."
        Exec { & $MSBuildPath $SolutionFilePath /v:m /maxcpucount /t:Build "/p:Configuration=$Configuration;TreatWarningsAsErrors=True" }

    } finally {
        [System.IO.File]::WriteAllText($AssemblyVersionFilePath, $savedAssemblyVersionFileText)
    }
}

function _ReplaceVersionAtributeValue($fileText, $attributeIdentifier, $value) {
    Write-Host "Replacing '$attributeIdentifier' attribute value with '$value' ..."
    return $fileText -Replace "(\[assembly:\s*$attributeIdentifier\s*)\([^)]+\)","`${1}(`"$value`")"
}

function Test() {
    Write-Host "Running tests ..."
    $nunitExePath = Join-Path (GetSolutionPackagePath "NUnit.ConsoleRunner") tools\nunit3-console.exe
    $testResultsPath = Join-Path $BuildOutputPath "TestResult.xml"

    $nunitArgs = "$NUnitTestAssemblyPaths --result=$testResultsPath $NUnitAdditionalArgs"

    $openCoverExePath = Join-Path (GetSolutionPackagePath "OpenCover") tools\OpenCover.Console.exe
    $coverageResultsPath = Join-Path $BuildOutputPath "TestCoverage.xml"

    Exec { 
        & $openCoverExePath -target:$nunitExePath "-targetargs:$nunitArgs" "-filter:$TestCoverageFilter" "-excludebyattribute:*.ExcludeFromCodeCoverage*" -returntargetcode -register:user -output:$coverageResultsPath

        if ($env:APPVEYOR) { 
            Write-Host "Publishing NUnit results '$testResultsPath' ..."
            $webClient = New-Object System.Net.WebClient
            $webClient.UploadFile("https://ci.appveyor.com/api/testresults/nunit3/$($env:APPVEYOR_JOB_ID)", $testResultsPath)
        }
    }

    $reportGeneratorExePath = Join-Path (GetSolutionPackagePath "ReportGenerator") tools\ReportGenerator.exe
    $coverageReportPath = Join-Path $BuildOutputPath "TestCoverage"
    $reportTypes = "HTML;MHTML;Badges"
    Exec { & $reportGeneratorExePath -reports:$coverageResultsPath -reporttypes:$reportTypes -targetdir:$coverageReportPath -verbosity:Info }

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
    return $Version -Replace "^(\d+\.\d+\.\d+\.\d+)","`${1}$reSharperVersionInNuGetVersion"
}

function NugetPack() {
    Write-Host "Injecting release notes text into .nuspec ..."

    $releaseNotesText = [System.IO.File]::ReadAllText("History.md")
    $releaseNotesText = ([Regex]::Matches($releaseNotesText, '(?s)(###.+?###.+?)(?=###|$)').Captures | Select -First 10) -Join ''

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
    [xml] $xml = Get-Content "SolutionItems.csproj"
    $version = $xml.SelectNodes("/Project/ItemGroup/PackageReference[@Include = '$packageId']/@Version") | Select -ExpandProperty Value
    return [System.IO.Path]::Combine(${env:USERPROFILE}, ".nuget", "packages", "$packageId", "$version")
}

function Exec([scriptblock] $cmd) {
    & $cmd
    if ($LastExitCode -ne 0) {
        throw "The following call failed with exit code $LastExitCode. '$cmd'"
    }
}
