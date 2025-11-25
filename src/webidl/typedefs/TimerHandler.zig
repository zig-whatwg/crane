//! WebIDL typedef: TimerHandler
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const callbacks = @import("callbacks");

pub const TimerHandler = union(enum) {
    variant_0: runtime.DOMString,
    variant_1: callbacks.Function,
    variant_2: *const anyopaque,
};
