//! Parser-held nodes follow the Document's collectible graph, while active
//! parser calls keep detached nodes safe across replacement and collection.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const engine = @import("engine");
const scripted_parser = @import("html").scripted_parser;

fn onFreshThread(comptime exercise: fn () anyerror!void) !void {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            exercise() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

fn collect(browser: *browser_mod.Browser) !void {
    const Collect = struct {
        fn steps(data: ?*anyopaque) void {
            engine.requestGarbageCollection(@ptrCast(@alignCast(data.?)));
        }
    };
    const realm = browser.getRealm() orelse return error.NoRealm;
    const agent = browser.getAgent() orelse return error.NoAgent;
    try engine.runInRealm(realm, Collect.steps, agent);
    try engine.runInRealm(realm, Collect.steps, agent);
}

fn currentNode(parser: *scripted_parser.DocumentParser) !*runtime.Instance {
    const tree_node = parser.tree_builder.currentNode() orelse return error.NoCurrentNode;
    return parser.adapter.getDomNode(tree_node) orelse error.NoCurrentDOMNode;
}

fn detachedNodeUntilEOF() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    try page.runScript("document.open(); document.write('<!doctype html><body><div id=parser-held>')");
    const document = page.document_instance orelse return error.NoDocument;
    const parser = dom.document_internals.getInternal(document).?.active_parser orelse return error.NoParser;
    const node = try currentNode(parser);
    const generation = runtime.SlabAllocator.generationOf(node);
    try page.runScript("document.getElementById('parser-held').remove()");
    try collect(browser);
    try testing.expectEqual(generation, runtime.SlabAllocator.generationOf(node));
    try testing.expectEqual(node, try currentNode(parser));
    try testing.expectEqual(@as(usize, 0), parser.adapter.holds.items.len);
    try page.runScript("document.write('still parsed</div>')");
    var text = try interfaces.Node.get_textContent(node);
    defer if (text) |*value| value.deinit(testing.allocator);
    try testing.expectEqualStrings("still parsed", (text orelse return error.NoText).asSlice());
    try page.runScript("document.close()");
    try testing.expect(dom.document_internals.getInternal(document).?.active_parser == null);
    try collect(browser);
    try testing.expect(generation != runtime.SlabAllocator.generationOf(node));
}

test "parser-held detached nodes survive GC until EOF and collect after completion" {
    try onFreshThread(detachedNodeUntilEOF);
}

const LoaderLifetime = struct {
    references: usize = 1,
    releases: usize = 0,

    fn retain(data: ?*anyopaque) void {
        const self: *LoaderLifetime = @ptrCast(@alignCast(data.?));
        self.references += 1;
    }

    fn release(data: ?*anyopaque) void {
        const self: *LoaderLifetime = @ptrCast(@alignCast(data.?));
        self.references -= 1;
        self.releases += 1;
    }

    fn load(_: ?*anyopaque, _: []const u8) ?[]const u8 {
        return null;
    }

    fn descriptor(self: *LoaderLifetime) scripted_parser.ScriptLoader {
        return .{ .context = self, .retain = retain, .release = release, .loadScript = load };
    }
};

fn unreachableSuspendedCycle() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    var document_owner: ?engine.Owned = try browser.evaluateScript("document.implementation.createHTMLDocument('unreachable parser')");
    defer if (document_owner) |held| held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    const document = engine.convertToPlatformObject(realm, document_owner.?.borrow()) orelse return error.NoDocument;
    const document_generation = runtime.SlabAllocator.generationOf(document);
    var loader = LoaderLifetime{};
    const parser = try scripted_parser.DocumentParser.createComplete(testing.allocator, realm, document, "<!doctype html><body><div>waiting", .{ .script_loader = loader.descriptor() });
    var initiating_owner = true;
    defer if (initiating_owner) parser.release();
    try testing.expect(dom.document_lifecycle.associateParser(document, parser));
    parser.input_stream.complete = false;
    parser.input_stream.processInserted();
    const node = try currentNode(parser);
    const node_generation = runtime.SlabAllocator.generationOf(node);
    try testing.expect(!parser.input_stream.eof_processed);
    try testing.expectEqual(@as(usize, 0), parser.adapter.holds.items.len);
    parser.release();
    initiating_owner = false;
    document_owner.?.release();
    document_owner = null;
    try collect(browser);
    // A permanent parser Owned would root this Document/parser/node cycle.
    try testing.expect(document_generation != runtime.SlabAllocator.generationOf(document));
    try testing.expect(node_generation != runtime.SlabAllocator.generationOf(node));
    try testing.expectEqual(@as(usize, 1), loader.references);
    try testing.expectEqual(@as(usize, 1), loader.releases);
}

