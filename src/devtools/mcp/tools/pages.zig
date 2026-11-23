//! The navigation tools: list_pages, select_page, close_page, new_page,
//! navigate_page - chrome-devtools-mcp's src/tools/pages.ts
//! (chrome-devtools-mcp-v1.13.0), with Puppeteer's page operations as the
//! CDP commands they send: goto is Page.navigate then the load event
//! (Puppeteer's default waitUntil 'load'), reload Page.reload, a new page
//! Target.createTarget(about:blank) then goto, close Target.closeTarget.

const std = @import("std");
const registry = @import("../tools.zig");
const Context = registry.Context;
const Tool = registry.Tool;
const session_mod = @import("../session.zig");
const Session = session_mod.Session;
const Page = session_mod.Page;
const Response = @import("../response.zig").Response;
const client_mod = @import("../client.zig");
const wait = @import("../wait.zig");
const url_check = @import("../url_check.zig");

pub const list = [_]Tool{
    .{ .name = "close_page", .page_tool = false, .run = closePage },
    .{ .name = "handle_dialog", .page_tool = true, .run = handleDialog },
    .{ .name = "list_pages", .page_tool = false, .run = listPages },
    .{ .name = "navigate_page", .page_tool = true, .run = navigatePage },
    .{ .name = "new_page", .page_tool = false, .run = newPage },
    .{ .name = "select_page", .page_tool = false, .run = selectPage },
};

/// McpContext's CLOSE_PAGE_ERROR.
const close_page_error = "The last open page cannot be closed. It is fine to keep it open.";
/// McpPage's NAVIGATION_TIMEOUT: the pages' default navigation timeout
/// (Page.setDefaultNavigationTimeout).
const default_navigation_timeout_ms: u32 = 10_000;

fn listPages(ctx: *Context, args: std.json.ObjectMap, page: ?*Page, response: *Response) anyerror!void {
    _ = .{ ctx, args, page };
    response.include_pages = true;
}

fn selectPage(ctx: *Context, args: std.json.ObjectMap, page: ?*Page, response: *Response) anyerror!void {
    _ = page;
    const id = registry.numberArg(args, "pageId") orelse return ctx.fail("Input validation error: Invalid arguments for tool select_page: pageId: Invalid input: expected number, received undefined", .{});
    const target = ctx.session.pageById(@intFromFloat(id)) orelse return ctx.fail("No page found", .{});
    try emulateFocus(ctx, target);
    ctx.session.select(target);
    response.include_pages = true;
    response.page = target;
    if (registry.boolArg(args, "bringToFront") orelse false) try command(ctx, target, "Page.bringToFront", "{}");
}

fn closePage(ctx: *Context, args: std.json.ObjectMap, page: ?*Page, response: *Response) anyerror!void {
    _ = page;
    const id = registry.numberArg(args, "pageId") orelse return ctx.fail("Input validation error: Invalid arguments for tool close_page: pageId: Invalid input: expected number, received undefined", .{});
    const target = ctx.session.pageById(@intFromFloat(id)) orelse return ctx.fail("No page found", .{});
    const live = try ctx.session.livePages(ctx.arena);
    if (live.len == 1) {
        try response.line("{s}", .{close_page_error});
    } else {
        const params = try std.fmt.allocPrint(ctx.arena, "{{\"targetId\":{f}}}", .{std.json.fmt(target.target_id, .{})});
        var r = try ctx.session.client.call("Target.closeTarget", params, "", session_mod.command_timeout_ms);
        defer r.deinit();
        if (r.errorMessage()) |message| return ctx.fail("{s}", .{message});
        target.closed = true;
    }
    response.include_pages = true;
}

