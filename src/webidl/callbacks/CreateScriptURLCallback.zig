//! WebIDL callback: CreateScriptURLCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");

pub const CreateScriptURLCallback = *const fn (input: runtime.DOMString, arguments: []const v8.JSValue) runtime.USVString;
