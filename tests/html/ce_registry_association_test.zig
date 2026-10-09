//! CE2-S2 (tmp/analysis/fix-list.md): an element's custom element registry
//! association. DOM keeps a global registry on an element only as its node
//! document's own registry (flatten-element-creation-options 3.2.3, importNode
//! 3, clone a single node 2.3, adopt 3.3.2.4), and the document keeps that
//! registry - so an element created with it must not draw an engine edge of
//! its own. Every element creation did: an unwrapped element's edge waits in
//! its realm's wrapper cache as a Global until the element is wrapped, a
//! wrapped one carries a private property. Only a scoped registry, which
//! nothing else keeps, is traced from the element.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
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

fn run(browser: *browser_mod.Browser, source: []const u8) !void {
    const held = try browser.evaluateScript(source);
    held.release();
}

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

/// V8's own count of the bytes its used global handles take
/// (used_global_handles_size): no bookkeeping of ours in it.
fn globalHandleBytes() !i64 {
    if (engine.capabilities.diagnostic_counters == .unsupported) return error.SkipZigTest;
    const counters = try engine.diagnosticCounters(testing.allocator);
    defer testing.allocator.free(counters);
    for (counters) |counter| {
        if (std.mem.eql(u8, counter.name, "global_handle_bytes")) return counter.value;
    }
    return error.SkipZigTest;
}

const parsed_elements = 2000;

fn globalRegistryHoldsNoHandle() !void {
    const browser = try open();
    defer browser.deinit();
    try run(browser, "globalThis.host = document.createElement('div'); 0");
    try collect(browser);
    const before = try globalHandleBytes();
    // innerHTML creates its elements unwrapped, each with the document's
    // global registry, and the host keeps them.
    try run(browser, std.fmt.comptimePrint("host.innerHTML = '<p></p>'.repeat({d}); 0", .{parsed_elements}));
    try collect(browser);
    const after = try globalHandleBytes();
    try expectTrue(browser, std.fmt.comptimePrint("host.children.length === {d}", .{parsed_elements}));
    // A Global per element is 2,000 handles (V8's node is 32 bytes on a
    // 64-bit target: 64,000 bytes). Allow far less than one per element.
    if (after - before >= parsed_elements * 4) {
        std.debug.print("global handle bytes grew {d} for {d} parsed elements\n", .{ after - before, parsed_elements });
        return error.TestUnexpectedResult;
    }
    // The association reads as before: the document's registry.
    try expectTrue(browser, "host.firstChild.customElementRegistry === customElements && host.lastChild.customElementRegistry === document.customElementRegistry");
}

test "an element created with its document's global registry holds no engine handle for it" {
    try onFreshThread(globalRegistryHoldsNoHandle);
}

fn globalRegistrySurvivesCollection() !void {
    const browser = try open();
    defer browser.deinit();
    try run(browser,
        \\globalThis.kept = document.createElement('div');
        \\globalThis.parsed = document.createElement('div');
        \\parsed.innerHTML = '<span></span><x-a></x-a>';
        \\0
    );
    try collect(browser);
    try run(browser, "globalThis.others = []; for (let i = 0; i < 200; i++) others.push(new CustomElementRegistry()); 0");
    try expectTrue(browser, "kept.customElementRegistry === customElements");
    try expectTrue(browser, "parsed.firstChild.customElementRegistry === customElements && parsed.lastChild.customElementRegistry === customElements");
    // Defined later, the parsed x-a, once in the document, still upgrades
    // through it (define upgrades the document's shadow-including
    // descendants).
    try run(browser, "document.body.appendChild(parsed); customElements.define('x-a', class extends HTMLElement {}); 0");
    try expectTrue(browser, "parsed.lastChild.constructor !== HTMLElement && parsed.lastChild.matches(':defined')");
}

test "a global registry association survives collection and still upgrades" {
    try onFreshThread(globalRegistrySurvivesCollection);
}