test "an unreachable suspended Document parser graph has no independent root" {
    try onFreshThread(unreachableSuspendedCycle);
}

const Reentry = struct {
    browser: *browser_mod.Browser,
    page: *browser_mod.Context,
    old_node: *runtime.Instance,
    old_generation: u64,
    new_node: ?*runtime.Instance = null,
    new_generation: u64 = 0,
    failure: ?anyerror = null,
    calls: usize = 0,

    fn finished(document: *runtime.Instance, parser: *scripted_parser.DocumentParser) void {
        const self: *Reentry = @ptrCast(@alignCast(parser.script_context.script_loader_ctx.?));
        self.calls += 1;
        self.replace(document) catch |err| {
            self.failure = err;
        };
    }

    fn replace(self: *Reentry, document: *runtime.Instance) !void {
        // Completion can replace the parser after pump returned, while the
        // old close still has native cleanup and stream restoration to do.
        try self.page.runScript("document.open(); document.write('<!doctype html><body><div id=replacement>')");
        const replacement = dom.document_internals.getInternal(document).?.active_parser orelse return error.NoReplacementParser;
        const node = try currentNode(replacement);
        self.new_node = node;
        self.new_generation = runtime.SlabAllocator.generationOf(node);
        try self.page.runScript("document.getElementById('replacement').remove()");
        try collect(self.browser);
        try testing.expectEqual(self.old_generation, runtime.SlabAllocator.generationOf(self.old_node));
        try testing.expectEqual(self.new_generation, runtime.SlabAllocator.generationOf(node));
        try testing.expectEqual(node, try currentNode(replacement));
    }
};

fn replacementDuringCompletion() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    try page.runScript("document.open(); document.write('<!doctype html><body><div id=old-parser>')");
    const document = page.document_instance orelse return error.NoDocument;
    const parser = dom.document_internals.getInternal(document).?.active_parser orelse return error.NoParser;
    const node = try currentNode(parser);
    var reentry: Reentry = .{ .browser = browser, .page = page, .old_node = node, .old_generation = runtime.SlabAllocator.generationOf(node) };
    parser.script_context.script_loader_ctx = &reentry;
    parser.on_finished = Reentry.finished;
    try page.runScript("document.getElementById('old-parser').remove(); document.close()");
    if (reentry.failure) |err| return err;
    try testing.expectEqual(@as(usize, 1), reentry.calls);
    const replacement = dom.document_internals.getInternal(document).?.active_parser orelse return error.NoReplacementParser;
    const replacement_node = reentry.new_node orelse return error.NoReplacementNode;
    try testing.expectEqual(replacement_node, try currentNode(replacement));
    try collect(browser);
    try testing.expect(reentry.old_generation != runtime.SlabAllocator.generationOf(node));
    // Old final cleanup must not remove the new parser's ownership edge.
    try testing.expectEqual(reentry.new_generation, runtime.SlabAllocator.generationOf(replacement_node));
    try page.runScript("document.write('replacement still works</div>'); document.close()");
    try testing.expect(dom.document_internals.getInternal(document).?.active_parser == null);
    try collect(browser);
    try testing.expect(reentry.new_generation != runtime.SlabAllocator.generationOf(replacement_node));
}

test "completion replacement keeps old in-flight nodes and preserves the successor graph" {
    try onFreshThread(replacementDuringCompletion);
}

