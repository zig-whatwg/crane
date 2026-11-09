//! The live parser holds the nodes its own structures name - the stack of
//! open elements, the head and form element pointers, the formatting list -
//! natively, with no wrapper per node (tmp/plans/parser-holds-design.md
//! 5.1), each counted. When script detaches a tree that contains one of
//! them, nothing is rooted for it: since the wrapper redesign's P6 its
//! Document traces the parser's held nodes and their trees (the rescue that
//! rooted the detached tree's root from a Document member is gone). Blink
//! traces the same structures (HTMLConstructionSite::Trace); WebKit's stack
//! records own their nodes.
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
    return openPage("<!doctype html><body></body>", "about:blank");
}

/// A Browser whose page is `markup`, loaded once into the navigation's fresh
/// document (a load never reuses a document that has children here).
fn openPage(markup: []const u8, url: []const u8) !*browser_mod.Browser {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    errdefer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(markup, .{ .base_url = url });
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
    const browser = try openPage("<!doctype html><body><div id=a><p id=b><span id=c>text</span></p></div><script>window.done = 1;</script>", "about:blank");
    defer browser.deinit();
    const page = browser.current_context.?;
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

fn detachedHeldTreeIsKept() !void {
    const browser = try openBrowser();
    defer browser.deinit();
    const page = browser.current_context.?;
    try page.runScript("document.open(); document.write('<!doctype html><body><div id=a><p id=b><span id=c>')");
    const document = page.document_instance orelse return error.NoDocument;
    _ = try activeParser(document);
    const a = Saved.of(try byId(document, "a"));
    const b = Saved.of(try byId(document, "b"));
    const c = Saved.of(try byId(document, "c"));
    // Replace all removes #a without script ever seeing it.
    try page.runScript("document.body.innerHTML = ''");
    // Nothing is wrapped for it: the parser's counted holds keep the tree.
    try testing.expect(!engine.hasWrapper(a.node));
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

test "a held subtree script detaches is kept, unwrapped, until the parser ends" {
    try onFreshThread(detachedHeldTreeIsKept);
}

fn removalsRootNothing() !void {
    const browser = try openBrowser();
    defer browser.deinit();
    const page = browser.current_context.?;
    try page.runScript("document.open(); document.write('<!doctype html><body><p id=done>closed</p><div id=open>')");
    const document = page.document_instance orelse return error.NoDocument;
    const open = Saved.of(try byId(document, "open"));
    // A popped element, a node the parser never made, and - by replace all,
    // unseen by script - an element the parser holds.
    try page.runScript(
        \\document.getElementById('done').remove();
        \\document.body.appendChild(document.createElement('i')).remove();
        \\document.body.innerHTML = '';
    );
    // No wrapper is made for the held element, and no Document member
    // roots anything (the parsers' kept-roots array went with the rescue).
    try testing.expect(!engine.hasWrapper(open.node));
    if (engine.tracedValue(document, .{ .name = "document-parser:kept-roots" })) |kept| {
        kept.release();
        return error.KeptRootsMade;
    }
    try collect(browser);
    try testing.expect(open.alive());
    try page.runScript("document.close()");
}

test "removing nodes the parser holds, or does not, roots nothing and wraps nothing" {
    try onFreshThread(removalsRootNothing);
}

fn templateOnTheStack() !void {
    const browser = try openBrowser();
    defer browser.deinit();
    const page = browser.current_context.?;
    try page.runScript("document.open(); document.write('<!doctype html><body><template id=t><div id=in>')");
    const document = page.document_instance orelse return error.NoDocument;
    const template = Saved.of(try byId(document, "t"));
    // The held div is in the template's contents: its host-including
    // ancestor is the template that replace all removes.
    try page.runScript("document.body.innerHTML = ''");
    try testing.expect(!engine.hasWrapper(template.node));
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
    const head = Saved.of((try interfaces.Document.get_head(document)) orelse return error.NoHead);
    // The head is popped; only the head element pointer holds it.
    try page.runScript("document.documentElement.innerHTML = ''");
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

fn frameRemovedWithDetachedHeldTree() !void {
    const browser = try openPage("<!doctype html><body><iframe id=f></iframe></body>", "http://example.test/holds");
    defer browser.deinit();
    const page = browser.current_context.?;
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
    _ = try activeParser(child);
    // The frame's realm ends with a suspended parser holding a detached
    // tree: std.testing.allocator sees no leak.
    try page.runScript("document.getElementById('f').remove()");
    _ = try browser.runEventLoopBlocking(20);
    try collect(browser);
}

test "a removed frame's suspended parser holding a detached tree ends without a leak" {
    try onFreshThread(frameRemovedWithDetachedHeldTree);
}

const DiscardedOnStack = struct {
    browser: *browser_mod.Browser,
    parser: *scripted_parser.DocumentParser,
    held: [2]Saved,
    calls: usize = 0,
    alive_after_collection: bool = false,

    fn steps(data: ?*anyopaque, _: []const runtime.JSValue) runtime.EngineError!runtime.JSValue {
        const self: *DiscardedOnStack = @ptrCast(@alignCast(data.?));
        self.calls += 1;
        // document.open has discarded the old parser, and replace all removed
        // its tree; the parser is still on the native stack, unreleased.
        engine.requestGarbageCollection(self.browser.getAgent().?);
        engine.requestGarbageCollection(self.browser.getAgent().?);
        self.alive_after_collection = self.held[0].alive() and self.held[1].alive();
        return .undefined;
    }
};

fn discardedParserOnTheStackStillHolds() !void {
    const browser = try openBrowser();
    defer browser.deinit();
    const page = browser.current_context.?;
    try page.runScript("document.open(); document.write('<!doctype html><body><div id=held><span id=deep>')");
    const document = page.document_instance orelse return error.NoDocument;
    const parser = try activeParser(document);
    var probe: DiscardedOnStack = .{
        .browser = browser,
        .parser = parser,
        .held = .{ Saved.of(try byId(document, "held")), Saved.of(try byId(document, "deep")) },
    };
    const callback: engine.BuiltinFunction = .{ .steps = DiscardedOnStack.steps, .data = &probe };
    try engine.defineBuiltinFunction(document.ctx, "collectWhileDiscarded", 0, &callback);
    // A reaction to the parser's own insertion opens the document: the
    // writing parser is discarded while its write still runs it. It keeps
    // its stack - and so its holds - until it is released (design 5.6), and
    // its Document traces it while it is on the stack (the wrapper
    // redesign's P6: DocumentParser.on_stack).
    try page.runScript(
        \\customElements.define('x-open', class extends HTMLElement {
        \\  connectedCallback() {
        \\    if (window.opened) return;
        \\    window.opened = true;
        \\    document.open();
        \\    collectWhileDiscarded();
        \\  }
        \\});
        \\document.write('<x-open></x-open><b id=after>after</b>');
    );
    try testing.expectEqual(@as(usize, 1), probe.calls);
    try testing.expect(probe.alive_after_collection);
    // The write returned and released the old parser: its tree is garbage.
    try collect(browser);
    try testing.expect(!probe.held[0].alive());
    try page.runScript("document.close()");
}

test "a discarded parser still on the native stack holds its nodes across a collection until it is released" {
    try onFreshThread(discardedParserOnTheStackStillHolds);
}

test "the wrapper check is skipped only for a creation known to have run no script" {
    const DomTreeAdapter = @import("html").parser_script_execution.DomTreeAdapter;
    // The default is the safe answer: an unknown creation is asked.
    try testing.expect(DomTreeAdapter.mustCheckWrapper(null));
    try testing.expect(DomTreeAdapter.mustCheckWrapper(.may_have_run_script));
    try testing.expect(!DomTreeAdapter.mustCheckWrapper(.ran_no_script));
}

const PendingProbe = struct {
    parser: *scripted_parser.DocumentParser,
    seen: [4]usize = .{ 0, 0, 0, 0 },
    count: usize = 0,

    fn steps(data: ?*anyopaque, _: []const runtime.JSValue) runtime.EngineError!runtime.JSValue {
        const self: *PendingProbe = @ptrCast(@alignCast(data.?));
        if (self.count < self.seen.len) self.seen[self.count] = self.parser.adapter.pending.items.len;
        self.count += 1;
        return .undefined;
    }
};

fn creationsThatRanScriptAreChecked() !void {
    const browser = try openBrowser();
    defer browser.deinit();
    const page = browser.current_context.?;
    try page.runScript("document.open(); document.write('<!doctype html><body><span id=open>')");
    const document = page.document_instance orelse return error.NoDocument;
    var probe: PendingProbe = .{ .parser = try activeParser(document) };
    const callback: engine.BuiltinFunction = .{ .steps = PendingProbe.steps, .data = &probe };
    try engine.defineBuiltinFunction(document.ctx, "pendingNow", 0, &callback);
    try page.runScript(
        \\customElements.define('x-def', class extends HTMLElement {
        \\  static observedAttributes = ['a'];
        \\  attributeChangedCallback() { pendingNow(); }
        \\});
        \\customElements.define('x-builtin', class extends HTMLParagraphElement {
        \\  static observedAttributes = ['a'];
        \\  attributeChangedCallback() { pendingNow(); }
        \\}, { extends: 'p' });
        \\document.write('<x-def a=1 id=x></x-def><p is=x-builtin a=1 id=b></p>' +
        \\  '<div id=plain a=1>t<!--c--></div><template id=tp><b>in</b></template>' +
        \\  '<p is=x-unknown id=nodef></p><svg><circle id=c></circle></svg>');
    );
    // A token with a definition, autonomous or customized built-in (is=),
    // will execute script: its wrapper is checked, found, and held from
    // creation through the reactions to its attributes.
    try testing.expectEqual(@as(usize, 2), probe.count);
    try testing.expectEqual(@as(usize, 1), probe.seen[0]);
    try testing.expectEqual(@as(usize, 1), probe.seen[1]);
    try testing.expect(engine.hasWrapper(try byId(document, "x")));
    try testing.expect(engine.hasWrapper(try byId(document, "b")));
    // Inserted: no pending hold and no orphan is left.
    try testing.expectEqual(@as(usize, 0), probe.parser.adapter.pending.items.len);
    try testing.expectEqual(@as(usize, 0), probe.parser.adapter.orphans.items.len);
    // No definition, or not an element: no script ran, nothing wrapped them.
    const plain = try byId(document, "plain");
    for ([_]*runtime.Instance{
        plain,
        (try interfaces.Node.get_firstChild(plain)).?,
        (try interfaces.Node.get_lastChild(plain)).?,
        try byId(document, "tp"),
        try byId(document, "nodef"),
        try byId(document, "c"),
    }) |node| try testing.expect(!engine.hasWrapper(node));
    try page.runScript("document.close()");
}

test "a creation that ran script keeps its wrapper check and pending hold; one that ran none skips it" {
    try onFreshThread(creationsThatRanScriptAreChecked);
}

fn retainedDestroyedDocumentKeeps() !void {
    const browser = try openBrowser();
    defer browser.deinit();
    const page = browser.current_context.?;
    const owned = try browser.evaluateScript("globalThis.retired = document.implementation.createHTMLDocument('retired')");
    defer owned.release();
    const document = engine.convertToPlatformObject(browser.getRealm().?, owned.borrow()) orelse return error.NoDocument;
    // A document whose navigable is gone can still be opened and parsed.
    dom.document_lifecycle.destroy(document);
    try page.runScript("retired.open(); retired.write('<!doctype html><body><div id=a><span id=s>')");
    _ = try activeParser(document);
    const span = Saved.of(try byId(document, "s"));
    try page.runScript("retired.body.innerHTML = ''");
    try collect(browser);
    try testing.expect(span.alive());
    try page.runScript("retired.write('kept</span></div>'); retired.close()");
    const text = try textOf(span.node);
    defer testing.allocator.free(text);
    try testing.expectEqualStrings("kept", text);
}

test "a retained document whose navigable was destroyed still keeps what its new parser holds" {
    try onFreshThread(retainedDestroyedDocumentKeeps);
}
