//! An empty fragment in an HTML html-element context still creates head/body.
//! Each Browser runs on a fresh thread; tests/html shares one test executable.
const std = @import("std");
const browser_mod = @import("browser");
const engine = @import("engine");

fn checkOnFreshThread(source: []const u8) !void {
    const Run = struct {
        fn run(script: []const u8, failure: *?anyerror) void {
            check(script) catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{ source, &failure });
    thread.join();
    if (failure) |err| return err;
}

fn check(source: []const u8) !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    const result = try browser.evaluateScript(source);
    defer result.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    try std.testing.expect(engine.toBoolean(realm, result.borrow()));
}

test "empty innerHTML parses head and body for an HTML html context" {
    try checkOnFreshThread(
        \\const root = document.createElement('html');
        \\root.innerHTML = '<head><title>old</title></head><body>old</body>';
        \\const old = Array.from(root.childNodes);
        \\root.innerHTML = '';
        \\root.innerHTML === '<head></head><body></body>' &&
        \\  root.firstChild instanceof HTMLHeadElement &&
        \\  root.lastChild instanceof HTMLBodyElement &&
        \\  old.every(node => node.parentNode === null)
    );
}

test "empty innerHTML keeps other HTML and foreign contexts empty" {
    try checkOnFreshThread(
        \\const contexts = ['div', 'table', 'tbody', 'tr', 'select', 'template'].map(name => document.createElement(name));
        \\contexts.push(document.createElementNS('http://www.w3.org/2000/svg', 'html'));
        \\contexts.push(document.createElementNS(null, 'html'));
        \\const xml = document.implementation.createDocument('http://www.w3.org/1999/xhtml', 'html');
        \\contexts.push(xml.documentElement);
        \\contexts.every(element => {
        \\  const target = element.content || element;
        \\  target.appendChild(element.ownerDocument.createTextNode('old'));
        \\  element.innerHTML = '';
        \\  return target.childNodes.length === 0;
        \\})
    );
}
