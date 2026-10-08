//! The live parser holds the nodes its own structures name - the stack of
//! open elements, the head and form element pointers - natively, with no
//! wrapper per node (tmp/plans/parser-holds-design.md 5.1). When script
//! detaches a tree that contains one of them, the parser rescues that tree's
//! ROOT: it roots that one wrapper from a fixed, collectible member of its
//! Document until it ends (5.3). Blink traces the same structures
//! (HTMLConstructionSite::Trace); WebKit's stack records own their nodes.
//!
//! Each test runs a real Browser on a thread of its own: tests/html is one
//! executable, and a Browser's agent belongs to the thread that made it.
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

fn openBrowser() !*browser_mod.Browser {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    errdefer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    return browser;
}

/// The element with `id` in `document`, found natively: no wrapper is made.
fn byId(document: *runtime.Instance, id: []const u8) !*runtime.Instance {
    return (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned(id))) orelse error.NoSuchElement;
}

fn activeParser(document: *runtime.Instance) !*scripted_parser.DocumentParser {
    return dom.document_internals.getInternal(document).?.active_parser orelse error.NoParser;
}

fn textOf(node: *runtime.Instance) ![]u8 {
    var text = try interfaces.Node.get_textContent(node);
    defer if (text) |*value| value.deinit(testing.allocator);
    return testing.allocator.dupe(u8, (text orelse return error.NoText).asSlice());
}

const Saved = struct {
    node: *runtime.Instance,
    generation: u64,

    fn of(node: *runtime.Instance) Saved {
        return .{ .node = node, .generation = runtime.SlabAllocator.generationOf(node) };
    }

    fn alive(self: Saved) bool {
        return runtime.SlabAllocator.generationOf(self.node) == self.generation;
    }
};

fn untouchedNodesStayUnwrapped() !void {
    const browser = try openBrowser();
    defer browser.deinit();
    const page = browser.current_context.?;
    try page.loadHTML("<!doctype html><body><div id=a><p id=b><span id=c>text</span></p></div><script>window.done = 1;</script>", .{ .base_url = "about:blank" });
    const document = page.document_instance orelse return error.NoDocument;
    for ([_][]const u8{ "a", "b", "c" }) |id| {
        if (engine.hasWrapper(try byId(document, id))) {
            std.debug.print("#{s} was wrapped by a parse no script touched\n", .{id});
            return error.ParsedNodeWrapped;
        }
    }
}

test "a parsed node no script touched has no wrapper" {
    try onFreshThread(untouchedNodesStayUnwrapped);
}

fn detachedHeldTreeIsRescuedByItsRoot() !void {
    const browser = try openBrowser();
    defer browser.deinit();
    const page = browser.current_context.?;
    try page.runScript("document.open(); document.write('<!doctype html><body><div id=a><p id=b><span id=c>')");
    const document = page.document_instance orelse return error.NoDocument;
    const parser = try activeParser(document);
    const a = Saved.of(try byId(document, "a"));
    const b = Saved.of(try byId(document, "b"));
    const c = Saved.of(try byId(document, "c"));
    try testing.expectEqual(@as(usize, 0), parser.rescues.items.len);
    // Replace all removes #a without script ever seeing it.
    try page.runScript("document.body.innerHTML = ''");
    try testing.expectEqual(@as(usize, 1), parser.rescues.items.len);
    try testing.expect(engine.hasWrapper(a.node));
    // The root's wrapper alone keeps the tree: no wrapper below it.
    try testing.expect(!engine.hasWrapper(b.node));
    try testing.expect(!engine.hasWrapper(c.node));
    try collect(browser);
    try testing.expect(a.alive() and b.alive() and c.alive());
    // The parser keeps building into the detached tree.
    try page.runScript("document.write('still parsed</span></p></div>')");
    const text = try textOf(c.node);
    defer testing.allocator.free(text);
    try testing.expectEqualStrings("still parsed", text);
    try page.runScript("document.close()");
    try testing.expect(dom.document_internals.getInternal(document).?.active_parser == null);
    // Released at the parser's end: nothing reaches the tree any more.
    try collect(browser);
    try testing.expect(!a.alive());
}

test "a held subtree script detaches is rescued through its root alone, until the parser ends" {
    try onFreshThread(detachedHeldTreeIsRescuedByItsRoot);
}

