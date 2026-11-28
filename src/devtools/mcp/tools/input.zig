//! Input automation tools - chrome-devtools-mcp's src/tools/input.ts
//! (chrome-devtools-mcp-v1.13.0, Copyright 2025 Google LLC, Apache-2.0;
//! THIRD_PARTY_NOTICES.md): click, hover, drag, fill, fill_form, press_key,
//! type_text, and upload_file.
//!
//! Element-targeted trusted input follows User Ruling Option 2 (2026-11-23
//! 12:51 PM ET, tmp/plans/mcp1-design.md §6 & §11): uid -> element -> Crane's
//! real device pipeline (`user_input` / `drag_and_drop`, `isTrusted: true`,
//! Chrome event order, focus, `:hover`/`:active`, activation) through local-only
//! Browser-thread `Input` handlers, refusing elements that computed style or
//! HTML state says cannot be hit (`visibility: hidden`, `pointer-events:
//! none`, `inert`). `clientX`/`clientY` are 0, nothing scrolls first, and
//! overlays never intercept.
//!
//! What Puppeteer's locator waits for, Crane waits for the same way (`Locator`
//! below; main's rulings (a), 2026-11-27 7:59 PM ET, and 9:27 PM ET for
//! display: none): an element with no box (`display: none`, itself or an
//! ancestor) is acted on once it has one, a native form control with a
//! `disabled` attribute once it loses it, and a failed fill (read-only, no such
//! option, a value the input rejects, nothing to fill) is tried again - every
//! 100 ms, until the locator's timeout ends it with chrome-devtools-mcp's "The
//! element did not become interactive within the configured timeout." The
//! geometry-bound differences - pointer-events: none refused rather than
//! clicked through, overlays, coordinates, scrolling - are the differential's
//! expected differences (rulings (b) and (c)); README.md's "Element input" says
//! what an agent sees.

const std = @import("std");
const registry = @import("../tools.zig");
const Context = registry.Context;
const Tool = registry.Tool;
const session_mod = @import("../session.zig");
const Page = session_mod.Page;
const Response = @import("../response.zig").Response;
const wait = @import("../wait.zig");
const keyboard = @import("../keyboard.zig");
const elements = @import("../elements.zig");
const snapshot_tools = @import("snapshot.zig");
const platform = @import("platform");

pub const list = [_]Tool{
    .{ .name = "click", .page_tool = true, .blocked_by_dialog = true, .run = click },
    .{ .name = "click_at", .page_tool = true, .blocked_by_dialog = true, .experimental_vision = true, .run = clickAt },
    .{ .name = "drag", .page_tool = true, .blocked_by_dialog = true, .run = drag },
    .{ .name = "fill", .page_tool = true, .blocked_by_dialog = true, .run = fill },
    .{ .name = "fill_form", .page_tool = true, .blocked_by_dialog = true, .run = fillForm },
    .{ .name = "hover", .page_tool = true, .blocked_by_dialog = true, .run = hover },
    .{ .name = "press_key", .page_tool = true, .blocked_by_dialog = true, .run = pressKey },
    .{ .name = "type_text", .page_tool = true, .blocked_by_dialog = true, .run = typeText },
    .{ .name = "upload_file", .page_tool = true, .blocked_by_dialog = true, .files = &.{.{ .name = "filePaths" }}, .run = uploadFile },
};

/// Puppeteer's typingThreshold (api/locators/locators.ts): values shorter than
/// 100 bytes are typed via trusted keyboard events; longer ones fill directly.
const typing_threshold: usize = 100;

/// Puppeteer's waitForFileChooser timeout in chrome-devtools-mcp uploadFile.
const file_chooser_timeout_ms: u32 = 3000;

/// chrome-devtools-mcp's DEFAULT_TIMEOUT (src/McpPage.ts): the page's default
/// timeout, which every locator takes, before CPU throttling.
const default_timeout_ms: f64 = 5_000;

/// fillFormElements' timeoutPerChar: a fill's locator gets 10 ms more a character.
const fill_timeout_per_char_ms: u64 = 10;

/// handleActionError's words for the locator's TimeoutError.
const locator_timeout_reason = "The element did not become interactive within the configured timeout.";

/// The locator's timeout (ms): the page's default timeout -
/// McpPage.updateTimeouts' DEFAULT_TIMEOUT x the CPU throttling rate - plus
/// `extra_ms`.
pub fn locatorTimeoutMs(cpu_throttling_rate: f64, extra_ms: u64) u64 {
    const rate = if (cpu_throttling_rate > 1) cpu_throttling_rate else 1;
    return @as(u64, @intFromFloat(default_timeout_ms * rate)) + extra_ms;
}

/// Puppeteer's locator retry (puppeteer-core 25.17.0
/// src/api/locators/locators.ts, Apache-2.0, THIRD_PARTY_NOTICES.md:
/// `retryAndRaceWithSignalAndTimer` - `retry({delay: RETRY_DELAY})` raced with
/// `timeout(this._timeout)`): an attempt whose conditions do not hold yet, or
/// that failed, is made again RETRY_DELAY later, until the timeout. The page's
/// events are served while it waits; a dialog ends the wait (handleActionError:
/// the action opened it).
const Locator = struct {
    deadline_ms: i64,

    /// RETRY_DELAY.
    const retry_delay_ms: i64 = 100;

    const Next = enum { again, timed_out, interrupted };

    fn start(page: *const Page, extra_ms: u64) Locator {
        const timeout: i64 = @intCast(locatorTimeoutMs(page.emulation.cpu_throttling_rate, extra_ms));
        return .{ .deadline_ms = platform.monotonicMillis() + timeout };
    }

    /// After a failed attempt: wait RETRY_DELAY (or what is left), then
    /// `.again`; `.timed_out` once the timeout has passed; `.interrupted` when a
    /// dialog opened.
    fn next(self: Locator, ctx: *Context, page: *Page) !Next {
        if (interrupted(ctx, page)) return .interrupted;
        const now = platform.monotonicMillis();
        if (now >= self.deadline_ms) return .timed_out;
        const until = @min(now + retry_delay_ms, self.deadline_ms);
        while (platform.monotonicMillis() < until) {
            _ = try ctx.session.client.pump(10 * std.time.ns_per_ms);
            if (interrupted(ctx, page)) return .interrupted;
        }
        return .again;
    }

    fn interrupted(ctx: *Context, page: *Page) bool {
        if (page.dialog != null) return true;
        if (ctx.session.watch) |w| return w.dialog_detected or w.aborted;
        return false;
    }
};

// Page functions copied from Puppeteer (https://github.com/puppeteer/puppeteer,
// tag puppeteer-core-v25.17.0 = f255d2374e24a24880d4c37582d53f422377c7d4;
// "Copyright 2023 Google Inc.", SPDX-License-Identifier: Apache-2.0;
// THIRD_PARTY_NOTICES.md): packages/puppeteer-core/src/api/locators/locators.ts -
// #waitForEnabledIfNeeded's condition (enabled_js), #fill's classification,
// typeable step and fillDirectly (classify_fill_js, prepare_typeable_js,
// fill_directly_js) - and src/api/ElementHandle.ts - select and focus
// (select_value_js, focus_js). What they throw is answered as a value, so the
// attempt can be made again; Crane's own additions are marked.

