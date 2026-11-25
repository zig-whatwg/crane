//! Forced Colors Mode end-to-end browser tests via emulated media (CDP
//! Emulation.setEmulatedMedia -> HostOverrides.setMedia; lane forcedcolors1).
//!
//! Covers:
//! - Toggling forced-colors: none -> active (light) -> active (dark) -> none
//!   invalidates cached styles and MatchedPropertiesCache immediately.
//! - getComputedStyle() vs computedStyleMap() separation (WPT forced-colors-mode-40/41).
//! - UA stylesheet rules for <mark>, <a href>, <a><em>, <svg><path>, <svg><foreignObject>
//!   (CSS Color Adjust 1 §3.2; WPT forced-colors-mode-03, -26, -52).
//! - @media (forced-colors: active) + forced-color-adjust: none / preserve-parent-color
//!   (WPT forced-colors-mode-09, -10, -11, -20, -21, -27, -50, -51, -54, -60).
const std = @import("std");
const testing = std.testing;
const html = @import("html");
const dom = @import("dom");
const browser_mod = @import("browser");

fn onFreshThread(comptime body: fn () anyerror!void) !void {
    const Run = struct {
        failure: ?anyerror = null,
        fn thread(self: *@This()) void {
            body() catch |err| {
                self.failure = err;
            };
        }
    };
    var run: Run = .{};
    const thread = try std.Thread.spawn(.{}, Run.thread, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}

fn topOf(browser: *browser_mod.Browser, tab: u64) !*html.BrowsingContext {
    const navigables = dom.browser_state.existingNavigablesIn(browser.scope) orelse return error.NoNavigables;
    for (navigables.contexts()) |bc| {
        if (bc.parent == null and bc.id == tab) return bc;
    }
    return error.NoTab;
}

fn expectEval(page: *browser_mod.Context, source: []const u8, expected: []const u8) !void {
    const got = try page.evaluateScriptToString(source, testing.allocator);
    defer testing.allocator.free(got);
    if (!std.mem.eql(u8, got, expected)) {
        std.debug.print("eval failed:\n  expr:     {s}\n  expected: {s}\n  got:      {s}\n", .{ source, expected, got });
    }
    try testing.expectEqualStrings(expected, got);
}

fn emulatedMediaToggleAndCascade() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(
        \\<!doctype html>
        \\<style>
        \\  body { color: rgb(255, 0, 0); }
        \\  #box {
        \\    color: rgb(0, 128, 0);
        \\    background-color: rgba(114, 173, 218, 0.3);
        \\    border: 2px solid rgb(0, 128, 0);
        \\    outline: 1px solid rgb(0, 128, 0);
        \\    box-shadow: 2px 2px rgb(128, 0, 128);
        \\    text-shadow: 1px 1px rgb(255, 165, 0);
        \\    background-image: linear-gradient(red, yellow);
        \\    color-scheme: dark;
        \\    accent-color: rgb(0, 128, 0);
        \\    scrollbar-color: rgb(0, 128, 0) rgb(255, 0, 0);
        \\    font-variant-emoji: unicode;
        \\  }
        \\  #optout {
        \\    forced-color-adjust: none;
        \\    color: rgb(0, 128, 0);
        \\    background-color: rgb(128, 0, 128);
        \\    color-scheme: light;
        \\    accent-color: rgb(0, 128, 0);
        \\  }
        \\  #withurl {
        \\    background-image: url("https://example.test/bg.png");
        \\    accent-color: CanvasText;
        \\    font-variant-emoji: emoji;
        \\  }
        \\  #mk { color: orange; background-color: purple; }
        \\  #lnk { color: red; }
        \\  @media (forced-colors: active) {
        \\    #mq_auto { color: rgb(0, 0, 255); }
        \\    #mq_none { color: rgb(0, 128, 0); background-color: rgb(0, 0, 255); forced-color-adjust: none; }
        \\  }
        \\</style>
        \\<body>
        \\  <div id="box"></div>
        \\  <div id="optout"></div>
        \\  <div id="withurl"></div>
        \\  <mark id="mk">hi</mark>
        \\  <a id="lnk" href="https://example.test"><em id="lnk_em">go</em></a>
        \\  <p id="mq_auto"></p>
        \\  <p id="mq_none"></p>
        \\</body>
    , .{ .base_url = "https://example.test/" });

    // 1. Default forced-colors: none — author styles intact.
    try expectEval(page,
        \\[
        \\  matchMedia('(forced-colors: active)').matches,
        \\  getComputedStyle(box).color,
        \\  getComputedStyle(box).backgroundColor,
        \\  getComputedStyle(box).boxShadow !== 'none',
        \\  getComputedStyle(box).backgroundImage !== 'none',
        \\  getComputedStyle(box).colorScheme,
        \\  getComputedStyle(box).accentColor,
        \\  getComputedStyle(box).scrollbarColor,
        \\  getComputedStyle(box).fontVariantEmoji,
        \\].join('|')
    , "false|rgb(0, 128, 0)|rgba(114, 173, 218, 0.3)|true|true|dark|rgb(0, 128, 0)|rgb(0, 128, 0) rgb(255, 0, 0)|unicode");

    // 2. Enable forced-colors: active (light) via HostOverrides (same path as CDP Emulation.setEmulatedMedia).
    const tab = browser.hostTraversableId() orelse return error.NoTab;
    const top = try topOf(browser, tab);
    top.host_overrides.setMedia(1, .{ .forced_colors = true, .color_scheme = .light });

    // Immediate invalidation: getComputedStyle reflects forced light palette while computedStyleMap keeps unforced color.
    try expectEval(page,
        \\[
        \\  matchMedia('(forced-colors: active)').matches,
        \\  getComputedStyle(box).color,
        \\  box.computedStyleMap().get('color').toString(),
        \\  getComputedStyle(box).backgroundColor,
        \\  box.computedStyleMap().get('background-color').toString(),
        \\  getComputedStyle(box).borderTopColor,
        \\  getComputedStyle(box).outlineColor,
        \\  getComputedStyle(box).boxShadow,
        \\  getComputedStyle(box).textShadow,
        \\  getComputedStyle(box).backgroundImage,
        \\  getComputedStyle(box).colorScheme,
        \\  getComputedStyle(box).accentColor,
        \\  getComputedStyle(box).scrollbarColor,
        \\  getComputedStyle(box).fontVariantEmoji,
        \\].join('|')
    , "true|rgb(0, 0, 0)|rgb(0, 128, 0)|rgba(255, 255, 255, 0.3)|rgba(114, 173, 218, 0.3)|rgb(0, 0, 0)|rgb(0, 0, 0)|none|none|none|light dark|auto|auto|text");

    // Opt-out, url() preservation, <mark>, <a><em>, and @media (forced-colors: active).
    try expectEval(page,
        \\[
        \\  getComputedStyle(optout).color,
        \\  getComputedStyle(optout).backgroundColor,
        \\  getComputedStyle(optout).colorScheme,
        \\  getComputedStyle(optout).accentColor,
        \\  getComputedStyle(withurl).backgroundImage,
        \\  getComputedStyle(withurl).accentColor,
        \\  getComputedStyle(withurl).fontVariantEmoji,
        \\  getComputedStyle(mk).color,
        \\  getComputedStyle(mk).backgroundColor,
        \\  getComputedStyle(lnk).color,
        \\  getComputedStyle(lnk_em).color,
        \\  getComputedStyle(mq_auto).color,
        \\  getComputedStyle(mq_none).color,
        \\  getComputedStyle(mq_none).backgroundColor,
        \\].join('|')
    , "rgb(0, 128, 0)|rgb(128, 0, 128)|light|rgb(0, 128, 0)|url(\"https://example.test/bg.png\")|rgb(0, 0, 0)|emoji|rgb(0, 0, 0)|rgb(255, 255, 0)|rgb(0, 0, 159)|rgb(0, 0, 159)|rgb(0, 0, 0)|rgb(0, 128, 0)|rgb(0, 0, 255)");

    // 3. Switch to forced-colors: active + prefers-color-scheme: dark (§5.2 dark palette).
    top.host_overrides.setMedia(1, .{ .forced_colors = true, .color_scheme = .dark });
    try expectEval(page,
        \\[
        \\  getComputedStyle(box).color,
        \\  getComputedStyle(box).backgroundColor,
        \\  getComputedStyle(lnk).color,
        \\  getComputedStyle(lnk_em).color,
        \\].join('|')
    , "rgb(255, 255, 255)|rgba(0, 0, 0, 0.3)|rgb(255, 255, 0)|rgb(255, 255, 0)");

    // 4. Disable forced-colors -> returns cleanly to author styles.
    top.host_overrides.setMedia(1, null);
    try expectEval(page,
        \\[
        \\  matchMedia('(forced-colors: active)').matches,
        \\  getComputedStyle(box).color,
        \\  getComputedStyle(box).backgroundColor,
        \\  getComputedStyle(box).accentColor,
        \\  getComputedStyle(box).colorScheme,
        \\].join('|')
    , "false|rgb(0, 128, 0)|rgba(114, 173, 218, 0.3)|rgb(0, 128, 0)|dark");
}

