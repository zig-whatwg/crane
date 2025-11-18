//! WebIDL callback: CreateScriptCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const CreateScriptCallback = *const fn (input: runtime.DOMString, arguments: anyopaque) anyopaque;
