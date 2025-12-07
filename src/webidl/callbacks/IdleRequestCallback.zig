//! WebIDL callback: IdleRequestCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");

pub const IdleRequestCallback = *const fn (deadline: *const anyopaque) void;
