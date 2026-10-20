//! Responsive images select their source after the caller's task and use
//! the document's media environment. Run through the generated bindings.
const std = @import("std");
const Browser = @import("browser").Browser;

test "srcset selects the first valid density candidate after the microtask" {
    const browser = try Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "https://images.test/page" });
    const setup = try browser.evaluateScript(
        \\globalThis.image = document.createElement('img');
        \\image.srcset = 'data:image/png,first 1x, data:image/png,second 2x';
        \\image.src = 'data:image/png,fallback';
        \\0
    );
    setup.release();
    const current = try page.evaluateScriptToString("image.currentSrc", std.testing.allocator);
    defer std.testing.allocator.free(current);
    try std.testing.expectEqualStrings("data:image/png,first", current);
}

test "srcset descriptor errors, default source and source sizes" {
    const browser = try Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "https://images.test/page" });
    const setup = try browser.evaluateScript(
        \\globalThis.images = [
        \\  ['data:,bad 1x 2x, data:,good 1x', '', 'data:,good'],
        \\  ['data:,bad +1x, data:,good 1e0x', '', 'data:,good'],
        \\  ['data:,bad 1.x, data:,good .5x', '', 'data:,good'],
        \\  ['data:,first 1x, data:,second 1x', '', 'data:,first'],
        \\  ['data:,first, data:,second 2x', '', 'data:,first'],
        \\  ['data:,small 200w, data:,large 600w', '400px', 'data:,large'],
        \\  ['data:,small 200w, data:,large 600w', '(min-width: 1px) 100px, 100vw', 'data:,small'],
        \\  ['data:,small 200w 100h, data:,large 600w', '100px', 'data:,small'],
        \\  ['data:,bad 100h, data:,good 1x', '', 'data:,good'],
        \\  ['data:,bad 0w, data:,good 1x', '', 'data:,good'],
        \\].map(([srcset, sizes, expected]) => {
        \\  const img = new Image(); img.srcset = srcset; img.sizes = sizes;
        \\  return {img, expected};
        \\});
        \\0
    );
    setup.release();
    const failures = try page.evaluateScriptToString(
        "JSON.stringify(images.filter(({img, expected}) => img.currentSrc !== expected).map(({img, expected}) => [img.srcset, img.currentSrc, expected]))",
        std.testing.allocator,
    );
    defer std.testing.allocator.free(failures);
    try std.testing.expectEqualStrings("[]", failures);
}
