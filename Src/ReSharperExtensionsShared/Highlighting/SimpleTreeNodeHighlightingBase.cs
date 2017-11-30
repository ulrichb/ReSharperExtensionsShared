using JetBrains.Annotations;
using JetBrains.DocumentModel;
using JetBrains.ReSharper.Feature.Services.Daemon;
using JetBrains.ReSharper.Psi.Tree;

namespace ReSharperExtensionsShared.Highlighting
{
    public abstract class SimpleTreeNodeHighlightingBase<T> : IHighlighting where T : ITreeNode
    {
        protected SimpleTreeNodeHighlightingBase([NotNull] T highlightingNode, [NotNull] string toolTipText)
        {
            HighlightingNode = highlightingNode;
            ToolTip = toolTipText;
        }

        [NotNull]
        [PublicAPI]
        public T HighlightingNode { get; }

        public string ToolTip { get; }

        public string ErrorStripeToolTip => ToolTip;

        public bool IsValid() => HighlightingNode.IsValid();

        public virtual DocumentRange CalculateRange() => HighlightingNode.GetDocumentRange();
    }
}
