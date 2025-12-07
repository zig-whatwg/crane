//! WebIDL callback: OnErrorEventHandlerNonNull
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");

pub const OnErrorEventHandlerNonNull = *const fn (event: *const anyopaque, source: webidl.Opt(runtime.DOMString), lineno: webidl.Opt(u32), colno: webidl.Opt(u32), @"error": webidl.Opt(v8.JSValue)) v8.JSValue;
