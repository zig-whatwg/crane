//! The tree builder tells the DOM adapter about a text node's content once per
//! run of text, not once per character.
//!
//! The adapter mirrors each notification into the DOM with
//! `CharacterData.set_data`, which copies the whole string. Notifying per
//! character made parsing a run of N characters O(N^2): a frame whose body
//! held two 100,000-character runs burnt 30 seconds of CPU in
//! `CharacterData.replaceData`, and the 52
//! `the-script-element/moving-between-documents/` files, which load two such
//! frames each, ran past their 60-second ceiling.
//!
//! The tokenizer batches plain ASCII into `text_run` tokens only for static
//! input. Every page parses through an InputStreamManager, and non-ASCII text
//! is never batched, so those arrive one character token at a time - which is
//! why these tests use "é".
//!
//! Blink buffers the same way (`HTMLConstructionSite::pending_text_`, flushed
//! by `FlushPendingText` before anything else touches the tree). What script
//! can observe must not change: a script, or any other node the parser
//! creates, sees every character inserted before it.

const std = @import("std");
const testing = std.testing;

const html = @import("html");
const parser = html.parser;
const Tokenizer = parser.Tokenizer;
const TreeBuilder = parser.TreeBuilder;
const TreeNode = parser.TreeNode;

/// What the DOM adapter would have seen of the FIRST text node the parser
/// creates: how many change notifications, and its length as of the latest.
const Mirror = struct {
    text_changes: usize = 0,
    watched: ?*TreeNode = null,
    watched_len: usize = 0,
    /// The watched node's mirrored length when the script callback ran.
    len_at_script: ?usize = null,
    /// The watched node's mirrored length when a <p> element was created.
    len_at_p: ?usize = null,

    fn record(self: *Mirror, node: *TreeNode) void {
        if (node.node_type != .text) return;
        if (self.watched == null) self.watched = node;
        if (self.watched != node) return;
        self.watched_len = node.text_content.toSlice().len;
    }

    fn onNodeCreated(node: *TreeNode, context: ?*anyopaque) void {
        const self: *Mirror = @ptrCast(@alignCast(context.?));
        if (node.node_type == .element and node.hasTagName("p")) self.len_at_p = self.watched_len;
        self.record(node);
    }

    fn onChildAppended(parent: *TreeNode, child: *TreeNode, context: ?*anyopaque) void {
        _ = parent;
        _ = child;
        _ = context;
    }

    fn onTextContentChanged(node: *TreeNode, context: ?*anyopaque) void {
        const self: *Mirror = @ptrCast(@alignCast(context.?));
        if (self.watched == node) self.text_changes += 1;
        self.record(node);
    }

    fn onScript(script: *TreeNode, context: ?*anyopaque) void {
        _ = script;
        const self: *Mirror = @ptrCast(@alignCast(context.?));
        self.len_at_script = self.watched_len;
    }
};

fn parse(allocator: std.mem.Allocator, source: []const u8, mirror: *Mirror) !void {
    var tokenizer = Tokenizer.init(allocator, source);
    defer tokenizer.deinit();
    var builder = try TreeBuilder.init(allocator, &tokenizer);
    defer builder.deinit();
    builder.scripting_enabled = true;
    builder.setScriptExecutionCallback(&Mirror.onScript, mirror);
    builder.setDomAdapterCallbacks(mirror, &Mirror.onNodeCreated, &Mirror.onChildAppended, &Mirror.onTextContentChanged);
    try builder.parse();
}

const e_acute = "\u{e9}"; // two bytes of UTF-8

test "a run of text reaches the adapter once, whole" {
    const allocator = testing.allocator;
    const run_chars = 5000;
    const source = try std.mem.concat(allocator, u8, &.{ "<!DOCTYPE html><body>", e_acute ** run_chars, "</body>" });
    defer allocator.free(source);

    var mirror: Mirror = .{};
    try parse(allocator, source, &mirror);

    try testing.expect(mirror.text_changes <= 1);
    try testing.expectEqual(@as(usize, run_chars * e_acute.len), mirror.watched_len);
}

test "a script sees every character parsed before it" {
    const allocator = testing.allocator;
    var mirror: Mirror = .{};
    try parse(allocator, "<!DOCTYPE html><body>" ++ e_acute ** 6 ++ "<script>x</script>", &mirror);

    try testing.expectEqual(@as(?usize, 6 * e_acute.len), mirror.len_at_script);
}

test "a node created after a run sees the run complete" {
    const allocator = testing.allocator;
    var mirror: Mirror = .{};
    try parse(allocator, "<!DOCTYPE html><body>" ++ e_acute ** 6 ++ "<p>xy</p>", &mirror);

    try testing.expectEqual(@as(?usize, 6 * e_acute.len), mirror.len_at_p);
}
