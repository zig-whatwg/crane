//! CE2-M2 remainder (tmp/analysis/fix-list.md): a document's custom element
//! registry and a FormData's File entries are native pointers that a traced
//! edge keeps alive. When the edge is lost they must read as gone - null, or
//! no entry - and never as a freed or reissued object. Each case drops the
//! edge by hand, collects, lets other objects take the freed slots, and
//! reads (the shape of kept_object_liveness_test.zig, which covers elements
//! and form-associated File values).
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
    if (failure) |err| {
        std.debug.print("failed with {s}\n", .{@errorName(err)});
        return err;
    }
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

fn lostDocumentRegistryReadsNull() !void {
    const browser = try open();
    defer browser.deinit();
    // A document whose only keeper of its scoped registry is its own edge:
    // no elements (initialize would associate each, and each would keep it).
    const document = try platformObject(browser,
        \\globalThis.doc = document.implementation.createDocument(null, null);
        \\new CustomElementRegistry().initialize(doc);
        \\doc
    );
    const registry = (try interfaces.Document.get_customElementRegistry(document)) orelse return error.NoRegistry;
    const generation = runtime.SlabAllocator.generationOf(registry);

    engine.forgetTracedChild(document, .{ .name = "customElementRegistry" });
    try collect(browser);
    try run(browser, "globalThis.others = []; for (let i = 0; i < 200; i++) others.push(new CustomElementRegistry()); 0");
    // The test's premise: the registry was collected and its slot moved on.
    if (runtime.SlabAllocator.generationOf(registry) == generation) return error.RegistryNotCollected;

    if ((try interfaces.Document.get_customElementRegistry(document)) != null) return error.ReadAGoneRegistry;
    try expectTrue(browser, "doc.customElementRegistry === null");
    // The document still makes elements.
    try expectTrue(browser, "doc.createElement('x-y').localName === 'x-y'");
}

test "a document whose registry is gone reads a null registry, not a freed one" {
    try onFreshThread(lostDocumentRegistryReadsNull);
}

fn lostFileEntryIsNoEntry() !void {
    const browser = try open();
    defer browser.deinit();
    const form_data = try platformObject(browser,
        \\globalThis.fd = new FormData();
        \\fd.append('a', 'text');
        \\fd.append('f', new File(['x'], 'kept-only-by-fd.txt'));
        \\fd
    );
    try expectTrue(browser, "fd.get('f') instanceof File && fd.get('f').name === 'kept-only-by-fd.txt'");

    // The edge that kept the File, lost; the collector takes it and other
    // Files take its slot.
    engine.forgetTracedChild(form_data, .{ .name = "entryFiles" });
    try collect(browser);
    try run(browser, "globalThis.files = []; for (let i = 0; i < 200; i++) files.push(new File(['y' + i], 'other.txt')); 0");

    // Gone is no entry - every read agrees, and nothing reissued comes back.
    try expectTrue(browser, "fd.get('f') === null");
    try expectTrue(browser, "fd.getAll('f').length === 0");
    try expectTrue(browser, "fd.has('f') === false");
    try expectTrue(browser, "[...fd.keys()].join() === 'a'");
    try expectTrue(browser, "fd.get('a') === 'text'");
}

test "a FormData File entry that is gone is no entry, not a freed File" {
    try onFreshThread(lostFileEntryIsNoEntry);
}