const AbortReentry = struct {
    browser: *browser_mod.Browser,
    page: *browser_mod.Context,
    document: *runtime.Instance,
    parser: *scripted_parser.DocumentParser,
    old_node: *runtime.Instance,
    old_generation: u64,
    new_node: ?*runtime.Instance = null,
    new_generation: u64 = 0,
    calls: usize = 0,
    failure: ?anyerror = null,

    fn steps(data: ?*anyopaque, _: []const runtime.JSValue) runtime.EngineError!runtime.JSValue {
        const self: *AbortReentry = @ptrCast(@alignCast(data.?));
        self.replace() catch |err| {
            self.failure = err;
        };
        return .undefined;
    }

    fn replace(self: *AbortReentry) !void {
        self.calls += 1;
        // HTML's aborted flag makes document.open return unchanged. A host
        // parser association models replacement during the readiness callback
        // without mutating that flag merely to make the test reentrant.
        try self.page.runScript("document.open()");
        try testing.expect(dom.document_internals.getInternal(self.document).?.active_parser == self.parser);
        const base = dom.instance_bridge.getNodeBase(self.document) orelse return error.NoDocumentBase;
        try dom.mutation.replaceAll(@as(?*dom.NodeBase, null), base);
        const replacement = try scripted_parser.DocumentParser.createComplete(testing.allocator, self.document.ctx, self.document, "<!doctype html><body><div id=abort-replacement>", .{});
        defer replacement.release();
        try testing.expect(dom.document_lifecycle.associateParser(self.document, replacement));
        replacement.input_stream.complete = false;
        replacement.input_stream.processInserted();
        const node = try currentNode(replacement);
        self.new_node = node;
        self.new_generation = runtime.SlabAllocator.generationOf(node);
        const parent = (try interfaces.Node.get_parentNode(node)) orelse return error.NoParent;
        _ = try interfaces.Node.call_removeChild(parent, node);
        try collect(self.browser);
        try testing.expectEqual(self.old_generation, runtime.SlabAllocator.generationOf(self.old_node));
        try testing.expectEqual(self.new_generation, runtime.SlabAllocator.generationOf(node));
    }
};

fn replacementDuringAbortReadiness() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    try page.runScript("document.open(); document.write('<!doctype html><body><div id=abort-old>'); document.getElementById('abort-old').remove()");
    const document = page.document_instance orelse return error.NoDocument;
    const parser = dom.document_internals.getInternal(document).?.active_parser orelse return error.NoParser;
    const node = try currentNode(parser);
    var reentry: AbortReentry = .{ .browser = browser, .page = page, .document = document, .parser = parser, .old_node = node, .old_generation = runtime.SlabAllocator.generationOf(node) };
    const callback: engine.BuiltinFunction = .{ .steps = AbortReentry.steps, .data = &reentry };
    try engine.defineBuiltinFunction(document.ctx, "replaceParserDuringAbort", 0, &callback);
    try page.runScript(
        \\document.addEventListener('readystatechange', () => {
        \\  if (document.readyState === 'interactive') replaceParserDuringAbort();
        \\}, { once: true });
    );
    dom.document_lifecycle.abort(document);
    if (reentry.failure) |err| return err;
    try testing.expectEqual(@as(usize, 1), reentry.calls);
    const replacement = dom.document_internals.getInternal(document).?.active_parser orelse return error.NoReplacementParser;
    try testing.expect(replacement != parser);
    const replacement_node = reentry.new_node orelse return error.NoReplacementNode;
    try collect(browser);
    try testing.expect(reentry.old_generation != runtime.SlabAllocator.generationOf(node));
    try testing.expectEqual(reentry.new_generation, runtime.SlabAllocator.generationOf(replacement_node));
    try testing.expectEqual(replacement_node, try currentNode(replacement));
    dom.document_lifecycle.discardParser(document, replacement);
    try collect(browser);
    try testing.expect(reentry.new_generation != runtime.SlabAllocator.generationOf(replacement_node));
}

