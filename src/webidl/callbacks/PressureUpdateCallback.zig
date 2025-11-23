//! WebIDL callback: PressureUpdateCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const PressureUpdateCallback = *const fn (changes: *const anyopaque, observer: *const anyopaque) void;
