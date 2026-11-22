//! HTML 8.1.8.1's event handler content attributes on MathML and SVG
//! elements. MathML Core 2.1.4: "All MathML elements support event handler
//! content attributes, as described in event handler content attributes in
//! HTML"; SVG 2 15.8: an SVG element's event attributes follow "the same
//! requirements as for event handler content attributes" in HTML, and the
//! function's one parameter is named `evt` (Blink, Gecko and WebKit all name
//! it so for an SVG element). An element of any other namespace has no event
//! handler content attributes: no IDL attribute, nothing compiled.
const std = @import("std");
const browser_mod = @import("browser");
const engine = @import("engine");

fn expectScript(comptime source: []const u8) !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    const result = try browser.evaluateScript(source);
    defer result.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    try std.testing.expect(engine.toBoolean(realm, result.borrow()));
}

fn onThread(comptime source: []const u8) !void {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            expectScript(source) catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

test "a MathML element's handler content attribute compiles into its IDL attribute" {
    try onThread(
        \\(() => {
        \\  const m = document.createElementNS('http://www.w3.org/1998/Math/MathML', 'math');
        \\  if (m.onclick !== null) return false;
        \\  m.setAttribute('onclick', 'return 7');
        \\  if (typeof m.onclick !== 'function' || m.onclick() !== 7) return false;
        \\  // Cloning copies the attribute, and its change steps compile it again.
        \\  const clone = m.cloneNode(true);
        \\  if (typeof clone.onclick !== 'function' || clone.onclick() !== 7) return false;
        \\  m.setAttribute('onclick', 'return 8');
        \\  if (m.onclick() !== 8) return false;
        \\  m.removeAttribute('onclick');
        \\  if (m.onclick !== null) return false;
        \\  // The parser sets it too, and dispatch runs it.
        \\  const div = document.createElement('div');
        \\  div.insertAdjacentHTML('beforeend', '<math onfocus="globalThis.ran = event.type"></math>');
        \\  div.firstElementChild.dispatchEvent(new Event('focus'));
        \\  return globalThis.ran === 'focus';
        \\})()
    );
}

test "an SVG element's handler content attribute compiles with its parameter named evt" {
    try onThread(
        \\(() => {
        \\  const r = document.createElementNS('http://www.w3.org/2000/svg', 'rect');
        \\  r.setAttribute('onclick', 'return evt');
        \\  if (typeof r.onclick !== 'function' || r.onclick(42) !== 42) return false;
        \\  const div = document.createElement('div');
        \\  div.innerHTML = '<svg onclick="globalThis.svgType = evt.type"></svg>';
        \\  div.firstElementChild.dispatchEvent(new Event('click'));
        \\  return globalThis.svgType === 'click';
        \\})()
    );
}

test "an element of another namespace has no handler content attributes" {
    try onThread(
        \\(() => {
        \\  const x = document.createElementNS('urn:example', 'x');
        \\  x.setAttribute('onclick', 'globalThis.otherRan = true');
        \\  x.dispatchEvent(new Event('click'));
        \\  return !('onclick' in x) && globalThis.otherRan === undefined;
        \\})()
    );
}
