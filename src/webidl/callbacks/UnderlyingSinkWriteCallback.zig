//! WebIDL callback: UnderlyingSinkWriteCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");

pub const UnderlyingSinkWriteCallback = *const fn (chunk: v8.JSValue, controller: *const anyopaque) *const anyopaque;
