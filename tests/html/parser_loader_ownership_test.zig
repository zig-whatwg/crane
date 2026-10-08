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

/// A window realm with an engine, made the way a page's is, for the adapter
/// tests below: its Document is the window's.
const EngineRealm = struct {
    host: @import("html_core").agent_host.AgentHost,
    agent: *engine.Agent,
    realm: runtime.Context,
    capture: WindowCapture,
    document: *runtime.Instance,

    fn open(self: *EngineRealm, allocator: std.mem.Allocator) !void {
        self.host = @import("html_core").agent_host.AgentHost.init(allocator);
        errdefer self.host.deinit();
        self.agent = try engine.createAgent(.{
            .can_block = false,
            .from_snapshot = false,
            .allocator = allocator,
            .host = &self.host,
            .hooks = &.{},
        });
        errdefer engine.destroyAgent(self.agent);
        self.capture = .{};
        self.realm = try engine.createWindowRealm(&.{
            .agent = self.agent,
            .allocator = allocator,
            .from_snapshot = false,
            .timer = null,
            .create_global_object = WindowCapture.create,
            .host = &self.capture,
        });
        const window = self.capture.window orelse return error.NoWindow;
        self.document = try interfaces.Document.init(allocator, self.realm);
        dom.window_globals.setDocument(window, self.document);
        dom.document_browsing_context.setWindow(self.document, window);
    }

    fn close(self: *EngineRealm) void {
        engine.destroyWindowRealm(self.realm, .global_detached);
        engine.destroyAgent(self.agent);
        self.host.deinit();
    }
};

fn expectTransientAdapterDefaults() !void {
    const allocator = std.testing.allocator;
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    interfaces.process_hooks.startHooksForTest();
    try engine.initializeEngine(.{});
    var page: EngineRealm = undefined;
    try page.open(allocator);
    defer page.close();

    // An adapter no scripted parser owns: no rescuer, so nothing is rooted
    // on its behalf.
    var adapter = html.parser_script_execution.DomTreeAdapter.init(allocator, page.realm, page.document);
    var adapter_live = true;
    defer if (adapter_live) adapter.deinit();
    try std.testing.expect(adapter.rescuer == null);

    const TreeNode = @import("html_core").parser.TreeNode;
    var tree_nodes: [3]*TreeNode = undefined;
    var made: usize = 0;
    defer for (tree_nodes[0..made]) |tree_node| tree_node.deinit();
    var created: [3]*runtime.Instance = undefined;
    var generations: [3]u64 = undefined;
    for ([_][]const u8{ "div", "span", "p" }, 0..) |local_name, i| {
        tree_nodes[i] = try TreeNode.initElement(allocator, local_name, .html);
        made += 1;
        try adapter.onNodeCreated(tree_nodes[i]);
        created[i] = adapter.getDomNode(tree_nodes[i]) orelse return error.NoDOMNode;
        generations[i] = runtime.SlabAllocator.generationOf(created[i]);
        // No wrapper and no root per created node (parser holds design 5.1,
        // 5.4: only an element its creation wrapped is held, until its first
        // insertion attempt).
        try std.testing.expect(!engine.hasWrapper(created[i]));
    }
    try std.testing.expectEqual(@as(usize, 0), adapter.pending.items.len);

    // An aborted transient parse: nothing was inserted. Its unwrapped
    // orphans are the adapter's alone, and it frees them.
    adapter.deinit();
    adapter_live = false;
    for (created, generations) |node, generation| {
        try std.testing.expect(runtime.SlabAllocator.generationOf(node) != generation);
    }
}

test "an adapter no scripted parser owns roots nothing per node and frees its orphans" {
    const Run = struct {
        fn run(result: *?anyerror) void {
            expectTransientAdapterDefaults() catch |err| {
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    if (result) |err| return err;
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
    // The parser holds its open elements natively (parser holds design
    // 5.1): no wrapper, no pending hold, no rescued root, and so no
    // independent root keeping the suspended Document/parser graph.
    try std.testing.expect(!engine.hasWrapper(instance));
    try std.testing.expectEqual(@as(usize, 0), parser.adapter.pending.items.len);
    try std.testing.expectEqual(@as(usize, 0), parser.rescues.items.len);
}

test "a suspended DocumentParser holds its open elements with no wrapper and no root" {
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
