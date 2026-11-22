//! A Browser's pages asking for a new window - window.open(), or a link or
//! form whose target names none - as its host sees them, before the new
//! top-level traversable is made: the Browser's one hook slot
//! (`Navigables.window_open`), set to its own dispatcher, which fans out to
//! the host's listeners (CDP's Page.windowOpen, which Playwright reads for a
//! popup's requested size). Blink fires the same probe, probe::WindowOpen,
//! in CreateNewWindow (third_party/blink/renderer/core/page/create_window.cc)
//! after the target name found no existing frame and before the sandbox's
//! popup check, so a host hears it before the popup exists (lane cdph,
//! CDP part 1).
const std = @import("std");
const browsing_context = @import("../window/browsing_context.zig");

const Navigables = browsing_context.Navigables;

/// A request for a new window. Every slice BORROWED for the call.
pub const Opened = struct {
    /// The opener's top-level traversable (its tab) and its own navigable.
    tab: u64,
    navigable: u64,
    /// The URL the new window will navigate to, serialized; empty when none
    /// was given (the window stays at about:blank).
    url: []const u8,
    /// The target name the new window gets ("_blank" for none).
    name: []const u8,
    /// The features asked for, each "name" or "name=value", as Blink's
    /// InspectorPageAgent GetEnabledWindowFeatures lists them.
    features: []const []const u8,
    /// Whether the opener had transient activation (a user gesture).
    user_gesture: bool,
};

/// The Browser's hook (`Navigables.window_open`).
pub const Hook = struct {
    context: *anyopaque,
    opened: *const fn (context: *anyopaque, opened: *const Opened) void,
};

/// Tell `navigables`' hook that a page asks for a new window.
pub fn opened(navigables: ?*const Navigables, request: *const Opened) void {
    const list = navigables orelse return;
    const hook = list.window_open orelse return;
    hook.opened(hook.context, request);
}

/// The features a request names, in Blink's order and form
/// (InspectorPageAgent GetEnabledWindowFeatures): the geometry it set, the
/// five chrome features when the window is not a popup, then noopener. Made
/// in place (`fill`): its items point into its own `text`.
pub const FeatureList = struct {
    items: [10][]const u8 = undefined,
    len: usize = 0,
    text: [4][24]u8 = undefined,

    pub fn fill(self: *FeatureList, geometry: browsing_context.WindowGeometry, is_popup: bool, noopener: bool) void {
        self.len = 0;
        self.addNumber(0, "left", geometry.x);
        self.addNumber(1, "top", geometry.y);
        self.addNumber(2, "width", geometry.width);
        self.addNumber(3, "height", geometry.height);
        if (!is_popup) {
            for ([_][]const u8{ "menubar", "toolbar", "status", "scrollbars", "resizable" }) |name| self.add(name);
        }
        if (noopener) self.add("noopener");
    }

    fn add(self: *FeatureList, item: []const u8) void {
        self.items[self.len] = item;
        self.len += 1;
    }

    fn addNumber(self: *FeatureList, slot: usize, name: []const u8, value: ?i32) void {
        const number = value orelse return;
        const formatted = std.fmt.bufPrint(&self.text[slot], "{s}={d}", .{ name, number }) catch return;
        self.add(formatted);
    }

    pub fn slice(self: *const FeatureList) []const []const u8 {
        return self.items[0..self.len];
    }
};

test "FeatureList lists geometry, the chrome features of a non-popup, then noopener" {
    var list: FeatureList = .{};
    list.fill(.{ .width = 300, .height = 200 }, false, true);
    const items = list.slice();
    try std.testing.expectEqual(@as(usize, 8), items.len);
    try std.testing.expectEqualStrings("width=300", items[0]);
    try std.testing.expectEqualStrings("height=200", items[1]);
    try std.testing.expectEqualStrings("menubar", items[2]);
    try std.testing.expectEqualStrings("resizable", items[6]);
    try std.testing.expectEqualStrings("noopener", items[7]);

    var popup: FeatureList = .{};
    popup.fill(.{ .x = -5 }, true, false);
    try std.testing.expectEqual(@as(usize, 1), popup.slice().len);
    try std.testing.expectEqualStrings("left=-5", popup.slice()[0]);
}
