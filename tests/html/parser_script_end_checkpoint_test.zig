//! Parser checkpoints observe flushed text before the script leaves its stack.
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html#parsing-main-incdata

const std = @import("std");
const parser = @import("html").parser;
const TreeBuilder = parser.TreeBuilder;

const Probe = struct {
    builder: *TreeBuilder,
    checkpoints: usize = 0,
    executions: usize = 0,
    observed_text: bool = false,
    checked_text_was_flushed: bool = false,
    checked_current_script: bool = false,
    checked_nesting_zero: bool = false,
    cancel: bool = false,

    fn checkpoint(context: ?*anyopaque) bool {
        const self: *Probe = @ptrCast(@alignCast(context.?));
        self.checkpoints += 1;
        self.checked_text_was_flushed = self.observed_text;
        self.checked_current_script = self.builder.currentNode().?.hasTagName("script");
        self.checked_nesting_zero = self.builder.script_nesting_level == 0;
        if (self.cancel) {
            self.builder.input_stream_manager.?.discardInput();
            return false;
        }
        return true;
    }

    fn textChanged(text: *parser.TreeNode, context: ?*anyopaque) void {
        const self: *Probe = @ptrCast(@alignCast(context.?));
        self.observed_text = self.observed_text or std.mem.eql(u8, text.text_content.toSlice(), "payload");
    }

    fn execute(_: *parser.TreeNode, context: ?*anyopaque) void {
        const self: *Probe = @ptrCast(@alignCast(context.?));
        self.executions += 1;
    }
};

fn expectCheckpointBehavior(cancel: bool) !void {
    const allocator = std.testing.allocator;
    var stream = try parser.document_write.InputStreamManager.init(allocator, "<body><script>payload</script><p>after</p>");
    var tokenizer = parser.Tokenizer.initWithStreamManager(allocator, &stream);
    stream.attach(&tokenizer);
    defer {
        stream.deinit();
        tokenizer.deinit();
    }
    var builder = try TreeBuilder.initWithStreamManager(allocator, &tokenizer, &stream);
    defer builder.deinit();
    builder.scripting_enabled = true;
    var probe = Probe{ .builder = &builder, .cancel = cancel };
    builder.setDomAdapterCallbacks(&probe, null, null, &Probe.textChanged);
    builder.setScriptExecutionCallback(&Probe.execute, &probe);
    // The existing implementation has no checkpoint seam. It still compiles
    // this test, then fails the observable ordering assertions below.
    if (@hasDecl(TreeBuilder, "setScriptEndCheckpointCallback"))
        builder.setScriptEndCheckpointCallback(&Probe.checkpoint, &probe);
    try builder.parse();
    try std.testing.expectEqual(@as(usize, 1), probe.checkpoints);
    try std.testing.expect(probe.observed_text);
    try std.testing.expect(probe.checked_text_was_flushed);
    try std.testing.expect(probe.checked_current_script);
    try std.testing.expect(probe.checked_nesting_zero);
    try std.testing.expectEqual(@as(usize, if (cancel) 0 else 1), probe.executions);
    if (cancel) {
        try std.testing.expect(builder.currentNode().?.hasTagName("script"));
        try std.testing.expect(!stream.eof_processed);
        try std.testing.expect(builder.currentNode().?.next_sibling == null);
    } else {
        try std.testing.expect(stream.eof_processed);
    }
}

test "script-end checkpoint sees text before stack pop and preparation" {
    try expectCheckpointBehavior(false);
}

test "script-end checkpoint can cancel the old parser before script or following markup" {
    try expectCheckpointBehavior(true);
}
