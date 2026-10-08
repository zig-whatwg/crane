//! Persistent parsers retain their loader independently of the initiating run.
const std = @import("std");
const html = @import("html");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const engine = @import("engine");

const LoaderContext = struct {
    allocator: std.mem.Allocator,
    references: usize = 1,
    releases: *usize,

    fn create(releases: *usize) !*LoaderContext {
        const self = try std.testing.allocator.create(LoaderContext);
        self.* = .{ .allocator = std.testing.allocator, .releases = releases };
        return self;
    }

    fn retain(context: ?*anyopaque) void {
        const self: *LoaderContext = @ptrCast(@alignCast(context.?));
        self.references += 1;
    }

    fn release(context: ?*anyopaque) void {
        const self: *LoaderContext = @ptrCast(@alignCast(context.?));
        self.releases.* += 1;
        self.references -= 1;
        if (self.references == 0) self.allocator.destroy(self);
    }

    fn load(context: ?*anyopaque, _: []const u8) ?[]const u8 {
        const self: *LoaderContext = @ptrCast(@alignCast(context.?));
        std.debug.assert(self.references > 0);
        return null;
    }

    fn descriptor(self: *LoaderContext) html.scripted_parser.ScriptLoader {
        return .{ .context = self, .loadScript = &load, .retain = &retain, .release = &release };
    }
};

test "an acquired loader outlives its initiating owner" {
    var releases: usize = 0;
    const context = try LoaderContext.create(&releases);
    var owned = context.descriptor().acquire();
    try std.testing.expectEqual(@as(usize, 2), context.references);
    LoaderContext.release(context);
    try std.testing.expect(owned.load("/late.js") == null);
    owned.deinit();
    try std.testing.expectEqual(@as(usize, 2), releases);
}

test "a complete-input parser releases its loader on synchronous EOF" {
    interfaces.process_hooks.startHooksForTest();
    const allocator = std.testing.allocator;
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(allocator, .{});
    defer ctx.deinit();
    var releases: usize = 0;
    const context = try LoaderContext.create(&releases);
    defer LoaderContext.release(context);
    const document = try html.scripted_parser.parseHTMLWithScripting(allocator, &ctx, "<!doctype html><p>done", .{ .script_loader = context.descriptor() });
    defer interfaces.Document.deinit(document);
    try std.testing.expectEqual(@as(usize, 1), context.references);
    try std.testing.expectEqual(@as(usize, 1), releases);
    try std.testing.expect(dom.document_internals.getInternal(document).?.active_parser == null);
}

test "a waiting parser releases its loader after its run owner disappears and it is canceled" {
    interfaces.process_hooks.startHooksForTest();
    const allocator = std.testing.allocator;
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(allocator, .{});
    defer ctx.deinit();
    const document = try interfaces.Document.init(allocator, &ctx);
    defer interfaces.Document.deinit(document);
    var releases: usize = 0;
    const context = try LoaderContext.create(&releases);
    const parser = try html.scripted_parser.DocumentParser.createComplete(allocator, &ctx, document, "<p>later", .{ .script_loader = context.descriptor() });
    try std.testing.expect(dom.document_lifecycle.associateParser(document, parser));
    parser.release(); // Document retains the waiting parser.
    LoaderContext.release(context); // The initiating run has already returned.
    try std.testing.expectEqual(@as(usize, 1), releases);
    dom.document_lifecycle.discardParser(document, null);
    try std.testing.expectEqual(@as(usize, 2), releases);
    try std.testing.expect(dom.document_internals.getInternal(document).?.active_parser == null);
}

test "document destruction releases a waiting parser's loader" {
    interfaces.process_hooks.startHooksForTest();
    const allocator = std.testing.allocator;
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(allocator, .{});
    defer ctx.deinit();
    var releases: usize = 0;
    const context = try LoaderContext.create(&releases);
    defer LoaderContext.release(context);
    const document = try interfaces.Document.init(allocator, &ctx);
    const parser = try html.scripted_parser.DocumentParser.createComplete(allocator, &ctx, document, "<p>later", .{ .script_loader = context.descriptor() });
    try std.testing.expect(dom.document_lifecycle.associateParser(document, parser));
    parser.release();
    interfaces.Document.deinit(document);
    try std.testing.expectEqual(@as(usize, 1), context.references);
    try std.testing.expectEqual(@as(usize, 1), releases);
}

