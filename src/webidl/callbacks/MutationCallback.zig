//! WebIDL callback: MutationCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");

pub const MutationCallback = *const fn (mutations: *const anyopaque, observer: *const anyopaque) void;
