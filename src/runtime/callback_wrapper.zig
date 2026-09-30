//! A callback interface argument as the binding converts it today.
//!
//! WebIDL callback interfaces (EventListener, NodeFilter, XPathNSResolver)
//! reach impls as a `*CallbackWrapper`: the adapter's own object for the
//! argument, BORROWED for the call like every other argument (AGENTS.md "The
//! engine boundary", rule 3) - the binding releases it when the call returns.
//! An impl that keeps the callback takes a CallbackInterface of its own with
//! the engine protocol's takeCallbackInterface; nothing else reads it.
//!
//! TRANSITIONAL: goes when codegen types callback interface parameters as the
//! protocol's CallbackInterface (engine_protocol.zig names this type so).

/// Opaque: only the adapter that made it reads it.
pub const CallbackWrapper = opaque {};
