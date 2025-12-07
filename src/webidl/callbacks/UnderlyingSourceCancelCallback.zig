//! WebIDL callback: UnderlyingSourceCancelCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");

pub const UnderlyingSourceCancelCallback = *const fn (reason: webidl.Opt(v8.JSValue)) *const anyopaque;
