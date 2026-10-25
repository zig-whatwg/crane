//! CSS Fonts4 §2.3 and Q85: one alias map supplies CSSOM named properties.
//! The queued owner API changes the expected registration result automatically.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const properties = @import("dom").style.css.properties;
const testing = std.testing;

fn count(names: []const runtime.DOMString, wanted: []const u8) usize {
    var total: usize = 0;
    for (names) |name| if (std.mem.eql(u8, name.asSlice(), wanted)) {
        total += 1;
    };
    return total;
}

fn run() !void {
    if (comptime !@hasField(properties.Longhand, "font_width")) return error.FontWidthNotImplemented;
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(testing.allocator, .{});
    defer context.deinit();
    const style = try interfaces.CSSStyleDeclaration.init(testing.allocator, &context);
    defer interfaces.CSSStyleDeclaration.deinit(style);
    const names = try interfaces.CSSStyleDeclaration.getSupportedPropertyNames(style, testing.allocator);
    defer {
        for (names) |*name| name.deinit(testing.allocator);
        testing.allocator.free(names);
    }
    try testing.expectEqual(@as(usize, 1), count(names, "font-width"));
    // Q85: row118 owns this API/consumer pair. Before its gated MAIN merge,
    // pin the gap without making the unrelated native gate red; afterward,
    // require the aliases exactly once. Never add a second alias map here.
    const alias_count: usize = if (@hasDecl(properties, "legacy_alias_names")) 1 else 0;
    try testing.expectEqual(alias_count, count(names, "font-stretch"));
    try testing.expectEqual(alias_count, count(names, "-webkit-appearance"));

    try interfaces.CSSStyleDeclaration.call_setProperty(style, .initInterned("font-stretch"), .initInterned("condensed"), .notPassed());
    for ([_][]const u8{ "font-width", "font-stretch" }) |name| {
        var value = try interfaces.CSSStyleDeclaration.call_getPropertyValue(style, .initInterned(name));
        defer value.deinit(testing.allocator);
        try testing.expectEqualStrings("condensed", value.asSlice());
    }
    try testing.expectEqual(@as(u32, 1), try interfaces.CSSStyleDeclaration.get_length(style));
    var item = try interfaces.CSSStyleDeclaration.call_item(style, 0);
    defer item.deinit(testing.allocator);
    try testing.expectEqualStrings("font-width", item.asSlice());
    var text = try interfaces.CSSStyleDeclaration.get_cssText(style);
    defer text.deinit(testing.allocator);
    try testing.expectEqualStrings("font-width: condensed;", text.asSlice());
}

test "font stretch alias has one canonical declaration and the owner names API controls registration" {
    const Run = struct {
        fn main(failure: *?anyerror) void {
            run() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.main, .{&failure});
    thread.join();
    if (failure) |err| return err;
}
