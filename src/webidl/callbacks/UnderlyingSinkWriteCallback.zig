//! WebIDL callback: UnderlyingSinkWriteCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const UnderlyingSinkWriteCallback = *const fn (chunk: runtime.JSValue, controller: runtime.JSValue) runtime.JSValue;
