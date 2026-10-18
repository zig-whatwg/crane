# Architecture: A shared append hook needs the reason carried with the attribute

**Date**: 2026-10-18
**Lesson**: When an attribute change step must behave differently for one caller - cloning - and that caller reaches the element through the same hook as others, carry the reason on the call itself; the element cannot infer it from its own state.

**Why**: DOM "clone a single node" step 3 appends each attribute to the copy, and Crane's Node.cloneSingleNode does it through `dom.element_attributes.append` - the same hook the HTML parser (appendParsedAttribute) and the XML parser use. At append time a clone looks exactly like a freshly parsed element: just created, not yet inserted, its node document set. So Element's style attribute change steps could not skip the CSP check for a clone without also skipping it for parsed style attributes, which must stay blocked.

**What Happened**: All three browsers keep a cloned element's style attribute declarations under a policy that blocks style attributes (wpt.fyi: Chrome, Firefox and Safari pass inline-style-allowed-while-cloning-objects subtests 1/3/5/7/8). Blink carries `AttributeModificationReason::kByCloning` into Element::StyleAttributeChanged, and WebKit `AttributeModificationReason::ByCloning` into StyledElement::styleAttributeChanged. The brief expected the fix to be an Element.zig hunk; the clone path turned out to be Node.zig plus the shared hook.

**Fix**: `element_attributes.Attribute.by_cloning` (defaulted false, so the parsers' calls are unchanged); Node.zig's attribute loop sets it; Element's appendAttributeHook raises `InternalState.appending_clone` for a cloned style attribute only, cleared by `defer`, and styleAttributeChangeSteps consumes it - no block, no violation report. Crane test crane/style3-clone-style-csp.html keeps the controls: a parsed and a setAttribute style attribute are still blocked and reported, and exactly two reports arrive.

**Takeaway**: **If two callers share a hook and only one may skip a check, the reason must travel with the call (Blink's AttributeModificationReason); state the element "notices" cannot tell them apart.**
