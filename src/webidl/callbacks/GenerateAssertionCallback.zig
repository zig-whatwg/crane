//! WebIDL callback: GenerateAssertionCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const GenerateAssertionCallback = *const fn (contents: runtime.DOMString, origin: runtime.DOMString, options: webidl.Opt(*const anyopaque)) *const anyopaque;