fn svgUaForcedColorAdjust() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(
        \\<!doctype html>
        \\<style>
        \\  body { color: rgb(255, 0, 0); }
        \\  #wrap { fill: rgb(255, 0, 0); stroke: rgb(0, 0, 255); }
        \\  #s2 { fill: currentColor; stroke: currentColor; }
        \\  #fo_div { color: rgb(255, 0, 0); }
        \\</style>
        \\<body>
        \\  <div id="wrap">
        \\    <svg id="s1"><path id="p1"></path></svg>
        \\    <svg id="s2"><path id="p2"></path><foreignObject id="fo"><div id="fo_div">hi</div></foreignObject></svg>
        \\    <svg id="s3" style="forced-color-adjust: auto"><path id="p3"></path></svg>
        \\  </div>
        \\</body>
    , .{ .base_url = "https://example.test/" });

    const tab = browser.hostTraversableId() orelse return error.NoTab;
    const top = try topOf(browser, tab);
    top.host_overrides.setMedia(1, .{ .forced_colors = true, .color_scheme = .light });

    // CSS Color Adjust 1 §3.2 UA rules:
    // - svg { forced-color-adjust: preserve-parent-color; }
    // - foreignObject { forced-color-adjust: auto; }
    try expectEval(page,
        \\[
        \\  getComputedStyle(s1).forcedColorAdjust,
        \\  getComputedStyle(p1).forcedColorAdjust,
        \\  getComputedStyle(p1).fill,
        \\  getComputedStyle(p1).stroke,
        \\  getComputedStyle(s2).color,
        \\  getComputedStyle(p2).fill,
        \\  getComputedStyle(fo).forcedColorAdjust,
        \\  getComputedStyle(fo_div).color,
        \\  getComputedStyle(p3).fill,
        \\  getComputedStyle(p3).stroke,
        \\].join('|')
    , "preserve-parent-color|preserve-parent-color|rgb(255, 0, 0)|rgb(0, 0, 255)|rgb(0, 0, 0)|rgb(0, 0, 0)|auto|rgb(0, 0, 0)|rgb(0, 0, 0)|rgb(0, 0, 0)");
}

test "emulated forced-colors toggles cascade, getComputedStyle vs computedStyleMap, and invalidation" {
    try onFreshThread(emulatedMediaToggleAndCascade);
}

test "SVG UA forced-color-adjust rules preserve parent color and reset on foreignObject" {
    try onFreshThread(svgUaForcedColorAdjust);
}
