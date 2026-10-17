//! HTML 8.1.8.1: an inline handler captures only its element's form owner.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");

fn exercise() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    const checked = try browser.evaluateScript(
        \\(() => {
        \\  const ancestor = document.createElement("form");
        \\  const owner = document.createElement("form");
        \\  owner.id = "explicit-handler-owner";
        \\  ancestor.__scopeValue = "ancestor";
        \\  owner.__scopeValue = "owner";
        \\  document.body.append(ancestor, owner);
        \\  const input = document.createElement("input");
        \\  const image = document.createElement("img");
        \\  const div = document.createElement("div");
        \\  input.setAttribute("form", owner.id);
        \\  ancestor.append(input, image, div);
        \\  input.setAttribute("onclick", "return __scopeValue;");
        \\  image.setAttribute("onclick", "return __scopeValue;");
        \\  div.setAttribute("onclick", "return typeof __scopeValue;");
        \\  const correct = input.onclick() === "owner" &&
        \\    image.onclick() === "ancestor" && div.onclick() === "undefined";
        \\  globalThis.retainedHandler = input.onclick;
        \\  ancestor.remove();
        \\  owner.remove();
        \\  return correct;
        \\})()
    );
    defer checked.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    try testing.expect(engine.toBoolean(realm, checked.borrow()));

    const Collect = struct {
        fn run(data: ?*anyopaque) void {
            engine.requestGarbageCollection(@ptrCast(@alignCast(data.?)));
        }
    };
    const agent = browser.getAgent() orelse return error.NoAgent;
    try engine.runInRealm(realm, Collect.run, agent);
    try engine.runInRealm(realm, Collect.run, agent);
    try browser.runEventLoop(10);
    const retained = try browser.evaluateScript("retainedHandler() === 'owner'");
    defer retained.release();
    try testing.expect(engine.toBoolean(realm, retained.borrow()));
}

test "inline handlers capture the actual form owner and keep it through GC" {
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
