//! The streams graph (runtime.streams_graph): the classes every adapter's
//! wrapper cache holds strongly, and the only ones streams_js.Realm.wrap
//! accepts. Everything else keeps the weak default - and a weak wrapper made
//! and let go can be collected before its caller holds it.

const std = @import("std");
const runtime = @import("runtime");
const streams_graph = runtime.streams_graph;

test "every streams class is in the graph" {
    for (streams_graph.streams_graph_classes) |name| try std.testing.expect(streams_graph.isStreamsGraphObject(name));
    try std.testing.expectEqual(@as(usize, 11), streams_graph.streams_graph_classes.len);
}

test "weak wrapper classes are not - the default is weak" {
    for ([_][]const u8{ "AbortController", "AbortSignal", "TextDecoderStream", "TextEncoderStream", "Window", "Event", "Node", "" }) |name| {
        try std.testing.expect(!streams_graph.isStreamsGraphObject(name));
    }
}
