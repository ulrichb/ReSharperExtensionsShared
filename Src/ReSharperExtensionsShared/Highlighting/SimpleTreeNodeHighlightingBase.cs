using JetBrains.Annotations;
using JetBrains.DocumentModel;
using JetBrains.ReSharper.Feature.Services.Daemon;
using JetBrains.ReSharper.Psi.Tree;

namespace ReSharperExtensionsShared.Highlighting
{
    public abstract class SimpleTreeNodeHighlightingBase<T> : IHighlighting where T : ITreeNode
    {
        protected SimpleTreeNodeHighlightingBase([NotNull] T treeNode, [NotNull] string toolTipText)
        {
            TreeNode = treeNode;
            ToolTip = toolTipText;
        }

        [NotNull, PublicAPI]
        public T TreeNode { get; }

        public string ToolTip { get; }

        public string ErrorStripeToolTip => ToolTip;

        public bool IsValid()
        {
            return TreeNode.IsValid();
        }

        public virtual DocumentRange CalculateRange()
        {
            return TreeNode.GetDocumentRange();
        }
    }
}