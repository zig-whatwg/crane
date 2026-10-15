# Spec Compliance: Handler registration does not require the event source

**Date**: 2026-10-14
**Lesson**: An initialized EventTarget supports its declared handler attributes even when the feature that normally emits those events is unfinished.

**Why**: HTML's event handler IDL getter and setter operate on the target's handler map. A fullscreen, media or device integration is not a prerequisite for registering a callback and dispatching a synthetic event.

**What Happened**: Element's fullscreen handlers silently discarded assignments, and other initialized targets threw NotImplemented. Their overrides hid the generated accessors that already implement HTML 8.1.8.1. A separate assumption that the event type is always the attribute name minus `on` registered the four WebKit-prefixed handlers under the wrong case.

**Fix**: Remove inert overrides only after proving that construction initializes EventTarget. Keep accessors with additional specified behavior, such as MessagePort's enabling setter. Use HTML 8.1.8.2's mixed-case event types for the four legacy WebKit attributes. Native tests exercise defaults with the testing allocator; Crane tests verify assignment, replacement, cancellation, removal, content attributes and case-sensitive dispatch.

WebKit likewise routes handler accessors through its shared implementation ([CodeGeneratorJS.pm](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/bindings/scripts/CodeGeneratorJS.pm)); its [GlobalEventHandlers.idl](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/dom/GlobalEventHandlers.idl) declares the mixed-case implementation names.

**Takeaway**: **Separate callback registration from the event source, and take event names from the handler table rather than a spelling rule.**
