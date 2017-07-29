using JetBrains.Annotations;
using JetBrains.ReSharper.Daemon.Stages.Dispatcher;
using JetBrains.ReSharper.Feature.Services.Daemon;
using JetBrains.ReSharper.Psi;
using JetBrains.ReSharper.Psi.Tree;

namespace ReSharperExtensionsShared.ProblemAnalyzers
{
    public abstract class SimpleElementProblemAnalyzer<TDeclaration, TDeclaredElement> : ElementProblemAnalyzer<TDeclaration>
        where TDeclaration : IDeclaration
        where TDeclaredElement : IDeclaredElement
    {
        protected sealed override void Run(TDeclaration element, ElementProblemAnalyzerData data, IHighlightingConsumer consumer)
        {
            var declaredElement = element.DeclaredElement;

            if (declaredElement != null)
            {
                Run(element, (TDeclaredElement) declaredElement, data, consumer);
            }
        }

        protected abstract void Run(
            [NotNull] TDeclaration declaration,
            [NotNull] TDeclaredElement declaredElement,
            [NotNull] ElementProblemAnalyzerData data,
            [NotNull] IHighlightingConsumer consumer);
    }
}
