//! Output reset removes its descendant input, which must still reset next.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const engine = @import("engine");
const browser_mod = @import("browser");
const testing = std.testing;

fn exercise() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    const document = page.document_instance orelse return error.NoDocument;
    const realm = browser.getRealm() orelse return error.NoRealm;
    const form = try interfaces.Document.call_createElement(document, runtime.DOMString.initInterned("form"), .notPassed());
    const body = (try interfaces.Document.get_body(document)) orelse return error.NoBody;
    _ = try interfaces.Node.call_appendChild(body, form);
    const output = try interfaces.Document.call_createElement(document, runtime.DOMString.initInterned("output"), .notPassed());
    _ = try interfaces.Node.call_appendChild(form, output);
    const input = try interfaces.Document.call_createElement(document, runtime.DOMString.initInterned("input"), .notPassed());
    // DOM insertion permits this nesting; output reset removes the input.
    _ = try interfaces.Node.call_appendChild(output, input);
    const held = try engine.retainValue(realm, .{ .instance = input });
    defer held.release();
    try interfaces.HTMLInputElement.set_defaultValue(input, runtime.DOMString.initInterned("default"));
    try interfaces.HTMLInputElement.set_value(input, runtime.DOMString.initInterned("dirty"));
    try testing.expectEqual(form, (try interfaces.HTMLInputElement.get_form(input)).?);
    try interfaces.HTMLFormElement.call_reset(form);
    try testing.expectEqual(null, try interfaces.Node.get_parentNode(input));
    var value = try interfaces.HTMLInputElement.get_value(input);
    defer value.deinit(testing.allocator);
    try testing.expectEqualStrings("default", value.asSlice());
}

test "form reset reaches a snapshotted input removed by output reset" {
    const Run = struct {
        fn run(result: *?anyerror) void {
            exercise() catch |err| {
                std.debug.print("reset snapshot fixture failed: {s}\n", .{@errorName(err)});
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    if (result) |err| return err;
}
