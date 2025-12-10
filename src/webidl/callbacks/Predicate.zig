//! WebIDL callback: Predicate
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const Predicate = *const fn (value: runtime.JSValue, index: u64) bool;
