//! WebIDL callback: QueuingStrategySize
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");

pub const QueuingStrategySize = *const fn (chunk: v8.JSValue) f64;