test "a suspended parser reaches EOF after the initiating owner returned" {
    interfaces.process_hooks.startHooksForTest();
    const allocator = std.testing.allocator;
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(allocator, .{});
    defer ctx.deinit();
    const document = try interfaces.Document.init(allocator, &ctx);
    defer interfaces.Document.deinit(document);
    var releases: usize = 0;
    const context = try LoaderContext.create(&releases);
    const parser = try html.scripted_parser.DocumentParser.createComplete(allocator, &ctx, document, "<p>later", .{ .script_loader = context.descriptor() });
    try std.testing.expect(dom.document_lifecycle.associateParser(document, parser));
    parser.input_stream.complete = false;
    parser.input_stream.processInserted();
    try std.testing.expect(!parser.input_stream.eof_processed);
    parser.release();
    LoaderContext.release(context);
    try std.testing.expectEqual(@as(usize, 1), releases);
    parser.input_stream.complete = true;
    parser.input_stream.processInserted(); // Its retained pump can release Document's last reference at EOF.
    try std.testing.expectEqual(@as(usize, 2), releases);
    try std.testing.expect(dom.document_internals.getInternal(document).?.active_parser == null);
}

test "a DOM adapter defaults to transient strong roots" {
    interfaces.process_hooks.startHooksForTest();
    const allocator = std.testing.allocator;
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(allocator, .{});
    defer ctx.deinit();
    const document = try interfaces.Document.init(allocator, &ctx);
    defer interfaces.Document.deinit(document);
    var adapter = html.parser_script_execution.DomTreeAdapter.init(allocator, &ctx, document);
    defer adapter.deinit();
    try std.testing.expectEqual(.strong_roots, adapter.ownership_mode);
}

const WindowCapture = struct {
    window: ?*runtime.Instance = null,

    fn create(realm: runtime.Context, _: runtime.JSValue, context: ?*anyopaque) ?*runtime.Instance {
        const self: *WindowCapture = @ptrCast(@alignCast(context orelse return null));
        self.window = interfaces.Window.init(std.testing.allocator, realm) catch return null;
        return self.window;
    }
};

fn expectDocumentTracedParser() !void {
    const allocator = std.testing.allocator;
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    interfaces.process_hooks.startHooksForTest();
    try engine.initializeEngine(.{});
    var host = @import("html_core").agent_host.AgentHost.init(allocator);
    defer host.deinit();
    const agent = try engine.createAgent(.{
        .can_block = false,
        .from_snapshot = false,
        .allocator = allocator,
        .host = &host,
        .hooks = &.{},
    });
    defer engine.destroyAgent(agent);
    var capture = WindowCapture{};
    const realm = try engine.createWindowRealm(&.{
        .agent = agent,
        .allocator = allocator,
        .from_snapshot = false,
        .timer = null,
        .create_global_object = WindowCapture.create,
        .host = &capture,
    });
    defer engine.destroyWindowRealm(realm, .global_detached);
    const window = capture.window orelse return error.NoWindow;
    const document = try interfaces.Document.init(allocator, realm);
    dom.window_globals.setDocument(window, document);
    dom.document_browsing_context.setWindow(document, window);

    const parser = try html.scripted_parser.DocumentParser.createComplete(allocator, realm, document, "<!doctype html><html><body><div>waiting", .{});
    defer parser.release();
    try std.testing.expect(dom.document_lifecycle.associateParser(document, parser));
    parser.input_stream.complete = false;
    parser.input_stream.processInserted();
    try std.testing.expect(!parser.input_stream.eof_processed);
    const current = parser.tree_builder.currentNode() orelse return error.NoCurrentNode;
    const instance = parser.adapter.getDomNode(current) orelse return error.NoCurrentDOMNode;
    try std.testing.expect(engine.hasWrapper(instance));
    // An independent Owned root makes the suspended Document/parser/node
    // cycle permanently reachable. Its nodes must instead be Document edges.
    try std.testing.expectEqual(@as(usize, 0), parser.adapter.holds.items.len);
    try std.testing.expectEqual(.document_traced, parser.adapter.ownership_mode);
}

test "a suspended DocumentParser traces wrappers without independent roots" {
    const Run = struct {
        fn run(result: *?anyerror) void {
            expectDocumentTracedParser() catch |err| {
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    if (result) |err| return err;
}
