//! Registry extends validation follows HTML's existing element-interface lookup.
const std = @import("std");
const browser_mod = @import("browser");
const testing = std.testing;

fn registryValidation() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    const result = try page.evaluateScriptToString(
        \\(() => {
        \\  for (const tag of ['param', 'div', 'button', 'span', 'input', 'font', 'center', 'acronym', 'dir', 'listing', 'xmp', 'plaintext', 'frameset', 'frame', 'marquee']) {
        \\    const element = document.createElement(tag);
        \\    class Customized extends element.constructor {}
        \\    try { customElements.define('ac4-native-' + tag, Customized, {extends: tag}); }
        \\    catch (error) { return tag + ': ' + error.name; }
        \\    if (!(document.createElement(tag, {is: 'ac4-native-' + tag}) instanceof Customized)) return tag + ': not customized';
        \\  }
        \\  for (const tag of ['applet', 'keygen', 'unknown', 'DIV', 'my-element', 'x-custom', '']) {
        \\    class Invalid extends HTMLElement {}
        \\    try { customElements.define('ac4-invalid-' + (tag || 'empty').toLowerCase(), Invalid, {extends: tag}); }
        \\    catch (error) { if (error.name === 'NotSupportedError') continue; return tag + ': wrong exception ' + error.name; }
        \\    return tag + ': unexpectedly accepted';
        \\  }
        \\  return 'ok';
        \\})()
    , testing.allocator);
    defer testing.allocator.free(result);
    try testing.expectEqualStrings("ok", result);
}

test "customized built-ins recognize obsolete interfaces and reject unknown or custom local names" {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            registryValidation() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}
