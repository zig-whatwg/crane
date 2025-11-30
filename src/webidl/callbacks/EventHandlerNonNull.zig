//! WebIDL callback: EventHandlerNonNull
//!
//! This file has been MANUALLY MODIFIED to use CallbackWrapper for proper V8 interop.
//!
//! The original generated code was a Zig function pointer, but EventHandler is a
//! JavaScript callback that needs to be stored and invoked later. CallbackWrapper
//! provides proper storage for V8 function references.
//!
//! See: src/runtime/engines/v8/callback_wrapper.zig for the wrapper implementation.
//! See: AGENTS.md "Lessons Learned" for rationale.

const runtime = @import("runtime");
const webidl = @import("webidl");

/// EventHandlerNonNull is a JavaScript callback function.
/// It wraps a V8 Function reference that can be stored and invoked later.
/// The CallbackWrapper handles proper V8 persistent handle management.
pub const EventHandlerNonNull = *runtime.CallbackWrapper;
