//! WebIDL callback: Reducer
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const Reducer = *const fn (accumulator: *const anyopaque, currentValue: *const anyopaque, index: u64) *const anyopaque;
