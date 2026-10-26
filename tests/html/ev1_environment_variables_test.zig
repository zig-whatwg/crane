//! Host environment values through the real document and style binding.
//! Run each case on its own thread: tests/html is one process and earlier
//! files may already have initialized V8 and the per-thread runtime.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");
const html = @import("html");
const platform = @import("platform");
const env = dom.style.environment_variables;
const helper = @import("edges_node_holders_helpers.zig");

const Scenario = enum { provider, invalidation, no_platform, uninstalled };

test "environment provider: host numbers become owned CSS text in the document's Browser" {
    try run(.provider);
}

test "environment provider: host revisions invalidate cached and inherited computed styles" {
    try run(.invalidation);
}

test "environment provider: a standalone realm has no host values or revision" {
    try run(.no_platform);
}

test "environment provider: uninstalled callbacks expose no values even with a Browser platform" {
    try run(.uninstalled);
}

fn run(scenario: Scenario) !void {
    if (comptime !std.mem.eql(u8, platform.name, "testing")) return error.SkipZigTest;
    var trial: Trial = .{ .scenario = scenario };
    const thread = try std.Thread.spawn(.{}, Trial.run, .{&trial});
    thread.join();
    try trial.result;
}

const Trial = struct {
    scenario: Scenario,
    result: anyerror!void = {},

    fn run(self: *Trial) void {
        self.result = self.check();
    }

    fn global(realm: runtime.Context, _: runtime.JSValue, _: ?*anyopaque) ?*runtime.Instance {
        return interfaces.Window.init(testing.allocator, realm) catch null;
    }

    fn check(self: *Trial) !void {
        if (self.scenario == .invalidation) return invalidation();
        try engine.initializeEngine(.{});
        runtime.initializeRuntime(testing.allocator);
        defer runtime.deinitializeRuntime();
        interfaces.process_hooks.startHooksForTest();
        const saved_provider = dom.style.hooks.environmentProvider();
        defer env.install(saved_provider orelse .{});
        if (self.scenario == .uninstalled) env.install(.{}) else html.platform_state.installHooks();
        var scope = runtime.BrowserScope.init(testing.allocator);
        defer scope.deinit();
        if (self.scenario != .no_platform) try html.platform_state.create(&scope);
        const hooks: engine.HostHooks = .{};
        const agent = try engine.createAgent(.{
            .can_block = false,
            .from_snapshot = false,
            .hooks = &hooks,
            .allocator = testing.allocator,
        });
        defer engine.destroyAgent(agent);
        const realm = try engine.createWindowRealm(&.{
            .agent = agent,
            .allocator = testing.allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://env.test",
            .browser_scope = &scope,
            .create_global_object = global,
        });
        defer engine.destroyWindowRealm(realm, .global_detached);
        try expectScript(realm,
            \\globalThis.d = new Document().implementation.createHTMLDocument('env');
            \\'ok'
        , "ok");
        const held = try engine.evaluateClassicScript(realm, .{ .utf8 = "d" }, "", null, .{ .report = reportScriptError });
        defer held.release();
        const document = engine.convertToPlatformObject(realm, held.value) orelse return error.NoDocument;
        if (self.scenario == .no_platform or self.scenario == .uninstalled) {
            try testing.expect(try env.lookup(document, testing.allocator, "safe-area-inset-top", &.{}) == null);
            try testing.expectEqual(@as(u64, 0), env.revision(document));
            try testing.expectEqual(@as(u64, 0), dom.style.hooks.environmentRevision(document));
            return;
        }
        const browser = html.platform_state.of(realm) orelse return error.NoPlatform;
        switch (self.scenario) {
            .provider => try provider(document, browser),
            .invalidation, .no_platform, .uninstalled => unreachable,
        }
    }
};

fn provider(document: *runtime.Instance, browser: *platform.BrowserPlatform) !void {
    try expectLookup(document, "safe-area-inset-top", &.{}, "0px");
    try expectLookup(document, "preferred-text-scale", &.{}, "1");
    try testing.expectEqual(@as(u64, 0), dom.style.hooks.environmentRevision(document));
    var failing = testing.FailingAllocator.init(testing.allocator, .{ .fail_index = 0 });
    try testing.expectError(error.OutOfMemory, env.lookup(document, failing.allocator(), "safe-area-inset-top", &.{}));
    inline for (@typeInfo(platform.CssEnvironmentVariable).@"enum".fields, 0..) |field, i| {
        const variable: platform.CssEnvironmentVariable = @enumFromInt(field.value);
        const number: f64 = @as(f64, @floatFromInt(i)) + 0.25;
        try platform.adapter.setCssEnvironmentVariable(browser, 0, variable, 0, 0, number);
        var name: [field.name.len]u8 = undefined;
        for (field.name, 0..) |c, j| name[j] = if (c == '_') '-' else c;
        const query = dom.style.css.environment_variables.query(&name, &.{});
        const indices: []const u32 = if (query != null) &.{} else &.{ 0, 0 };
        const expected = try std.fmt.allocPrint(testing.allocator, "{d}{s}", .{ number, if (variable == .preferred_text_scale) @as([]const u8, "") else "px" });
        defer testing.allocator.free(expected);
        try expectLookup(document, &name, indices, expected);
    }
    try testing.expectEqual(@as(u64, 25), dom.style.hooks.environmentRevision(document));
    // A second read must not borrow a scratch buffer that overwrites a
    // previous substitution's tokens.
    const first = (try env.lookup(document, testing.allocator, "safe-area-inset-top", &.{})).?;
    defer testing.allocator.free(first);
    try platform.adapter.setCssEnvironmentVariable(browser, 0, .safe_area_inset_top, 0, 0, 32);
    try expectLookup(document, "safe-area-inset-top", &.{}, "32px");
    try testing.expectEqualStrings("0.25px", first);
    try platform.adapter.setCssEnvironmentVariable(browser, 0, .viewport_segment_width, 1, 0, 420.5);
    try expectLookup(document, "viewport-segment-width", &.{ 1, 0 }, "420.5px");
    try testing.expect(try env.lookup(document, testing.allocator, "viewport-segment-width", &.{ 0, 1 }) == null);
    try testing.expect(try env.lookup(document, testing.allocator, "safe-area-inset-top", &.{0}) == null);
    try testing.expect(try env.lookup(document, testing.allocator, "SAFE-AREA-INSET-TOP", &.{}) == null);
    try testing.expect(try env.lookup(document, testing.allocator, "unknown", &.{}) == null);
    try platform.adapter.setCssEnvironmentVariable(browser, 0, .safe_area_inset_top, 0, 0, null);
    try testing.expect(try env.lookup(document, testing.allocator, "safe-area-inset-top", &.{}) == null);
}

