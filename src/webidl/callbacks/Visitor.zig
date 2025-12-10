//! WebIDL callback: Visitor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const Visitor = *const fn (value: runtime.JSValue, index: u64) void;
