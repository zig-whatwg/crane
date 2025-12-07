//! WebIDL callback: SubscribeCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const SubscribeCallback = *const fn (subscriber: *const anyopaque) void;
