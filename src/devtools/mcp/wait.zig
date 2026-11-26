//! WaitForHelper.waitForEventsAfterAction - chrome-devtools-mcp's
//! src/utils/WaitForHelper.ts (chrome-devtools-mcp-v1.13.0, Copyright 2025
//! Google LLC, Apache-2.0; THIRD_PARTY_NOTICES.md), translated. Around a
//! tool's action on a page: dialogs are answered as `handleDialog` says (one
//! no action answers ends the waits); after the action, a navigation that
//! starts within 100 ms is waited for up to the timeout (3 s by default);
//! then, unless a dialog came or the caller said not to, the DOM is waited on
//! until 100 ms pass without a mutation (3 s at most). The result names the
//! URL the page navigated to, whether a dialog was handled, and the pages the
//! action opened.

const std = @import("std");
const session_mod = @import("session.zig");
const Session = session_mod.Session;
const Page = session_mod.Page;
const Watch = session_mod.Watch;
const Response = @import("response.zig").Response;
const Context = @import("tools.zig").Context;

pub const Options = struct {
    /// The navigation's timeout (ms); null: #navigationTimeout, 3 s.
    timeout: ?u32 = null,
    wait_for_stable_dom: bool = true,
    /// expectNavigationIn (ms).
    expect_navigation_in: u32 = 100,
    dialog_action: Watch.DialogAction = .{},
};

/// WaitForHelper's #stableDomFor, #stableDomTimeout, #navigationTimeout.
const stable_dom_for_ms = 100;
const stable_dom_timeout_ms = 3000;
const navigation_timeout_ms = 3000;

pub const Result = struct {
    navigated_to_url: ?[]const u8 = null,
    dialog_handled: bool = false,
    opened_pages: []const *Page = &.{},

    pub fn forResponse(self: Result) Response.WaitResult {
        return .{ .navigated_to_url = self.navigated_to_url, .opened_pages = self.opened_pages };
    }
};

/// Run `action.run(ctx)` on `page` under the wait. An error the action
/// returns ends the wait and is returned.
pub fn afterAction(ctx: *Context, page: *Page, options: Options, action: anytype) !Result {
    const session = ctx.session;
    var watch: Watch = .{ .page = page, .dialog_action = options.dialog_action };
    defer watch.opened.deinit(session.allocator);
    const previous = session.watch;
    session.watch = &watch;
    defer session.watch = previous;
    const initial_url = try ctx.arena.dupe(u8, page.url);

    try action.run(ctx);

    // A navigation that starts within expectNavigationIn.
    const Started = struct {
        w: *Watch,
        fn done(self: @This()) bool {
            return self.w.navigation_started or self.w.aborted or self.w.page.closed;
        }
    };
    _ = try session.waitUntil(options.expect_navigation_in, Started{ .w = &watch }, Started.done);
    if (watch.navigation_started and !watch.aborted) {
        const Finished = struct {
            w: *Watch,
            fn done(self: @This()) bool {
                return self.w.navigation_finished or self.w.aborted or self.w.page.closed;
            }
        };
        const scaled_nav_timeout: u32 = @intFromFloat(@as(f64, @floatFromInt(navigation_timeout_ms)) * session_mod.Emulation.networkMultiplier(page.emulation.network_conditions));
        _ = try session.waitUntil(options.timeout orelse scaled_nav_timeout, Finished{ .w = &watch }, Finished.done);
    }
    if (!watch.dialog_detected and options.wait_for_stable_dom and !page.closed) try stableDom(ctx, page);
    return .{
        .navigated_to_url = if (watch.loaded_new_document or !std.mem.eql(u8, page.url, initial_url)) try ctx.arena.dupe(u8, page.url) else null,
        .dialog_handled = watch.dialog_handled,
        .opened_pages = try ctx.arena.dupe(*Page, watch.opened.items),
    };
}

/// waitForStableDom: a MutationObserver on the body, resolved once
/// #stableDomFor passes without a mutation, given up after
/// #stableDomTimeout (the evaluation disconnects itself then, as the abort
/// does); no body, nothing to wait for.
fn stableDom(ctx: *Context, page: *Page) !void {
    const source = std.fmt.comptimePrint(
        \\new Promise((resolve) => {{
        \\  let timeoutId;
        \\  const observer = new MutationObserver(callback);
        \\  function callback() {{
        \\    clearTimeout(timeoutId);
        \\    timeoutId = setTimeout(() => {{ observer.disconnect(); resolve(); }}, {d});
        \\  }}
        \\  callback();
        \\  setTimeout(() => {{ clearTimeout(timeoutId); observer.disconnect(); resolve(); }}, {d});
        \\  observer.observe(document.body, {{childList: true, subtree: true, attributes: true}});
        \\}})
    , .{ stable_dom_for_ms, stable_dom_timeout_ms });
    const params = try std.fmt.allocPrint(ctx.arena, "{{\"expression\":{f},\"awaitPromise\":true,\"returnByValue\":true}}", .{std.json.fmt(source, .{})});
    var r = ctx.session.client.call("Runtime.evaluate", params, page.session_id, stable_dom_timeout_ms + 100) catch |err| switch (err) {
        // Bounded: a paused page (an open dialog) is not waited on longer.
        error.Timeout => return,
        else => return err,
    };
    r.deinit();
}