/// Puppeteer's `#waitForEnabledIfNeeded` condition: a native form control is
/// enabled when it has no `disabled` attribute - its own, not a fieldset's -
/// and anything else is.
const enabled_js =
    \\element => {
    \\  if (!(element instanceof HTMLElement)) {
    \\    return 'enabled';
    \\  }
    \\  const isNativeFormControl = [
    \\    'BUTTON',
    \\    'INPUT',
    \\    'SELECT',
    \\    'TEXTAREA',
    \\    'OPTION',
    \\    'OPTGROUP',
    \\  ].includes(element.nodeName);
    \\  return !isNativeFormControl || !element.hasAttribute('disabled') ? 'enabled' : 'disabled';
    \\}
    \\//# sourceURL=pptr:internal
    \\
;

/// Whether `element` meets the locator's enabled condition; an evaluation that
/// fails counts as not yet (the locator retries every failure).
fn enabled(ctx: *Context, page: *Page, context_id: i64, element: elements.Element) !bool {
    const answer = callOnString(ctx, page, context_id, enabled_js, element.argument, null) catch |err| switch (err) {
        error.DialogAborted, error.OutOfMemory => return err,
        else => return false,
    };
    return if (answer) |a| std.mem.eql(u8, a, "enabled") else false;
}

/// A JavaScript string's length (UTF-16 code units), as Puppeteer measures a value.
fn jsLength(s: []const u8) usize {
    return std.unicode.calcUtf16LeLen(s) catch s.len;
}

test "the locator's timeout: DEFAULT_TIMEOUT times the CPU throttling rate, plus a fill's 10 ms a character" {
    try std.testing.expectEqual(@as(u64, 5_000), locatorTimeoutMs(1, 0));
    try std.testing.expectEqual(@as(u64, 20_000), locatorTimeoutMs(4, 0));
    try std.testing.expectEqual(@as(u64, 5_000), locatorTimeoutMs(0.5, 0));
    try std.testing.expectEqual(@as(u64, 5_000 + 7 * fill_timeout_per_char_ms), locatorTimeoutMs(1, jsLength("changed") * fill_timeout_per_char_ms));
    try std.testing.expectEqual(@as(usize, 2), jsLength("\u{1F600}"));
}

/// `click_at` (`--experimentalVision`): coordinate-based clicks require a
/// renderer/layout engine to hit-test screen coordinates (design §4 & §6).
fn clickAt(ctx: *Context, args: std.json.ObjectMap, page: ?*Page, response: *Response) anyerror!void {
    _ = .{ args, page, response };
    return ctx.fail("click_at is not supported by Crane's MCP server: Crane is headless and has no renderer or layout to hit-test screen coordinates.", .{});
}

// ============================================================================
// click
// ============================================================================

fn click(ctx: *Context, args: std.json.ObjectMap, page: ?*Page, response: *Response) anyerror!void {
    const target = page.?;
    const uid = registry.stringArg(args, "uid") orelse "";
    const dbl_click = registry.boolArg(args, "dblClick") orelse false;
    const include_snapshot = registry.boolArg(args, "includeSnapshot") orelse false;

    const target_info = try elements.targetByUid(ctx, target, uid);
    const element = try elements.byUid(ctx, target, uid);
    defer if (element.object_id) |id| elements.release(ctx, target, id);

    const Click = struct {
        page: *Page,
        uid: []const u8,
        element: elements.Element,
        role: []const u8,
        dbl_click: bool,

        /// Locator.click: the attempt again every RETRY_DELAY until it acts.
        pub fn run(self: @This(), c: *Context) !void {
            const locator = Locator.start(self.page, 0);
            while (!try self.attempt(c)) {
                switch (try locator.next(c, self.page)) {
                    .again => {},
                    .interrupted => return,
                    .timed_out => return failInteract(c, self.uid, locator_timeout_reason),
                }
            }
        }

        /// One attempt: true once it acted (or a dialog cut it short), false
        /// while the element has no box or is not enabled yet.
        fn attempt(self: @This(), c: *Context) !bool {
            if (!self.dbl_click and std.mem.eql(u8, self.role, "option")) {
                switch (try selectNativeOption(c, self.page, self.element)) {
                    .selected => return true,
                    .disabled => return false,
                    .not_native => {},
                }
            }
            const object_id = self.element.object_id orelse return failInteract(c, self.uid, "Node is not an Element.");
            const context_id = try elements.mainWorld(c, self.page, self.element.frame_id);
            const ready = enabled(c, self.page, context_id, self.element) catch |err| switch (err) {
                error.DialogAborted => return true,
                else => return err,
            };
            if (!ready) return false;
            // The locator has waited for enabled; the click itself is
            // ElementHandle.click, which checks nothing more.
            const params = try std.fmt.allocPrint(
                c.arena,
                "{{\"objectId\":{f},\"clickCount\":{d},\"checkEnabled\":false}}",
                .{ std.json.fmt(object_id, .{}), if (self.dbl_click) @as(u32, 2) else @as(u32, 1) },
            );
            const acted = elementAction(c, self.page, self.uid, "Input._craneClickElement", params) catch |err| switch (err) {
                error.DialogAborted => return true,
                else => return err,
            };
            return acted == .acted;
        }
    };

    const result = try wait.afterAction(ctx, target, .{}, Click{
        .page = target,
        .uid = uid,
        .element = element,
        .role = target_info.role,
        .dbl_click = dbl_click,
    });
    if (result.dialog_detected or target.dialog != null) {
        if (dbl_click) {
            try response.line("The element was double clicked and it opened a dialog.", .{});
        } else {
            try response.line("The element was clicked and it opened a dialog.", .{});
        }
    } else if (dbl_click) {
        try response.line("Successfully double clicked on the element", .{});
    } else {
        try response.line("Successfully clicked on the element", .{});
    }
    response.wait_result = result.forResponse();
    if (include_snapshot and target.dialog == null) response.snapshot = try snapshot_tools.capture(ctx, target, false);
}

const NativeOption = enum { selected, disabled, not_native };

/// chrome-devtools-mcp selectNativeSelectOption: for an AX `option` inside a
/// native `<select>`, select it and dispatch `input` + `change` on the select;
/// `.not_native` if the element has no ancestor `<select>` (fall back to
/// click). A disabled option, optgroup or select is `.disabled`: Chrome's
/// server falls back to the locator's click on the option then, which waits
/// for it to be enabled - here the attempt is made again until it is.
fn selectNativeOption(ctx: *Context, page: *Page, element: elements.Element) !NativeOption {
    const context_id = try elements.mainWorld(ctx, page, element.frame_id);
    const ans = callOnString(ctx, page, context_id, select_native_option_js, element.argument, null) catch |err| switch (err) {
        error.DialogAborted => return .selected,
        else => return err,
    };
    const status = ans orelse return .not_native;
    if (std.mem.eql(u8, status, "ok")) return .selected;
    if (std.mem.eql(u8, status, "disabled")) return .disabled;
    return .not_native;
}

