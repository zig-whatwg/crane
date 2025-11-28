//! WebIDL callback: IntersectionObserverCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const IntersectionObserverCallback = *const fn (entries: *const anyopaque, observer: *const anyopaque) void;
