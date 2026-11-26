//! A tool call's answer, assembled as chrome-devtools-mcp's McpResponse
//! formats it (src/McpResponse.ts `format`, chrome-devtools-mcp-v1.13.0): the
//! tool's own lines, then the sections the tool asked for, in McpResponse's
//! order - the selected page's open dialog, then the pages - joined by
//! newlines into one text item (images after it). An error the tool raises
//! is the error's message alone, with `isError` (ToolHandler's errorResult).

const std = @import("std");
const Allocator = std.mem.Allocator;
const protocol = @import("protocol.zig");
const text_util = @import("text.zig");
const session_mod = @import("session.zig");
const Session = session_mod.Session;
const Page = session_mod.Page;

pub const Response = struct {
    arena: Allocator,
    lines: std.ArrayList([]const u8) = .empty,
    /// McpResponse.setIncludePages.
    include_pages: bool = false,
    /// The page the tool ran on (McpResponse.setPage): its dialog is shown.
    page: ?*Page = null,
    images: std.ArrayList(protocol.Content) = .empty,
    /// McpResponse.setError: the answer is an error result.
    is_error: bool = false,
    /// McpResponse.setError's message: the answer's last line is
    /// "Error: <message>", after every section.
    error_message: ?[]const u8 = null,
    /// attachWaitForResult: what the action led to.
    wait_result: ?WaitResult = null,
    /// The sections McpResponse.handle computes, in format's order after
    /// the pages: the page's snapshot (includeSnapshot: its text, each line
    /// ending in a newline), the attached request's and message's detailed
    /// text, then the request list's and the console list's lines.
    snapshot: ?[]const u8 = null,
    /// includeSnapshot with a filePath: the file it went to, said in the
    /// snapshot's place ("Saved snapshot to <file>.").
    snapshot_file: ?[]const u8 = null,
    detailed_network: ?[]const u8 = null,
    detailed_console: ?[]const u8 = null,
    network_list: ?[]const []const u8 = null,
    console_list: ?[]const []const u8 = null,

    pub const WaitResult = struct {
        /// The URL after the action, when the page navigated.
        navigated_to_url: ?[]const u8 = null,
        /// Pages the action opened (popups), by MCP page.
        opened_pages: []const *Page = &.{},
    };

    pub fn init(arena: Allocator) Response {
        return .{ .arena = arena };
    }

    /// McpResponse.appendResponseLine.
    pub fn line(self: *Response, comptime format: []const u8, args: anytype) !void {
        try self.lines.append(self.arena, try std.fmt.allocPrint(self.arena, format, args));
    }

    /// The tool result (McpResponse.handle + format, the sections batch 1
    /// tools use).
    pub fn finish(self: *Response, session: *Session) !protocol.ToolResult {
        var out: std.ArrayList([]const u8) = .empty;
        const any_opened = if (self.wait_result) |r| r.opened_pages.len > 0 else false;
        if (self.include_pages or any_opened) {
            session.snapshot();
            session.refreshTitles();
        }
        if (self.include_pages) {
            if (self.page == null or self.page.?.closed) self.page = session.selected;
        }
        try out.appendSlice(self.arena, self.lines.items);
        if (self.wait_result) |result| {
            if (result.navigated_to_url) |url| try out.append(self.arena, try std.fmt.allocPrint(self.arena, "Page navigated to {s}.", .{url}));
            var opened: std.ArrayList(*Page) = .empty;
            for (result.opened_pages) |p| if (!p.closed) try opened.append(self.arena, p);
            if (opened.items.len > 0) {
                try out.append(self.arena, "## Opened pages");
                for (opened.items) |p| try out.append(self.arena, try pageLabel(self.arena, p));
            }
        }
        // The page's emulation, in McpResponse's order (geolocation is not
        // supported yet).
        if (self.page) |page| try emulationLines(self.arena, &page.emulation, &out);
        if (self.page) |page| if (!page.closed) if (page.dialog) |dialog| {
            const default_value = if (std.mem.eql(u8, dialog.type, "prompt"))
                try std.fmt.allocPrint(self.arena, " (default value: \"{s}\")", .{dialog.default_prompt})
            else
                "";
            try out.append(self.arena, try std.fmt.allocPrint(self.arena, "# Open dialog\n{s}: {s}{s}.\nCall handle_dialog to handle it before continuing.", .{ dialog.type, dialog.message, default_value }));
        };
        if (self.include_pages) try self.pagesSection(session, &out);
        if (self.snapshot_file) |file| {
            try out.append(self.arena, try std.fmt.allocPrint(self.arena, "Saved snapshot to {s}.", .{file}));
        } else if (self.snapshot) |text| {
            try out.append(self.arena, "## Latest page snapshot");
            try out.append(self.arena, text);
        }
        if (self.detailed_network) |text| try out.append(self.arena, text);
        if (self.detailed_console) |text| try out.append(self.arena, text);
        if (self.network_list) |section| try out.appendSlice(self.arena, section);
        if (self.console_list) |section| try out.appendSlice(self.arena, section);
        if (self.error_message) |message| try out.append(self.arena, try std.fmt.allocPrint(self.arena, "Error: {s}", .{message}));
        const text = try std.mem.join(self.arena, "\n", out.items);
        var content: std.ArrayList(protocol.Content) = .empty;
        try content.append(self.arena, .{ .text = text });
        try content.appendSlice(self.arena, self.images.items);
        return .{ .content = content.items, .is_error = self.is_error or self.error_message != null };
    }

    fn pagesSection(self: *Response, session: *Session, out: *std.ArrayList([]const u8)) !void {
        if (session.selection_fallback) |fallback| {
            const now = if (session.selected) |s| try std.fmt.allocPrint(self.arena, " Page {d} is now selected.", .{s.id}) else "";
            try out.append(self.arena, try std.fmt.allocPrint(self.arena, "Note: the previously selected page {s}.{s}", .{ if (fallback.was_closed) "was closed" else "is no longer listed", now }));
            session.selection_fallback = null;
        }
        const pages = try session.livePages(self.arena);
        if (pages.len == 0) return;
        try out.append(self.arena, "## Pages");
        for (pages) |page| {
            const selected = if (session.selected == page) " [selected]" else "";
            const context_label = if (page.isolated_context) |name| try std.fmt.allocPrint(self.arena, " isolatedContext={s}", .{name}) else "";
            try out.append(self.arena, try std.fmt.allocPrint(self.arena, "{s}{s}{s}", .{ try pageLabel(self.arena, page), selected, context_label }));
        }
    }
};

