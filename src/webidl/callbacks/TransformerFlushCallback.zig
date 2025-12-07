//! WebIDL callback: TransformerFlushCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");

pub const TransformerFlushCallback = *const fn (controller: *const anyopaque) *const anyopaque;
