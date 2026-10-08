//! A template's content fragment belongs to its live template (HTML 4.12.3:
//! the template contents are the template's own DocumentFragment), natively,
//! the way WebKit's HTMLTemplateElement keeps a RefPtr to it and Blink's
//! traces content_ - not through an edge between their two wrappers, which
//! goes with either wrapper (PR-M1, tmp/analysis/fix-list.md).
//!
//! Each case runs on a thread of its own: it starts its own Browser, and the
//! directory's other files share this process.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const engine = @import("engine");

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

fn open() !*browser_mod.Browser {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    errdefer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    return browser;
}

/// The platform object `source` evaluates to; script keeps it if `source`
/// stores it.
fn platformObject(browser: *browser_mod.Browser, source: []const u8) !*runtime.Instance {
    const held = try browser.evaluateScript(source);
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    return engine.convertToPlatformObject(realm, held.borrow()) orelse error.NotAPlatformObject;
}

fn expectTrue(browser: *browser_mod.Browser, source: []const u8) !void {
    const held = try browser.evaluateScript(source);
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    if (!engine.toBoolean(realm, held.borrow())) {
        std.debug.print("expected true: {s}\n", .{source});
        return error.TestExpectedTrue;
    }
}

/// Reissue freed slab slots: a fragment freed under its template comes back
/// as one of these.
fn churn(browser: *browser_mod.Browser) !void {
    const held = try browser.evaluateScript("for (let i = 0; i < 1000; i++) document.createDocumentFragment(); 0");
    held.release();
}

fn customizedBuiltInKeepsContent() !void {
    const browser = try open();
    defer browser.deinit();
    // `new X()` binds the element to the object V8 made for X: the binding's
    // `.created` path. The template's content was made - and, before the
    // fix, the template wrapped - while the element was created.
    const template = try platformObject(browser,
        \\class X extends HTMLTemplateElement {}
        \\customElements.define('lf1-x-t', X, { extends: 'template' });
        \\globalThis.t = new X();
        \\t.content.append('a');
        \\t
    );
    const content = try interfaces.HTMLTemplateElement.get_content(template);
    const generation = runtime.SlabAllocator.generationOf(content);

    try collect(browser);
    try churn(browser);
    try collect(browser);

    // The fragment the template points at is the one it made.
    try testing.expectEqual(generation, runtime.SlabAllocator.generationOf(content));
    try testing.expectEqual(content, try interfaces.HTMLTemplateElement.get_content(template));
    try expectTrue(browser, "t.content.nodeType === 11 && t.content.textContent === 'a' && t.content === t.content");
    try expectTrue(browser, "t instanceof X && t.customElementRegistry === customElements");
}

test "a customized built-in template made by its constructor keeps its content through a collection" {
    try onFreshThread(customizedBuiltInKeepsContent);
}

fn unexposedTemplateSurvives() !void {
    const browser = try open();
    defer browser.deinit();
    const page = browser.current_context orelse return error.NoPage;
    const document = page.document_instance orelse return error.NoDocument;
    // A template script has never seen, held natively - as a parser or a
    // fragment conversion holds the nodes it makes. Nothing of it is the
    // collector's to free.
    const template = try interfaces.Document.call_createElement(document, runtime.DOMString.initInterned("template"), .{ .was_passed = false, .value = undefined });
    const template_generation = runtime.SlabAllocator.generationOf(template);
    // Only while it is still the template made here (a collection that
    // freed it must not be followed by a second free).
    defer if (runtime.SlabAllocator.generationOf(template) == template_generation) dom.node_creation.destroyUninserted(template);
    const content = try interfaces.HTMLTemplateElement.get_content(template);
    const content_generation = runtime.SlabAllocator.generationOf(content);
    try testing.expect(!engine.hasWrapper(template));

    try collect(browser);
    try churn(browser);
    try collect(browser);

    try testing.expectEqual(template_generation, runtime.SlabAllocator.generationOf(template));
    try testing.expectEqual(content_generation, runtime.SlabAllocator.generationOf(content));
    try testing.expectEqual(content, try interfaces.HTMLTemplateElement.get_content(template));
}

test "a template script never saw, held natively, keeps itself and its content through a collection" {
    try onFreshThread(unexposedTemplateSurvives);
}