const select_native_option_js =
    \\element => {
    \\  const select = element.closest('select');
    \\  if (!select) return 'no_select';
    \\  const group = element.parentElement;
    \\  if (element.disabled || select.disabled || (group instanceof HTMLOptGroupElement && group.disabled)) return 'disabled';
    \\  if (select.multiple) {
    \\    element.selected = true;
    \\  } else {
    \\    for (const opt of select.options) opt.selected = (opt === element);
    \\  }
    \\  select.dispatchEvent(new Event('input', { bubbles: true }));
    \\  select.dispatchEvent(new Event('change', { bubbles: true }));
    \\  return 'ok';
    \\}
    \\//# sourceURL=pptr:internal
    \\
;

// ============================================================================
// hover
// ============================================================================

fn hover(ctx: *Context, args: std.json.ObjectMap, page: ?*Page, response: *Response) anyerror!void {
    const target = page.?;
    const uid = registry.stringArg(args, "uid") orelse "";
    const include_snapshot = registry.boolArg(args, "includeSnapshot") orelse false;

    const element = try elements.byUid(ctx, target, uid);
    defer if (element.object_id) |id| elements.release(ctx, target, id);

    const Hover = struct {
        page: *Page,
        uid: []const u8,
        element: elements.Element,

        /// Locator.hover: no enabled wait, but an element with no box is
        /// waited for.
        pub fn run(self: @This(), c: *Context) !void {
            const object_id = self.element.object_id orelse return failInteract(c, self.uid, "Node is not an Element.");
            const params = try std.fmt.allocPrint(c.arena, "{{\"objectId\":{f}}}", .{std.json.fmt(object_id, .{})});
            const locator = Locator.start(self.page, 0);
            while (true) {
                const acted = elementAction(c, self.page, self.uid, "Input._craneHoverElement", params) catch |err| switch (err) {
                    error.DialogAborted => return,
                    else => return err,
                };
                if (acted == .acted) return;
                switch (try locator.next(c, self.page)) {
                    .again => {},
                    .interrupted => return,
                    .timed_out => return failInteract(c, self.uid, locator_timeout_reason),
                }
            }
        }
    };

    const result = try wait.afterAction(ctx, target, .{}, Hover{ .page = target, .uid = uid, .element = element });
    if (result.dialog_detected or target.dialog != null) {
        try response.line("The element was hovered and it opened a dialog.", .{});
    } else {
        try response.line("Successfully hovered over the element", .{});
    }
    response.wait_result = result.forResponse();
    if (include_snapshot and target.dialog == null) response.snapshot = try snapshot_tools.capture(ctx, target, false);
}

// ============================================================================
// drag
// ============================================================================

fn drag(ctx: *Context, args: std.json.ObjectMap, page: ?*Page, response: *Response) anyerror!void {
    const target = page.?;
    const from_uid = registry.stringArg(args, "from_uid") orelse "";
    const to_uid = registry.stringArg(args, "to_uid") orelse "";
    const include_snapshot = registry.boolArg(args, "includeSnapshot") orelse false;

    const from_el = try elements.byUid(ctx, target, from_uid);
    defer if (from_el.object_id) |id| elements.release(ctx, target, id);
    const to_el = try elements.byUid(ctx, target, to_uid);
    defer if (to_el.object_id) |id| elements.release(ctx, target, id);

    const Drag = struct {
        page: *Page,
        from: elements.Element,
        to: elements.Element,

        pub fn run(self: @This(), c: *Context) !void {
            const from_id = self.from.object_id orelse return c.fail("Node is not an Element.", .{});
            const to_id = self.to.object_id orelse return c.fail("Node is not an Element.", .{});
            const start_params = try std.fmt.allocPrint(
                c.arena,
                "{{\"fromObjectId\":{f},\"toObjectId\":{f}}}",
                .{ std.json.fmt(from_id, .{}), std.json.fmt(to_id, .{}) },
            );
            callElementAction(c, self.page, null, "Input._craneDragStart", start_params) catch |err| switch (err) {
                error.DialogAborted => return,
                else => return err,
            };
            // chrome-devtools-mcp pauses 50 ms between drag and drop.
            var waited: u32 = 0;
            while (waited < 50) : (waited += 10) _ = try c.session.client.pump(10 * std.time.ns_per_ms);
            const drop_params = try std.fmt.allocPrint(c.arena, "{{\"toObjectId\":{f}}}", .{std.json.fmt(to_id, .{})});
            callElementAction(c, self.page, null, "Input._craneDragDrop", drop_params) catch |err| switch (err) {
                error.DialogAborted => return,
                else => return err,
            };
        }
    };

    const result = try wait.afterAction(ctx, target, .{}, Drag{ .page = target, .from = from_el, .to = to_el });
    try response.line("Successfully dragged an element", .{});
    response.wait_result = result.forResponse();
    if (include_snapshot and target.dialog == null) response.snapshot = try snapshot_tools.capture(ctx, target, false);
}

// ============================================================================
// fill & fill_form
// ============================================================================

fn fill(ctx: *Context, args: std.json.ObjectMap, page: ?*Page, response: *Response) anyerror!void {
    const target = page.?;
    const uid = registry.stringArg(args, "uid") orelse "";
    const value = registry.stringArg(args, "value") orelse "";
    const include_snapshot = registry.boolArg(args, "includeSnapshot") orelse false;

    const Fill = struct {
        page: *Page,
        uid: []const u8,
        value: []const u8,

        pub fn run(self: @This(), c: *Context) !void {
            _ = try fillOne(c, self.page, self.uid, self.value);
        }
    };

    const result = try wait.afterAction(ctx, target, .{}, Fill{ .page = target, .uid = uid, .value = value });
    if (result.dialog_detected or target.dialog != null) {
        try response.line("The element was filled out and it opened a dialog.", .{});
    } else {
        try response.line("Successfully filled out the element", .{});
    }
    response.wait_result = result.forResponse();
    if (include_snapshot and target.dialog == null) response.snapshot = try snapshot_tools.capture(ctx, target, false);
}

fn fillForm(ctx: *Context, args: std.json.ObjectMap, page: ?*Page, response: *Response) anyerror!void {
    const target = page.?;
    const include_snapshot = registry.boolArg(args, "includeSnapshot") orelse false;
    const items: []const std.json.Value = if (args.get("elements")) |v| (if (v == .array) v.array.items else &.{}) else &.{};

    var dialog_uid: ?[]const u8 = null;
    var has_remaining = false;

    const FillForm = struct {
        page: *Page,
        items: []const std.json.Value,
        dialog_uid: *?[]const u8,
        has_remaining: *bool,

        pub fn run(self: @This(), c: *Context) !void {
            for (self.items, 0..) |item, i| {
                if (item != .object) continue;
                const uid = registry.stringArg(item.object, "uid") orelse "";
                const value = registry.stringArg(item.object, "value") orelse "";
                const opened_dialog = try fillOne(c, self.page, uid, value);
                if (opened_dialog or self.page.dialog != null) {
                    self.dialog_uid.* = uid;
                    self.has_remaining.* = (i + 1 < self.items.len);
                    return;
                }
            }
        }
    };

    const result = try wait.afterAction(ctx, target, .{}, FillForm{
        .page = target,
        .items = items,
        .dialog_uid = &dialog_uid,
        .has_remaining = &has_remaining,
    });
    if (dialog_uid) |duid| {
        if (has_remaining) {
            try response.line("Filling out the element with uid {s} opened a dialog. The remaining elements were not filled out.", .{duid});
        } else {
            try response.line("Filling out the element with uid {s} opened a dialog.", .{duid});
        }
    } else {
        try response.line("Successfully filled out the form", .{});
    }
    response.wait_result = result.forResponse();
    if (include_snapshot and target.dialog == null) response.snapshot = try snapshot_tools.capture(ctx, target, false);
}

