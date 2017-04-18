using JetBrains.Application.BuildScript.Application.Zones;
using JetBrains.ReSharper.Psi.CSharp;
using JetBrains.ReSharper.TestFramework;
using JetBrains.TestFramework;
using JetBrains.TestFramework.Application.Zones;
using NUnit.Framework;

[assembly: RequiresSTA]

namespace ReSharperExtensionsShared.Tests
{
    [ZoneDefinition]
    public interface ITestEnvironmentZone : ITestsZone, IRequire<PsiFeatureTestZone>
    {
    }

    [ZoneMarker]
    public class ZoneMarker : IRequire<ILanguageCSharpZone>, IRequire<ITestEnvironmentZone>
    {
    }

    [SetUpFixture]
    public class TestEnvironmentSetUpFixture : ExtensionTestEnvironmentAssembly<ITestEnvironmentZone>
    {
    }
}
