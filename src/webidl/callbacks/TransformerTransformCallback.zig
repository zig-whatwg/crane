//! WebIDL callback: TransformerTransformCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const TransformerTransformCallback = *const fn (chunk: runtime.JSValue, controller: *const anyopaque) *const anyopaque;
