//! WebIDL callback: UnderlyingSourceCancelCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const UnderlyingSourceCancelCallback = *const fn (reason: webidl.Opt(runtime.JSValue)) *const anyopaque;