/// Fill one element (`chrome-devtools-mcp` `fillFormElements` + Puppeteer
/// `Locator.#fill`). Returns true if filling triggered a JS dialog.
fn fillOne(ctx: *Context, page: *Page, uid: []const u8, raw_value: []const u8) !bool {
    const target_info = try elements.targetByUid(ctx, page, uid);
    const element = try elements.byUid(ctx, page, uid);
    defer if (element.object_id) |id| elements.release(ctx, page, id);

    const object_id = element.object_id orelse return failInteract(ctx, uid, "Node is not an Element.");
    const context_id = try elements.mainWorld(ctx, page, element.frame_id);

    // What fillFormElements decides before it hands the element to a locator.
    var value = raw_value;
    var toggle: ?bool = null;
    var extra_ms: u64 = 0;
    if (std.mem.eql(u8, target_info.role, "combobox") and target_info.options.len > 0) {
        // selectOption: an AX combobox with option children takes an
        // option's accessible name ("Could not find option with text ...").
        var matched_opt = false;
        for (target_info.options) |opt| {
            if (!std.mem.eql(u8, opt.name, raw_value)) continue;
            matched_opt = true;
            const opt_el = elements.resolveNode(ctx, page, opt.backend_node_id, opt.loader_id, opt.frame_id) catch break;
            defer if (opt_el.object_id) |oid| elements.release(ctx, page, oid);
            const opt_ctx = elements.mainWorld(ctx, page, opt.frame_id) catch break;
            if (callOnString(ctx, page, opt_ctx, read_option_value_js, opt_el.argument, null) catch null) |ov| {
                value = ov;
            }
            break;
        }
        if (!matched_opt) {
            return ctx.fail("Failed to interact with the element with uid {s}. Could not find option with text \"{s}\"", .{ uid, raw_value });
        }
    } else {
        const kind = (callOnString(ctx, page, context_id, is_toggle_js, element.argument, null) catch |err| switch (err) {
            error.DialogAborted => return true,
            else => return err,
        }) orelse "";
        if (std.mem.eql(u8, kind, "toggle")) {
            if (std.mem.eql(u8, raw_value, "true")) {
                toggle = true;
            } else if (std.mem.eql(u8, raw_value, "false")) {
                toggle = false;
            } else {
                return ctx.fail("Failed to interact with the element with uid {s}. Checkboxes, radio boxes and toggles require \"true\" or \"false\" value, but {s} was used", .{ uid, raw_value });
            }
        } else {
            // "Increase timeout for longer input values."
            extra_ms = jsLength(raw_value) * fill_timeout_per_char_ms;
        }
    }

    const locator = Locator.start(page, extra_ms);
    while (true) {
        switch (try fillAttempt(ctx, page, uid, element, object_id, context_id, value, toggle)) {
            .done => return dialogOpened(ctx, page),
            .dialog => return true,
            .not_yet => {},
        }
        switch (try locator.next(ctx, page)) {
            .again => {},
            .interrupted => return true,
            .timed_out => return failInteract(ctx, uid, locator_timeout_reason),
        }
    }
}

const FillAttempt = enum { done, dialog, not_yet };

/// One attempt of Locator.#fill: the conditions (a box, enabled), the
/// classification (whose errors - no such option, read-only, a value the input
/// does not accept, nothing to fill - are retried as the locator retries
/// them), then the fill. `.not_yet`: try again after RETRY_DELAY.
fn fillAttempt(
    ctx: *Context,
    page: *Page,
    uid: []const u8,
    element: elements.Element,
    object_id: []const u8,
    context_id: i64,
    value: []const u8,
    toggle: ?bool,
) !FillAttempt {
    // Option 2's refusals (visibility:hidden, inert) answer at once; an
    // element with no box is waited for. That it is enabled is the next wait.
    const check_params = try std.fmt.allocPrint(
        ctx.arena,
        "{{\"objectId\":{f},\"checkEnabled\":false,\"checkPointerEvents\":false}}",
        .{std.json.fmt(object_id, .{})},
    );
    const checked_box = elementAction(ctx, page, uid, "Input._craneCheckElement", check_params) catch |err| switch (err) {
        error.DialogAborted => return .dialog,
        else => return err,
    };
    if (checked_box == .not_rendered) return .not_yet;
    const ready = enabled(ctx, page, context_id, element) catch |err| switch (err) {
        error.DialogAborted => return .dialog,
        else => return err,
    };
    if (!ready) return .not_yet;

    const info_json = (callOnString(ctx, page, context_id, classify_fill_js, element.argument, value) catch |err| switch (err) {
        error.DialogAborted => return .dialog,
        error.OutOfMemory => return err,
        else => return .not_yet,
    }) orelse return .not_yet;
    const parsed = std.json.parseFromSliceLeaky(std.json.Value, ctx.arena, info_json, .{}) catch return .not_yet;
    if (parsed != .object) return .not_yet;
    const kind = session_mod.str(parsed.object.get("kind"));

    if (std.mem.eql(u8, kind, "toggle")) {
        // toggleIfNeeded: click unless it is already in the asked state (a
        // mixed one is always clicked); ElementHandle.click checks nothing more.
        const want = toggle orelse (value.len != 0);
        const state = parsed.object.get("state") orelse return .not_yet;
        const mixed = state == .string;
        const checked = state == .bool and state.bool;
        if (mixed or checked != want) {
            const click_params = try std.fmt.allocPrint(
                ctx.arena,
                "{{\"objectId\":{f},\"clickCount\":1,\"checkEnabled\":false}}",
                .{std.json.fmt(object_id, .{})},
            );
            callElementAction(ctx, page, uid, "Input._craneClickElement", click_params) catch |err| switch (err) {
                error.DialogAborted => return .dialog,
                else => return err,
            };
        }
        return .done;
    }

    if (std.mem.eql(u8, kind, "select")) {
        const res = callOnString(ctx, page, context_id, select_value_js, element.argument, value) catch |err| switch (err) {
            error.DialogAborted => return .dialog,
            error.OutOfMemory => return err,
            else => return .not_yet,
        };
        return if (res != null and std.mem.eql(u8, res.?, "ok")) .done else .not_yet;
    }

    if (std.mem.eql(u8, kind, "typeable") and jsLength(value) < typing_threshold) {
        // Clear what does not lead to the value, then ElementHandle.type the rest.
        const rest = (callOnString(ctx, page, context_id, prepare_typeable_js, element.argument, value) catch |err| switch (err) {
            error.DialogAborted => return .dialog,
            error.OutOfMemory => return err,
            else => return .not_yet,
        }) orelse return .not_yet;
        if (rest.len == 0) return .done;
        _ = callOnString(ctx, page, context_id, focus_js, element.argument, null) catch |err| switch (err) {
            error.DialogAborted => return .dialog,
            error.OutOfMemory => return err,
            else => return .not_yet,
        };
        typeChars(ctx, page, rest) catch |err| switch (err) {
            error.DialogAborted => return .dialog,
            else => return err,
        };
        return .done;
    }

    if (std.mem.eql(u8, kind, "typeable") or std.mem.eql(u8, kind, "direct")) {
        // fillDirectly: focus, then set the value and fire input and change.
        _ = callOnString(ctx, page, context_id, fill_directly_js, element.argument, value) catch |err| switch (err) {
            error.DialogAborted => return .dialog,
            error.OutOfMemory => return err,
            else => return .not_yet,
        };
        return .done;
    }

    // 'unknown': "Element cannot be filled out." - retried like any failure.
    return .not_yet;
}

