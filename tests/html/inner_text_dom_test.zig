//! Rendered-text context through a real document. These cases are native
//! because their evidence is the CSS algorithms and engine source, rather
//! than measured browser results (codex-innertext Q7/Q8/Q10).
const std = @import("std");
const Browser = @import("browser").Browser;

fn expectText(browser: *Browser, source: []const u8, expected: []const u8) !void {
    const context = browser.current_context orelse return error.NoContext;
    const text = try context.evaluateScriptToString(source, std.testing.allocator);
    defer std.testing.allocator.free(text);
    try std.testing.expectEqualStrings(expected, text);
}

fn exercise() !void {
    const browser = try Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigateWithOptions("https://innertext.test/", .window, .{ .skip_load = true });
    const context = browser.current_context orelse return error.NoContext;
    try context.loadHTML("<!doctype html><body><div id='target'></div></body>", .{ .base_url = "https://innertext.test/" });

    // CSS Text 4 whitespace processing includes hidden boxes; HTML's
    // rendered text collection omits their text strings.
    try expectText(browser,
        \\target.innerHTML = 'a <span style="visibility:hidden">x</span> b';
        \\target.innerText;
    , "a  b");
    // Blink LayoutText::TransformAndSecureText/ApplyTextTransform and
    // WebKit RenderText.cpp applyTextTransform use each original Text
    // separately for case mapping, but pass previous word context to
    // capitalization.
    try expectText(browser,
        \\target.innerHTML = '<span style="text-transform:lowercase">Ο<span>Σ</span></span>';
        \\target.innerText;
    , "οσ");
    try expectText(browser,
        \\target.innerHTML = '<span lang="lt" style="text-transform:lowercase">I<span>\u0301</span></span>';
        \\target.innerText;
    , "i\u{301}");
    try expectText(browser,
        \\target.innerHTML = '<span style="visibility:hidden">x</span><span style="text-transform:capitalize">abc</span>';
        \\target.innerText;
    , "abc");
    // CSS Shadow 1 §4.1: assigned Text nodes inherit from their slot.
    // HTML language inheritance still follows the DOM parent.
    try expectText(browser,
        \\target.replaceChildren();
        \\const host = document.createElement('div'); host.lang = 'tr';
        \\target.appendChild(host);
        \\const shadow = host.attachShadow({mode:'open'});
        \\const slot = document.createElement('slot');
        \\slot.style.cssText = 'text-transform:uppercase; white-space:pre';
        \\shadow.appendChild(slot); host.appendChild(document.createTextNode(' i  '));
        \\host.innerText;
    , " İ  ");
    try expectText(browser, "slot.style.display = 'none'; host.innerText;", "");
    try expectText(browser,
        \\slot.style.display = 'contents'; slot.style.visibility = 'hidden';
        \\host.innerText;
    , "");
    try expectText(browser,
        \\slot.style.visibility = 'visible'; slot.style.display = 'none';
        \\const assigned = document.createElement('span'); assigned.textContent = 'i';
        \\host.replaceChildren(assigned); host.innerText;
    , "");
}

fn exerciseOutOfFlow(comptime box_style: []const u8, comptime following: []const u8, expected: []const u8) !void {
    const browser = try Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigateWithOptions("https://innertext.test/", .window, .{ .skip_load = true });
    const context = browser.current_context orelse return error.NoContext;
    try context.loadHTML("<!doctype html><body><div id='target'></div></body>", .{ .base_url = "https://innertext.test/" });
    // CSS Text 4 §2.1.1, text-transform-capitalize-033.html (all three
    // engines pass), WebKit RenderText::previousCharacter and Gecko
    // CanTextCrossFrameBoundary: out-of-flow boxes are not word boundaries.
    // HTML's returned required line break remains a separate operation.
    try expectText(
        browser,
        "target.style.textTransform = 'capitalize';" ++
            "target.innerHTML = 'p<span style=\"" ++ box_style ++ "\"></span>" ++ following ++ "';" ++
            "target.innerText;",
        expected,
    );
}

fn onFreshThread(comptime exerciseFn: anytype) !void {
    const Run = struct {
        fn run(result: *?anyerror) void {
            exerciseFn() catch |err| {
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    if (result) |err| return err;
}

test "innerText keeps hidden and per-node context and inherits slotted Text style" {
    try onFreshThread(exercise);
}

test "innerText required breaks do not split capitalize at an absolute box inside a word" {
    try onFreshThread(struct {
        fn run() !void {
            try exerciseOutOfFlow("position:absolute", "ass", "P\nass");
        }
    }.run);
}

test "innerText required breaks do not split capitalize at a float inside a word" {
    try onFreshThread(struct {
        fn run() !void {
            try exerciseOutOfFlow("float:left", "ass", "P\nass");
        }
    }.run);
}

test "innerText preserves a capitalize word boundary beside an absolute box" {
    try onFreshThread(struct {
        fn run() !void {
            try exerciseOutOfFlow("position:absolute", " ass", "P\nAss");
        }
    }.run);
}

test "innerText preserves a capitalize word boundary beside a float" {
    try onFreshThread(struct {
        fn run() !void {
            try exerciseOutOfFlow("float:left", " ass", "P\nAss");
        }
    }.run);
}

test "float does not suppress capitalize boundaries on flex and grid items" {
    try onFreshThread(struct {
        fn run() !void {
            const browser = try Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
            defer browser.deinit();
            try browser.navigateWithOptions("https://innertext.test/", .window, .{ .skip_load = true });
            const context = browser.current_context orelse return error.NoContext;
            try context.loadHTML("<!doctype html><body><div id='target'></div></body>", .{ .base_url = "https://innertext.test/" });
            // CSS Display: a computed float does not take a flex/grid item
            // out of flow. Keep this exception to Q13's boundary rule.
            inline for (.{ "flex", "grid" }) |display| {
                try expectText(
                    browser,
                    "target.style.cssText = 'display:" ++ display ++ ";text-transform:capitalize';" ++
                        "target.innerHTML = 'p<span style=\"float:left\"></span>ass';target.innerText;",
                    "P\nAss",
                );
            }
        }
    }.run);
}
