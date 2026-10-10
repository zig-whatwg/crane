//! HTML "create an element for a token" step 15: a form-associated element
//! the parser creates while the form element pointer is set is associated
//! with that form - a misnested or foster-parented control too - and "reset
//! the form owner" undoes it when a removal separates it from its form, or
//! its form attribute changes. Removing the form resets it as well (Blink,
//! WebKit; html/form_associated.zig states the deviation). A form-associated
//! custom element is never associated. Chrome, Firefox and Safari associate.
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

fn associations() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(
        \\<!doctype html><script>
        \\customElements.define('p2-face', class extends HTMLElement {
        \\  static formAssociated = true;
        \\  constructor() { super(); this.internals = this.attachInternals(); }
        \\});
        \\</script><body>
        \\<div><form id=f1></div><input id=a><p2-face id=face></p2-face><input id=b form=none><input id=c></form>
        \\<table><form id=f2><input id=d type=text><tr><td><select id=e></select></td></tr></table></form>
        \\<div id=wrap><div><form id=f3></div><input id=g></div></form>
    , .{ .base_url = "http://example.test/parser-form-association" });
    const result = try page.evaluateScriptToString(
        \\(() => {
        \\  const $ = (id) => document.getElementById(id);
        \\  const fail = [];
        \\  if ($('a').form !== $('f1')) fail.push('misnested');
        \\  if ($('face').internals.form !== null) fail.push('FACE associated');
        \\  if ($('b').form !== null) fail.push('form attribute');
        \\  if ($('d').parentNode !== document.body || $('d').form !== $('f2')) fail.push('foster-parented');
        \\  if ($('e').form !== $('f2')) fail.push('in a cell');
        \\  const listed = Array.from($('f1').elements).map(e => e.id).join();
        \\  if (listed !== 'a,c') fail.push('elements ' + listed);
        \\  $('c').setAttribute('form', 'x'); $('c').removeAttribute('form');
        \\  if ($('c').form !== null) fail.push('form attribute set later');
        \\  const a = $('a');
        \\  a.remove(); document.body.append(a);
        \\  if (a.form !== null) fail.push('control removed');
        \\  const wrap = $('wrap');
        \\  wrap.remove(); document.body.append(wrap);
        \\  if ($('g').form !== $('f3')) fail.push('removed with its form');
        \\  $('f3').remove();
        \\  if ($('g').form !== null) fail.push('form removed');
        \\  const doc = new DOMParser().parseFromString('<div><form id=p></div><input id=q>', 'text/html');
        \\  if (doc.getElementById('q').form !== doc.getElementById('p')) fail.push('DOMParser');
        \\  const div = document.createElement('div');
        \\  div.innerHTML = '<div><form></div><input>';
        \\  if (div.querySelector('input').form !== null) fail.push('fragment');
        \\  return fail.length ? fail.join('; ') : 'ok';
        \\})()
    , testing.allocator);
    defer testing.allocator.free(result);
    try testing.expectEqualStrings("ok", result);
}

test "the parser associates controls through the form element pointer, and resets undo it" {
    try onFreshThread(associations);
}