fn newPage(ctx: *Context, args: std.json.ObjectMap, page: ?*Page, response: *Response) anyerror!void {
    _ = page;
    const url = registry.stringArg(args, "url") orelse return ctx.fail("Input validation error: Invalid arguments for tool new_page: url: Invalid input: expected string, received undefined", .{});
    if (try url_check.validate(ctx.arena, url, ctx.url_options)) |message| return ctx.fail("{s}", .{message});
    const background = registry.boolArg(args, "background") orelse false;
    const session = ctx.session;
    const previous = session.selected;
    var context_id: ?[]const u8 = null;
    var context_name: ?[]const u8 = null;
    if (registry.stringArg(args, "isolatedContext")) |name| {
        context_name = name;
        if (session.isolated_contexts.get(name)) |existing| {
            context_id = existing;
        } else {
            var created = try session.client.call("Target.createBrowserContext", "{}", "", session_mod.command_timeout_ms);
            defer created.deinit();
            if (created.errorMessage()) |message| return ctx.fail("Protocol error (Target.createBrowserContext): {s}", .{message});
            const id = session_mod.str(created.result().?.object.get("browserContextId"));
            const key = try session.allocator.dupe(u8, name);
            errdefer session.allocator.free(key);
            const value = try session.allocator.dupe(u8, id);
            errdefer session.allocator.free(value);
            try session.isolated_contexts.put(session.allocator, key, value);
            context_id = value;
        }
    }
    var params: std.Io.Writer.Allocating = .init(ctx.arena);
    try params.writer.writeAll("{\"url\":\"about:blank\"");
    if (context_id) |id| try params.writer.print(",\"browserContextId\":{f}", .{std.json.fmt(id, .{})});
    if (background) try params.writer.writeAll(",\"background\":true");
    try params.writer.writeAll("}");
    var created = try session.client.call("Target.createTarget", params.written(), "", session_mod.command_timeout_ms);
    defer created.deinit();
    if (created.errorMessage()) |message| return ctx.fail("Protocol error (Target.createTarget): {s}", .{message});
    const target_id = session_mod.str(created.result().?.object.get("targetId"));
    // The auto-attach announces it (Puppeteer waits for the page's target).
    const Waiter = struct {
        session: *Session,
        target_id: []const u8,
        fn found(self: @This()) bool {
            return self.session.pageByTarget(self.target_id) != null;
        }
    };
    if (!try session.waitUntil(session_mod.command_timeout_ms, Waiter{ .session = session, .target_id = target_id }, Waiter.found)) return ctx.fail("Timed out waiting for the new page", .{});
    try session.initPages();
    const new = session.pageByTarget(target_id).?;
    if (context_name) |name| new.isolated_context = try session.allocator.dupe(u8, name);
    try emulateFocus(ctx, new);
    session.select(new);
    session.snapshot();
    response.page = new;
    const timeout = timeoutArg(args);
    const Goto = struct {
        page: *Page,
        url: []const u8,
        timeout: ?u32,
        pub fn run(self: @This(), c: *Context) !void {
            try goto(c, self.page, self.url, self.timeout orelse default_navigation_timeout_ms);
        }
    };
    _ = wait.afterAction(ctx, new, .{ .timeout = timeout }, Goto{ .page = new, .url = url, .timeout = timeout }) catch |err| {
        if (err != error.ToolFailed) return err;
        // A dialog-blocked load stays open for handle_dialog (the pages are
        // listed); otherwise the previous selection comes back and the new
        // tab is closed.
        if (new.dialog != null) response.include_pages = true;
        if (new.dialog == null) {
            if (previous) |p| if (!p.closed) session.select(p);
            if ((try session.livePages(ctx.arena)).len > 1) {
                const close_params = try std.fmt.allocPrint(ctx.arena, "{{\"targetId\":{f}}}", .{std.json.fmt(new.target_id, .{})});
                if (session.client.call("Target.closeTarget", close_params, "", session_mod.command_timeout_ms)) |r| {
                    var closed = r;
                    closed.deinit();
                    new.closed = true;
                } else |_| {}
            }
        }
        return err;
    };
    response.include_pages = true;
}

/// handle_dialog: Dialog.accept(promptText) / dismiss() - awaited; an
/// answer that fails (the dialog already closed) is not an error.
fn handleDialog(ctx: *Context, args: std.json.ObjectMap, page: ?*Page, response: *Response) anyerror!void {
    const target = page.?;
    const action = registry.stringArg(args, "action") orelse return ctx.fail("Input validation error: Invalid arguments for tool handle_dialog: action: Invalid option: expected one of \"accept\"|\"dismiss\"", .{});
    if (target.dialog == null) return ctx.fail("No open dialog found", .{});
    const accept = std.mem.eql(u8, action, "accept");
    var params: std.Io.Writer.Allocating = .init(ctx.arena);
    try params.writer.print("{{\"accept\":{}", .{accept});
    if (accept) if (registry.stringArg(args, "promptText")) |text| try params.writer.print(",\"promptText\":{f}", .{std.json.fmt(text, .{})});
    try params.writer.writeAll("}");
    if (ctx.session.client.call("Page.handleJavaScriptDialog", params.written(), target.session_id, session_mod.command_timeout_ms)) |r| {
        var answered = r;
        answered.deinit();
    } else |err| if (err == error.OutOfMemory) return err;
    try response.line("Successfully {s} the dialog", .{if (accept) "accepted" else "dismissed"});
    target.clearDialog(ctx.session.allocator);
    response.include_pages = true;
}

