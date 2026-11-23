//! A profile directory through the C ABI (include/crane.h, src/browser/
//! capi.zig; lane tab1, roadmap `instances` "host API"): crane_browser_create
//! takes `profile_dir` as the Zig host API does (BrowserConfig.profile_dir;
//! docs/instances.md, the user's ruling D6 2026-11-21: Puppeteer's
//! --user-data-dir fully supported). The Browser holds the directory for its
//! life - a second live Browser on it is CRANE_ERR_PROFILE_IN_USE, as
//! Chrome's profile lock refuses one - and what its pages store persists
//! there for the next Browser on it.

const std = @import("std");
const testing = std.testing;
const capi = @import("browser").capi;

fn optionsFor(profile: [*:0]const u8) capi.BrowserOptions {
    return .{ .struct_size = @sizeOf(capi.BrowserOptions), .profile_dir = profile };
}

/// `source` evaluated in tab `tab` of `handle`: its RemoteValue JSON is
/// `want`.
fn expectEvaluation(handle: ?*capi.Handle, tab: u64, source: []const u8, want: []const u8) !void {
    var result: capi.EvaluateResult = .{};
    try testing.expectEqual(capi.Status.ok, capi.crane_tab_evaluate(handle, tab, source.ptr, source.len, 0, &result));
    defer capi.crane_evaluate_result_free(&result);
    const json: []const u8 = if (result.json) |j| std.mem.span(j) else "(null)";
    if (!std.mem.eql(u8, want, json)) std.debug.print("{s}\n  expected: {s}\n  got:      {s}\n", .{ source, want, json });
    try testing.expect(!result.exception);
    try testing.expectEqualStrings(want, json);
}

/// A tab of `handle` showing `url`, loaded.
fn openTab(handle: ?*capi.Handle, url: [*:0]const u8) !u64 {
    var tab: u64 = 0;
    try testing.expectEqual(capi.Status.ok, capi.crane_tab_create(handle, null, false, &tab));
    var navigated: capi.NavigateResult = .{};
    try testing.expectEqual(capi.Status.ok, capi.crane_tab_navigate(handle, tab, url, @backingInt(capi.Readiness.complete), &navigated));
    capi.crane_navigate_result_free(&navigated);
    return tab;
}

test "a profile directory through the C ABI: held while its Browser lives, refused to a second one, its localStorage kept for the next" {
    try testing.expectEqual(capi.Status.ok, capi.crane_process_init(null));
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(testing.io, .{ .sub_path = "page.html", .data = "<!doctype html><title>profile</title>" });
    const base = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
    defer testing.allocator.free(base);
    const profile = try std.fmt.allocPrintSentinel(testing.allocator, "{s}/profile", .{base}, 0);
    defer testing.allocator.free(profile);
    const page = try std.fmt.allocPrintSentinel(testing.allocator, "file://{s}/page.html", .{base}, 0);
    defer testing.allocator.free(page);

    {
        var first: ?*capi.Handle = null;
        const options = optionsFor(profile.ptr);
        try testing.expectEqual(capi.Status.ok, capi.crane_browser_create(&options, &first));
        defer capi.crane_browser_destroy(first);
        // The directory is the first Browser's while it lives.
        try tmp.dir.access(testing.io, "profile/LOCK", .{});
        var second: ?*capi.Handle = null;
        try testing.expectEqual(capi.Status.profile_in_use, capi.crane_browser_create(&options, &second));
        try testing.expect(second == null);

        const tab = try openTab(first, page.ptr);
        try expectEvaluation(first, tab, "localStorage.setItem('kept', 'across Browsers'); 'set'", "{\"type\":\"string\",\"value\":\"set\"}");
    }

    // The next Browser on the directory: free again, and the first's
    // localStorage is there (written at the first's end, as Chrome's
    // LocalStorageImpl::ShutDown flushes).
    var next: ?*capi.Handle = null;
    const options = optionsFor(profile.ptr);
    try testing.expectEqual(capi.Status.ok, capi.crane_browser_create(&options, &next));
    defer capi.crane_browser_destroy(next);
    const tab = try openTab(next, page.ptr);
    try expectEvaluation(next, tab, "localStorage.getItem('kept')", "{\"type\":\"string\",\"value\":\"across Browsers\"}");
}

fn expectFocus(handle: ?*capi.Handle, tab: u64, comptime focused: []const u8) !void {
    try expectEvaluation(handle, tab, "document.hasFocus()", "{\"type\":\"boolean\",\"value\":" ++ focused ++ "}");
}

test "focus_mode through the C ABI: an embedder that narrows focus gives it to the tab it activates" {
    try testing.expectEqual(capi.Status.ok, capi.crane_process_init(null));
    var handle: ?*capi.Handle = null;
    const options: capi.BrowserOptions = .{ .struct_size = @sizeOf(capi.BrowserOptions), .focus_mode = @backingInt(capi.FocusMode.active_tab) };
    try testing.expectEqual(capi.Status.ok, capi.crane_browser_create(&options, &handle));
    defer capi.crane_browser_destroy(handle);
    var infos: ?[*]capi.TabInfo = null;
    var count: usize = 0;
    try testing.expectEqual(capi.Status.ok, capi.crane_tab_list(handle, &infos, &count));
    const first = infos.?[0].id;
    capi.crane_tab_info_free(infos, count);
    try expectFocus(handle, first, "true");
    var second: u64 = 0;
    try testing.expectEqual(capi.Status.ok, capi.crane_tab_create(handle, null, false, &second));
    try expectFocus(handle, second, "true");
    try expectFocus(handle, first, "false");
    try testing.expectEqual(capi.Status.ok, capi.crane_tab_activate(handle, first));
    try expectFocus(handle, first, "true");
    try expectFocus(handle, second, "false");
    // An unknown mode is refused.
    var refused: ?*capi.Handle = null;
    try testing.expectEqual(capi.Status.invalid_argument, capi.crane_browser_create(&.{ .struct_size = @sizeOf(capi.BrowserOptions), .focus_mode = 7 }, &refused));
}
