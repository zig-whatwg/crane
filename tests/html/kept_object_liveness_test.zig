//! An element's custom element registry and a form-associated custom
//! element's File value are native pointers to platform objects that only a
//! traced edge keeps alive (CE2-M2, tmp/analysis/fix-list.md). The lesson of
//! 2026-10-03 forbids a native pointer that survives only because a JS edge
//! happens to exist: when the edge is lost - a replaced wrapper (PR-M1), a
//! teardown order - the pointer must read as gone, never as a freed or
//! reissued object. These cases drop the edge by hand, collect, reissue the
//! freed slots, and read.
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

fn platformObject(browser: *browser_mod.Browser, source: []const u8) !*runtime.Instance {
    const held = try browser.evaluateScript(source);
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    return engine.convertToPlatformObject(realm, held.borrow()) orelse error.NotAPlatformObject;
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

fn lostRegistryReadsNull() !void {
    const browser = try open();
    defer browser.deinit();
    const element = try platformObject(browser,
        \\globalThis.registry = new CustomElementRegistry();
        \\globalThis.el = document.createElement('div', { customElementRegistry: registry });
        \\el
    );
    const registry = (try interfaces.Element.get_customElementRegistry(element)) orelse return error.NoRegistry;
    const generation = runtime.SlabAllocator.generationOf(registry);

    // The edge that kept it, lost; script lets go of it; the collector takes
    // it and other registries take its slot.
    engine.forgetTracedChild(element, .{ .name = "customElementRegistry" });
    try run(browser, "delete globalThis.registry; 0");
    try collect(browser);
    try run(browser, "globalThis.others = []; for (let i = 0; i < 200; i++) others.push(new CustomElementRegistry()); 0");
    try testing.expect(runtime.SlabAllocator.generationOf(registry) != generation);

    // Gone reads as none - never a freed or reissued registry.
    try testing.expect((try interfaces.Element.get_customElementRegistry(element)) == null);
    try expectTrue(browser, "el.customElementRegistry === null");
    // And the element still inserts and attaches a shadow root.
    try expectTrue(browser, "document.body.appendChild(el) === el && el.attachShadow({ mode: 'open' }) instanceof ShadowRoot");
}

test "an element whose registry is gone reads a null registry, not a freed one" {
    try onFreshThread(lostRegistryReadsNull);
}

fn lostFileIsNotSubmitted() !void {
    const browser = try open();
    defer browser.deinit();
    const internals = try platformObject(browser,
        \\class FACE extends HTMLElement {
        \\  static formAssociated = true;
        \\  constructor() { super(); this.internals = this.attachInternals(); }
        \\}
        \\customElements.define('lf1-face', FACE);
        \\globalThis.form = document.body.appendChild(document.createElement('form'));
        \\globalThis.face = form.appendChild(new FACE());
        \\face.setAttribute('name', 'f');
        \\face.internals.setFormValue(new File(['x'], 'a.txt'));
        \\face.internals
    );
    try expectTrue(browser, "new FormData(form).getAll('f').length === 1");

    // Both edges that kept the File (the submission value and the state),
    // lost; the collector takes it and other Files take its slot.
    engine.forgetTracedChild(internals, .{ .name = "submissionValue" });
    engine.forgetTracedChild(internals, .{ .name = "formState" });
    try collect(browser);
    try run(browser, "globalThis.files = []; for (let i = 0; i < 200; i++) files.push(new File(['y' + i], 'b.txt')); 0");

    // A File that is gone is not submitted - no freed or reissued one is.
    try expectTrue(browser, "new FormData(form).getAll('f').length === 0");
}

test "a form-associated element whose File value is gone submits no File, not a freed one" {
    try onFreshThread(lostFileIsNotSubmitted);
}
