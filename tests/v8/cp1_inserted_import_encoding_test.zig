//! An inserted import reads the encoding retained by its parent sheet.
//! Fetching this inserted rule is a separate loader capability.
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");

fn createGlobal(realm: runtime.Context, _: runtime.JSValue, _: ?*anyopaque) ?*runtime.Instance {
    return interfaces.Window.init(realm.allocator, realm) catch null;
}

fn checkInsertedImport() !void {
    const a = std.testing.allocator;
    var scope = runtime.BrowserScope.init(a);
    defer scope.deinit();
    const no_hooks: engine.HostHooks = .{};
    const agent = try engine.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
    defer engine.destroyAgent(agent);
    const realm = try engine.createWindowRealm(&.{
        .agent = agent,
        .allocator = a,
        .from_snapshot = false,
        .timer = null,
        .origin = "https://sheet.example",
        .browser_scope = &scope,
        .create_global_object = createGlobal,
    });
    defer engine.destroyWindowRealm(realm, .global_detached);
    const decoding = dom.style.css.rules.stylesheet_encoding;
    const encoding = decoding.encodingForLabel("windows-1251").?;
    const parent = try dom.style.SheetRecord.create(a, "a { color: red }", .{
        .location = "https://sheet.example/parent.css",
        .base_url = "https://sheet.example/parent.css",
        .encoding = encoding,
    });
    defer parent.unref();
    _ = try parent.rulesWith(.{ .allocator = a });
    try std.testing.expect(parent.text == null);
    parent.detach();
    const object = try interfaces.CSSStyleSheet.initWith(a, realm, .{ .sheet_record = parent });
    defer interfaces.CSSStyleSheet.deinit(object);
    try std.testing.expectEqual(@as(u32, 0), try interfaces.CSSStyleSheet.call_insertRule(
        object,
        runtime.DOMString.initInterned("@import url(https://sheet.example/child.css);"),
        .passed(0),
    ));
    const inserted = parent.rules.?.items[0];
    try std.testing.expectEqual(.import, inserted.kind());
    try std.testing.expect(inserted.sheet() == parent);
    var child = try decoding.decode(a, ".\xe6 { color: blue }", .{
        .environment_label = inserted.sheet().?.encoding.?.name,
    });
    defer child.deinit(a);
    try std.testing.expectEqualStrings(".ж { color: blue }", child.text);
    try std.testing.expect(child.encoding == encoding);
}

test "CSSOM-inserted import inherits a parsed detached parent's encoding" {
    try engine.initializeEngine(.{});
    interfaces.process_hooks.startHooksForTest();
    const Run = struct {
        fn run(result: *anyerror!void) void {
            result.* = checkInsertedImport();
        }
    };
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{ .stack_size = 16 * 1024 * 1024 }, Run.run, .{&result});
    thread.join();
    try result;
}
