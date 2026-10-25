//! The user agent style sheet: HTML's chapter 15 "Rendering" CSS
//! (html.css), its presentational hints (html-hints.css, entering the
//! cascade at the author presentational hint origin with zero specificity,
//! Cascade 5 6.5) and its quirks-mode rules (html-quirks.css).
//!
//! Parsed once, when the process starts (crane.Process, ruling Q2), into
//! rule sets every Browser and thread reads and nothing writes - Stylo
//! shares its UA cascade data across documents the same way
//! (UA_CASCADE_DATA_CACHE, style/stylist.rs). A value a declaration of it
//! holds as text is made immortal (uncounted), so threads copying it into
//! computed styles never touch a count. Freed when the process ends.
//!
//! Left out of HTML's CSS, stated: the ISO-8859-8 bidi-override block (it
//! depends on the document's encoding), the select element's base
//! appearance blocks (a rendering mode Crane does not model), and 15.7.4's
//! examples. A select is styled as a drop-down box with native appearance.
//! Changed, stated in html.css: the link colors are LinkText, VisitedText and
//! ActiveText rather than their light hex values, as in all three browsers
//! (an anchor's color follows the element color scheme; whatwg/html#12761).
//!
//! Spec: https://html.spec.whatwg.org/multipage/rendering.html#the-css-user-agent-style-sheet-and-presentational-hints

const std = @import("std");
const css = @import("css");
const sheet = @import("sheet.zig");

const Contents = sheet.Contents;

pub const html_css = @embedFile("html.css");
pub const hints_css = @embedFile("html-hints.css");
pub const quirks_css = @embedFile("html-quirks.css");

pub const Sheets = struct {
    rules: *Contents,
    hints: *Contents,
    quirks: *Contents,
};

/// The process's allocator for the UA sheets (malloc: thread-safe).
const allocator = std.heap.c_allocator;

// process-wide: the UA style sheet's rule sets, built once at process start (crane.Process.init) before any Browser exists and never written after; every Browser and thread only reads them, and their text values are immortal
var built: ?Sheets = null;

/// Parse the UA sheets (Process.init). Idempotent.
pub fn build() void {
    if (built != null) return;
    built = buildWith(allocator) catch null;
}

/// Free them (Process.deinit).
pub fn release() void {
    const s = built orelse return;
    destroySheets(s);
    built = null;
}

/// The UA sheets; null before the process started.
pub fn get() ?*const Sheets {
    if (built) |*s| return s;
    return null;
}

pub fn buildWith(a: std.mem.Allocator) std.mem.Allocator.Error!Sheets {
    const rules = try Contents.parse(a, html_css, .{});
    errdefer destroyContents(rules);
    const hints = try Contents.parse(a, hints_css, .{});
    errdefer destroyContents(hints);
    const quirks = try Contents.parse(a, quirks_css, .{});
    errdefer destroyContents(quirks);
    for ([_]*Contents{ rules, hints, quirks }) |c| makeImmortal(c);
    return .{ .rules = rules, .hints = hints, .quirks = quirks };
}

pub fn destroySheets(s: Sheets) void {
    destroyContents(s.rules);
    destroyContents(s.hints);
    destroyContents(s.quirks);
}

/// Every text value is uncounted from now on; `destroyContents` frees them.
fn makeImmortal(c: *Contents) void {
    for (c.style_rules.items) |rule| {
        var it = rule.data.style.block.typed();
        while (it.next()) |d| switch (d.value) {
            .value => |v| if (v.sharedText()) |t| t.makeImmortal(),
            .css_wide => {},
        };
    }
}

fn destroyContents(c: *Contents) void {
    // An immortal text value is not freed by its block's release: free each
    // one once - a shorthand shares one value among its longhands - and
    // leave the declarations holding none.
    var seen: std.AutoHashMapUnmanaged(*css.style_values.SharedText, void) = .empty;
    defer seen.deinit(std.heap.c_allocator);
    for (c.style_rules.items) |rule| {
        for (rule.data.style.block.entries.items) |*e| switch (e.*) {
            .typed => |*d| switch (d.value) {
                .value => |v| if (v.sharedText()) |t| {
                    d.value = .{ .value = css.style_values.Value.kw(.none) };
                    const slot = seen.getOrPut(std.heap.c_allocator, t) catch continue;
                    if (!slot.found_existing) t.destroyImmortal();
                },
                .css_wide => {},
            },
            .unparsed, .custom => {},
        };
    }
    c.destroy();
}

test "the UA sheets parse, and every rule is HTML-only" {
    const s = try buildWith(std.testing.allocator);
    defer destroySheets(s);
    try std.testing.expect(s.rules.html_only);
    try std.testing.expect(s.rules.rules.items.len > 100);
    try std.testing.expect(s.rules.buckets.tag.get("div") != null);
    try std.testing.expect(s.rules.buckets.attribute.get("hidden") != null);
    try std.testing.expect(s.quirks.rules.items.len > 0);
}
