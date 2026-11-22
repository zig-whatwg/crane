//! An <svg> element has no WindowEventHandlers (lane fw2, from Angular's
//! zone.js test "should patch all possible on properties on svg element").
//! SVG 2's IDL says `SVGSVGElement includes WindowEventHandlers`, and no
//! browser ships it: Chrome 157, Firefox 159 and Safari 27 expose none of
//! onafterprint ... onunload on an <svg> (SVGSVGElement.prototype has no
//! onafterprint; HTMLBodyElement.prototype does), and w3c/svgwg#741 (open
//! since 2019) asks whether the line is meant at all. Golden rule 2's last
//! case: the browsers agree with each other and no newer spec is lagging, so
//! Crane does what they do (src/webidl/codegen/include_removals.zig). The
//! element keeps its GlobalEventHandlers, and <body> and the Window keep
//! WindowEventHandlers.
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
    if (!engine.toBoolean(realm, result.borrow())) {
        const why = try browser.evaluateScript("String(globalThis.why)");
        defer why.release();
        const text = try engine.convertToDOMString(realm, why.borrow(), std.testing.allocator);
        defer std.testing.allocator.free(text);
        std.debug.print("failed: {s}\n", .{text});
        return error.TestUnexpectedResult;
    }
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

const window_handlers = "['onafterprint', 'onbeforeprint', 'onbeforeunload', 'onhashchange', 'onlanguagechange', 'onmessage', 'onmessageerror', 'onoffline', 'ononline', 'onpagehide', 'onpagereveal', 'onpageshow', 'onpageswap', 'onpopstate', 'onrejectionhandled', 'onstorage', 'onunhandledrejection', 'onunload']";

test "an <svg> element has no WindowEventHandlers, and keeps its GlobalEventHandlers" {
    try onThread("(() => { const names = " ++ window_handlers ++
        \\;
        \\  const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
        \\  const present = names.filter((n) => n in svg);
        \\  if (present.length) { globalThis.why = 'on svg: ' + present.join(','); return false; }
        \\  if (Object.prototype.hasOwnProperty.call(SVGSVGElement.prototype, 'onafterprint')) { globalThis.why = 'SVGSVGElement.prototype.onafterprint'; return false; }
        \\  if (!('onclick' in svg) || svg.onclick !== null) { globalThis.why = 'onclick'; return false; }
        \\  return true;
        \\})()
    );
}

test "<body> and the Window keep WindowEventHandlers" {
    try onThread("(() => { const names = " ++ window_handlers ++
        \\;
        \\  const missing = names.filter((n) => !(n in document.body) || !(n in window));
        \\  if (missing.length) { globalThis.why = 'missing: ' + missing.join(','); return false; }
        \\  return Object.prototype.hasOwnProperty.call(HTMLBodyElement.prototype, 'onafterprint') && document.body.onafterprint === null;
        \\})()
    );
}

test "an onafterprint content attribute on <svg> makes no handler, on the element or on the Window" {
    try onThread(
        \\(() => {
        \\  globalThis.ran = [];
        \\  const div = document.createElement('div');
        \\  div.innerHTML = '<svg onafterprint="globalThis.ran.push(event.currentTarget === window ? \'window\' : \'svg\')"></svg>';
        \\  document.body.append(div);
        \\  const svg = div.firstElementChild;
        \\  svg.dispatchEvent(new Event('afterprint'));
        \\  window.dispatchEvent(new Event('afterprint'));
        \\  if (ran.length) { globalThis.why = 'ran: ' + ran.join(','); return false; }
        \\  if (window.onafterprint !== null) { globalThis.why = 'window.onafterprint is ' + typeof window.onafterprint; return false; }
        \\  // The body's content attribute still reaches the Window.
        \\  document.body.setAttribute('onafterprint', 'globalThis.ran.push("body")');
        \\  window.dispatchEvent(new Event('afterprint'));
        \\  if (ran.join(',') !== 'body') { globalThis.why = 'body attribute: ' + ran.join(','); return false; }
        \\  return true;
        \\})()
    );
}
