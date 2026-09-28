# Codegen: Regenerating specs/supplementary alone rewrites a typedef of an IDL interface

**Date**: 2026-09-27
**Lesson**: A codegen run over one source resolves every typedef against that source's model only, so `typedef Window WindowProxy` (specs/supplementary/WindowProxy.idl) is written as `runtime.JSValue` when `Window` is not in the run.

**Why**: AGENTS.md says to regenerate one source per invocation. The supplementary run parses 4 files, does not know `Window` is an interface, and maps the typedef's target as an unknown type. The committed `src/webidl/typedefs/WindowProxy.zig` says `*runtime.Instance`. The supplementary run also fails while writing its roots (FileNotFound), after it has already written the typedefs.

**What Happened**: The reflection lane regenerated specs/idl and then specs/supplementary for its restricted-float tables. The wpt-runner build then failed in 25 places: every `WindowProxy` parameter or result had become a JSValue (Document.zig, Window.zig, HTMLIFrameElement.zig, event_handler_target.zig, ...). The specs/idl run on its own changed no typedef.

**Fix**: Regenerate from specs/idl only, unless the change is to a supplementary definition. After any regeneration, check drift in `typedefs/` as well as in `interfaces/`, `mixins/` and `dictionaries/`, and restore the root.zig files. The durable fix is codegen resolving a supplementary typedef against the full model.

**Takeaway**: **After a regeneration, diff every generated directory, typedefs included. A one-source run resolves types against that source alone.**
