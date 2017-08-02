using FakeItEasy;
using JetBrains.DocumentModel;
using JetBrains.ReSharper.Psi;
using JetBrains.ReSharper.Psi.ExtensionsAPI.Tree;
using JetBrains.ReSharper.Psi.Tree;
using JetBrains.Util;
using NUnit.Framework;
using ReSharperExtensionsShared.Highlighting;

namespace ReSharperExtensionsShared.Tests.Highlighting
{
    [TestFixture]
    public class SimpleTreeNodeHighlightingBaseTest
    {
        private ITreeNode _fakeTreeNode;
        private SimpleTreeNodeHighlightingBase<ITreeNode> _sut;

        [SetUp]
        public void SetUp()
        {
            _fakeTreeNode = A.Fake<ITreeNode>();
            _sut = new TestHighlighting(_fakeTreeNode, "ToolTipText");
        }

        [Test]
        public void TreeNode()
        {
            Assert.That(_sut.TreeNode, Is.EqualTo(_fakeTreeNode));
        }

        [Test]
        public void ToolTip()
        {
            Assert.That(_sut.ToolTip, Is.EqualTo("ToolTipText"));
        }

        [Test]
        public void ErrorStripeToolTip()
        {
            Assert.That(_sut.ErrorStripeToolTip, Is.EqualTo("ToolTipText"));
        }

        [Test]
        public void IsValid_WithInvalidTreeNode()
        {
            A.CallTo(() => _fakeTreeNode.IsValid()).Returns(false);

            Assert.That(_sut.IsValid(), Is.EqualTo(false));
        }

        [Test]
        public void IsValid_WithValidTreeNode()
        {
            A.CallTo(() => _fakeTreeNode.IsValid()).Returns(true);

            Assert.That(_sut.IsValid(), Is.EqualTo(true));
        }

        [Test]
        public void CalculateRange()
        {
            // IDEA: If we get *integrative* highlighting tests, replace this test

            var fakeDocument = A.Fake<IDocument>();

            var fakeFile = A.Fake<IFileImpl>();
            A.CallTo(() => fakeFile.IsValid()).Returns(true);
            A.CallTo(() => fakeFile.SecondaryRangeTranslator).Returns(null);
            A.CallTo(() => fakeFile.DocumentRangeTranslator.Translate(A<TreeTextRange>._))
                .Returns(new DocumentRange(fakeDocument, new TextRange(42, 10)));

            A.CallTo(() => _fakeTreeNode.GetContainingNode<IFile>(A<bool>._)).Returns(fakeFile);

            //

            var result = _sut.CalculateRange();

            //

            Assert.That(result, Is.EqualTo(new DocumentRange(fakeDocument, new TextRange(42, 10))));
        }

        private class TestHighlighting : SimpleTreeNodeHighlightingBase<ITreeNode>
        {
            public TestHighlighting(ITreeNode treeNode, string toolTipText)
                : base(treeNode, toolTipText)
            {
            }
        }
    }
}
