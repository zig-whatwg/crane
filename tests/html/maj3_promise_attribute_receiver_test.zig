//! WebIDL 3.7.6, the attribute getter: its steps - the receiver check
//! included - run in a "try", and "if an exception E was thrown: if
//! attribute's type is a promise type, then return ! Call(%Promise.reject%,
//! %Promise%, «E»)". So a promise-typed attribute read on a wrong receiver
//! returns a promise rejected with the TypeError instead of throwing it, as an
//! operation returning a promise already does. A getter of any other type
//! still throws.
//!
//! Chrome, Firefox and Safari all return the rejected promise (wpt.fyi
//! 2358bd4835: streams/idlharness.any.html "ReadableStreamDefaultReader
//! interface: attribute closed", css/css-font-loading/idlharness.https.html
//! "FontFace interface: attribute loaded", web-animations/idlharness.window.html
//! "Animation interface: attribute ready": PASS in all three).
const std = @import("std");
const browser_mod = @import("browser");
const testing = std.testing;

fn exercise() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    const started = try page.evaluateScriptToString(
        \\(() => {
        \\  const cases = [
        \\    ['ReadableStreamDefaultReader', 'closed'],
        \\    ['ReadableStreamBYOBReader', 'closed'],
        \\    ['WritableStreamDefaultWriter', 'closed'],
        \\    ['WritableStreamDefaultWriter', 'ready'],
        \\    ['FontFace', 'loaded'],
        \\    ['Animation', 'ready'],
        \\    ['Animation', 'finished'],
        \\  ];
        \\  globalThis.outcomes = [];
        \\  globalThis.expected = 0;
        \\  const settle = (label, p) => {
        \\    if (!(p instanceof Promise)) { outcomes.push(label + ': not a promise'); return; }
        \\    expected++;
        \\    p.then(() => outcomes.push(label + ': fulfilled'),
        \\           (e) => outcomes.push(e instanceof TypeError ? 'ok' : label + ': rejected with ' + e));
        \\  };
        \\  for (const [iface, name] of cases) {
        \\    const I = globalThis[iface];
        \\    if (typeof I !== 'function') { outcomes.push(iface + ': no interface object'); continue; }
        \\    const desc = Object.getOwnPropertyDescriptor(I.prototype, name);
        \\    // The getter called on an object that is no instance.
        \\    try { settle(iface + '.' + name + ' on {}', desc.get.call({})); }
        \\    catch (e) { outcomes.push(iface + '.' + name + ' on {} threw ' + e); }
        \\    // The interface prototype object itself is no instance either.
        \\    try { settle(iface + '.prototype.' + name, I.prototype[name]); }
        \\    catch (e) { outcomes.push(iface + '.prototype.' + name + ' threw ' + e); }
        \\  }
        \\  // A getter whose type is not a promise still throws.
        \\  try {
        \\    Object.getOwnPropertyDescriptor(Node.prototype, 'nodeType').get.call({});
        \\    outcomes.push('Node.nodeType on {}: did not throw');
        \\  } catch (e) {
        \\    if (!(e instanceof TypeError)) outcomes.push('Node.nodeType on {} threw ' + e);
        \\  }
        \\  return String(expected);
        \\})()
    , testing.allocator);
    defer testing.allocator.free(started);
    _ = try browser.runEventLoopBlocking(20);
    const outcomes = try page.evaluateScriptToString("outcomes.filter((o) => o !== 'ok').join('\\n') + '|' + outcomes.filter((o) => o === 'ok').length", testing.allocator);
    defer testing.allocator.free(outcomes);
    // Seven attributes, each read two ways: fourteen promises, each rejected
    // with a TypeError, and nothing else recorded.
    try testing.expectEqualStrings("14", started);
    try testing.expectEqualStrings("|14", outcomes);
}

test "a promise-typed attribute read on a wrong receiver returns a promise rejected with a TypeError" {
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
