//! Browsing context groups (HTML 7.3.2.1): an auxiliary browsing context
//! joins its opener's top-level browsing context's group; a new top-level
//! traversable made with noopener begins one of its own. "Find a navigable by
//! target name" step 7 searches only the searching page's group, so a window
//! opened with noopener is not found by name from its opener's page.

const std = @import("std");
const html_core = @import("html_core");
const BrowsingContext = html_core.window.BrowsingContext;

test "an auxiliary browsing context joins its opener's top-level group" {
    const allocator = std.testing.allocator;
    const page = try BrowsingContext.initTopLevel(allocator);
    defer page.deinit();
    const frame = try BrowsingContext.initChild(allocator, page);
    defer frame.deinit();

    // Opened from the page, and from a frame of it: the page's group.
    const popup = try BrowsingContext.initAuxiliary(allocator, page, false);
    defer popup.deinit();
    try std.testing.expect(popup.isInSameGroup(page));
    const from_frame = try BrowsingContext.initAuxiliary(allocator, frame, false);
    defer from_frame.deinit();
    try std.testing.expect(from_frame.isInSameGroup(page));

    // A popup's popup: still the page's group.
    const nested = try BrowsingContext.initAuxiliary(allocator, popup, false);
    defer nested.deinit();
    try std.testing.expect(nested.isInSameGroup(page));
}

test "a top-level traversable made with noopener begins a group of its own" {
    const allocator = std.testing.allocator;
    const page = try BrowsingContext.initTopLevel(allocator);
    defer page.deinit();
    const first = try BrowsingContext.initAuxiliary(allocator, page, false);
    defer first.deinit();
    const second = try BrowsingContext.initAuxiliary(allocator, page, false);
    defer second.deinit();

    first.startOwnGroup();
    try std.testing.expect(!first.isInSameGroup(page));
    try std.testing.expect(second.isInSameGroup(page));

    // Another noopener window has a group of its own too, not the first's.
    second.startOwnGroup();
    try std.testing.expect(!second.isInSameGroup(first));
    try std.testing.expect(!second.isInSameGroup(page));

    // What it opens joins ITS group.
    const child_of_first = try BrowsingContext.initAuxiliary(allocator, first, false);
    defer child_of_first.deinit();
    try std.testing.expect(child_of_first.isInSameGroup(first));
    try std.testing.expect(!child_of_first.isInSameGroup(page));
}
