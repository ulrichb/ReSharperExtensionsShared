using System;
using System.Diagnostics;
using System.Linq;
using JetBrains.ProjectModel;
using JetBrains.ReSharper.Psi;
using JetBrains.ReSharper.Psi.CSharp.Tree;
using JetBrains.ReSharper.Psi.Tree;
using JetBrains.ReSharper.TestFramework;
using JetBrains.Util;
using NUnit.Framework;
using ReSharperExtensionsShared.Debugging;

namespace ReSharperExtensionsShared.Tests.Integrative
{
    [TestFixture]
    public class DebugUtilityTest : BaseTestWithSingleProject
    {
        protected override string RelativeTestDataPath => typeof(DebugUtilityTest).Name;

        [Test]
        public void FormatIncludingContext()
        {
            UsingClassInFile("SampleClass.cs", classElement =>
            {
                Assert.That(DebugUtility.FormatIncludingContext(classElement), Is.EqualTo("Class 'SampleClass' in NULL"));

                var field = classElement.Fields.Single();
                Assert.That(DebugUtility.FormatIncludingContext(field), Is.EqualTo("CSharpField '_field' in SomeNamespace.SampleClass"));

                var method = classElement.Methods.Single();
                Assert.That(DebugUtility.FormatIncludingContext(method), Is.EqualTo("CSharpMethod 'Method' in SomeNamespace.SampleClass"));

                var parameter = method.Parameters.Single();
                Assert.That(DebugUtility.FormatIncludingContext(parameter),
                    Is.EqualTo("CSharpRegularParameter 'param' in SomeNamespace.SampleClass.Method()"));
            });
        }

        [Test]
        public void FormatIncludingContext_WithGenericClass()
        {
            UsingClassInFile("GenericClass.cs", classElement =>
            {
                Assert.That(DebugUtility.FormatIncludingContext(classElement), Is.EqualTo("Class 'GenericClass' in NULL"));

                var typeParameter = classElement.TypeParameters.Single();
                Assert.That(DebugUtility.FormatIncludingContext(typeParameter),
                    Is.EqualTo("TypeParameter 'TParam' in SomeNamespace.GenericClass`1"));
            });
        }

        [Test]
        public void FormatIncludingContext_WithNullInput()
        {
            Assert.That(DebugUtility.FormatIncludingContext(null), Is.EqualTo("NULL"));
        }

        [Test]
        public void FormatWithElapsed()
        {
            Assert.That(DebugUtility.FormatWithElapsed("message", new Stopwatch()), Is.EqualTo("message took 0 usec"));
        }

        private void UsingClassInFile(string fileName, Action<IClass> action)
        {
            WithSingleProject(GetTestDataFilePath2(fileName).FullPath,
                (lifetime, solution, project) => RunGuarded(() =>
                {
                    var primaryPsiFile = project.GetAllProjectFiles().Single().GetPrimaryPsiFile().NotNull();

                    var classElement = (IClass) primaryPsiFile.ThisAndDescendants<IClassDeclaration>().Collect().Single().DeclaredElement.NotNull();

                    action(classElement);
                }));
        }
    }
}