//! HTML "text" insertion mode, an end tag whose tag name is "script": "If the
//! JavaScript execution context stack is empty, perform a microtask
//! checkpoint." The mutation records the parser queued for its own insertions
//! since the last script are delivered, in one callback, before the next
//! parser-inserted script runs - what Chrome, Firefox and Safari do
//! (dom/nodes/MutationObserver-document.html 4/4 in all three).
//!
//! The checkpoint asked engine.hasRunningScript, and V8 answered yes for any
//! entered agent - a page's is entered for its whole life - so a page never
//! had one: 4 records still pending at the next script, and no callback.
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

fn recordsBeforeEachScript() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(
        \\<!doctype html><body><script>
        \\var calls = [];
        \\new MutationObserver(function (records) {
        \\  var added = [];
        \\  for (var record of records) for (var node of record.addedNodes) if (node.nodeType === 1) added.push(node.localName);
        \\  calls.push(added.join(','));
        \\}).observe(document.body, { childList: true });
        \\</script><div></div><script>var atSecond = calls.join('|');</script><p></p><script>var atThird = calls.join('|');</script>
    , .{ .base_url = "http://example.test/parser-checkpoint" });
    const result = try page.evaluateScriptToString("atSecond + ' / ' + atThird", testing.allocator);
    defer testing.allocator.free(result);
    try testing.expectEqualStrings("div,script / div,script|p,script", result);
}

test "the parser's script end tag delivers the records of its own insertions first" {
    try onFreshThread(recordsBeforeEachScript);
}
