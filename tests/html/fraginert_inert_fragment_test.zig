//! Lane fraginert: the HTML fragment parser's inert-document option and its
//! Fragment scripting mode (html.dom_parser.FragmentOptions).
//!
//! "Set and filter HTML" (setHTML, and setHTMLUnsafe with a sanitizer) must
//! not run anything from markup the sanitizer removes: Blink parses into the
//! context document's template document with no registry
//! (FragmentParser::ParseHTMLFragmentInternal, ForceInertTemplate::kForce),
//! Gecko into nsContentUtils::CreateInertHTMLDocument (SetAndFilterHTML), and
//! insertion adopts the survivors. These probes run the parser natively and
//! watch what script can see: custom element constructors, image loads,
//! error events, event handler attributes and scripts - before insertion and
//! after it.
//!
//! Each test runs a real Browser on a thread of its own: tests/html is one
//! executable, and a Browser's agent belongs to the thread that made it.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const runtime = @import("runtime");
const engine = @import("engine");
const dom = @import("dom");
const html = @import("html");

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

fn open() !*browser_mod.Browser {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    errdefer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    return browser;
}

fn run(browser: *browser_mod.Browser, source: []const u8) !void {
    const held = try browser.evaluateScript(source);
    held.release();
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

/// Parse `markup` with `options` into a fragment for the element script
/// names `globalThis.target` (an attached div), and hand the fragment to
/// script as `globalThis.frag`.
fn parseForTarget(browser: *browser_mod.Browser, markup: []const u8, options: html.dom_parser.FragmentOptions) !void {
    const realm = browser.getRealm() orelse return error.NoRealm;
    const target_value = try browser.evaluateScript(
        \\globalThis.target = document.body.appendChild(document.createElement('div'));
        \\target
    );
    defer target_value.release();
    const target = engine.convertToPlatformObject(realm, target_value.borrow()) orelse return error.NotAPlatformObject;
    const fragment = try html.dom_parser.parseFragmentWith(target.ctx.allocator, target.ctx, markup, target, options);
    const global = try browser.evaluateScript("globalThis");
    defer global.release();
    engine.setProperty(realm, global.borrow(), "frag", .{ .instance = fragment }) catch |err| {
        dom.node_creation.destroyUninserted(fragment);
        return err;
    };
}

const inert: html.dom_parser.FragmentOptions = .{ .allow_declarative_shadow_roots = true, .inert_document = true };

fn inertDocumentOwnsTheFragment() !void {
    const browser = try open();
    defer browser.deinit();
    try parseForTarget(browser, "<p id=a>x<b>y</b></p>", inert);
    // The context document's template contents owner document: no browsing
    // context, so nothing in it fetches or compiles a handler.
    try expectTrue(browser,
        \\const inertDocument = document.createElement('template').content.ownerDocument;
        \\frag.ownerDocument === inertDocument && inertDocument !== document &&
        \\  inertDocument.defaultView === null &&
        \\  frag.firstChild.ownerDocument === inertDocument &&
        \\  frag.firstChild.lastChild.ownerDocument === inertDocument &&
        \\  frag.firstChild.outerHTML === '<p id="a">x<b>y</b></p>'
    );
    // Insertion adopts the survivors into the target's document.
    try expectTrue(browser,
        \\const p = frag.firstChild;
        \\target.append(frag);
        \\p.ownerDocument === document && p.lastChild.ownerDocument === document && target.firstChild === p
    );
}

test "the inert option builds the fragment in the context document's template contents owner document" {
    try onFreshThread(inertDocumentOwnsTheFragment);
}

fn customElementsUpgradeOnInsertion() !void {
    const browser = try open();
    defer browser.deinit();
    try run(browser,
        \\globalThis.constructed = 0;
        \\globalThis.Probe = class extends HTMLElement { constructor() { super(); constructed++; } };
        \\customElements.define('fi-probe', Probe);
    );
    try parseForTarget(browser, "<fi-probe></fi-probe><div><fi-probe></fi-probe></div>", inert);
    _ = try browser.runEventLoopBlocking(10);
    // No registry was looked up: nothing upgraded, no constructor ran.
    try expectTrue(browser, "constructed === 0 && !(frag.firstChild instanceof Probe) && frag.firstChild.customElementRegistry === null");
    // The survivors upgrade when they are inserted into the document.
    try expectTrue(browser,
        \\target.append(frag);
        \\constructed === 2 && target.firstChild instanceof Probe && target.lastChild.firstChild instanceof Probe
    );
}

test "an inert fragment's custom elements are constructed only once inserted" {
    try onFreshThread(customElementsUpgradeOnInsertion);
}

fn removedElementsNeverConstruct() !void {
    const browser = try open();
    defer browser.deinit();
    try run(browser,
        \\globalThis.constructed = 0;
        \\customElements.define('fi-gone', class extends HTMLElement { constructor() { super(); constructed++; } });
    );
    try parseForTarget(browser, "<fi-gone></fi-gone><p>kept</p>", inert);
    try run(browser, "frag.firstChild.remove(); target.append(frag);");
    _ = try browser.runEventLoopBlocking(10);
    try expectTrue(browser, "constructed === 0 && target.innerHTML === '<p>kept</p>'");
}

test "a custom element removed from an inert fragment before insertion is never constructed" {
    try onFreshThread(removedElementsNeverConstruct);
}

fn imagesWaitForAdoption() !void {
    const browser = try open();
    defer browser.deinit();
    try parseForTarget(browser,
        \\<img id=data src="data:image/png," onerror="globalThis.handled = (globalThis.handled | 0) + 1"><img id=net src="http://127.0.0.1:65533/fraginert-probe.png">
    , inert);
    try run(browser,
        \\globalThis.errors = 0;
        \\for (const img of frag.children) img.addEventListener('error', () => errors++);
    );
    _ = try browser.runEventLoopBlocking(50);
    // No load started: no fetch in flight, no error event, no handler run.
    try testing.expectEqual(@as(usize, 0), browser.agent_host.fetches.inFlight());
    try expectTrue(browser, "errors === 0 && globalThis.handled === undefined");
    // Adopted into the document, the image's adopting steps (a relevant
    // mutation) update its image data: the broken data: image errors, and
    // its handler - compiled now, in the document it runs in - hears it.
    try run(browser, "target.append(frag.firstChild);");
    _ = try browser.runEventLoopBlocking(50);
    try expectTrue(browser, "errors === 1 && globalThis.handled === 1");
}

test "an inert fragment's image does not load or fire error until it is adopted" {
    try onFreshThread(imagesWaitForAdoption);
}

fn handlersRunOnceAdopted() !void {
    const browser = try open();
    defer browser.deinit();
    try parseForTarget(browser,
        \\<button id=b onclick="globalThis.clicks = (globalThis.clicks | 0) + 1; return this.id"></button>
    , inert);
    // Scripting is disabled for the inert document: the handler's current
    // value is null there, and clicking runs nothing.
    try expectTrue(browser,
        \\const b = frag.firstChild;
        \\b.onclick === null && (b.click(), globalThis.clicks === undefined)
    );
    try expectTrue(browser,
        \\const button = frag.firstChild;
        \\target.append(frag);
        \\typeof button.onclick === 'function' && (button.click(), globalThis.clicks === 1) &&
        \\  button.onclick === button.onclick
    );
}

test "an inert fragment's event handler attribute runs once its element is adopted" {
    try onFreshThread(handlersRunOnceAdopted);
}

fn handlerClearedWhileInert() !void {
    const browser = try open();
    defer browser.deinit();
    try parseForTarget(browser, "<button onclick='globalThis.clicked = true'></button>", inert);
    // The IDL attribute set to null deactivates the raw handler: adoption
    // later has nothing to compile.
    try run(browser, "const b = frag.firstChild; b.onclick = null; target.append(frag); b.click();");
    try expectTrue(browser, "target.firstChild.onclick === null && globalThis.clicked === undefined && target.firstChild.hasAttribute('onclick')");
}

test "a raw handler set to null while inert stays null once adopted" {
    try onFreshThread(handlerClearedWhileInert);
}

fn rawHandlerSyntaxErrorReportedOnUse() !void {
    const browser = try open();
    defer browser.deinit();
    try run(browser, "globalThis.reported = 0; window.addEventListener('error', () => reported++);");
    try parseForTarget(browser, "<div onclick='}'></div>", inert);
    // Neither parsing nor adoption compiles it.
    try expectTrue(browser, "target.append(frag); reported === 0");
    // Getting the current value compiles it: the syntax error is reported
    // for the document's global, and the value is null from then on.
    try expectTrue(browser, "target.firstChild.onclick === null && reported === 1 && target.firstChild.onclick === null && reported === 1");
}

test "a raw handler that does not parse is reported when its value is first needed" {
    try onFreshThread(rawHandlerSyntaxErrorReportedOnUse);
}

fn defaultModeUnchanged() !void {
    const browser = try open();
    defer browser.deinit();
    try run(browser,
        \\globalThis.constructed = 0;
        \\customElements.define('fi-live', class extends HTMLElement { constructor() { super(); constructed++; } });
    );
    try parseForTarget(browser, "<fi-live></fi-live><button onclick='globalThis.live = 1'></button>", .{});
    _ = try browser.runEventLoopBlocking(10);
    // innerHTML's path (the spec's and every browser's): the target's own
    // document, its registry, and handlers compiled where they are set.
    try expectTrue(browser, "frag.ownerDocument === document && frag.firstChild.ownerDocument === document && constructed === 1 && typeof frag.lastChild.onclick === 'function'");
}

test "without the inert option fragment parsing builds in the target's document as before" {
    try onFreshThread(defaultModeUnchanged);
}

fn scriptingModes() !void {
    const browser = try open();
    defer browser.deinit();
    try run(browser, "globalThis.ran = [];");
    // Inert (the default): every script is already started and never runs.
    try parseForTarget(browser, "<script>ran.push('inert')</script>", .{});
    try run(browser, "target.append(frag);");
    // Fragment, in the target's document: the scripts run once inserted -
    // not before.
    try parseForTarget(browser, "<script>ran.push('fragment')</script><div><script>ran.push('nested')</script></div>", .{ .scripting_mode = .fragment });
    try expectTrue(browser, "ran.length === 0");
    try run(browser, "target.append(frag);");
    try expectTrue(browser, "ran.join() === 'fragment,nested'");
    // Fragment, in the inert document: adoption and insertion run them.
    try parseForTarget(browser, "<script>ran.push('adopted')</script>", .{ .scripting_mode = .fragment, .inert_document = true });
    try expectTrue(browser, "ran.length === 2");
    try run(browser, "target.append(frag);");
    try expectTrue(browser, "ran.join() === 'fragment,nested,adopted'");
}

test "the Fragment scripting mode runs a fragment's scripts when it is inserted, the Inert mode never" {
    try onFreshThread(scriptingModes);
}
