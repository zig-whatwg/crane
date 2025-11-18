//! WebIDL callback: EffectCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const EffectCallback = *const fn (progress: anyopaque, currentTarget: anyopaque, animation: anyopaque) void;
