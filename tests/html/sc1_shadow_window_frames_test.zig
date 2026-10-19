//! Window's child navigables follow document tree order, excluding shadow trees.
const std = @import("std");
const interfaces = @import("interfaces");
const runtime = @import("runtime");
const helpers = @import("edges_node_holders_helpers.zig");

fn expectNames(window: *runtime.Instance, expected: []const []const u8) !void {
    const names = try interfaces.Window.getSupportedPropertyNames(window, std.testing.allocator);
    defer {
        for (names) |*name| name.deinit(std.testing.allocator);
        std.testing.allocator.free(names);
    }
    try std.testing.expectEqual(expected.len, names.len);
    for (names) |name| try std.testing.expect(!std.mem.eql(u8, name.asSlice(), "sc1ShadowOnly"));
    for (expected) |wanted| {
        var count: usize = 0;
        for (names) |name| {
            if (std.mem.eql(u8, name.asSlice(), wanted)) count += 1;
        }
        try std.testing.expectEqual(@as(usize, 1), count);
    }
}

fn windowFrames() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\const sc1FrameHost = document.body.appendChild(document.createElement('div'));
        \\const sc1FrameShadow = sc1FrameHost.attachShadow({mode: 'closed'});
        \\const sc1HiddenFrame = document.createElement('iframe');
        \\sc1HiddenFrame.name = 'sc1ShadowOnly';
        \\sc1FrameShadow.appendChild(sc1HiddenFrame);
    );
    const window = page.browser.current_context.?.window_instance orelse return error.NoWindow;
    try std.testing.expectEqual(@as(u32, 0), try interfaces.Window.get_length(window));
    // Q13: the iframe's legacy engine-side own property bypasses the named
    // computation. Test the generated interface here; WPT retains every
    // script-level named-access assertion as evidence of that dependency.
    try expectNames(window, &.{});
    const result = try page.evaluate(
        \\(() => {
        \\  const first = document.createElement('iframe');
        \\  first.name = 'sc1NamedFrame';
        \\  first.id = 'sc1NamedFrame';
        \\  document.body.appendChild(first);
        \\  const second = document.createElement('iframe');
        \\  second.name = 'sc1SecondFrame';
        \\  document.body.appendChild(second);
        \\  globalThis.sc1DocumentFrames = [first, second];
        \\  if (window.length !== 2) return 'light length';
        \\  // Exercise Window's existing-child lookup. The separate WPT fixture
        \\  // reads indices before contentWindow to retain the adapter's lazy-path regression.
        \\  void first.contentWindow; void second.contentWindow;
        \\  if (window[0] !== first.contentWindow || window[1] !== second.contentWindow) return 'index';
        \\  document.body.insertBefore(second, first);
        \\  void first.contentWindow; void second.contentWindow;
        \\  if (window[0] !== second.contentWindow || window[1] !== first.contentWindow) return 'order';
        \\  return 'ok';
        \\})()
    );
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings("ok", result);
    // The first name is contributed by both its navigable and its element
    // ID; the supported property names contain it only once.
    try expectNames(window, &.{ "sc1NamedFrame", "sc1SecondFrame" });
    try page.run("for (const frame of sc1DocumentFrames) frame.remove(); sc1FrameHost.remove();");
    try std.testing.expectEqual(@as(u32, 0), try interfaces.Window.get_length(window));
    try expectNames(window, &.{});
}

test "Window frame length, names and indices use only document-tree children" {
    try helpers.onFreshThread(windowFrames);
}
