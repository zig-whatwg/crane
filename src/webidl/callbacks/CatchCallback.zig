//! WebIDL callback: CatchCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const CatchCallback = *const fn (value: *const anyopaque) *const anyopaque;
