//! WebIDL typedef: TimerHandler
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const callbacks = @import("callbacks");
const typedefs = @import("root.zig");

pub const TimerHandler = union(enum) {
    domstring: runtime.DOMString,
    function: callbacks.Function,
    trusted_script: *runtime.Instance,
};
