//! A child unload handler can open its parent without unloading twice.
const std = @import("std");
const browser_mod = @import("browser");
const dom = @import("dom");
const interfaces = @import("interfaces");
const runtime = @import("runtime");

fn exercise() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.TestUnexpectedResult;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "http://example.test/nr1" });
    try page.runScript(
        \\globalThis.unloadCount = 0;
        \\globalThis.child = document.body.appendChild(document.createElement('iframe'));
        \\child.id = 'child';
        \\child.contentWindow.onunload = () => {
        \\  if (++unloadCount === 1) document.open();
        \\};
    );
    const document = page.document_instance orelse return error.TestUnexpectedResult;
    const frame = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("child"))) orelse return error.TestUnexpectedResult;
    const child_document = (try interfaces.HTMLIFrameElement.get_contentDocument(frame)) orelse return error.TestUnexpectedResult;
    dom.document_lifecycle.unload(child_document);
    try page.runScript(
        \\if (unloadCount !== 1) throw new Error('child unloaded ' + unloadCount + ' times');
        \\if (document.childNodes.length !== 0) throw new Error('parent was not opened');
        \\document.write('<p id="continued">continued</p>');
        \\document.close();
        \\if (document.getElementById('continued')?.textContent !== 'continued')
        \\  throw new Error('parent parser cannot continue after child unload');
    );
}

test "document.open in child unload does not reenter that unload" {
    // The directory shares one executable; keep this Browser's thread state
    // independent of whichever HTML test ran first.
    const Run = struct {
        failure: ?anyerror = null,
        fn thread(self: *@This()) void {
            exercise() catch |err| {
                self.failure = err;
            };
        }
    };
    var run: Run = .{};
    const thread = try std.Thread.spawn(.{}, Run.thread, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}
