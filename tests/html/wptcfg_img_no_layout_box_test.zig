//! D3 (the user, 2026-11-09 22:21 UTC): geometry is a read on the rendering
//! engine the compiled-in platform plugs in (docs/platform-protocol.md 6.9);
//! Crane never computes a box itself. With no renderer plugged in - the
//! testing platform answers layout as kit/headless does - an img has no
//! layout box even when its image is available and it has width and height
//! attributes, so CSSOM View's no-box answers hold:
//!
//! - clientWidth, clientHeight: "1. If the element has no associated CSS
//!   layout box or if the CSS layout box is inline, return zero." (CSSOM View
//!   3.1);
//! - offsetParent: "1. If any of the following holds true return null ...:
//!   The element does not have an associated CSS layout box." (CSSOM View 7);
//! - width, height: not being rendered, HTML's "determine the dimensions"
//!   gives the attributes' values (HTML 4.8.4.3, the dimension attributes).

const std = @import("std");
const Browser = @import("browser").Browser;

/// A 1x1 GIF: the image's natural size is 1x1.
const gif = "data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7";

test "with no renderer an img with a natural size and width and height attributes has no layout box" {
    const allocator = std.testing.allocator;
    const browser = try Browser.init(allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body><img id=picture width=40 height=30 src='" ++ gif ++ "'></body>", .{ .base_url = "https://geometry.test/page" });
    const setup = try browser.evaluateScript("globalThis.picture = document.getElementById('picture'); 0");
    setup.release();

    // Its image is available: the natural size is the GIF's.
    var turns: usize = 0;
    while (true) : (turns += 1) {
        const loaded = try page.evaluateScriptToString("String(picture.complete && picture.naturalWidth === 1)", allocator);
        defer allocator.free(loaded);
        if (std.mem.eql(u8, loaded, "true")) break;
        if (turns == 300) return error.ImageNeverLoaded;
        _ = try browser.runEventLoopBlocking(10);
    }

    const geometry = try page.evaluateScriptToString(
        "JSON.stringify([picture.naturalWidth, picture.naturalHeight, picture.clientWidth, picture.clientHeight, picture.offsetParent, picture.width, picture.height])",
        allocator,
    );
    defer allocator.free(geometry);
    try std.testing.expectEqualStrings("[1,1,0,0,null,40,30]", geometry);
}
