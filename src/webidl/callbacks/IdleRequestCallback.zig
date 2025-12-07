//! WebIDL callback: IdleRequestCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const IdleRequestCallback = *const fn (deadline: *const anyopaque) void;
