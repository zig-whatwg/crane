//! WebIDL callback: MutationCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const MutationCallback = *const fn (mutations: runtime.JSValue, observer: *runtime.Instance) void;