fn dialogOpened(ctx: *Context, page: *Page) bool {
    if (page.dialog != null) return true;
    if (ctx.session.watch) |w| if (w.dialog_detected) return true;
    return false;
}

const read_option_value_js =
    \\element => String(element.value ?? '')
    \\//# sourceURL=pptr:internal
    \\
;

/// fillFormElements' isToggle (chrome-devtools-mcp src/tools/input.ts).
const is_toggle_js =
    \\el => {
    \\  if (el instanceof HTMLInputElement) {
    \\    return el.type === 'checkbox' || el.type === 'radio' ? 'toggle' : 'other';
    \\  }
    \\  const role = el.getAttribute('role');
    \\  return role === 'checkbox' || role === 'radio' || role === 'switch' ? 'toggle' : 'other';
    \\}
    \\//# sourceURL=pptr:internal
    \\
;

/// Locator.#fill's classification (copied; its throws answered as `{retry}`),
/// with toggleIfNeeded's state read for a toggle (Crane's: `toggleState`, from
/// toggleIfNeeded's evaluation).
const classify_fill_js =
    \\(el, newValue) => {
    \\  const toggleState = el => (el.indeterminate || el.getAttribute('aria-checked') === 'mixed')
    \\    ? 'mixed'
    \\    : !!(el.checked || el.getAttribute('aria-checked') === 'true');
    \\  if (el instanceof HTMLSelectElement) {
    \\    if (!Array.from(el.options).some(option => option.value === newValue)) {
    \\      return JSON.stringify({ retry: `Element has no option with the value "${newValue}".` });
    \\    }
    \\    return JSON.stringify({ kind: 'select' });
    \\  }
    \\  if (el instanceof HTMLTextAreaElement) {
    \\    if (el.readOnly) {
    \\      return JSON.stringify({ retry: 'Element is read-only.' });
    \\    }
    \\    return JSON.stringify({ kind: 'typeable' });
    \\  }
    \\  if (el instanceof HTMLInputElement) {
    \\    if (el.type === 'checkbox' || el.type === 'radio') {
    \\      return JSON.stringify({ kind: 'toggle', state: toggleState(el) });
    \\    }
    \\    if (
    \\      el.readOnly &&
    \\      [
    \\        'text',
    \\        'search',
    \\        'url',
    \\        'tel',
    \\        'email',
    \\        'password',
    \\        'number',
    \\        'date',
    \\        'month',
    \\        'week',
    \\        'time',
    \\        'datetime-local',
    \\      ].includes(el.type)
    \\    ) {
    \\      return JSON.stringify({ retry: 'Element is read-only.' });
    \\    }
    \\    if (el.type !== 'file' && String(newValue) !== '') {
    \\      // Validate without modifying the element before a possible retry.
    \\      const probe = document.createElement('input');
    \\      probe.type = el.type;
    \\      probe.value = String(newValue);
    \\      if (probe.value === '') {
    \\        return JSON.stringify({ retry: `Element did not accept the value "${newValue}".` });
    \\      }
    \\    }
    \\    switch (el.type) {
    \\      case 'text':
    \\      case 'url':
    \\      case 'tel':
    \\      case 'search':
    \\      case 'password':
    \\      case 'number':
    \\      case 'email':
    \\        return JSON.stringify({ kind: 'typeable' });
    \\      default:
    \\        return JSON.stringify({ kind: 'direct' });
    \\    }
    \\  }
    \\  switch (el.getAttribute('role')) {
    \\    case 'checkbox':
    \\    case 'radio':
    \\    case 'switch':
    \\      return JSON.stringify({ kind: 'toggle', state: toggleState(el) });
    \\  }
    \\  if (el.isContentEditable) {
    \\    return JSON.stringify({ kind: 'typeable' });
    \\  }
    \\  return JSON.stringify({ retry: 'Element cannot be filled out.' });
    \\}
    \\//# sourceURL=pptr:internal
    \\
;

/// ElementHandle.select (copied) for one value.
const select_value_js =
    \\(element, value) => {
    \\  const values = new Set([value]);
    \\  if (!(element instanceof HTMLSelectElement)) {
    \\    return 'not_select';
    \\  }
    \\  if (!element.multiple) {
    \\    for (const option of element.options) {
    \\      option.selected = false;
    \\    }
    \\    for (const option of element.options) {
    \\      if (values.has(option.value)) {
    \\        option.selected = true;
    \\        break;
    \\      }
    \\    }
    \\  } else {
    \\    for (const option of element.options) {
    \\      option.selected = values.has(option.value);
    \\    }
    \\  }
    \\  element.dispatchEvent(new Event('input', {bubbles: true}));
    \\  element.dispatchEvent(new Event('change', {bubbles: true}));
    \\  return 'ok';
    \\}
    \\//# sourceURL=pptr:internal
    \\
;

/// Locator.#fill's typeable step (copied): nothing when the value is there,
/// else clear what does not lead to it and answer what is left to type ('' for
/// nothing).
const prepare_typeable_js =
    \\(input, newValue) => {
    \\  const element = input;
    \\  const valString = String(newValue);
    \\  const currentValue = element.isContentEditable
    \\    ? element.innerText
    \\    : input.value;
    \\  if (currentValue === valString) {
    \\    return '';
    \\  }
    \\  if (!valString.startsWith(currentValue) || !currentValue) {
    \\    if (element.isContentEditable) {
    \\      element.innerText = '';
    \\    } else {
    \\      input.value = '';
    \\    }
    \\    return valString;
    \\  }
    \\  if (element.isContentEditable) {
    \\    element.innerText = '';
    \\    element.innerText = currentValue;
    \\  } else {
    \\    input.value = '';
    \\    input.value = currentValue;
    \\  }
    \\  return valString.substring(currentValue.length);
    \\}
    \\//# sourceURL=pptr:internal
    \\
;

