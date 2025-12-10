//! WebIDL callback: UnderlyingSinkAbortCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const UnderlyingSinkAbortCallback = *const fn (reason: webidl.Opt(runtime.JSValue)) runtime.JSValue;
