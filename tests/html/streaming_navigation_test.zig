//! A navigation's document is parsed as its response body arrives (HTML 7.5.1
//! "load an HTML document": each networking task fills the parser's input
//! byte stream; when no more bytes are available the parser gets the implied
//! EOF). The parser owns the body's reader for its whole life - the bytes,
//! the decoding state and EOF share the parser's lifetime.
//!
//! These tests feed a navigation parser from a body pipe the test fills, in a
//! realm with no engine and no event loop: each `readNetworkInput` call is
//! the networking task the pipe's notification would queue.
//!
//! tests/html is one executable: the engine may already be started.
const std = @import("std");
const testing = std.testing;
const html = @import("html");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const fetch = @import("fetch");

const DocumentParser = html.scripted_parser.DocumentParser;
const PipeSource = fetch.internal.PipeSource;
const StreamedBody = @import("html_core").navigation.fetch_integration.StreamedBody;

/// The test's network end of a body: it pushes the bytes and says when the
/// transfer was cancelled.
const Network = struct {
    source: *PipeSource,
    cancelled: bool = false,

    fn cancel(context: *anyopaque) void {
        const self: *Network = @ptrCast(@alignCast(context));
        self.cancelled = true;
    }

    fn holderAlive(_: *anyopaque) bool {
        return true;
    }

    /// A source with this producer and one reader: the body the parser takes.
    fn open(self: *Network) !*StreamedBody {
        self.source = try PipeSource.create(testing.allocator);
        self.source.producer = .{ .context = self, .cancel = &cancel };
        const pipe = try self.source.branch();
        return StreamedBody.create(testing.allocator, pipe, .{ .context = self, .alive = &holderAlive });
    }
};

const Realm = struct {
    ctx: runtime.ContextData,

    fn init(self: *Realm) !void {
        interfaces.process_hooks.startHooksForTest();
        runtime.initializeRuntime(testing.allocator);
        self.ctx = try runtime.ContextData.init(testing.allocator, .{});
    }

    fn deinit(self: *Realm) void {
        self.ctx.deinit();
        runtime.deinitializeRuntime();
    }
};

/// A loading document whose navigation parser reads `pipe`, associated as
/// the document's active parser (which owns it from here).
fn streamingDocument(realm: *Realm, pipe: *StreamedBody, content_type: ?[]const u8) !struct { *runtime.Instance, *DocumentParser } {
    const document = try interfaces.Document.initWith(testing.allocator, &realm.ctx, .{ .ready_state = ._loading_ });
    errdefer interfaces.Document.deinit(document);
    const parser = try DocumentParser.createStreaming(testing.allocator, &realm.ctx, document, .{
        .byte_stream = .{ .content_type = content_type },
        .body_stream = pipe,
    });
    try testing.expect(dom.document_lifecycle.associateParser(document, parser));
    parser.release(); // The document's reference keeps it.
    return .{ document, parser };
}

fn textOf(document: *runtime.Instance, id: []const u8) !?[]u8 {
    const element = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned(id))) orelse return null;
    var content = (try interfaces.Node.get_textContent(element)) orelse return null;
    defer content.deinit(element.ctx.allocator);
    return try testing.allocator.dupe(u8, content.asSlice());
}

fn expectText(document: *runtime.Instance, id: []const u8, expected: ?[]const u8) !void {
    const actual = try textOf(document, id);
    defer if (actual) |a| testing.allocator.free(a);
    if (expected) |e| {
        try testing.expect(actual != null);
        try testing.expectEqualStrings(e, actual.?);
    } else try testing.expect(actual == null);
}

fn parserOf(document: *runtime.Instance) ?*anyopaque {
    return dom.document_internals.getInternal(document).?.active_parser;
}

test "a navigation parser parses what has arrived and waits for the rest of its body" {
    var realm: Realm = undefined;
    try realm.init();
    defer realm.deinit();
    var network: Network = undefined;
    network = .{ .source = undefined };
    const pipe = try network.open();
    const document, const parser = try streamingDocument(&realm, pipe, "text/html; charset=utf-8");
    defer interfaces.Document.deinit(document);

    network.source.push("<!doctype html><body><p id=a>one</p>");
    parser.readNetworkInput();
    // The first chunk is in the DOM; the document is still loading, its
    // parser waiting for more rather than at EOF.
    try expectText(document, "a", "one");
    try expectText(document, "b", null);
    try testing.expect(parserOf(document) != null);

    network.source.push("<p id=b>two</p>");
    network.source.finish();
    parser.readNetworkInput();
    // The end of the body is the implied EOF: the parser finished.
    try expectText(document, "b", "two");
    try testing.expect(parserOf(document) == null);
    try testing.expect(!network.cancelled);
}

