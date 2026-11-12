//! SVG 2 §16.1.7.2 "Fetching the document" for the url() references of the
//! used values of fill, stroke and the markers (on SVG elements) and of
//! clip-path, filter and mask-image (on any element with a box): a reference
//! to another document fetches that document once, whatever fragments name
//! elements in it; a same-document reference fetches nothing. The fetches
//! are made at the rendering opportunity (resource_loading.updateRendering),
//! counted in flight against a server that never answers, and cancelled by
//! the document's abort (lane quick1 b2; Chrome + Firefox fetch every one).
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

/// Load `body` (the page's script) into a fresh Browser whose base URL
/// never answers, run its rendering opportunities, and return how many
/// fetches are in flight; then abort the document and check none is left.
fn inFlightAfter(script: []const u8) !usize {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "http://127.0.0.1:65533/page.html" });
    const result = try browser.evaluateScript(script);
    result.release();
    var turns: usize = 0;
    while (turns < 5) : (turns += 1) _ = try browser.runEventLoopBlocking(20);
    const count = browser.agent_host.fetches.inFlight();
    const stopped = try browser.evaluateScript("window.stop(); true");
    stopped.release();
    try testing.expectEqual(@as(usize, 0), browser.agent_host.fetches.inFlight());
    return count;
}

const svg_path =
    \\const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    \\const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    \\path.setAttribute('d', 'M 0,0 10,10 z');
    \\svg.append(path);
    \\document.body.append(svg);
;

fn paintReference() !void {
    try testing.expectEqual(@as(usize, 1), try inFlightAfter(svg_path ++
        \\path.style = 'fill: url(http://127.0.0.1:65533/paint.svg#gradient)';
        \\true
    ));
}

test "an SVG shape's fill naming another document fetches it" {
    try onFreshThread(paintReference);
}

fn oneDocumentManyFragments() !void {
    try testing.expectEqual(@as(usize, 1), try inFlightAfter(svg_path ++
        \\path.setAttribute('stroke', 'url(/defs.svg#a)');
        \\path.setAttribute('marker-start', 'url(/defs.svg#b)');
        \\path.style.clipPath = 'url(/defs.svg#c)';
        \\true
    ));
}

test "references into one document fetch it once, a presentation attribute's too" {
    try onFreshThread(oneDocumentManyFragments);
}

fn sameDocumentReferences() !void {
    try testing.expectEqual(@as(usize, 0), try inFlightAfter(svg_path ++
        \\path.style = 'fill: url(#local); filter: url(http://127.0.0.1:65533/page.html#f)';
        \\true
    ));
}

test "same-document references fetch nothing" {
    try onFreshThread(sameDocumentReferences);
}

fn htmlElements() !void {
    // fill paints SVG shapes only; filter and mask-image apply to any box.
    try testing.expectEqual(@as(usize, 2), try inFlightAfter(
        \\const a = document.createElement('div');
        \\a.style = 'fill: url(/not-for-html.svg#p)';
        \\const b = document.createElement('div');
        \\b.style = 'filter: url(/filters.svg#blur)';
        \\const c = document.createElement('div');
        \\c.style = 'mask-image: url(/mask.png)';
        \\document.body.append(a, b, c);
        \\true
    ));
}

test "an HTML element's filter and mask-image fetch, its fill does not" {
    try onFreshThread(htmlElements);
}
