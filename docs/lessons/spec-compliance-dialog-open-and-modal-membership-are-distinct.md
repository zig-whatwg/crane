# Spec Compliance: Dialog open state and modal membership are distinct

**Date**: 2026-10-19
**Lesson**: The `open` attribute alone cannot answer whether a dialog is modal or whether it blocks its document.

**Why**: HTML's dialog attribute-change steps clean up the open-dialog registration and close watcher when `open` disappears. They do not remove the element from the top layer. The close algorithm first checks `open`, while element removal clears modal membership independently.

**What Happened**: The dialog implementation began with unimplemented methods and a permanently false `:modal`. Treating `open` as modal state would have made `show()` modal, lost the modal state after direct attribute removal, and allowed outside focus while the document remained blocked.

**Fix**: Keep modal membership in the existing Document-owned top layer. Let `:open` read the content attribute, and make `:modal`, popover validity and modal focus exclusion consult the same modal state. Preserve membership on direct attribute removal, remove it during `close()` only after the post-event `open` check, and remove it unconditionally during the dialog's removing steps. Pin the attribute-removal and event-reentrancy cases in script tests, and mixed modal/popover removal orders in native tests.

**Takeaway**: **An attribute, a lifecycle flag and a container membership can change at different spec steps; derive state only when their transitions are actually identical.**

References: [HTML dialog algorithms](https://html.spec.whatwg.org/multipage/interactive-elements.html#the-dialog-element), [modal inertness](https://html.spec.whatwg.org/multipage/interaction.html#modal-dialogs-and-inert-subtrees), and [WebKit HTMLDialogElement](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/html/HTMLDialogElement.cpp) (`attributeChanged`, `close`, `removingSteps`).
