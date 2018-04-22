using System.Diagnostics.CodeAnalysis;
using FakeItEasy;
using JetBrains.ReSharper.Feature.Services.Daemon;
using JetBrains.ReSharper.Psi;
using JetBrains.ReSharper.Psi.Tree;
using NUnit.Framework;
using ReSharperExtensionsShared.ProblemAnalyzers;
using A_ = FakeItEasy.A;

namespace ReSharperExtensionsShared.Tests.ProblemAnalyzers
{
    [TestFixture]
    public class SimpleElementProblemAnalyzerTest
    {
        private IDeclaration _declaration;
        private ElementProblemAnalyzerData _data;
        private IHighlightingConsumer _consumer;

        private TestProblemAnalyzer _sut;

        [SetUp]
        public void SetUp()
        {
            _declaration = A_.Fake<IDeclaration>();
            _data = A_.Dummy<ElementProblemAnalyzerData>();
            _consumer = A_.Dummy<IHighlightingConsumer>();

            _sut = A_.Fake<TestProblemAnalyzer>(o => o.CallsBaseMethods());
        }

        [Test]
        public void Run()
        {
            ((IElementProblemAnalyzer) _sut).Run(_declaration, _data, _consumer);

            A_.CallTo(() => _sut.PublicRun(_declaration, _declaration.DeclaredElement, _data, _consumer)).MustHaveHappened(Repeated.Exactly.Once);
        }

        [Test]
        public void Run_WithNullDeclaredElement_IsFiltered()
        {
            A_.CallTo(() => _declaration.DeclaredElement).Returns(null);

            ((IElementProblemAnalyzer) _sut).Run(_declaration, _data, _consumer);

            A_.CallTo(_sut).MustNotHaveHappened();
        }

        // ReSharper disable once MemberCanBePrivate.Global
        public abstract class TestProblemAnalyzer : SimpleElementProblemAnalyzer<IDeclaration, IDeclaredElement>
        {
            protected override void Run(
                IDeclaration declaration,
                IDeclaredElement declaredElement,
                ElementProblemAnalyzerData data,
                IHighlightingConsumer consumer)
            {
                PublicRun(declaration, declaredElement, data, consumer);
            }

            [SuppressMessage("ReSharper", "UnusedParameter.Global")]
            public virtual void PublicRun(
                IDeclaration declaration,
                IDeclaredElement declaredElement,
                ElementProblemAnalyzerData data,
                IHighlightingConsumer consumer)
            {
            }
        }
    }
}
