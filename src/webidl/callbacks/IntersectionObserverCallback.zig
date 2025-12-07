//! WebIDL callback: IntersectionObserverCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");

pub const IntersectionObserverCallback = *const fn (entries: *const anyopaque, observer: *const anyopaque) void;
