//! WebIDL enum: ScriptingPolicyViolationType
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const ScriptingPolicyViolationType = enum {
    _externalScript_,
    _inlineScript_,
    _inlineEventHandler_,
    _eval_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "externalScript", "inlineScript", "inlineEventHandler", "eval" };
};
