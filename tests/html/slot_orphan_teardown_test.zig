//! A slot that leaves its tree while script holds no wrapper of it is an
//! orphan: nothing frees it before its browser ends (dom/teardown_sweeps.zig).
//! Its SlotState owns memory of its own - the assigned nodes' buffer, from the
//! allocator the slot was made with - so the browser's end must still free
//! that state, through the sweep HTMLSlotElement installs.
//!
//! The case WPT met (shadow-dom/declarative/declarative-shadow-dom-attachment.html,
//! 64 leaked buffers at exit): attachShadow on a host with a declarative shadow
//! root removes all of the root's children (DOM attachShadow step 4.3), and the
//! removed slot, which had an assigned node and no wrapper, is orphaned.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");

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

fn orphanAssignedSlot() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    // The slot gets the light <span> as an assigned node when the parser
    // inserts it; script never touches the slot, so it has no wrapper.
    try page.loadHTML(
        \\<!doctype html><body><div id=host><template shadowrootmode=open><slot></slot></template><span>light</span></div>
    , .{ .base_url = "http://example.test/slot-orphan" });
    const result = try page.evaluateScriptToString(
        \\(() => {
        \\  const host = document.getElementById('host');
        \\  // DOM attachShadow step 4.3: the declarative root's children,
        \\  // the slot among them, are removed - wrapperless, so orphaned.
        \\  const root = host.attachShadow({mode: 'open'});
        \\  return root.firstChild === null ? 'ok' : 'not emptied';
        \\})()
    , testing.allocator);
    defer testing.allocator.free(result);
    try testing.expectEqualStrings("ok", result);
}

test "a slot orphaned wrapperless with assigned nodes is freed at the browser's end" {
    try onFreshThread(orphanAssignedSlot);
}
