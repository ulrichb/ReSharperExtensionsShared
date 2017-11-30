using System;
using System.Diagnostics.CodeAnalysis;
using System.Linq;
using FakeItEasy;
using JetBrains.ProjectModel;
using JetBrains.ReSharper.Psi;
using JetBrains.ReSharper.Psi.Tree;
using JetBrains.ReSharper.TestFramework;
using JetBrains.Util;
using NUnit.Framework;
using ReSharperExtensionsShared.Highlighting;
using ReSharperExtensionsShared.QuickFixes;

namespace ReSharperExtensionsShared.Tests.QuickFixes
{
    [TestFixture]
    [TestNetFramework4]
    public class SimpleQuickFixBaseTest : BaseTestWithSingleProject
    {
        [Test]
        public void IsAvailable()
        {
            Test(sut =>
            {
                var userDataHolder = A.Fake<IUserDataHolder>();

                var result = sut.IsAvailable(userDataHolder);

                Assert.That(result, Is.EqualTo(true));
                A.CallTo(sut).Where(x => x.Method.Name == "IsAvailableForTreeNode")
                    .WhenArgumentsMatch((IUserDataHolder x) => ReferenceEquals(x, userDataHolder)).MustHaveHappened();
            });
        }

        [Test]
        public void IsAvailable_WithInvalidTreeNode()
        {
            Test(
                useNullTreeNode: true,
                action: sut =>
                {
                    var result = sut.IsAvailable(A.Fake<IUserDataHolder>());

                    Assert.That(result, Is.EqualTo(false));
                });
        }

        [Test]
        public void IsAvailable_WithIsAvailableForTreeNodeReturnsFalse()
        {
            Test(sut =>
            {
                A.CallTo(sut).Where(x => x.Method.Name == "IsAvailableForTreeNode").WithReturnType<bool>().Returns(false);

                var result = sut.IsAvailable(A.Fake<IUserDataHolder>());

                Assert.That(result, Is.EqualTo(false));
            });
        }

        private void Test(Action<SimpleQuickFixBase<TestHighlighting, ITreeNode>> action, bool useNullTreeNode = false)
        {
            WithSingleProject(
                GetTestDataFilePath2("SampleClass.cs").FullPath,
                (lifetime, solution, project) => RunGuarded(() =>
                {
                    var primaryPsiFile = project.GetAllProjectFiles().Single().GetPrimaryPsiFile().NotNull();

                    var highlighting = new TestHighlighting(useNullTreeNode ? null : primaryPsiFile);

                    var sut = A.Fake<SimpleQuickFixBase<TestHighlighting, ITreeNode>>(
                        o => o.WithArgumentsForConstructor(new[] { highlighting }).CallsBaseMethods());

                    A.CallTo(sut).Where(x => x.Method.Name == "IsAvailableForTreeNode").WithReturnType<bool>().Returns(true);

                    action(sut);
                }));
        }

        [SuppressMessage("ReSharper", "MemberCanBePrivate.Global")]
        public class TestHighlighting : SimpleTreeNodeHighlightingBase<ITreeNode>
        {
            public TestHighlighting(ITreeNode highlightingNode) : base(highlightingNode, "don't care")
            {
            }
        }
    }
}
