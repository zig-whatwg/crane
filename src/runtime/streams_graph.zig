//! The streams graph: the platform-object classes every adapter's wrapper
//! cache holds strongly for the realm's life.
//!
//! Streams objects reach each other through Zig pointers no engine can see -
//! a stream's [[controller]] and [[writer]], a controller's [[stream]], the
//! context of every pending promise reaction. Blink traces those slots
//! (third_party/blink/renderer/core/streams/, `Trace` on every class); with
//! handle-based wrappers there is nothing to trace, so collecting one wrapper
//! would free an instance another still points at. So these wrappers are
//! held strongly and the realm's teardown sweep frees them: memory for the
//! realm's lifetime, never a dangling [[controller]]. Only classes built on
//! the `impls/streams_*.zig` ownership rules belong here - their teardown
//! touches nothing but their own slots, so the sweep can free them in any
//! order.
//!
//! A wrapper-lifetime policy, so it lives in the runtime tier, where every
//! adapter and the streams impls read the same list:
//! - the V8 adapter's wrapper cache holds exactly these strongly
//!   (wrapper_cache.isStreamsGraphObject);
//! - `streams_js.Realm.wrap`, which makes a wrapper and lets it go, accepts
//!   only these: any other wrapper is weak and would be unheld between that
//!   wrap and the caller's own hold (setUpController once freed its
//!   AbortController that way). Anything else is held with `clone`.

const std = @import("std");

pub const streams_graph_classes = [_][]const u8{
    "WritableStream",
    "WritableStreamDefaultWriter",
    "WritableStreamDefaultController",
    "ReadableStream",
    "ReadableStreamDefaultReader",
    "ReadableStreamBYOBReader",
    "ReadableStreamDefaultController",
    "ReadableByteStreamController",
    "ReadableStreamBYOBRequest",
    "TransformStream",
    "TransformStreamDefaultController",
};

/// Whether `name` (an instance's vtable name) is one of `streams_graph_classes`.
pub fn isStreamsGraphObject(name: []const u8) bool {
    for (streams_graph_classes) |n| {
        if (std.mem.eql(u8, name, n)) return true;
    }
    return false;
}
