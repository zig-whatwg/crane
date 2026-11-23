//! HTMLIFrameElement's `sandbox` getter reads the content attribute; it never
//! writes it (lane bugs1, from lane impls8's report).
//!
//! HTML 2.6.1: a reflected DOMTokenList attribute's getter returns a
//! DOMTokenList whose associated element is the iframe and whose associated
//! attribute is "sandbox" - DOM's "when a DOMTokenList object is created"
//! steps parse the attribute's current value into its token set, and only
//! the list's own operations (add, remove, toggle, replace, the value setter)
//! "set an attribute value". So the first read makes no MutationRecord and
//! runs no [CEReactions] attribute change: Chrome, Firefox and Safari all
//! read it silently (Blink HTMLIFrameElement::sandbox makes a
//! DOMTokenList bound to the attribute, WebKit HTMLIFrameElement::sandbox the
//! same, Gecko nsDOMTokenList over the attribute - none sets it). Crane's
//! first read used to write the attribute back to its own value.
//!
//! Each test runs on a thread of its own.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const engine = @import("engine");
const Browser = @import("browser").Browser;

fn onThread(comptime body: fn () anyerror!void) !void {
    const Run = struct {
        fn run(result: *anyerror!void) void {
            result.* = body();
        }
    };
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{ .stack_size = 16 * 1024 * 1024 }, Run.run, .{&result});
    thread.join();
    try result;
}

fn openBrowser(url: []const u8, markup: []const u8) !*Browser {
    const browser = try Browser.init(testing.allocator, .{ .snapshot_path = "" });
    errdefer browser.deinit();
    try browser.navigateWithOptions(url, .window, .{ .skip_load = true });
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(markup, .{ .base_url = url });
    return browser;
}

fn ignoreReport(_: ?*anyopaque, _: *const engine.ErrorInfo) void {}

fn expectAnswer(realm: runtime.Context, source: []const u8, want: []const u8) !void {
    const got = try engine.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, testing.allocator, .{ .report = ignoreReport });
    defer testing.allocator.free(got);
    if (!std.mem.eql(u8, want, got)) std.debug.print("{s}\n  answered {s}\n", .{ source, got });
    try testing.expectEqualStrings(want, got);
}

fn firstReadMakesNoRecord() !void {
    const browser = try openBrowser("http://bugs1-sandbox.test/", "<!doctype html><body>");
    defer browser.deinit();
    const realm = browser.getRealm() orelse return error.NoRealm;
    // An iframe with a sandbox attribute, observed for attribute changes,
    // its `sandbox` read for the first time: no record, and the list holds
    // the attribute's tokens.
    try expectAnswer(realm,
        \\(() => {
        \\  const frame = document.createElement('iframe');
        \\  frame.setAttribute('sandbox', 'allow-scripts  allow-forms');
        \\  const observer = new MutationObserver(() => {});
        \\  observer.observe(frame, { attributes: true, attributeOldValue: true });
        \\  const list = frame.sandbox;
        \\  const records = observer.takeRecords();
        \\  observer.disconnect();
        \\  return [records.length, list.length, list.value, frame.getAttribute('sandbox')].join('|');
        \\})()
    , "0|2|allow-scripts  allow-forms|allow-scripts  allow-forms");
    // A connected iframe: the same.
    try expectAnswer(realm,
        \\(() => {
        \\  const frame = document.body.appendChild(document.createElement('iframe'));
        \\  frame.setAttribute('sandbox', 'allow-same-origin');
        \\  const observer = new MutationObserver(() => {});
        \\  observer.observe(frame, { attributes: true });
        \\  const value = frame.sandbox.value;
        \\  const records = observer.takeRecords();
        \\  observer.disconnect();
        \\  frame.remove();
        \\  return records.length + '|' + value;
        \\})()
    , "0|allow-same-origin");
    // No attribute: the first read does not add one, and the list is empty.
    try expectAnswer(realm,
        \\(() => {
        \\  const frame = document.createElement('iframe');
        \\  const observer = new MutationObserver(() => {});
        \\  observer.observe(frame, { attributes: true });
        \\  const length = frame.sandbox.length;
        \\  const records = observer.takeRecords();
        \\  observer.disconnect();
        \\  return [records.length, length, frame.hasAttribute('sandbox')].join('|');
        \\})()
    , "0|0|false");
    // The list's own operations still set the attribute: one record each,
    // with the old value.
    try expectAnswer(realm,
        \\(() => {
        \\  const frame = document.createElement('iframe');
        \\  frame.setAttribute('sandbox', 'allow-forms');
        \\  const observer = new MutationObserver(() => {});
        \\  observer.observe(frame, { attributes: true, attributeOldValue: true });
        \\  const list = frame.sandbox;
        \\  list.add('allow-popups');
        \\  const records = observer.takeRecords();
        \\  observer.disconnect();
        \\  return [records.length, records[0] && records[0].oldValue, frame.getAttribute('sandbox'), frame.sandbox === list].join('|');
        \\})()
    , "1|allow-forms|allow-forms allow-popups|true");
}

test "the first read of iframe.sandbox writes nothing: no MutationRecord, the attribute unchanged" {
    try onThread(firstReadMakesNoRecord);
}
