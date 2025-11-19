//! WebIDL callback: EffectCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const EffectCallback = *const fn (progress: f64, currentTarget: anyopaque, animation: anyopaque) void;
