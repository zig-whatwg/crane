//! HTML "abort a parser" pops open elements without delivering normal EOF.
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html#abort-a-parser

const std = @import("std");
const parser = @import("html").parser;

const Recorder = struct {
    finished: usize = 0,
    fn onFinished(_: *parser.TreeNode, context: ?*anyopaque) void {
        const self: *Recorder = @ptrCast(@alignCast(context.?));
        self.finished += 1;
    }
};

fn abortBuilder(context: *anyopaque) void {
    const builder: *parser.TreeBuilder = @ptrCast(@alignCast(context));
    builder.abort();
}

fn processBuilder(context: *anyopaque) void {
    const builder: *parser.TreeBuilder = @ptrCast(@alignCast(context));
    builder.parse() catch unreachable;
}

test "aborted streaming parser pops each open element without emitting EOF" {
    const allocator = std.testing.allocator;
    var stream = try parser.document_write.InputStreamManager.init(allocator, "<body><div><object>");
    stream.complete = false;
    var tokenizer = parser.Tokenizer.initWithStreamManager(allocator, &stream);
    stream.attach(&tokenizer);
    defer {
        stream.deinit();
        tokenizer.deinit();
    }
    var builder = try parser.TreeBuilder.initWithStreamManager(allocator, &tokenizer, &stream);
    defer builder.deinit();
    var recorder = Recorder{};
    builder.setDomAdapterCallbacks(&recorder, null, null, null);
    builder.setDomAdapterFinishedCallback(&Recorder.onFinished);
    stream.processor = .{ .context = &builder, .process = &processBuilder, .abort = &abortBuilder };
    try builder.parse();
    const open_count = builder.open_elements.len;
    const already_finished = recorder.finished;
    try std.testing.expect(open_count >= 4);
    stream.discardInput();
    try builder.parse();
    try std.testing.expectEqual(open_count, builder.open_elements.len);
    try std.testing.expectEqual(already_finished, recorder.finished);
    stream.abort();
    try std.testing.expectEqual(@as(usize, 0), builder.open_elements.len);
    try std.testing.expectEqual(already_finished + open_count, recorder.finished);
    try std.testing.expect(!stream.eof_processed);
    stream.abort();
    try builder.parse();
    try std.testing.expectEqual(already_finished + open_count, recorder.finished);
}
