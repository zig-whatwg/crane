//! Named CSS setters finish their custom-element reactions before returning.
const std = @import("std");
const browser_mod = @import("browser");
const testing = std.testing;

fn namedReactions() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    const result = try page.evaluateScriptToString(
        \\(() => {
        \\  const log = [];
        \\  let inner;
        \\  class Observed extends HTMLElement {
        \\    static observedAttributes = ['style'];
        \\    attributeChangedCallback() {
        \\      log.push(this.id + ':enter');
        \\      if (this.id === 'outer') inner.style['font-size'] = '20px';
        \\      log.push(this.id + ':exit');
        \\    }
        \\  }
        \\  customElements.define('ac4-native-style', Observed);
        \\  const outer = document.createElement('ac4-native-style');
        \\  inner = document.createElement('ac4-native-style');
        \\  outer.id = 'outer'; inner.id = 'inner';
        \\  outer.style.fontSize = '10px';
        \\  log.push('returned');
        \\  return log.join(',');
        \\})()
    , testing.allocator);
    defer testing.allocator.free(result);
    try testing.expectEqualStrings("outer:enter,inner:enter,inner:exit,outer:exit,returned", result);
}

test "named CSS setters invoke nested reactions synchronously" {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            namedReactions() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}
