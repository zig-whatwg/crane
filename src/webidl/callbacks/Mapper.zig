//! WebIDL callback: Mapper
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const Mapper = *const fn (value: *const anyopaque, index: u64) *const anyopaque;