test "abort readiness replacement preserves old abort-stack nodes and the successor graph" {
    try onFreshThread(replacementDuringAbortReadiness);
}

fn numericPrototypeSetter() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    try page.runScript(
        \\globalThis.parserSetterCalls = 0;
        \\Object.defineProperty(Array.prototype, '0', {
        \\  configurable: true,
        \\  set() { ++parserSetterCalls; throw new Error('parser invoked a numeric prototype setter'); }
        \\});
        \\try {
        \\  document.open();
        \\  document.write('<!doctype html><body><p id=setter-control>parsed</p>');
        \\  document.close();
        \\} finally { delete Array.prototype[0]; }
        \\if (parserSetterCalls !== 0 || document.getElementById('setter-control').textContent !== 'parsed')
        \\  throw new Error('parser storage ran user prototype code');
    );
}

test "parser retention does not invoke numeric Array prototype setters" {
    try onFreshThread(numericPrototypeSetter);
}

fn suspendedRealmTeardown() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    try page.runScript("document.open(); document.write('<!doctype html><body><div id=retired-parser>'); document.getElementById('retired-parser').remove()");
    const document = page.document_instance orelse return error.NoDocument;
    const parser = dom.document_internals.getInternal(document).?.active_parser orelse return error.NoParser;
    const node = try currentNode(parser);
    const generation = runtime.SlabAllocator.generationOf(node);
    try browser.navigate("about:blank", .window);
    try collect(browser);
    try testing.expect(generation != runtime.SlabAllocator.generationOf(node));
}

test "realm teardown releases a suspended parser and its detached nodes" {
    try onFreshThread(suspendedRealmTeardown);
}

fn nativeCleanup() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(testing.allocator, .{});
    defer context.deinit();
    const document = try interfaces.Document.init(testing.allocator, &context);
    defer interfaces.Document.deinit(document);
    var loader = LoaderLifetime{};
    const parser = try scripted_parser.DocumentParser.createComplete(testing.allocator, &context, document, "<!doctype html><body><div>native", .{ .script_loader = loader.descriptor() });
    var initiating_owner = true;
    defer if (initiating_owner) parser.release();
    try testing.expect(dom.document_lifecycle.associateParser(document, parser));
    parser.input_stream.complete = false;
    parser.input_stream.processInserted();
    try testing.expect((try currentNode(parser)).ctx == &context);
    parser.release();
    initiating_owner = false;
    dom.document_lifecycle.discardParser(document, null);
    dom.document_lifecycle.discardParser(document, null);
    try testing.expect(dom.document_internals.getInternal(document).?.active_parser == null);
    try testing.expectEqual(@as(usize, 1), loader.references);
    try testing.expectEqual(@as(usize, 1), loader.releases);
    const completed = try scripted_parser.parseHTMLWithScripting(testing.allocator, &context, "<p>implicit root", .{});
    defer interfaces.Document.deinit(completed);
    try testing.expect(dom.document_internals.getInternal(completed).?.active_parser == null);
}

test "engine-less parser cancellation and EOF release native ownership" {
    try onFreshThread(nativeCleanup);
}

fn parserConstructionFailure(allocator: std.mem.Allocator, context: runtime.Context) !void {
    const document = try interfaces.Document.init(testing.allocator, context);
    defer interfaces.Document.deinit(document);
    var loader = LoaderLifetime{};
    const parser = try scripted_parser.DocumentParser.createComplete(allocator, context, document, "<!doctype html><body><div>allocation failure", .{ .script_loader = loader.descriptor() });
    parser.release();
    try testing.expectEqual(@as(usize, 1), loader.references);
    try testing.expectEqual(@as(usize, 1), loader.releases);
}

fn allocationFailureCleanup() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(testing.allocator, .{});
    defer context.deinit();
    try testing.checkAllAllocationFailures(testing.allocator, parserConstructionFailure, .{&context});
}

test "parser construction allocation failures release native stages and loader ownership" {
    try onFreshThread(allocationFailureCleanup);
}
