//! PR-N1 (tmp/analysis/fix-list.md), custom elements: a definition kept its
//! registry as a bare pointer (definition.zig `registry`), and the HTML
//! element constructor's push (driver.pushConstructor) took an engine root on
//! it. A definition can outlive its registry - an element or a queued upgrade
//! retains it - so on a teardown order that frees the registry first, the
//! root was taken on a freed or reissued slot. Definition.setRegistry records
//! the slab generation and realm; liveRegistry reads none once the registry
//! is gone, and the push fails with InvalidStateError without touching the
//! slot. Tracing is what keeps a live page's registry; the check is a safety
//! net for teardown only.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
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

fn staleRegistryIsNeverTouched() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    const held = try browser.evaluateScript("customElements.define('lf2-def', class extends HTMLElement {}); 0");
    held.release();

    const realm = browser.getRealm() orelse return error.NoRealm;
    const document = blk: {
        const value = try browser.evaluateScript("document");
        defer value.release();
        break :blk engine.convertToPlatformObject(realm, value.borrow()) orelse return error.NoDocument;
    };
    const registry = (try interfaces.Document.get_customElementRegistry(document)) orelse return error.NoRegistry;
    const definition = dom.custom_elements.lookup(registry, html.custom_element_creation.html_namespace, "lf2-def", null) orelse return error.NoDefinition;

    // Its registry, recorded with its generation, is live: the push succeeds.
    try testing.expect(definition.liveRegistry() == registry);
    const state = try html.custom_elements.pushConstructor(realm, definition);
    state.popConstructor();

    // The same definition with a registry that is gone (its slot's
    // generation moved on): none to read, and the push fails before any
    // engine call on the slot.
    const generation = definition.registry_generation;
    definition.registry_generation +%= 1;
    defer definition.registry_generation = generation;
    try testing.expect(definition.liveRegistry() == null);
    try testing.expectError(error.InvalidStateError, html.custom_elements.pushConstructor(realm, definition));
}

test "a definition whose registry is gone reads none and its constructor push is InvalidStateError" {
    try onFreshThread(staleRegistryIsNeverTouched);
}

test "a registry set on a definition is live until its slot is freed" {
    const Run = struct {
        fn exercise() !void {
            interfaces.process_hooks.startHooksForTest();
            runtime.initializeRuntime(testing.allocator);
            defer runtime.deinitializeRuntime();
            var context = try runtime.ContextData.init(testing.allocator, .{});
            defer context.deinit();
            const registry = try interfaces.CustomElementRegistry.init(testing.allocator, &context);
            const definition = try dom.custom_elements.Definition.init(testing.allocator, "lf2-def", "lf2-def", .{ .function = .{ .value = .null }, .context = null });
            defer definition.deinit();
            definition.setRegistry(registry);
            try testing.expect(definition.liveRegistry() == registry);
            // Teardown order: the registry goes first; another takes its slot.
            runtime.Instance.deinit(registry);
            try testing.expect(definition.liveRegistry() == null);
            const other = try interfaces.CustomElementRegistry.init(testing.allocator, &context);
            defer runtime.Instance.deinit(other);
            try testing.expect(definition.liveRegistry() == null);
        }
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
