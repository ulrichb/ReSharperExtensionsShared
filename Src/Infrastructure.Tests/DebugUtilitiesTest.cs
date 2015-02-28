using System;
using System.Linq;
using JetBrains.ProjectModel;
using JetBrains.ReSharper.Psi;
using JetBrains.ReSharper.Psi.CSharp.Tree;
using JetBrains.ReSharper.Psi.Tree;
using JetBrains.ReSharper.TestFramework;
using JetBrains.Util;
using NUnit.Framework;

namespace Infrastructure.Tests
{
    [TestFixture]
    public class DebugUtilitiesTest : BaseTestWithSingleProject
    {
        [Test]
        public void FormatIncludingContext()
        {
            UsingClassInFile("SampleClass.cs", classElement =>
            {
                Assert.That(DebugUtilities.FormatIncludingContext(classElement), Is.EqualTo("Class 'SampleClass' in NULL"));

                var field = classElement.Fields.Single();
                Assert.That(DebugUtilities.FormatIncludingContext(field), Is.EqualTo("CSharpField '_field' in SomeNamespace.SampleClass"));

                var method = classElement.Methods.Single();
                Assert.That(DebugUtilities.FormatIncludingContext(method), Is.EqualTo("CSharpMethod 'Method' in SomeNamespace.SampleClass"));

                var parameter = method.Parameters.Single();
                Assert.That(DebugUtilities.FormatIncludingContext(parameter),
                    Is.EqualTo("CSharpRegularParameter 'param' in SomeNamespace.SampleClass.Method()"));
            });
        }

        [Test]
        public void FormatIncludingContext_WithGenericClass()
        {
            UsingClassInFile("GenericClass.cs", classElement =>
            {
                Assert.That(DebugUtilities.FormatIncludingContext(classElement), Is.EqualTo("Class 'GenericClass' in NULL"));

                var typeParameter = classElement.TypeParameters.Single();
                Assert.That(DebugUtilities.FormatIncludingContext(typeParameter),
                    Is.EqualTo("TypeParameter 'TParam' in SomeNamespace.GenericClass`1"));
            });
        }

        [Test]
        public void FormatIncludingContext_WithNullInput()
        {
            Assert.That(DebugUtilities.FormatIncludingContext(null), Is.EqualTo("NULL"));
        }

        private void UsingClassInFile(string fileName, Action<IClass> action)
        {
            WithSingleProject(GetTestDataFilePath(fileName),
                (lifetime, solution, project) => RunGuarded(() =>
                {
                    var primaryPsiFile = project.GetAllProjectFiles().Single().GetPrimaryPsiFile().NotNull();

                    var classElement = (IClass)primaryPsiFile.EnumerateSubTree().OfType<IClassDeclaration>().Single().DeclaredElement.NotNull();

                    action(classElement);
                }));
        }
    }
}