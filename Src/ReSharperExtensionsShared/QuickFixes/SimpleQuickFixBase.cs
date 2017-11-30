using JetBrains.Annotations;
using JetBrains.ReSharper.Feature.Services.QuickFixes;
using JetBrains.ReSharper.Intentions.Util;
using JetBrains.ReSharper.Psi.Tree;
using JetBrains.Util;
using ReSharperExtensionsShared.Highlighting;

namespace ReSharperExtensionsShared.QuickFixes
{
    /// <summary>
    /// A base class for Quick Fixes which provides <see cref="QuickFixBase.ExecutePsiTransaction"/> for
    /// valid declarations of <see cref="THighlighting"/>.
    /// </summary>
    public abstract class SimpleQuickFixBase<THighlighting, TDeclaration> : QuickFixBase
        where THighlighting : SimpleTreeNodeHighlightingBase<TDeclaration>
        where TDeclaration : class, ITreeNode
    {
        [NotNull]
        [PublicAPI]
        protected readonly THighlighting Highlighting;

        protected SimpleQuickFixBase([NotNull] THighlighting highlighting)
        {
            Highlighting = highlighting;
        }

        public override bool IsAvailable(IUserDataHolder cache) => IsTreeNodeValid && IsAvailableForTreeNode(cache);

        [PublicAPI]
        protected abstract bool IsAvailableForTreeNode([NotNull] IUserDataHolder cache);

        private bool IsTreeNodeValid => ValidUtils.Valid(Highlighting.HighlightingNode);
    }
}
