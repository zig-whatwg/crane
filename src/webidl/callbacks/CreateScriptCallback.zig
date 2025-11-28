//! WebIDL callback: CreateScriptCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const CreateScriptCallback = *const fn (input: runtime.DOMString, arguments: []const *const anyopaque) runtime.DOMString;
