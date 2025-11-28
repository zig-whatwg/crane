//! WebIDL callback: Predicate
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const Predicate = *const fn (value: *const anyopaque, index: u64) bool;
