//! WebIDL callback: Reducer
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");

pub const Reducer = *const fn (accumulator: v8.JSValue, currentValue: v8.JSValue, index: u64) v8.JSValue;