/// ElementHandle.focus (copied), before ElementHandle.type.
const focus_js =
    \\element => {
    \\  if (!(element instanceof HTMLElement)) {
    \\    throw new Error('Cannot focus non-HTMLElement');
    \\  }
    \\  element.focus();
    \\  return 'ok';
    \\}
    \\//# sourceURL=pptr:internal
    \\
;

/// Locator.#fill's fillDirectly (copied; the focus is its handle.focus()):
/// focus, then set the value unless it is there, firing input and change.
const fill_directly_js =
    \\(input, newValue) => {
    \\  input.focus();
    \\  const element = input;
    \\  const valString = String(newValue);
    \\  const currentValue = element.isContentEditable
    \\    ? element.innerText
    \\    : input.value;
    \\  if (currentValue === valString) {
    \\    return 'ok';
    \\  }
    \\  if (element.isContentEditable) {
    \\    element.innerText = valString;
    \\  } else {
    \\    input.value = valString;
    \\  }
    \\  element.dispatchEvent(new Event('input', {bubbles: true}));
    \\  element.dispatchEvent(new Event('change', {bubbles: true}));
    \\  return 'ok';
    \\}
    \\//# sourceURL=pptr:internal
    \\
;

// ============================================================================
// upload_file (direct DOM.setFileInputFiles + file-chooser interception fallback)
// ============================================================================

/// upload_file (chrome-devtools-mcp v1.13.0 src/tools/input.ts): try
/// ElementHandle.uploadFile first; any failure other than the `multiple`
/// assertion falls back to Page.setInterceptFileChooserDialog + element click
/// + waiting up to 3 s for Page.fileChooserOpened, then DOM.setFileInputFiles.
fn uploadFile(ctx: *Context, args: std.json.ObjectMap, page: ?*Page, response: *Response) anyerror!void {
    const target = page.?;
    const uid = registry.stringArg(args, "uid") orelse "";
    // validateToolFiles left the checked paths, blank ones dropped.
    var files: std.ArrayList([]const u8) = .empty;
    if (args.get("filePaths")) |paths| if (paths == .array) for (paths.array.items) |p| {
        if (p == .string) try files.append(ctx.arena, p.string);
    };
    const element = try elements.byUid(ctx, target, uid);
    defer if (element.object_id) |id| elements.release(ctx, target, id);

    const direct_ok = blk: {
        setInputFiles(ctx, target, element, files.items) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.MultipleUploads => return ctx.fail("Multiple file uploads only work with <input type=file multiple>", .{}),
            else => break :blk false,
        };
        break :blk true;
    };

    if (!direct_ok) {
        try uploadViaFileChooser(ctx, target, element, files.items);
    }

    if ((registry.boolArg(args, "includeSnapshot") orelse false) and target.dialog == null) {
        response.snapshot = try snapshot_tools.capture(ctx, target, false);
    }
    try response.line("File uploaded from {s}.", .{try std.mem.join(ctx.arena, ", ", files.items)});
}

const chooser_fail_message = "Failed to upload file. The element could not accept the file directly, and clicking it did not trigger a file chooser.";

fn uploadViaFileChooser(ctx: *Context, page: *Page, element: elements.Element, files: []const []const u8) !void {
    const object_id = element.object_id orelse return ctx.fail("{s}", .{chooser_fail_message});

    var intercept_on = try ctx.session.client.call("Page.setInterceptFileChooserDialog", "{\"enabled\":true}", page.session_id, session_mod.command_timeout_ms);
    defer intercept_on.deinit();
    defer {
        if (ctx.session.client.call("Page.setInterceptFileChooserDialog", "{\"enabled\":false}", page.session_id, session_mod.command_timeout_ms)) |r| {
            var off = r;
            off.deinit();
        } else |_| {}
    }

    var fc_wait: session_mod.FileChooserWait = .{ .session_id = page.session_id };
    const previous = ctx.session.file_chooser;
    ctx.session.file_chooser = &fc_wait;
    defer ctx.session.file_chooser = previous;

    // Click the element to trigger the file chooser.
    const click_params = try std.fmt.allocPrint(ctx.arena, "{{\"objectId\":{f},\"clickCount\":1,\"checkEnabled\":true}}", .{std.json.fmt(object_id, .{})});
    var click_res = ctx.session.client.call("Input._craneClickElement", click_params, page.session_id, session_mod.command_timeout_ms) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return ctx.fail("{s}", .{chooser_fail_message}),
    };
    defer click_res.deinit();
    if (click_res.errorMessage() != null) return ctx.fail("{s}", .{chooser_fail_message});

    const Opened = struct {
        fc: *session_mod.FileChooserWait,
        fn done(self: @This()) bool {
            return self.fc.opened;
        }
    };
    _ = try ctx.session.waitUntil(file_chooser_timeout_ms, Opened{ .fc = &fc_wait }, Opened.done);
    if (!fc_wait.opened) return ctx.fail("{s}", .{chooser_fail_message});
    const backend_id = fc_wait.backend_node_id orelse return ctx.fail("{s}", .{chooser_fail_message});
    if (files.len > 1 and !fc_wait.is_multiple) {
        return ctx.fail("Multiple file uploads only work with <input type=file multiple>", .{});
    }
    if (files.len == 0) {
        const context_id = try elements.mainWorld(ctx, page, element.frame_id);
        const resolve_params = try std.fmt.allocPrint(ctx.arena, "{{\"backendNodeId\":{d},\"executionContextId\":{d}}}", .{ backend_id, context_id });
        var resolved = try ctx.session.client.call("DOM.resolveNode", resolve_params, page.session_id, session_mod.command_timeout_ms);
        defer resolved.deinit();
        const obj = (resolved.result() orelse return ctx.fail("{s}", .{chooser_fail_message})).object.get("object") orelse return ctx.fail("{s}", .{chooser_fail_message});
        if (obj != .object) return ctx.fail("{s}", .{chooser_fail_message});
        const resolved_id = session_mod.str(obj.object.get("objectId"));
        if (resolved_id.len == 0) return ctx.fail("{s}", .{chooser_fail_message});
        defer elements.release(ctx, page, resolved_id);
        const arg = try std.fmt.allocPrint(ctx.arena, "{{\"objectId\":{f}}}", .{std.json.fmt(resolved_id, .{})});
        _ = callOn(ctx, page, context_id, clear_files, arg) catch return ctx.fail("{s}", .{chooser_fail_message});
        return;
    }

    var params: std.Io.Writer.Allocating = .init(ctx.arena);
    try params.writer.writeAll("{\"files\":[");
    for (files, 0..) |f, i| {
        if (i != 0) try params.writer.writeAll(",");
        try params.writer.print("{f}", .{std.json.fmt(f, .{})});
    }
    try params.writer.print("],\"backendNodeId\":{d}}}", .{backend_id});
    var set = try ctx.session.client.call("DOM.setFileInputFiles", params.written(), page.session_id, session_mod.command_timeout_ms);
    defer set.deinit();
    if (set.errorMessage() != null) return ctx.fail("{s}", .{chooser_fail_message});
}

