# Codegen: A mixin's live member is its includer's impl until the mixin is inherited

**Date**: 2026-09-30
**Lesson**: `element.focus()` is an HTMLOrSVGElement member, but HTMLOrSVGElement is not in codegen/inherited_mixins.zig yet. So the generated interfaces/HTMLElement.zig binds `focus` and `blur` to HTMLElementImpl, and SVGElement's are bound to SVGElementImpl. HTMLOrSVGElementImpl.call_focus is a delegate nothing reaches for any element.

**Why**: Until a mixin moves into inherited_mixins.zig, each includer's generated interface calls its own impl for the mixin's members (AGENTS.md, "Mixin members are inherited"). The mixin impl keeps an implementation that reads as the real one. It even held a Document-internals reference, but no binding calls it.

**What Happened**: The testdriver lane was granted HTMLOrSVGElement.zig to route focus()/blur() through the new focusing steps. Reading the generated HTMLElement.zig before editing showed the grant named dead code. The live `focus()` was HTMLElementImpl's, which set Document's active element through `DocumentImpl.setActiveElement` and fired no events. SVGElementImpl's returned NotImplemented.

**Fix**: All three (HTMLElement.zig, SVGElement.zig and the mixin's delegate) call one function, html.focus.focusMethod / blurMethod, so they cannot diverge. The follow-up is to move HTMLOrSVGElement into inherited_mixins.zig, which deletes the two per-includer copies.

**Takeaway**: **Before changing a mixin member, open the includer's generated interface and see which impl it calls: until the mixin is inherited, the includer's copy is the live one.**
