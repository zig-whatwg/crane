//! WebIDL callback: OnErrorEventHandlerNonNull
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const OnErrorEventHandlerNonNull = *const fn (event: *const anyopaque, source: webidl.Opt(runtime.DOMString), lineno: webidl.Opt(u32), colno: webidl.Opt(u32), @"error": webidl.Opt(*const anyopaque)) *const anyopaque;
