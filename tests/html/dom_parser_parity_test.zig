//! DOMParser's tree conversion (src/html/dom_parser.zig convertChildrenToDom)
//! makes the same document whatever shortcut it takes: the same markup, the
//! same template contents - nested templates included - and the same node
//! documents for them (HTML "appropriate template contents owner document").
//! Pinned before the conversion stopped looking up a node document for every
//! converted node (parser holds lane, M2), and unchanged after it.
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

const expected_markup =
    "<html><head><title>t</title></head><body>" ++
    "<div id=\"a\"><p>one<b>two</b></p>" ++
    "<template id=\"t1\"><span id=\"s1\">in</span><template id=\"t2\"><i id=\"s2\">deep</i><!--c--></template></template>" ++
    "text</div><table><tbody><tr><td>c</td></tr></tbody></table></body></html>";

fn domParserOutput() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    const result = try page.evaluateScriptToString(
        \\(() => {
        \\  const markup = '<!doctype html><html><head><title>t</title></head><body>' +
        \\    '<div id=a><p>one<b>two</b></p><template id=t1><span id=s1>in</span>' +
        \\    '<template id=t2><i id=s2>deep</i><!--c--></template></template>text</div>' +
        \\    '<table><tr><td>c</td></tr></table></body></html>';
        \\  const d = new DOMParser().parseFromString(markup, 'text/html');
        \\  const t1 = d.getElementById('t1');
        \\  const t2 = t1.content.querySelector('#t2');
        \\  return [
        \\    d.documentElement.outerHTML,
        \\    t1.ownerDocument === d,
        \\    t1.content.ownerDocument !== d,
        \\    t1.content.firstChild.ownerDocument === t1.content.ownerDocument,
        \\    t2.ownerDocument === t1.content.ownerDocument,
        \\    t2.content.ownerDocument === t1.content.ownerDocument,
        \\    t2.content.firstChild.ownerDocument === t2.content.ownerDocument,
        \\    t2.content.lastChild.nodeType,
        \\    d.getElementById('s1') === null,
        \\  ].join('|');
        \\})()
    , testing.allocator);
    defer testing.allocator.free(result);
    try testing.expectEqualStrings(expected_markup ++ "|true|true|true|true|true|true|8|true", result);
}

test "DOMParser makes the same document, template contents and their node documents included" {
    try onFreshThread(domParserOutput);
}
