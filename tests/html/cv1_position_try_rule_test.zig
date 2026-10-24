//! Anchor Position1 6.4 and 8.1: live CSSOM rules and restricted descriptors.
const std = @import("std");
const Browser = @import("browser").Browser;

fn exercise(comptime source: []const u8, expected: []const u8) !void {
    const browser = try Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigateWithOptions("https://cv1.test/", .window, .{ .skip_load = true });
    const context = browser.current_context orelse return error.NoContext;
    try context.loadHTML("<!doctype html><body><div id='target'></div></body>", .{ .base_url = "https://cv1.test/" });
    const text = try context.evaluateScriptToString(source, std.testing.allocator);
    defer std.testing.allocator.free(text);
    try std.testing.expectEqualStrings(expected, text);
}

fn fresh(comptime source: []const u8, expected: []const u8) !void {
    const Run = struct {
        fn run(want: []const u8, result: *?anyerror) void {
            exercise(source, want) catch |err| {
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{ expected, &result });
    thread.join();
    if (result) |err| return err;
}

test "position try exposes live restricted descriptors through the generated construction chain" {
    try fresh(
        \\const s = new CSSStyleSheet();
        \\s.replaceSync('@position-try --Foo { top:1px; color:red; --custom:yes; margin:2px; left:8px!important; width:fit-content(10px) }');
        \\const r = s.cssRules[0];
        \\if (!r) 'missing rule'; else {
        \\ const d = r.style;
        \\ const before = [r instanceof CSSPositionTryRule, d instanceof CSSPositionTryDescriptors,
        \\   r.name, r.type, r.parentStyleSheet === s, d.parentRule === r, d === r.style,
        \\   d.top, d.margin, d.getPropertyValue('color'), d.getPropertyValue('--custom'), d.left, d.width];
        \\ d.top = '3px'; d.setProperty('color','blue'); d.setProperty('left','4px','important');
        \\ const changed = [d.top, d.getPropertyValue('color'), d.left];
        \\ d.cssText = 'right:5px; opacity:.5; bottom:6px!important; @media all { top:7px }';
        \\ JSON.stringify([before,changed,d.cssText,r.cssText]);
        \\}
    , "[[true,true,\"--Foo\",0,true,true,true,\"1px\",\"2px\",\"\",\"\",\"\",\"fit-content(10px)\"],[\"3px\",\"\",\"\"],\"right: 5px;\",\"@position-try --Foo { right: 5px; }\"]");
}

test "position try validates exactly one dashed name and ignores nested rules" {
    try fresh(
        \\const s = new CSSStyleSheet();
        \\s.replaceSync('@position-try {} @position-try foo {} @position-try --a --b {} @position-try --a, --b {} @position-try --Good { @media all {left:1px} & {color:red} top:2px; }');
        \\JSON.stringify([s.cssRules.length,s.cssRules[0]?.name,s.cssRules[0]?.cssText]);
    , "[1,\"--Good\",\"@position-try --Good { top: 2px; }\"]");
}
