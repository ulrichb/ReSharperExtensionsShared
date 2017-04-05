<Query Kind="Program">
  <Reference>&lt;RuntimeDirectory&gt;\System.IO.Compression.FileSystem.dll</Reference>
  <Reference>&lt;RuntimeDirectory&gt;\System.Net.Http.dll</Reference>
  <Reference>&lt;RuntimeDirectory&gt;\System.IO.Compression.dll</Reference>
  <NuGetReference>Newtonsoft.Json</NuGetReference>
  <NuGetReference>NuGet.Versioning</NuGetReference>
  <Namespace>Newtonsoft.Json.Linq</Namespace>
  <Namespace>NuGet.Versioning</Namespace>
  <Namespace>System.IO.Compression</Namespace>
  <Namespace>System.Net.Http</Namespace>
  <Namespace>System.Threading.Tasks</Namespace>
</Query>

async Task Main(string workingDirectory = @"", string testSolutionPath = @"")
{
    var scriptDir = Path.GetDirectoryName(Util.CurrentQueryPath);
    var solutionDir = Path.Combine(scriptDir, "..");
    var outputDir = Path.Combine(solutionDir, "Build", "Output");
    var commandLineToolsPackageId = "JetBrains.ReSharper.CommandLineTools";
    var inspectCodeCachePath = "RSAT_InspectCodeCache";

    Environment.CurrentDirectory = workingDirectory;

    var latestBuiltNugetPackagePath = Directory.EnumerateFiles(outputDir, "*.nupkg").OrderByDescending(x => x).First();
    Console.WriteLine($"Package to test: {latestBuiltNugetPackagePath}");

    var latestBuiltNugetPackagePathMatch = Regex.Match(latestBuiltNugetPackagePath, @"\.(\d{4})(\d)");

    var inspectCodeDirectory = await InstallCommandLineToolsPackage(
        commandLineToolsPackageId,
        from: NuGetVersion.Parse(latestBuiltNugetPackagePathMatch.Groups[1].Value + "." + latestBuiltNugetPackagePathMatch.Groups[2].Value),
        toExclusive: NuGetVersion.Parse(latestBuiltNugetPackagePathMatch.Groups[1].Value + "." + (int.Parse(latestBuiltNugetPackagePathMatch.Groups[2].Value) + 1)));

    ExecuteInspectCode(inspectCodeDirectory, testSolutionPath, inspectCodeCachePath, resultFilePostFix: "_WoExt");
    ExecuteInspectCode(inspectCodeDirectory, testSolutionPath, inspectCodeCachePath, latestBuiltNugetPackagePath, resultFilePostFix: "_WExt");

    //PerformanceTest(inspectCodeDirectory, latestBuiltNugetPackagePath, testSolutionPath, inspectCodeCachePath);
}

void PerformanceTest(string inspectCodeDirectory, string latestBuiltNugetPackagePath, string testSolutionPath, string inspectCodeCachePath)
{
    var numberOfPerformanceRuns = 6;

    string cachePath = inspectCodeCachePath;

    for (int i = 1; i <= (numberOfPerformanceRuns / 2); i++)
        $"Run #{i} (no cache, no ext): {ExecuteInspectCode(inspectCodeDirectory, testSolutionPath, cachePath, resultFilePostFix: $"_{i}")}".Dump();

    for (int i = (numberOfPerformanceRuns / 2) + 1; i <= numberOfPerformanceRuns; i++)
        $"Run #{i} (cache, no ext): {ExecuteInspectCode(inspectCodeDirectory, testSolutionPath, cachePath, resultFilePostFix: $"_{i}", cleanCache: false)}".Dump();

    //

    for (int i = 1; i <= (numberOfPerformanceRuns / 2); i++)
        $"Run #{i} (no cache, ext): {ExecuteInspectCode(inspectCodeDirectory, testSolutionPath, cachePath, latestBuiltNugetPackagePath, $"_ext_{i}")}".Dump();

    for (int i = (numberOfPerformanceRuns / 2) + 1; i <= numberOfPerformanceRuns; i++)
        $"Run #{i} (cache, ext): {ExecuteInspectCode(inspectCodeDirectory, testSolutionPath, cachePath, latestBuiltNugetPackagePath, $"_ext_{i}", cleanCache: false)}".Dump();
}

TimeSpan ExecuteInspectCode(string inspectCodeDirectory, string solutionPath, string cachePath, string extensionPackage = null, string resultFilePostFix = null, bool cleanCache = true)
{
    Func<TimeSpan> execute = () =>
    {
        if (cleanCache && Directory.Exists(cachePath))
            Directory.Delete(cachePath, true);

        var sw = Stopwatch.StartNew();

        var inspectCodeExePath = Path.Combine(inspectCodeDirectory, "InspectCode.exe");
        var inspectCodeArgs = $"--caches-home:\"{cachePath}\" -o:Inspections{resultFilePostFix}.xml \"{solutionPath}\"";

        //Util.Cmd(inspectCodeExePath, inspectCodeArgs, quiet: true);
        Util.Cmd("CMD.exe", $"/C START {inspectCodeExePath} {inspectCodeArgs}");

        return sw.Elapsed;
    };

    if (extensionPackage != null)
        return UseFileWithinTarget(extensionPackage, inspectCodeDirectory, execute);
    else
        return execute();
}

static async Task<string> InstallCommandLineToolsPackage(string packageId, NuGetVersion from, NuGetVersion toExclusive)
{
    using (var httpClient = new HttpClient())
    {
        NuGetVersion packageVersion;

        using (var versionResponse = await httpClient.GetAsync($"https://api.nuget.org/v3-flatcontainer/{packageId}/index.json"))
        {
            var resultJson = JObject.Parse(await versionResponse.EnsureSuccessStatusCode().Content.ReadAsStringAsync());

            var packageVersions = resultJson["versions"].Select(x => NuGetVersion.Parse((string)x)).OrderByDescending(x => x);
            var filteredPackageVersions = packageVersions.Where(v => from <= v && v < toExclusive);
            packageVersion = filteredPackageVersions.First();
        }

        var targetPath = $"RSAT_{packageVersion}";

        if (Directory.Exists(targetPath))
        {
            Console.WriteLine($"'{targetPath}' is already present.");
        }
        else
        {

            var packageDownloadUrl = $"https://api.nuget.org/v3-flatcontainer/{packageId}/{packageVersion}/{packageId}.{packageVersion}.nupkg";
            Console.WriteLine($"Requesting '{packageDownloadUrl}' ...");

            using (var downlaodResponse = await httpClient.GetAsync(packageDownloadUrl))
            {
                using (var contentStream = await downlaodResponse.EnsureSuccessStatusCode().Content.ReadAsStreamAsync())
                using (var zipArchive = new ZipArchive(contentStream))
                {
                    zipArchive.ExtractToDirectory(targetPath);
                }
            }
        }

        return Path.Combine(targetPath, "tools");
    }
}

T UseFileWithinTarget<T>(string sourcePath, string targetDirectory, Func<T> func)
{
    var packageNextToInspectCodePath = Path.Combine(targetDirectory, Path.GetFileName(sourcePath));
    File.Copy(sourcePath, packageNextToInspectCodePath);
    try
    {
        return func();
    }
    finally
    {
        File.Delete(packageNextToInspectCodePath);
    }
}