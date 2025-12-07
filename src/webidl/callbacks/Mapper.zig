//! WebIDL callback: Mapper
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const Mapper = *const fn (value: runtime.JSValue, index: u64) runtime.JSValue;
