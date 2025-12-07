//! WebIDL callback: Predicate
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");

pub const Predicate = *const fn (value: v8.JSValue, index: u64) bool;