fn nativeCloneSurvives() !void {
    const browser = try open();
    defer browser.deinit();
    const source = try platformObject(browser,
        \\const outer = document.createElement('template');
        \\outer.innerHTML = '<template><b>x</b></template>';
        \\outer
    );
    // cloneNode(true) as a native caller makes it: the copy and its nested
    // copy are created, established and filled with no script holding them.
    const copy = try interfaces.Node.call_cloneNode(source, .{ .was_passed = true, .value = true });
    const copy_generation = runtime.SlabAllocator.generationOf(copy);
    defer if (runtime.SlabAllocator.generationOf(copy) == copy_generation) dom.node_creation.destroyUninserted(copy);
    const copy_content = try interfaces.HTMLTemplateElement.get_content(copy);
    const copy_content_generation = runtime.SlabAllocator.generationOf(copy_content);
    const nested = (try interfaces.Node.get_firstChild(copy_content)) orelse return error.NoNestedTemplate;
    const nested_generation = runtime.SlabAllocator.generationOf(nested);
    const nested_content = try interfaces.HTMLTemplateElement.get_content(nested);
    const nested_content_generation = runtime.SlabAllocator.generationOf(nested_content);

    try collect(browser);
    try churn(browser);
    try collect(browser);

    try testing.expectEqual(copy_generation, runtime.SlabAllocator.generationOf(copy));
    try testing.expectEqual(copy_content_generation, runtime.SlabAllocator.generationOf(copy_content));
    try testing.expectEqual(nested_generation, runtime.SlabAllocator.generationOf(nested));
    try testing.expectEqual(nested_content_generation, runtime.SlabAllocator.generationOf(nested_content));
    var text = try interfaces.Node.get_textContent(nested_content);
    defer if (text) |*value| value.deinit(testing.allocator);
    try testing.expectEqualStrings("x", (text orelse return error.NoText).asSlice());
}

test "a template cloned by a native caller keeps its content and its nested template's through a collection" {
    try onFreshThread(nativeCloneSurvives);
}

fn innerHTMLTemplatesSurvive() !void {
    const browser = try open();
    defer browser.deinit();
    const held = try browser.evaluateScript(
        \\globalThis.d = document.createElement('div');
        \\d.innerHTML = '<template id=a><template id=b>x</template></template><template id=c>y</template>';
        \\0
    );
    held.release();
    try collect(browser);
    try churn(browser);
    try collect(browser);
    try expectTrue(browser, "d.firstChild.content.firstChild.content.textContent === 'x' && d.lastChild.content.textContent === 'y'");
    try expectTrue(browser, "d.firstChild.content === d.firstChild.content");
}

test "templates parsed by innerHTML keep their contents through a collection" {
    try onFreshThread(innerHTMLTemplatesSurvive);
}

fn contentOutlivesItsTemplateWhileHeld() !void {
    const browser = try open();
    defer browser.deinit();
    // Script holds the content and drops the template: the content stays a
    // working fragment while script holds it.
    const held = try browser.evaluateScript(
        \\globalThis.c = document.createElement('template').content;
        \\c.append('kept');
        \\0
    );
    held.release();
    try collect(browser);
    try churn(browser);
    try collect(browser);
    try expectTrue(browser, "c.nodeType === 11 && c.textContent === 'kept'");
    try expectTrue(browser, "c.appendChild(document.createElement('i')) && c.childNodes.length === 2");
}

test "a template's content script still holds outlives its collected template" {
    try onFreshThread(contentOutlivesItsTemplateWhileHeld);
}

fn constructedCustomElementKeepsWrapper() !void {
    const browser = try open();
    defer browser.deinit();
    // The same binding path as the template's (`.created`), for a custom
    // element of a real definition: the object made for NewTarget is the
    // element's one wrapper - the node's alias - so once inserted, node
    // tracing keeps it, and with it the element's class and expandos.
    const held = try browser.evaluateScript(
        \\class Z extends HTMLElement {}
        \\customElements.define('lf1-z', Z);
        \\globalThis.Z = Z;
        \\globalThis.parent = document.body.appendChild(document.createElement('div'));
        \\(() => { const z = new Z(); z.expando = 7; parent.append(z); })();
        \\0
    );
    held.release();
    try collect(browser);
    try churn(browser);
    try collect(browser);
    try expectTrue(browser, "parent.firstChild instanceof Z && parent.firstChild.expando === 7");
}

test "a custom element made by its constructor keeps its wrapper once inserted" {
    try onFreshThread(constructedCustomElementKeepsWrapper);
}
