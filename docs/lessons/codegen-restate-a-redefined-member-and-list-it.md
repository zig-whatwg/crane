# Codegen: Restate a member another spec redefines, and list it

**Date**: 2026-10-03
**Lesson**: webref keeps the older declaration when one spec redefines another's member (HTMLScriptElement's text/src for Trusted Types, Document.execCommand's value for editing), so Crane restates the newer one in specs/supplementary and names it in member_overrides.zig.

**Why**: webref's trusted-types.idl omits the HTMLScriptElement partial because it conflicts with html.idl, and html.idl declares execCommand's value as DOMString while the editing spec says (TrustedHTML or DOMString). A supplementary partial merged as-is would append a second attribute (the writers keep the first) or turn an operation into an overload set the binding cannot distinguish.

**What Happened**: The first draft made every duplicate member an error; webref itself restates members across files (cssom-view's MouseEvent.screenX over uievents'), so codegen stopped on the real tree. The rule that holds: a supplementary file may replace a member only where `member_overrides.zig` lists (interface, member, file, reason); an unlisted collision involving a supplementary file is `error.DuplicateMember`; two webref files keep today's behaviour. An operation listed there is replaced in place, not overloaded.

**Fix**: specs/supplementary/trusted-types-script.idl and execcommand.idl, each citing its spec; `member_overrides.table` entries; `ir.mergeInterfacePartial`; tests in tests/codegen/trusted_type_unions_test.zig (listed attribute, listed operation, unlisted attribute, unlisted operation, webref-webref).

**Takeaway**: **When WPT expects a type the generated signature lacks, compare the defining spec's IDL with webref's; restate it in specs/supplementary and list the replacement explicitly - never merge a redefinition silently.**
