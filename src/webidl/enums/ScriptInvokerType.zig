//! WebIDL enum: ScriptInvokerType
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const ScriptInvokerType = enum {
    _classic_script_,
    _module_script_,
    _event_listener_,
    _user_callback_,
    _resolve_promise_,
    _reject_promise_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "classic-script", "module-script", "event-listener", "user-callback", "resolve-promise", "reject-promise" };
};
