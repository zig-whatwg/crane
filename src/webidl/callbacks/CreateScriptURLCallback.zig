//! WebIDL callback: CreateScriptURLCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const CreateScriptURLCallback = *const fn (input: runtime.DOMString, arguments: []const *const anyopaque) runtime.USVString;
