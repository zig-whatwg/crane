# Spec Compliance: Upgrade form ownership precedes custom state

**Date**: 2026-10-13
**Lesson**: A custom element's completed-upgrade predicate cannot gate steps that run before the upgrade sets that state.

**Why**: HTML's upgrade algorithm resets a form-associated custom element's form owner in step 11 and sets its state to `custom` in step 12. The definition already supplies form association during step 11, even though the ordinary `isFormAssociated` predicate still answers false.

**What Happened**: Restricting `form`-attribute ownership to listed elements correctly excluded images, but also excluded a connected element being upgraded. Two `form-associated-callback.html` subtests and one `ElementInternals-form.html` subtest regressed: the explicit owner was null. The unchanged baseline also fails `crane/ff-face-upgrade-isolated.html` and the matching native test.

**Fix**: Keep the general listed predicate unchanged. After ElementInternals validates that the target's definition is form-associated, use the shared owner algorithm with that listed status supplied explicitly. This makes the phase-specific knowledge local to the upgrade/internals path and preserves the constructor's earlier state. Test the isolated failure, both complete upstream files, and owner changes after upgrade.

Sources: [HTML upgrade steps 11–12](https://html.spec.whatwg.org/multipage/custom-elements.html#upgrades), [reset the form owner](https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#reset-the-form-owner), and [WebKit FormAssociatedCustomElement::didUpgrade](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/html/FormAssociatedCustomElement.cpp), which handles the form attribute after construction.

**Takeaway**: **Before reusing a state predicate in an algorithm, check when that algorithm establishes the state.**