fn scopedRegistryIsKeptByItsElement() !void {
    const browser = try open();
    defer browser.deinit();
    const element = try platformObject(browser,
        \\globalThis.el = document.createElement('div', { customElementRegistry: new CustomElementRegistry() });
        \\el
    );
    const registry = (try interfaces.Element.get_customElementRegistry(element)) orelse return error.NoRegistry;
    const generation = runtime.SlabAllocator.generationOf(registry);
    // Nothing but the element keeps the scoped registry.
    try collect(browser);
    try run(browser, "globalThis.others = []; for (let i = 0; i < 200; i++) others.push(new CustomElementRegistry()); 0");
    try testing.expectEqual(generation, runtime.SlabAllocator.generationOf(registry));
    try testing.expectEqual(@as(?*runtime.Instance, registry), try interfaces.Element.get_customElementRegistry(element));
    try expectTrue(browser, "el.customElementRegistry instanceof CustomElementRegistry && el.customElementRegistry !== customElements");
    try expectTrue(browser, "el.customElementRegistry === el.customElementRegistry");
}

test "a scoped registry is kept alive by the element associated with it" {
    try onFreshThread(scopedRegistryIsKeptByItsElement);
}

fn adoptionFollowsTheDocument() !void {
    const browser = try open();
    defer browser.deinit();
    try run(browser,
        \\globalThis.el = document.createElement('div');
        \\globalThis.scopedRegistry = new CustomElementRegistry();
        \\globalThis.scoped = document.createElement('div', { customElementRegistry: scopedRegistry });
        \\globalThis.other = document.implementation.createHTMLDocument('');
        \\0
    );
    // Adopt 3.3.2.4: a global registry becomes the new document's effective
    // global registry - null for a document with none; a scoped one stays.
    try expectTrue(browser, "other.customElementRegistry === null");
    try expectTrue(browser, "other.adoptNode(el) === el && el.customElementRegistry === null");
    try expectTrue(browser, "other.adoptNode(scoped) === scoped && scoped.customElementRegistry === scopedRegistry");
    // And back: a parentless element takes the document's registry.
    try expectTrue(browser, "document.adoptNode(el) === el && el.customElementRegistry === customElements");
    try collect(browser);
    try expectTrue(browser, "el.customElementRegistry === customElements && scoped.customElementRegistry === scopedRegistry");
}

test "adoption moves a global association to the new document's registry" {
    try onFreshThread(adoptionFollowsTheDocument);
}

fn shadowRootAssociations() !void {
    const browser = try open();
    defer browser.deinit();
    try run(browser,
        \\globalThis.globalHost = document.body.appendChild(document.createElement('div'));
        \\globalThis.globalRoot = globalHost.attachShadow({ mode: 'open' });
        \\globalThis.scopedHost = document.body.appendChild(document.createElement('div'));
        \\globalThis.scopedRoot = scopedHost.attachShadow({ mode: 'open', customElementRegistry: new CustomElementRegistry() });
        \\0
    );
    try collect(browser);
    try run(browser, "globalThis.others = []; for (let i = 0; i < 200; i++) others.push(new CustomElementRegistry()); 0");
    // The document keeps its global registry for the shadow root; the
    // scoped registry is kept by its shadow root alone.
    try expectTrue(browser, "globalRoot.customElementRegistry === customElements");
    try expectTrue(browser, "scopedRoot.customElementRegistry instanceof CustomElementRegistry && scopedRoot.customElementRegistry !== customElements");
    try expectTrue(browser, "scopedRoot.customElementRegistry === scopedRoot.customElementRegistry");
    // Content parsed into each uses its registry.
    try run(browser, "customElements.define('x-g', class extends HTMLElement {}); scopedRoot.customElementRegistry.define('x-g', class extends HTMLElement {}); 0");
    try expectTrue(browser, "(globalRoot.innerHTML = '<x-g></x-g>', globalRoot.firstChild.customElementRegistry === customElements && customElements.get('x-g') === globalRoot.firstChild.constructor)");
    try expectTrue(browser, "(scopedRoot.innerHTML = '<x-g></x-g>', scopedRoot.firstChild.customElementRegistry === scopedRoot.customElementRegistry && scopedRoot.firstChild.constructor === scopedRoot.customElementRegistry.get('x-g'))");
}

test "a shadow root keeps a scoped registry and reads its document's global one" {
    try onFreshThread(shadowRootAssociations);
}
