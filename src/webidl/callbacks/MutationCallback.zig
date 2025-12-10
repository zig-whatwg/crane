//! WebIDL callback: MutationCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const MutationCallback = *const fn (mutations: runtime.JSValue, observer: runtime.JSValue) void;