/// ElementHandle.uploadFile's compiled callbacks (puppeteer-core 25.17.0
/// lib/puppeteer/cdp/ElementHandle.js), with Puppeteer's sourceURL.
const is_multiple =
    \\element => {
    \\                return element.multiple;
    \\            }
    \\//# sourceURL=pptr:internal
    \\
;
const clear_files =
    \\element => {
    \\                    element.files = new DataTransfer().files;
    \\                    // Dispatch events for this case because it should behave akin to a user action.
    \\                    element.dispatchEvent(new Event('input', { bubbles: true, composed: true }));
    \\                    element.dispatchEvent(new Event('change', { bubbles: true }));
    \\                }
    \\//# sourceURL=pptr:internal
    \\
;

/// CdpElementHandle.uploadFile: `files` are already absolute.
fn setInputFiles(ctx: *Context, page: *Page, element: elements.Element, files: []const []const u8) !void {
    const object_id = element.object_id orelse return error.NotAnElement;
    const context_id = try elements.mainWorld(ctx, page, element.frame_id);
    const multiple = try callOn(ctx, page, context_id, is_multiple, element.argument);
    if (files.len > 1 and !(multiple == .bool and multiple.bool)) return error.MultipleUploads;
    if (files.len == 0) {
        _ = try callOn(ctx, page, context_id, clear_files, element.argument);
        return;
    }
    const describe_params = try std.fmt.allocPrint(ctx.arena, "{{\"objectId\":{f}}}", .{std.json.fmt(object_id, .{})});
    var described = try ctx.session.client.call("DOM.describeNode", describe_params, page.session_id, session_mod.command_timeout_ms);
    defer described.deinit();
    if (described.errorMessage() != null) return error.ProtocolError;
    const node = (described.result() orelse return error.ProtocolError).object.get("node") orelse return error.ProtocolError;
    if (node != .object) return error.ProtocolError;
    const backend = node.object.get("backendNodeId") orelse return error.ProtocolError;
    if (backend != .integer) return error.ProtocolError;
    var params: std.Io.Writer.Allocating = .init(ctx.arena);
    try params.writer.print("{{\"objectId\":{f},\"files\":[", .{std.json.fmt(object_id, .{})});
    for (files, 0..) |f, i| {
        if (i != 0) try params.writer.writeAll(",");
        try params.writer.print("{f}", .{std.json.fmt(f, .{})});
    }
    try params.writer.print("],\"backendNodeId\":{d}}}", .{backend.integer});
    var set = try ctx.session.client.call("DOM.setFileInputFiles", params.written(), page.session_id, session_mod.command_timeout_ms);
    defer set.deinit();
    if (set.errorMessage() != null) return error.ProtocolError;
}

// ============================================================================
// press_key & type_text
// ============================================================================

/// A schema transform's (parseKey's) failure: ToolHandler's validation
/// error, the message alone.
fn validationError(ctx: *Context, tool: []const u8, field: []const u8, message: []const u8) error{ToolFailed} {
    return ctx.failPlain("Input validation error: Invalid arguments for tool {s}: {s}: {s}", .{ tool, field, message });
}

fn pressKey(ctx: *Context, args: std.json.ObjectMap, page: ?*Page, response: *Response) anyerror!void {
    const target = page.?;
    const input = registry.stringArg(args, "key") orelse return validationError(ctx, "press_key", "key", "Invalid input: expected string, received undefined");
    const keys = switch (try keyboard.parseKey(ctx.arena, input)) {
        .keys => |k| k,
        .invalid => |message| return validationError(ctx, "press_key", "key", message),
    };
    const include_snapshot = registry.boolArg(args, "includeSnapshot") orelse false;
    const Press = struct {
        page: *Page,
        keys: []const *const keyboard.KeyDefinition,

        pub fn run(self: @This(), c: *Context) !void {
            const modifiers = self.keys[1..];
            var held: usize = 0;
            // Every modifier pressed is released, even when a later key
            // event fails (chrome-devtools-mcp #2309).
            defer {
                var i = held;
                while (i > 0) {
                    i -= 1;
                    keyUp(c, self.page, modifiers[i]) catch {};
                }
            }
            for (modifiers) |m| {
                try keyDown(c, self.page, m, true);
                held += 1;
            }
            try press(c, self.page, self.keys[0]);
        }
    };
    const result = try wait.afterAction(ctx, target, .{}, Press{ .page = target, .keys = keys });
    var names: std.Io.Writer.Allocating = .init(ctx.arena);
    for (keys[1..]) |m| try names.writer.print("{s}+", .{m.input});
    try names.writer.writeAll(keys[0].input);
    try response.line("Successfully pressed key: {s}", .{names.written()});
    response.wait_result = result.forResponse();
    if (include_snapshot and target.dialog == null) response.snapshot = try snapshot_tools.capture(ctx, target, false);
}

fn typeText(ctx: *Context, args: std.json.ObjectMap, page: ?*Page, response: *Response) anyerror!void {
    const target = page.?;
    const text = registry.stringArg(args, "text") orelse return validationError(ctx, "type_text", "text", "Invalid input: expected string, received undefined");
    var submit: ?*const keyboard.KeyDefinition = null;
    if (registry.stringArg(args, "submitKey")) |key| if (key.len != 0) {
        submit = keyboard.definition(key) orelse return validationError(ctx, "type_text", "submitKey", try keyboard.invalidKeyMessage(ctx.arena, key));
    };
    const Type = struct {
        page: *Page,
        text: []const u8,
        submit: ?*const keyboard.KeyDefinition,

        pub fn run(self: @This(), c: *Context) !void {
            typeChars(c, self.page, self.text) catch |err| switch (err) {
                error.DialogAborted => return,
                else => return err,
            };
            if (self.submit) |d| {
                pressInterruptible(c, self.page, d) catch |err| switch (err) {
                    error.DialogAborted => return,
                    else => return err,
                };
            }
        }
    };
    const result = try wait.afterAction(ctx, target, .{}, Type{ .page = target, .text = text, .submit = submit });
    if (submit) |d| {
        try response.line("Typed text \"{s} + {s}\"", .{ text, d.input });
    } else try response.line("Typed text \"{s}\"", .{text});
    response.wait_result = result.forResponse();
}

// ============================================================================
// Shared CDP & Keyboard helpers
// ============================================================================

/// keyboard.type: a character the layout has is pressed, any other inserted.
fn typeChars(ctx: *Context, page: *Page, text: []const u8) !void {
    const view = std.unicode.Utf8View.init(text) catch return ctx.fail("Invalid UTF-8 in text", .{});
    var it = view.iterator();
    while (it.nextCodepointSlice()) |char| {
        if (keyboard.definition(char)) |d| {
            try pressInterruptible(ctx, page, d);
        } else {
            const params = try std.fmt.allocPrint(ctx.arena, "{{\"text\":{f}}}", .{std.json.fmt(char, .{})});
            try sendInterruptible(ctx, page, "Input.insertText", params);
        }
    }
}

fn failInteract(ctx: *Context, uid: ?[]const u8, reason: []const u8) error{ToolFailed} {
    if (uid) |u| return ctx.fail("Failed to interact with the element with uid {s}. {s}", .{ u, reason });
    return ctx.fail("{s}", .{reason});
}

