//! The testing platform's layout - a STOPGAP (decision 19b): the one box it
//! computes is a connected replaced element's (an img), from the facts Crane
//! gives with the query, as CSS 2.1 sizes an inline replaced element whose
//! width and height are `auto` unless its width and height attributes'
//! presentational hints set them (HTML 15.4.3). Every other node has no
//! layout box, as headless. Replaced by OQ4's DOM-to-renderer design when
//! that is settled (docs/platform-protocol.md 6.9).
//!
//! CSS 2.1 10.3.2 (width) and 10.6.2 (height), for an element with no other
//! style: with both auto, the natural width and height; with one given, the
//! other from the natural aspect ratio, or the natural size when there is
//! none. An img whose image is not available has no natural size: a box of
//! its attributes' size if it has either attribute, else none - it is then
//! an empty inline (HTML 15.4.2), with no box to measure.

const std = @import("std");
const platform = @import("platform");

pub fn replacedElementBox(browser: *platform.BrowserPlatform, document: platform.LayoutNode, node: platform.LayoutNode, element: *const platform.ReplacedElementFacts) ?platform.BoxMetrics {
    _ = .{ browser, document, node };
    if (!element.connected) return null;
    const given_width: ?f64 = if (element.has_width_attribute) @floatFromInt(element.width_attribute) else null;
    const given_height: ?f64 = if (element.has_height_attribute) @floatFromInt(element.height_attribute) else null;
    if (!element.has_natural_size) {
        if (given_width == null and given_height == null) return null;
        return box(given_width orelse 0, given_height orelse 0);
    }
    const natural_width: f64 = @floatFromInt(element.natural_width);
    const natural_height: f64 = @floatFromInt(element.natural_height);
    // A natural aspect ratio needs both natural dimensions non-zero.
    const has_ratio = element.natural_width > 0 and element.natural_height > 0;
    if (given_width) |width| {
        if (given_height) |height| return box(width, height);
        // 10.6.2: height auto with an intrinsic ratio: width / ratio.
        return box(width, if (has_ratio) width * natural_height / natural_width else natural_height);
    }
    if (given_height) |height| {
        // 10.3.2: width auto with a non-auto height and an intrinsic ratio:
        // height * ratio.
        return box(if (has_ratio) height * natural_width / natural_height else natural_width, height);
    }
    // Both auto: the natural width and height.
    return box(natural_width, natural_height);
}

/// A box of content size `width` x `height` with no border, padding or
/// scrollbar: its client and offset rectangles are its content box.
fn box(width: f64, height: f64) platform.BoxMetrics {
    const rect: platform.Rect = .{ .width = width, .height = height };
    return .{
        .offset = rect,
        .offset_parent = .{ .id = 0 },
        .client = rect,
        .scroll_width = width,
        .scroll_height = height,
    };
}
