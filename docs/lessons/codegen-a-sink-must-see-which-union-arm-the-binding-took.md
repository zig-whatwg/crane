# Codegen: A sink must see which union arm the binding took

**Date**: 2026-10-03
**Lesson**: A `(TrustedHTML or DOMString)` argument the binding converts to a string makes a TrustedHTML indistinguishable from a string, so a Trusted Types sink must take a named union typedef.

**Why**: Trusted Types' "get trusted type compliant string" branches on the input's type: a TrustedHTML passes as its data, a string goes through the CSP check and the default policy. TrustedHTML has a stringifier, so a binding that converts the union to DOMString hands the impl the same bytes either way, and the sink cannot implement step 1.

**What Happened**: Every `block-string-assignment-to-*` file failed both ways at once: with enforcement on, a TrustedHTML threw like a string; with enforcement off nothing changed. The generated signatures said `value: runtime.DOMString` for innerHTML, setAttribute's value, document.write's variadic, Worker's scriptURL and the rest.

**Fix**: `argument_unions.nameTrustedTypeUnions` (632fca525) names every union with a Trusted Type member - `typedefs.TrustedHTMLOrDOMString`, `TrustedScriptURLOrUSVString` - in every position but attribute getters (a getter returns the string member's type). The sink takes the union and calls `dom.trusted_types.compliantStringFor(allocator, kind, this, value, sink)`; a caller in Zig that has a string wraps it, `.{ .domstring = s }`. A string the engine produced inside Crane never re-enters the sink: internal code calls the step after the check, not the IDL setter.

**Takeaway**: **When an algorithm branches on an argument's type, the binding must not flatten it - check the generated signature before writing the step.**