/// Invoke a local-only element action on `domains/input.zig`, aborting
/// immediately if a JS dialog opens during the event dispatch.
fn callElementAction(ctx: *Context, page: *Page, uid: ?[]const u8, method: []const u8, params: []const u8) !void {
    var r = if (ctx.session.watch) |w|
        ctx.session.client.callOrAbort(method, params, page.session_id, session_mod.command_timeout_ms, &w.aborted) catch |err| switch (err) {
            error.Aborted => return error.DialogAborted,
            else => return err,
        }
    else
        try ctx.session.client.call(method, params, page.session_id, session_mod.command_timeout_ms);
    defer r.deinit();
    if (r.errorMessage()) |message| return failInteract(ctx, uid, message);
}

/// What `Input._crane*Element` answers for an element that is not being
/// rendered (src/devtools/domains/input.zig validateElement). The locator waits
/// for such an element to get a box - #ensureElementIsInTheViewportIfNeeded's
/// isIntersectingViewport and scrollIntoView, retried (main's ruling, 9:27 PM
/// ET 2026-11-27); every other refusal answers at once.
const not_rendered_refusal = "Element is not visible (display: none).";

const Acted = enum { acted, not_rendered };

/// Invoke a local-only element action under the locator: `.not_rendered` for an
/// element with no box yet (try again), a failure naming why for any other
/// refusal.
fn elementAction(ctx: *Context, page: *Page, uid: []const u8, method: []const u8, params: []const u8) !Acted {
    var r = if (ctx.session.watch) |w|
        ctx.session.client.callOrAbort(method, params, page.session_id, session_mod.command_timeout_ms, &w.aborted) catch |err| switch (err) {
            error.Aborted => return error.DialogAborted,
            else => return err,
        }
    else
        try ctx.session.client.call(method, params, page.session_id, session_mod.command_timeout_ms);
    defer r.deinit();
    if (r.errorMessage()) |message| {
        if (std.mem.eql(u8, message, not_rendered_refusal)) return .not_rendered;
        return failInteract(ctx, uid, message);
    }
    return .acted;
}

/// ElementHandle.evaluate(fn) returning a string (copied into `ctx.arena`) or
/// null, aborting immediately if a JS dialog opens during execution.
fn callOnString(ctx: *Context, page: *Page, context_id: i64, declaration: []const u8, argument: []const u8, extra_string: ?[]const u8) !?[]const u8 {
    var params: std.Io.Writer.Allocating = .init(ctx.arena);
    try params.writer.print("{{\"functionDeclaration\":{f},\"executionContextId\":{d},\"arguments\":[{s}", .{ std.json.fmt(declaration, .{}), context_id, argument });
    if (extra_string) |s| try params.writer.print(",{{\"value\":{f}}}", .{std.json.fmt(s, .{})});
    try params.writer.writeAll("],\"returnByValue\":true,\"awaitPromise\":true,\"userGesture\":true}");
    var r = if (ctx.session.watch) |w|
        ctx.session.client.callOrAbort("Runtime.callFunctionOn", params.written(), page.session_id, session_mod.command_timeout_ms, &w.aborted) catch |err| switch (err) {
            error.Aborted => return error.DialogAborted,
            else => return err,
        }
    else
        try ctx.session.client.call("Runtime.callFunctionOn", params.written(), page.session_id, session_mod.command_timeout_ms);
    defer r.deinit();
    if (r.errorMessage() != null) return error.ProtocolError;
    const result = r.result() orelse return error.ProtocolError;
    if (result.object.get("exceptionDetails") != null) return error.Thrown;
    const remote = result.object.get("result") orelse return null;
    if (remote != .object) return null;
    const value = remote.object.get("value") orelse return null;
    return if (value == .string) try ctx.arena.dupe(u8, value.string) else null;
}

/// ElementHandle.evaluate(fn): Runtime.callFunctionOn by value with the
/// element as its argument; the returned boolean (or null).
fn callOn(ctx: *Context, page: *Page, context_id: i64, declaration: []const u8, argument: []const u8) !std.json.Value {
    const params = try std.fmt.allocPrint(ctx.arena, "{{\"functionDeclaration\":{f},\"executionContextId\":{d},\"arguments\":[{s}],\"returnByValue\":true,\"awaitPromise\":true,\"userGesture\":true}}", .{ std.json.fmt(declaration, .{}), context_id, argument });
    var r = try ctx.session.client.call("Runtime.callFunctionOn", params, page.session_id, session_mod.command_timeout_ms);
    defer r.deinit();
    if (r.errorMessage() != null) return error.ProtocolError;
    const result = r.result() orelse return error.ProtocolError;
    if (result.object.get("exceptionDetails") != null) return error.Thrown;
    const remote = result.object.get("result") orelse return .null;
    if (remote != .object) return .null;
    const value = remote.object.get("value") orelse return .null;
    return if (value == .bool) .{ .bool = value.bool } else .null;
}

/// Keyboard.press: down then up (no commands).
fn press(ctx: *Context, page: *Page, d: *const keyboard.KeyDefinition) !void {
    try keyDown(ctx, page, d, false);
    try keyUp(ctx, page, d);
}

fn pressInterruptible(ctx: *Context, page: *Page, d: *const keyboard.KeyDefinition) !void {
    try sendInterruptible(ctx, page, "Input.dispatchKeyEvent", try page.keyboard.down(ctx.session.allocator, ctx.arena, d, false));
    try sendInterruptible(ctx, page, "Input.dispatchKeyEvent", try page.keyboard.up(ctx.arena, d));
}

fn keyDown(ctx: *Context, page: *Page, d: *const keyboard.KeyDefinition, commands: bool) !void {
    try send(ctx, page, "Input.dispatchKeyEvent", try page.keyboard.down(ctx.session.allocator, ctx.arena, d, commands));
}

fn keyUp(ctx: *Context, page: *Page, d: *const keyboard.KeyDefinition) !void {
    try send(ctx, page, "Input.dispatchKeyEvent", try page.keyboard.up(ctx.arena, d));
}

fn send(ctx: *Context, page: *Page, method: []const u8, params: []const u8) !void {
    var r = try ctx.session.client.call(method, params, page.session_id, session_mod.command_timeout_ms);
    defer r.deinit();
    if (r.errorMessage()) |message| return ctx.fail("Protocol error ({s}): {s}", .{ method, message });
}

fn sendInterruptible(ctx: *Context, page: *Page, method: []const u8, params: []const u8) !void {
    var r = if (ctx.session.watch) |w|
        ctx.session.client.callOrAbort(method, params, page.session_id, session_mod.command_timeout_ms, &w.aborted) catch |err| switch (err) {
            error.Aborted => return error.DialogAborted,
            else => return err,
        }
    else
        try ctx.session.client.call(method, params, page.session_id, session_mod.command_timeout_ms);
    defer r.deinit();
    if (r.errorMessage()) |message| return ctx.fail("Protocol error ({s}): {s}", .{ method, message });
}
