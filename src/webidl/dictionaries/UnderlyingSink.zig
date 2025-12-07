//! WebIDL dictionary: UnderlyingSink
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const callbacks = @import("callbacks");

pub const UnderlyingSink = struct {
    start: ?callbacks.UnderlyingSinkStartCallback = null,
    write: ?callbacks.UnderlyingSinkWriteCallback = null,
    close: ?callbacks.UnderlyingSinkCloseCallback = null,
    abort: ?callbacks.UnderlyingSinkAbortCallback = null,
    @"type": ?runtime.JSValue = null,
};