/// McpPage.init({emulateFocus: true}): focused-page emulation, asked once
/// per page; a failure is retried by the next page tool.
pub fn emulateFocus(ctx: *Context, page: *Page) !void {
    if (page.focus_emulated) return;
    page.focus_emulated = true;
    var r = ctx.session.client.call("Emulation.setFocusEmulationEnabled", "{\"enabled\":true}", page.session_id, session_mod.command_timeout_ms) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => {
            page.focus_emulated = false;
            return;
        },
    };
    defer r.deinit();
    if (r.errorMessage() != null) page.focus_emulated = false;
}

fn navigatePage(ctx: *Context, args: std.json.ObjectMap, page: ?*Page, response: *Response) anyerror!void {
    const target = page.?;
    const url = registry.stringArg(args, "url");
    var kind = registry.stringArg(args, "type");
    if (kind == null and url == null) return ctx.fail("Either URL or a type is required.", .{});
    if (kind == null) kind = "url";
    if (url) |u| if (try url_check.validate(ctx.arena, u, ctx.url_options)) |message| return ctx.fail("{s}", .{message});
    const timeout = timeoutArg(args);
    var init_script_id: ?[]const u8 = null;
    if (registry.stringArg(args, "initScript")) |source| {
        const params = try std.fmt.allocPrint(ctx.arena, "{{\"source\":{f}}}", .{std.json.fmt(source, .{})});
        var r = try ctx.session.client.call("Page.addScriptToEvaluateOnNewDocument", params, target.session_id, session_mod.command_timeout_ms);
        defer r.deinit();
        if (r.errorMessage()) |message| return ctx.fail("Protocol error (Page.addScriptToEvaluateOnNewDocument): {s}", .{message});
        if (r.result()) |result| init_script_id = try ctx.arena.dupe(u8, session_mod.str(result.object.get("identifier")));
    }
    defer if (init_script_id) |id| {
        const params = std.fmt.allocPrint(ctx.arena, "{{\"identifier\":{f}}}", .{std.json.fmt(id, .{})}) catch null;
        if (params) |p| {
            if (ctx.session.client.call("Page.removeScriptToEvaluateOnNewDocument", p, target.session_id, session_mod.command_timeout_ms)) |r| {
                var owned = r;
                owned.deinit();
            } else |_| {}
        }
    };
    const action = registry.stringArg(args, "handleBeforeUnload") orelse "accept";
    const Navigate = struct {
        page: *Page,
        kind: []const u8,
        url: ?[]const u8,
        timeout: ?u32,
        ignore_cache: bool,
        response: *Response,

        pub fn run(self: @This(), c: *Context) !void {
            const t = self.timeout orelse default_navigation_timeout_ms;
            if (std.mem.eql(u8, self.kind, "url")) {
                const to = self.url orelse return c.fail("A URL is required for navigation of type=url.", .{});
                if (goto(c, self.page, to, t)) {
                    try self.response.line("Successfully navigated to {s}.", .{to});
                } else |err| {
                    if (err != error.ToolFailed) return err;
                    try self.response.line("Unable to navigate in the selected page: {s}.", .{c.failure.?});
                    c.failure = null;
                }
            } else if (std.mem.eql(u8, self.kind, "reload")) {
                if (reload(c, self.page, self.ignore_cache, t)) {
                    try self.response.line("Successfully reloaded the page.", .{});
                } else |err| {
                    if (err != error.ToolFailed) return err;
                    try self.response.line("Unable to reload the selected page: {s}.", .{c.failure.?});
                    c.failure = null;
                }
            } else {
                const back = std.mem.eql(u8, self.kind, "back");
                if (history(c, self.page, back, t)) {
                    try self.response.line("Successfully navigated {s} to {s}.", .{ if (back) "back" else "forward", self.page.url });
                } else |err| {
                    if (err != error.ToolFailed) return err;
                    try self.response.line("Unable to navigate {s} in the selected page: {s}.", .{ if (back) "back" else "forward", c.failure.? });
                    c.failure = null;
                }
            }
        }
    };
    const result = try wait.afterAction(ctx, target, .{ .timeout = timeout, .dialog_action = .{ .beforeunload = action } }, Navigate{
        .page = target,
        .kind = kind.?,
        .url = url,
        .timeout = timeout,
        .ignore_cache = registry.boolArg(args, "ignoreCache") orelse false,
        .response = response,
    });
    if (result.dialog_handled) {
        try response.line("{s} a beforeunload dialog.", .{if (std.mem.eql(u8, action, "dismiss")) "Dismissed" else "Accepted"});
        target.clearDialog(ctx.session.allocator);
    }
    response.include_pages = true;
}