test "a UTF-8 sequence split between two chunks decodes as one character" {
    var realm: Realm = undefined;
    try realm.init();
    defer realm.deinit();
    var network: Network = .{ .source = undefined };
    const pipe = try network.open();
    const document, const parser = try streamingDocument(&realm, pipe, "text/html; charset=utf-8");
    defer interfaces.Document.deinit(document);

    network.source.push("<!doctype html><p id=a>caf\xC3");
    parser.readNetworkInput();
    network.source.push("\xA9</p>");
    network.source.finish();
    parser.readNetworkInput();
    try expectText(document, "a", "caf\u{E9}");
    try testing.expect(parserOf(document) == null);
}

test "a meta charset past the prescan window changes the encoding of a streamed body" {
    var realm: Realm = undefined;
    try realm.init();
    defer realm.deinit();
    var network: Network = .{ .source = undefined };
    const pipe = try network.open();
    // No transport charset: the prescan decides, tentatively.
    const document, const parser = try streamingDocument(&realm, pipe, "text/html");
    defer interfaces.Document.deinit(document);

    // 1,100 bytes of comment: the prescan's 1,024 bytes find no meta.
    var padding: [1100]u8 = undefined;
    @memset(&padding, 'x');
    network.source.push("<!doctype html><!--");
    network.source.push(&padding);
    network.source.push("-->");
    parser.readNetworkInput();
    // windows-1251's 0xE9 is U+0439; the default (windows-1252) reads U+00E9.
    network.source.push("<meta charset=windows-1251><p id=a>\xE9</p>");
    network.source.finish();
    parser.readNetworkInput();
    try expectText(document, "a", "\u{439}");
}

test "the prescan waits for its window before deciding a tentative encoding" {
    var realm: Realm = undefined;
    try realm.init();
    defer realm.deinit();
    var network: Network = .{ .source = undefined };
    const pipe = try network.open();
    const document, const parser = try streamingDocument(&realm, pipe, "text/html");
    defer interfaces.Document.deinit(document);

    // The meta is split between two chunks of the first 1,024 bytes.
    network.source.push("<!doctype html><meta char");
    parser.readNetworkInput();
    network.source.push("set=windows-1251><p id=a>\xE9</p>");
    network.source.finish();
    parser.readNetworkInput();
    try expectText(document, "a", "\u{439}");
    try testing.expect(parserOf(document) == null);
}

test "a body that fails part-way ends the document with what arrived" {
    var realm: Realm = undefined;
    try realm.init();
    defer realm.deinit();
    var network: Network = .{ .source = undefined };
    const pipe = try network.open();
    const document, const parser = try streamingDocument(&realm, pipe, "text/html; charset=utf-8");
    defer interfaces.Document.deinit(document);

    network.source.push("<!doctype html><p id=a>one");
    parser.readNetworkInput();
    network.source.fail(.{ .kind = .network });
    parser.readNetworkInput();
    try expectText(document, "a", "one");
    try testing.expect(parserOf(document) == null);
}

test "a parser detached mid-body lets its body go, which stops the transfer" {
    var realm: Realm = undefined;
    try realm.init();
    defer realm.deinit();
    var network: Network = .{ .source = undefined };
    const pipe = try network.open();
    const document, const parser = try streamingDocument(&realm, pipe, "text/html; charset=utf-8");
    defer interfaces.Document.deinit(document);

    network.source.push("<!doctype html><p id=a>one");
    parser.readNetworkInput();
    try testing.expect(!network.cancelled);
    // document.open, window.stop, an abort: the document drops its parser.
    dom.document_lifecycle.discardParser(document, null);
    try testing.expect(network.cancelled);
}

test "a document destroyed mid-body lets its parser's body go" {
    var realm: Realm = undefined;
    try realm.init();
    defer realm.deinit();
    var network: Network = .{ .source = undefined };
    const pipe = try network.open();
    const document, const parser = try streamingDocument(&realm, pipe, "text/html; charset=utf-8");

    network.source.push("<!doctype html><p id=a>one");
    parser.readNetworkInput();
    interfaces.Document.deinit(document);
    try testing.expect(network.cancelled);
}
