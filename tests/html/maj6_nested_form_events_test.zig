//! Lane maj6: a submit or reset event that a form nested in another form
//! fires does not reach the outer form's listeners, nor anything past it.
//! No spec text says so: the three browsers each stop such an event at an
//! ancestor form before its listeners run, outside the capture phase - Blink
//! and WebKit in HTMLFormElement::HandleLocalEvents (handleLocalEvents),
//! Gecko in HTMLFormElement::WillHandleEvent - so golden rule 2 follows them
//! (Chrome 157, Firefox 160 and Safari 27.2 pass all of
//! dom/events/Event-dispatch-single-activation-behavior.html).
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");

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

fn open() !*browser_mod.Browser {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
    errdefer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "https://maj6.test/page.html" });
    _ = try browser.runEventLoopBlocking(20);
    return browser;
}

fn run(browser: *browser_mod.Browser, source: []const u8) !void {
    const held = try browser.evaluateScript(source);
    held.release();
}

fn expectLog(browser: *browser_mod.Browser, source: []const u8, expected: []const u8) !void {
    try run(browser, source);
    _ = try browser.runEventLoopBlocking(20);
    const page = browser.current_context orelse return error.NoPage;
    const log = try page.evaluateScriptToString("globalThis.log.join(' ')", testing.allocator);
    defer testing.allocator.free(log);
    if (!std.mem.eql(u8, expected, log)) std.debug.print("after: {s}\n  expected: {s}\n  got:      {s}\n", .{ source, expected, log });
    try testing.expectEqualStrings(expected, log);
}

/// The outer form, with a control (`outer_control`) the inner form is put
/// inside, and listeners on every node from the outer form up that log
/// "<id>:<phase>:<type>".
const setup =
    \\globalThis.build = (outerControl, innerControl) => {
    \\  document.body.innerHTML = '';
    \\  const wrap = document.createElement('div'); wrap.id = 'wrap';
    \\  const outer = document.createElement('form'); outer.id = 'outer';
    \\  const oc = document.createElement(outerControl.tag); oc.type = outerControl.type;
    \\  const inner = document.createElement('form'); inner.id = 'inner';
    \\  const ic = document.createElement(innerControl.tag); ic.type = innerControl.type; ic.id = 'click';
    \\  document.body.append(wrap); wrap.append(outer); outer.append(oc); oc.append(inner); inner.append(ic);
    \\  globalThis.log = [];
    \\  for (const node of [wrap, outer, inner]) for (const type of ['submit', 'reset']) {
    \\    node.addEventListener(type, (e) => { log.push(node.id + ':' + e.eventPhase + ':' + type); e.preventDefault(); }, true);
    \\    node.addEventListener(type, (e) => { log.push(node.id + ':' + e.eventPhase + ':' + type); e.preventDefault(); });
    \\  }
    \\};
    \\0;
;

fn nestedSubmitAndReset() !void {
    const browser = try open();
    defer browser.deinit();
    try run(browser, setup);
    // The inner form's submit button submits the inner form: its submit event
    // runs the outer form's and the wrapper's capture listeners, the inner
    // form's own, and stops at the outer form going up - none of the outer
    // form's bubbling listeners, nothing above it.
    try expectLog(browser,
        \\build({ tag: 'input', type: 'image' }, { tag: 'input', type: 'submit' });
        \\document.getElementById('click').click();
    , "wrap:1:submit outer:1:submit inner:2:submit inner:2:submit");
    try expectLog(browser,
        \\build({ tag: 'button', type: 'submit' }, { tag: 'button', type: 'submit' });
        \\document.getElementById('click').click();
    , "wrap:1:submit outer:1:submit inner:2:submit inner:2:submit");
    // Reset alike.
    try expectLog(browser,
        \\build({ tag: 'button', type: 'reset' }, { tag: 'input', type: 'reset' });
        \\document.getElementById('click').click();
    , "wrap:1:reset outer:1:reset inner:2:reset inner:2:reset");
    // The outer form's own submit event is untouched: it is the target.
    try expectLog(browser,
        \\build({ tag: 'button', type: 'submit' }, { tag: 'input', type: 'submit' });
        \\document.getElementById('outer').requestSubmit();
    , "wrap:1:submit outer:2:submit outer:2:submit wrap:3:submit");
    // An event of another type bubbles through both forms as before.
    try expectLog(browser,
        \\build({ tag: 'button', type: 'submit' }, { tag: 'input', type: 'submit' });
        \\for (const node of [document.getElementById('wrap'), document.getElementById('outer')]) node.addEventListener('input', () => log.push(node.id + ':input'));
        \\document.getElementById('inner').dispatchEvent(new Event('input', { bubbles: true }));
    , "outer:input wrap:input");
}

test "a nested form's submit and reset events stop at the outer form, before its listeners" {
    try onFreshThread(nestedSubmitAndReset);
}
