# Codegen: Unforgeable accessors must be installed on derived instances

**Date**: 2026-10-21
**Lesson**: V8 FunctionTemplate inheritance does not copy the JavaScript accessor properties placed on an ancestor's instance template.

**Why**: In linked V8 13.1.99, `src/api/api-natives.cc`'s `ConfigureInstance` walks ancestors for `property_accessors`, but reads `property_list` only from the concrete instance template. `SetAccessorProperty` uses the latter. A JavaScript-visible getter/setter pair is different from a native property interceptor.

**What Happened**: Moving Event.isTrusted from the prototype to the Event instance template fixed Event's unforgeable descriptor, but made the property disappear on AnimationEvent. The existing animation test caught the regression. Relying on FunctionTemplate::Inherit was insufficient.

**Fix**: Generate per-member LegacyUnforgeable metadata. When creating each concrete interface template, walk its interface ancestry and install each inherited unforgeable member using the defining interface's callbacks. Keep ordinary members on prototypes. Native metadata defaults and WPT descriptor/inheritance assertions cover both paths.

**Takeaway**: **An inherited WebIDL member still needs explicit instance installation when the engine template does not inherit that property representation.**
