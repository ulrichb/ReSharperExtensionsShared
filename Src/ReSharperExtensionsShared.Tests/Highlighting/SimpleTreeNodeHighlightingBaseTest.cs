using FakeItEasy;
using JetBrains.DocumentModel;
using JetBrains.ReSharper.Psi;
using JetBrains.ReSharper.Psi.ExtensionsAPI.Tree;
using JetBrains.ReSharper.Psi.Tree;
using JetBrains.Util;
using NUnit.Framework;
using ReSharperExtensionsShared.Highlighting;
using A_ = FakeItEasy.A;

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
            _fakeTreeNode = A_.Fake<ITreeNode>();
            _sut = new TestHighlighting(_fakeTreeNode, "ToolTipText");
        }

        [Test]
        public void HighlightingNode()
        {
            Assert.That(_sut.HighlightingNode, Is.EqualTo(_fakeTreeNode));
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
            A_.CallTo(() => _fakeTreeNode.IsValid()).Returns(false);

            Assert.That(_sut.IsValid(), Is.EqualTo(false));
        }

        [Test]
        public void IsValid_WithValidTreeNode()
        {
            A_.CallTo(() => _fakeTreeNode.IsValid()).Returns(true);

            Assert.That(_sut.IsValid(), Is.EqualTo(true));
        }

        [Test]
        public void CalculateRange()
        {
            // IDEA: If we get *integrative* highlighting tests, replace this test

            var fakeDocument = A_.Fake<IDocument>();

            var fakeFile = A_.Fake<IFileImpl>();
            A_.CallTo(() => fakeFile.IsValid()).Returns(true);
            A_.CallTo(() => fakeFile.SecondaryRangeTranslator).Returns(null);
            A_.CallTo(() => fakeFile.DocumentRangeTranslator.Translate(A<TreeTextRange>._))
                .Returns(new DocumentRange(fakeDocument, new TextRange(42, 10)));

            A_.CallTo(() => _fakeTreeNode.GetContainingNode<IFile>(A<bool>._)).Returns(fakeFile);

            //

            var result = _sut.CalculateRange();

            //

            Assert.That(result, Is.EqualTo(new DocumentRange(fakeDocument, new TextRange(42, 10))));
        }

        private class TestHighlighting : SimpleTreeNodeHighlightingBase<ITreeNode>
        {
            public TestHighlighting(ITreeNode highlightingNode, string toolTipText)
                : base(highlightingNode, toolTipText)
            {
            }
        }
    }
}
