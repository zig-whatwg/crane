//! Cloned roots preserve the existing flag governing ElementInternals access.
const std = @import("std");
const browser_mod = @import("browser");
const testing = std.testing;

fn cloneAvailability() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    const result = try page.evaluateScriptToString(
        \\(() => {
        \\  const late = document.createElement('ac4-native-late');
        \\  late.attachShadow({mode: 'closed', clonable: true});
        \\  customElements.define('ac4-native-late', class extends HTMLElement {
        \\    constructor() { super(); this.internals = this.attachInternals(); }
        \\  });
        \\  customElements.upgrade(late);
        \\  if (late.internals.shadowRoot !== null) return 'late root became available';
        \\  if (late.cloneNode(true).internals.shadowRoot !== null) return 'late clone became available';
        \\  customElements.define('ac4-native-early', class extends HTMLElement {
        \\    constructor() { super(); this.internals = this.attachInternals(); }
        \\  });
        \\  const early = document.createElement('ac4-native-early');
        \\  const shadow = early.attachShadow({mode: 'closed', clonable: true});
        \\  shadow.innerHTML = '<span>kept</span>';
        \\  const clone = early.cloneNode(true);
        \\  const clonedShadow = clone.internals.shadowRoot;
        \\  if (clonedShadow === null) return 'available root lost on clone';
        \\  if (clonedShadow === shadow) return 'clone reused root';
        \\  if (clonedShadow.textContent !== 'kept') return 'clone lost content';
        \\  return 'ok';
        \\})()
    , testing.allocator);
    defer testing.allocator.free(result);
    try testing.expectEqualStrings("ok", result);
}

test "cloning preserves both values of shadow root internals availability" {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            cloneAvailability() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}