/// formatPage's text: `<id>: <title> (<url>)`, or `<id>: <url>` with no
/// title - none, or a placeholder (McpPage.getTitle); truncateTitle cuts
/// the title to 50 code units, its "..." included.
/// McpResponse.format's emulation lines for the page: its viewport as
/// JSON.stringify writes McpPage's `{...defaults, ...viewport}` (a scale
/// the text left out is an undefined key, which JSON drops), its user
/// agent, then the media features.
fn emulationLines(arena: Allocator, emulation: *const session_mod.Emulation, out: *std.ArrayList([]const u8)) !void {
    if (emulation.network_conditions) |nc| {
        try out.append(arena, try std.fmt.allocPrint(arena, "Emulating network conditions: {s}", .{nc}));
        try out.append(arena, try std.fmt.allocPrint(arena, "Default navigation timeout set to {d} ms", .{session_mod.Emulation.defaultNavigationTimeoutMs(nc, emulation.cpu_throttling_rate)}));
    }
    if (emulation.viewport) |v| {
        const scale = if (v.scale) |s| try std.fmt.allocPrint(arena, "\"deviceScaleFactor\":{d},", .{s}) else "";
        try out.append(arena, try std.fmt.allocPrint(arena, "Emulating viewport: {{{s}\"isMobile\":{},\"hasTouch\":{},\"isLandscape\":{},\"width\":{d},\"height\":{d}}}", .{ scale, v.mobile, v.touch, v.landscape, v.width, v.height }));
    }
    if (emulation.user_agent) |ua| try out.append(arena, try std.fmt.allocPrint(arena, "Emulating user agent: {s}", .{ua}));
    if (emulation.cpu_throttling_rate > 1) try out.append(arena, try std.fmt.allocPrint(arena, "Emulating CPU throttling: {d}x slowdown", .{emulation.cpu_throttling_rate}));
    if (emulation.color_scheme) |value| try out.append(arena, try std.fmt.allocPrint(arena, "Emulating color scheme: {s}", .{value}));
    if (emulation.forced_colors) |value| try out.append(arena, try std.fmt.allocPrint(arena, "Emulating forced-colors: {s}", .{value}));
    if (emulation.prefers_contrast) |value| try out.append(arena, try std.fmt.allocPrint(arena, "Emulating prefers-contrast: {s}", .{value}));
    if (emulation.prefers_reduced_motion) |value| try out.append(arena, try std.fmt.allocPrint(arena, "Emulating prefers-reduced-motion: {s}", .{value}));
}

pub fn pageLabel(arena: Allocator, page: *const Page) ![]const u8 {
    // The target's title as it is (document.title already collapsed it).
    const title = if (isPlaceholderTitle(page.title, page.url)) "" else page.title;
    if (title.len == 0) return std.fmt.allocPrint(arena, "{d}: {s}", .{ page.id, page.url });
    return std.fmt.allocPrint(arena, "{d}: {s} ({s})", .{ page.id, try text_util.truncateText(arena, title, 50, .{ .include_ellipsis_in_length = true }), page.url });
}

/// isPlaceholderTitle: the URL, or the URL without its http(s):// (and
/// without its trailing slash).
fn isPlaceholderTitle(title: []const u8, url: []const u8) bool {
    if (std.mem.eql(u8, title, url)) return true;
    var without = url;
    if (std.mem.startsWith(u8, without, "http://")) without = without["http://".len..] else if (std.mem.startsWith(u8, without, "https://")) without = without["https://".len..];
    if (std.mem.eql(u8, title, without)) return true;
    if (std.mem.endsWith(u8, without, "/") and std.mem.eql(u8, title, without[0 .. without.len - 1])) return true;
    return false;
}

test "a page's label: title and URL, the title truncated to 50 code units with its ellipsis counted" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var page: Page = .{ .id = 2, .target_id = &.{}, .session_id = &.{}, .url = @constCast("https://a.test/"), .title = @constCast(""), .browser_context_id = &.{} };
    try std.testing.expectEqualStrings("2: https://a.test/", try pageLabel(arena, &page));
    page.title = @constCast("https://a.test/");
    try std.testing.expectEqualStrings("2: https://a.test/", try pageLabel(arena, &page));
    page.title = @constCast("a.test");
    try std.testing.expectEqualStrings("2: https://a.test/", try pageLabel(arena, &page));
    page.title = @constCast("Hello World");
    try std.testing.expectEqualStrings("2: Hello World (https://a.test/)", try pageLabel(arena, &page));
    const long: [60]u8 = @splat('a');
    const kept: [47]u8 = @splat('a');
    page.title = @constCast(&long);
    try std.testing.expectEqualStrings("2: " ++ kept ++ "... (https://a.test/)", try pageLabel(arena, &page));
}
