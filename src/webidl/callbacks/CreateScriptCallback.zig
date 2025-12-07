//! WebIDL callback: CreateScriptCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");

pub const CreateScriptCallback = *const fn (input: runtime.DOMString, arguments: []const v8.JSValue) runtime.DOMString;
