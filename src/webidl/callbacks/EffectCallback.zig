//! WebIDL callback: EffectCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const EffectCallback = *const fn (progress: ?f64, currentTarget: *const anyopaque, animation: *const anyopaque) void;