fn removalsOfUnheldNodesRescueNothing() !void {
    const browser = try openBrowser();
    defer browser.deinit();
    const page = browser.current_context.?;
    try page.runScript("document.open(); document.write('<!doctype html><body><p id=done>closed</p><div id=open>')");
    const document = page.document_instance orelse return error.NoDocument;
    const parser = try activeParser(document);
    // A popped element and a node the parser never made.
    try page.runScript(
        \\document.getElementById('done').remove();
        \\document.body.appendChild(document.createElement('i')).remove();
    );
    try testing.expectEqual(@as(usize, 0), parser.rescues.items.len);
    try page.runScript("window.stash = document.getElementById('open'); stash.remove()");
    try testing.expectEqual(@as(usize, 1), parser.rescues.items.len);
    // The same root detached again is already rescued.
    try page.runScript("document.body.appendChild(stash); stash.remove()");
    try testing.expectEqual(@as(usize, 1), parser.rescues.items.len);
    // One fixed Document member holds the parser's rescued roots.
    const kept = engine.tracedValue(document, .{ .name = "document-parser:kept-roots" }) orelse return error.NoKeptRoots;
    kept.release();
    try page.runScript("document.close()");
}

test "removing nodes the parser does not hold rescues nothing, and a root is rescued once" {
    try onFreshThread(removalsOfUnheldNodesRescueNothing);
}

fn templateOnTheStack() !void {
    const browser = try openBrowser();
    defer browser.deinit();
    const page = browser.current_context.?;
    try page.runScript("document.open(); document.write('<!doctype html><body><template id=t><div id=in>')");
    const document = page.document_instance orelse return error.NoDocument;
    const parser = try activeParser(document);
    const template = Saved.of(try byId(document, "t"));
    // The held div is in the template's contents: its host-including
    // ancestor is the template that replace all removes.
    try page.runScript("document.body.innerHTML = ''");
    try testing.expectEqual(@as(usize, 1), parser.rescues.items.len);
    try testing.expect(engine.hasWrapper(template.node));
    try collect(browser);
    try testing.expect(template.alive());
    try page.runScript("document.write('<span id=s></span></div></template>'); document.close()");
    const content = try interfaces.HTMLTemplateElement.get_content(template.node);
    _ = (try interfaces.DocumentFragment.call_getElementById(content, runtime.DOMString.initInterned("s"))) orelse return error.LateContentMissing;
}

test "a template on the stack whose element script removes keeps receiving its contents" {
    try onFreshThread(templateOnTheStack);
}

fn headElementPointer() !void {
    const browser = try openBrowser();
    defer browser.deinit();
    const page = browser.current_context.?;
    try page.runScript("document.open(); document.write('<!doctype html><head><title>x</title></head>')");
    const document = page.document_instance orelse return error.NoDocument;
    const parser = try activeParser(document);
    const head = Saved.of((try interfaces.Document.get_head(document)) orelse return error.NoHead);
    // The head is popped; only the head element pointer holds it.
    try page.runScript("document.documentElement.innerHTML = ''");
    try testing.expectEqual(@as(usize, 1), parser.rescues.items.len);
    try collect(browser);
    try testing.expect(head.alive());
    // "After head": a meta goes into the head element pointer's element.
    try page.runScript("document.write('<meta id=m>')");
    const meta = (try interfaces.Node.get_lastChild(head.node)) orelse return error.MetaMissing;
    var name = try interfaces.Element.get_localName(meta);
    defer name.deinit(meta.ctx.allocator);
    try testing.expectEqualStrings("meta", name.asSlice());
    try page.runScript("document.close()");
}

test "the head element pointer holds a popped head that script removes" {
    try onFreshThread(headElementPointer);
}

fn frameRemovedWithRescuedRoot() !void {
    const browser = try openBrowser();
    defer browser.deinit();
    const page = browser.current_context.?;
    try page.loadHTML("<!doctype html><body><iframe id=f></iframe></body>", .{ .base_url = "http://example.test/holds" });
    _ = try browser.runEventLoopBlocking(20);
    try page.runScript(
        \\const frameDocument = document.getElementById('f').contentDocument;
        \\frameDocument.open();
        \\frameDocument.write('<!doctype html><body><div id=held><span>');
        \\frameDocument.body.innerHTML = '';
    );
    const parent = page.document_instance orelse return error.NoDocument;
    const frame = try byId(parent, "f");
    const child = (try interfaces.HTMLIFrameElement.get_contentDocument(frame)) orelse return error.NoFrameDocument;
    const parser = try activeParser(child);
    try testing.expectEqual(@as(usize, 1), parser.rescues.items.len);
    // The frame's realm ends with a suspended parser and a rescued root: its
    // list is freed without engine calls, and std.testing.allocator sees no leak.
    try page.runScript("document.getElementById('f').remove()");
    _ = try browser.runEventLoopBlocking(20);
    try collect(browser);
}

test "a removed frame's suspended parser frees its rescued roots without a leak" {
    try onFreshThread(frameRemovedWithRescuedRoot);
}