fn invalidation() !void {
    const page = try helper.Page.open();
    defer page.close();
    const context = page.browser.current_context.?;
    const realm = context.realm.?;
    const document = context.document_instance.?;
    const browser = html.platform_state.of(realm) orelse return error.NoPlatform;
    const saved_provider = dom.style.hooks.environmentProvider();
    defer env.install(saved_provider orelse .{});
    html.platform_state.installHooks();
    try expectScript(realm,
        \\globalThis.d = document;
        \\globalThis.e = d.createElement('div');
        \\d.body.appendChild(e);
        \\e.style.marginLeft = 'env(safe-area-inset-top, 37px)';
        \\globalThis.cached = getComputedStyle(e);
        \\globalThis.envParent = d.createElement('div');
        \\globalThis.child = d.createElement('div');
        \\d.body.appendChild(envParent);
        \\envParent.appendChild(child);
        \\envParent.style.setProperty('--safe', 'env(safe-area-inset-top, 37px)');
        \\child.style.marginLeft = 'var(--safe)';
        \\[cached.marginLeft, getComputedStyle(child).marginLeft].join('|')
    , "0px|0px");
    const style_engine = dom.style.hooks.engineOf(document) orelse return error.NoStyleEngine;
    const before = style_engine.generation;
    try platform.adapter.setCssEnvironmentVariable(browser, 0, .safe_area_inset_top, 0, 0, 24.5);
    // No DOM or declaration change: the host's revision alone invalidates
    // the cached object and inherited custom-property substitution.
    try expectScript(realm, "[cached.marginLeft, getComputedStyle(child).marginLeft].join('|')", "24.5px|24.5px");
    try testing.expect(style_engine.generation != before);
    const unchanged = style_engine.generation;
    try platform.adapter.setCssEnvironmentVariable(browser, 0, .safe_area_inset_top, 0, 0, 24.5);
    try expectScript(realm, "cached.marginLeft", "24.5px");
    try testing.expectEqual(unchanged, style_engine.generation);
    try platform.adapter.setCssEnvironmentVariable(browser, 0, .safe_area_inset_top, 0, 0, null);
    try expectScript(realm, "[cached.marginLeft, getComputedStyle(child).marginLeft].join('|')", "37px|37px");
    try platform.adapter.setCssEnvironmentVariable(browser, 0, .safe_area_inset_top, 0, 0, 0);
    try expectScript(realm, "[cached.marginLeft, getComputedStyle(child).marginLeft].join('|')", "0px|0px");
    try platform.adapter.setCssEnvironmentVariable(browser, 0, .viewport_segment_width, std.math.maxInt(u32), 0, 17);
    try expectScript(realm, "e.style.marginRight = 'env(viewport-segment-width 4294967295 0, 37px)'; cached.marginRight", "17px");
    // An integer outside the platform query's index range cannot alias
    // its largest valid index. vars1 owns this overflow/fallback decision.
    try expectScript(realm, "e.style.marginRight = 'env(viewport-segment-width 4294967296 0, 37px)'; cached.marginRight", "37px");
}

fn expectLookup(document: *runtime.Instance, name: []const u8, indices: []const u32, expected: []const u8) !void {
    const text = (try env.lookup(document, testing.allocator, name, indices)) orelse return error.NoValue;
    defer testing.allocator.free(text);
    try testing.expectEqualStrings(expected, text);
}

fn expectScript(realm: runtime.Context, source: []const u8, expected: []const u8) !void {
    const text = try engine.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, testing.allocator, .{ .report = reportScriptError });
    defer testing.allocator.free(text);
    try testing.expectEqualStrings(expected, text);
}

fn reportScriptError(_: ?*anyopaque, info: *const engine.ErrorInfo) void {
    std.debug.print("environment test: {s}\n", .{info.message});
}
