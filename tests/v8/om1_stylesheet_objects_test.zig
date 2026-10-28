//! CSSOM 6.4.4; import media identity through native records and public interfaces.
//! Liaison Q4/Q77. A fresh thread owns every runtime pool and realm.
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");
const a = std.testing.allocator;

const Host = struct {
    fn window(realm: runtime.Context, _: runtime.JSValue, _: ?*anyopaque) ?*runtime.Instance {
        return interfaces.Window.init(a, realm) catch null;
    }
};

fn importViews(realm: runtime.Context) !void {
    for ([_]bool{ false, true }) |sheet_first| {
        const parent = try dom.style.SheetRecord.create(a, "@import url(child.css) screen;", .{});
        defer parent.unref();
        const child = try dom.style.SheetRecord.create(a, "", .{ .media = "screen" });
        // attachImport takes the child's reference on both success and error.
        try parent.attachImport(.{ .allocator = a }, 0, child);
        const rule = child.owner_rule orelse return error.NoImportRule;
        const rule_object = try dom.style.objects.ruleObject(rule, realm);
        const held_rule = try engine.retainValue(realm, .{ .instance = rule_object });
        defer held_rule.release();
        const sheet_object = try dom.style.objects.sheetObject(child, realm);
        const held_sheet = try engine.retainValue(realm, .{ .instance = sheet_object });
        defer held_sheet.release();
        const first = if (sheet_first)
            try interfaces.StyleSheet.get_media(sheet_object)
        else
            try interfaces.CSSImportRule.get_media(rule_object);
        const second = if (sheet_first)
            try interfaces.CSSImportRule.get_media(rule_object)
        else
            try interfaces.StyleSheet.get_media(sheet_object);
        try std.testing.expect(first == second);
        try std.testing.expect(first == try interfaces.CSSImportRule.get_media(rule_object));
        try std.testing.expect(first == try interfaces.StyleSheet.get_media(sheet_object));
        try interfaces.MediaList.set_mediaText(second, runtime.DOMString.initInterned("print"));
        var text = try interfaces.MediaList.get_mediaText(first);
        defer text.deinit(a);
        try std.testing.expectEqualStrings("print", text.asSlice());
        try interfaces.MediaList.call_appendMedium(first, runtime.DOMString.initInterned("screen"));
        var changed = try interfaces.MediaList.get_mediaText(second);
        defer changed.deinit(a);
        try std.testing.expectEqualStrings("print, screen", changed.asSlice());
        const parent_object = try interfaces.StyleSheet.get_parentStyleSheet(sheet_object) orelse return error.NoParentSheet;
        const ordinary_media = try interfaces.StyleSheet.get_media(parent_object);
        try std.testing.expect(ordinary_media != first);
        try std.testing.expectEqual(@as(u32, 0), try interfaces.MediaList.get_length(ordinary_media));
    }
}

fn checkImports() !void {
    try engine.initializeEngine(.{});
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(a);
    defer runtime.deinitializeRuntime();
    var scope = runtime.BrowserScope.init(a);
    defer scope.deinit();
    const hooks: engine.HostHooks = .{};
    const agent = try engine.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &hooks, .allocator = a });
    defer engine.destroyAgent(agent);
    const realm = try engine.createWindowRealm(&.{ .agent = agent, .allocator = a, .from_snapshot = false, .timer = null, .origin = "https://om1.test", .browser_scope = &scope, .create_global_object = Host.window });
    defer engine.destroyWindowRealm(realm, .global_detached);
    const Run = struct {
        realm: runtime.Context,
        result: anyerror!void = {},
        fn steps(raw: ?*anyopaque) void {
            const self: *@This() = @ptrCast(@alignCast(raw.?));
            self.result = importViews(self.realm);
        }
    };
    var run: Run = .{ .realm = realm };
    try engine.runInRealm(realm, Run.steps, &run);
    try run.result;
}

test "an import and its associated sheet share one live MediaList in either getter order" {
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, struct {
        fn body(out: *anyerror!void) void {
            out.* = checkImports();
        }
    }.body, .{&result});
    thread.join();
    try result;
}
