//! WebIDL callback: Reducer
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const Reducer = *const fn (accumulator: runtime.JSValue, currentValue: runtime.JSValue, index: u64) runtime.JSValue;