/// timeoutSchema: 0 or less means the default (null).
fn timeoutArg(args: std.json.ObjectMap) ?u32 {
    const t = registry.numberArg(args, "timeout") orelse return null;
    if (t <= 0) return null;
    return @intFromFloat(@min(t, 3_600_000));
}

/// A command on `page`'s session; its error fails the tool.
fn command(ctx: *Context, page: *Page, method: []const u8, params: []const u8) !void {
    var r = try ctx.session.client.call(method, params, page.session_id, session_mod.command_timeout_ms);
    defer r.deinit();
    if (r.errorMessage()) |message| return ctx.fail("Protocol error ({s}): {s}", .{ method, message });
}

/// Puppeteer's page.goto(url, {timeout}): Page.navigate, then the load
/// event; a navigation error is "<errorText> at <url>".
fn goto(ctx: *Context, page: *Page, url: []const u8, timeout: u32) !void {
    page.load_fired = false;
    const params = try std.fmt.allocPrint(ctx.arena, "{{\"url\":{f}}}", .{std.json.fmt(url, .{})});
    var r = try ctx.session.client.call("Page.navigate", params, page.session_id, timeout);
    defer r.deinit();
    if (r.errorMessage()) |message| return ctx.fail("Protocol error (Page.navigate): {s}", .{message});
    const result = r.result().?.object;
    const error_text = session_mod.str(result.get("errorText"));
    if (error_text.len != 0) return ctx.fail("{s} at {s}", .{ error_text, url });
    // A same-document navigation (no loaderId) has no load to wait for.
    if (result.get("loaderId") == null) return;
    try waitForLoad(ctx, page, timeout);
}

fn reload(ctx: *Context, page: *Page, ignore_cache: bool, timeout: u32) !void {
    page.load_fired = false;
    const params = if (ignore_cache) "{\"ignoreCache\":true}" else "{}";
    var r = try ctx.session.client.call("Page.reload", params, page.session_id, timeout);
    defer r.deinit();
    if (r.errorMessage()) |message| return ctx.fail("Protocol error (Page.reload): {s}", .{message});
    try waitForLoad(ctx, page, timeout);
}

/// Puppeteer's goBack/goForward: Page.getNavigationHistory, then
/// Page.navigateToHistoryEntry and the load.
fn history(ctx: *Context, page: *Page, back: bool, timeout: u32) !void {
    var h = try ctx.session.client.call("Page.getNavigationHistory", "{}", page.session_id, timeout);
    defer h.deinit();
    if (h.errorMessage()) |message| return ctx.fail("Protocol error (Page.getNavigationHistory): {s}", .{message});
    const result = h.result().?.object;
    const index: i64 = result.get("currentIndex").?.integer;
    const entries = result.get("entries").?.array.items;
    const next = if (back) index - 1 else index + 1;
    if (next < 0 or next >= entries.len) return ctx.fail("History entry to navigate to not found.", .{});
    const entry_id = entries[@intCast(next)].object.get("id").?.integer;
    page.load_fired = false;
    const params = try std.fmt.allocPrint(ctx.arena, "{{\"entryId\":{d}}}", .{entry_id});
    var r = try ctx.session.client.call("Page.navigateToHistoryEntry", params, page.session_id, timeout);
    defer r.deinit();
    if (r.errorMessage()) |message| return ctx.fail("Protocol error (Page.navigateToHistoryEntry): {s}", .{message});
    try waitForLoad(ctx, page, timeout);
}

fn waitForLoad(ctx: *Context, page: *Page, timeout: u32) !void {
    const Loaded = struct {
        page: *Page,
        fn done(self: @This()) bool {
            // A dialog that blocks the load is waited out, as Puppeteer's
            // LifecycleWatcher does: the navigation times out and the dialog
            // stays for handle_dialog.
            return self.page.load_fired or self.page.closed;
        }
    };
    if (!try ctx.session.waitUntil(timeout, Loaded{ .page = page }, Loaded.done)) return ctx.fail("Navigation timeout of {d} ms exceeded", .{timeout});
}

test {
    _ = client_mod;
}
