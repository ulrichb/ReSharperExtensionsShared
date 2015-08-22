using System;
using JetBrains.Annotations;
using JetBrains.DocumentModel;
using JetBrains.ReSharper.Psi.Tree;
#if RESHARPER8
using IHighlighting = JetBrains.ReSharper.Daemon.Impl.IHighlightingWithRange;

#else
using JetBrains.ReSharper.Feature.Services.Daemon;

#endif

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

        [NotNull]
        public T TreeNode { get; private set; }

        public string ToolTip
        {
            get { return _toolTipText; }
        }

        public string ErrorStripeToolTip
        {
            get { return _toolTipText; }
        }

        public int NavigationOffsetPatch
        {
            get { return 0; }
        }

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