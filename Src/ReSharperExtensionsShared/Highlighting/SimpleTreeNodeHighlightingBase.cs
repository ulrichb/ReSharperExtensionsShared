using JetBrains.Annotations;
using JetBrains.DocumentModel;
using JetBrains.ReSharper.Feature.Services.Daemon;
using JetBrains.ReSharper.Psi.Tree;

namespace ReSharperExtensionsShared.Highlighting
{
    public abstract class SimpleTreeNodeHighlightingBase<T> : IHighlighting where T : ITreeNode
    {
        private readonly string _toolTipText;

        protected SimpleTreeNodeHighlightingBase([NotNull] T treeNode, [NotNull] string toolTipText)
        {
            TreeNode = treeNode;
            _toolTipText = toolTipText;
        }

        [NotNull, PublicAPI]
        public T TreeNode { get; }

        public string ToolTip => _toolTipText;

        public string ErrorStripeToolTip => _toolTipText;


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