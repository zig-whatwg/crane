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
//! HTML state says cannot be hit (`display: none`, `visibility: hidden`,
//! `pointer-events: none`, `inert`, and `disabled` controls where Puppeteer's
//! locator requires enabled). `clientX`/`clientY` are 0, nothing scrolls first,
//! and overlays never intercept.

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

pub const list = [_]Tool{
    .{ .name = "click", .page_tool = true, .blocked_by_dialog = true, .run = click },
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

        pub fn run(self: @This(), c: *Context) !void {
            if (!self.dbl_click and std.mem.eql(u8, self.role, "option")) {
                const handled = try selectNativeOption(c, self.page, self.uid, self.element);
                if (handled) return;
            }
            const object_id = self.element.object_id orelse return failInteract(c, self.uid, "Node is not an Element.");
            const params = try std.fmt.allocPrint(
                c.arena,
                "{{\"objectId\":{f},\"clickCount\":{d},\"checkEnabled\":true}}",
                .{ std.json.fmt(object_id, .{}), if (self.dbl_click) @as(u32, 2) else @as(u32, 1) },
            );
            callElementAction(c, self.page, self.uid, "Input._craneClickElement", params) catch |err| switch (err) {
                error.DialogAborted => return,
                else => return err,
            };
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

/// chrome-devtools-mcp selectNativeSelectOption: for an AX `option` inside a
/// native `<select>`, select it and dispatch `input` + `change` on the select.
/// Returns false if the element has no ancestor `<select>` (fall back to click).
fn selectNativeOption(ctx: *Context, page: *Page, uid: []const u8, element: elements.Element) !bool {
    const context_id = try elements.mainWorld(ctx, page, element.frame_id);
    const ans = callOnString(ctx, page, context_id, select_native_option_js, element.argument, null) catch |err| switch (err) {
        error.DialogAborted => return true,
        else => return err,
    };
    const status = ans orelse return false;
    if (std.mem.eql(u8, status, "ok")) return true;
    if (std.mem.eql(u8, status, "no_select")) return false;
    if (std.mem.eql(u8, status, "disabled")) return failInteract(ctx, uid, "Element is disabled and cannot be interacted with.");
    return false;
}

const select_native_option_js =
    \\element => {
    \\  const select = element.closest('select');
    \\  if (!select) return 'no_select';
    \\  if (element.disabled || select.disabled) return 'disabled';
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

        pub fn run(self: @This(), c: *Context) !void {
            const object_id = self.element.object_id orelse return failInteract(c, self.uid, "Node is not an Element.");
            const params = try std.fmt.allocPrint(c.arena, "{{\"objectId\":{f}}}", .{std.json.fmt(object_id, .{})});
            callElementAction(c, self.page, self.uid, "Input._craneHoverElement", params) catch |err| switch (err) {
                error.DialogAborted => return,
                else => return err,
            };
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
    // Option 2 preconditions: visible (not display:none / visibility:hidden), not inert, not disabled.
    const check_params = try std.fmt.allocPrint(
        ctx.arena,
        "{{\"objectId\":{f},\"checkEnabled\":true,\"checkPointerEvents\":false}}",
        .{std.json.fmt(object_id, .{})},
    );
    callElementAction(ctx, page, uid, "Input._craneCheckElement", check_params) catch |err| switch (err) {
        error.DialogAborted => return true,
        else => return err,
    };

    // chrome-devtools-mcp selectOption: for AX combobox with option children,
    // match an option by its accessible name, or fail with chrome-devtools-mcp's
    // exact message ("Could not find option with text ...").
    var effective_value = raw_value;
    if (std.mem.eql(u8, target_info.role, "combobox") and target_info.options.len > 0) {
        var matched_opt = false;
        for (target_info.options) |opt| {
            if (!std.mem.eql(u8, opt.name, raw_value)) continue;
            matched_opt = true;
            const opt_el = elements.resolveNode(ctx, page, opt.backend_node_id, opt.loader_id, opt.frame_id) catch break;
            defer if (opt_el.object_id) |oid| elements.release(ctx, page, oid);
            const opt_ctx = elements.mainWorld(ctx, page, opt.frame_id) catch break;
            if (callOnString(ctx, page, opt_ctx, read_option_value_js, opt_el.argument, null) catch null) |ov| {
                effective_value = ov;
            }
            break;
        }
        if (!matched_opt) {
            return ctx.fail("Failed to interact with the element with uid {s}. Could not find option with text \"{s}\"", .{ uid, raw_value });
        }
    }

    const context_id = try elements.mainWorld(ctx, page, element.frame_id);
    const info_json = (callOnString(ctx, page, context_id, classify_fill_js, element.argument, null) catch |err| switch (err) {
        error.DialogAborted => return true,
        else => return err,
    }) orelse return failInteract(ctx, uid, "Element cannot be filled out.");

    const parsed = std.json.parseFromSliceLeaky(std.json.Value, ctx.arena, info_json, .{}) catch
        return failInteract(ctx, uid, "Element cannot be filled out.");
    if (parsed != .object) return failInteract(ctx, uid, "Element cannot be filled out.");
    const info = parsed.object;
    const kind = session_mod.str(info.get("kind"));
    const read_only = if (info.get("readOnly")) |v| v == .bool and v.bool else false;
    const checked = if (info.get("checked")) |v| v == .bool and v.bool else false;

    if (read_only) return failInteract(ctx, uid, "Element is read-only.");

    if (std.mem.eql(u8, kind, "select")) {
        const res = callOnString(ctx, page, context_id, select_value_js, element.argument, effective_value) catch |err| switch (err) {
            error.DialogAborted => return true,
            else => return err,
        };
        if (res == null or !std.mem.eql(u8, res.?, "ok")) {
            return ctx.fail("Failed to interact with the element with uid {s}. Element has no option with the value \"{s}\".", .{ uid, effective_value });
        }
        return dialogOpened(ctx, page);
    }

    if (std.mem.eql(u8, kind, "toggle")) {
        const is_true = std.mem.eql(u8, raw_value, "true");
        const is_false = std.mem.eql(u8, raw_value, "false");
        if (!is_true and !is_false) {
            return ctx.fail("Failed to interact with the element with uid {s}. Checkboxes, radio boxes and toggles require \"true\" or \"false\" value, but {s} was used", .{ uid, raw_value });
        }
        if (is_true != checked) {
            const click_params = try std.fmt.allocPrint(
                ctx.arena,
                "{{\"objectId\":{f},\"clickCount\":1,\"checkEnabled\":true}}",
                .{std.json.fmt(object_id, .{})},
            );
            callElementAction(ctx, page, uid, "Input._craneClickElement", click_params) catch |err| switch (err) {
                error.DialogAborted => return true,
                else => return err,
            };
        }
        return dialogOpened(ctx, page);
    }

    if (std.mem.eql(u8, kind, "typeable")) {
        if (effective_value.len < typing_threshold) {
            const prep = callOnString(ctx, page, context_id, prepare_typeable_js, element.argument, effective_value) catch |err| switch (err) {
                error.DialogAborted => return true,
                else => return err,
            };
            const prep_str = prep orelse "0";
            if (std.mem.eql(u8, prep_str, "done")) return dialogOpened(ctx, page);
            const prefix_len = std.fmt.parseInt(usize, prep_str, 10) catch 0;
            const suffix = if (prefix_len <= effective_value.len) effective_value[prefix_len..] else effective_value;
            typeChars(ctx, page, suffix) catch |err| switch (err) {
                error.DialogAborted => return true,
                else => return err,
            };
            return dialogOpened(ctx, page);
        }
        return fillDirectly(ctx, page, uid, context_id, element.argument, effective_value);
    }

    if (std.mem.eql(u8, kind, "direct")) {
        return fillDirectly(ctx, page, uid, context_id, element.argument, effective_value);
    }

    return failInteract(ctx, uid, "Element cannot be filled out.");
}

fn fillDirectly(ctx: *Context, page: *Page, uid: []const u8, context_id: i64, argument: []const u8, value: []const u8) !bool {
    const res = callOnString(ctx, page, context_id, fill_directly_js, argument, value) catch |err| switch (err) {
        error.DialogAborted => return true,
        else => return err,
    };
    if (res != null and std.mem.eql(u8, res.?, "rejected")) {
        return ctx.fail("Failed to interact with the element with uid {s}. Element did not accept the value \"{s}\".", .{ uid, value });
    }
    return dialogOpened(ctx, page);
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

const classify_fill_js =
    \\element => {
    \\  if (!element || element.nodeType !== 1) return JSON.stringify({ kind: 'unsupported' });
    \\  const tag = element.tagName;
    \\  if (tag === 'SELECT') return JSON.stringify({ kind: 'select', readOnly: false });
    \\  const role = (element.getAttribute('role') || '').toLowerCase();
    \\  if (tag === 'INPUT') {
    \\    const t = (element.type || 'text').toLowerCase();
    \\    if (t === 'checkbox' || t === 'radio') {
    \\      return JSON.stringify({ kind: 'toggle', checked: !!element.checked, readOnly: false });
    \\    }
    \\    if (t === 'button' || t === 'submit' || t === 'reset' || t === 'image' || t === 'file' || t === 'hidden') {
    \\      return JSON.stringify({ kind: 'unsupported' });
    \\    }
    \\    const typeable = (t === 'text' || t === 'search' || t === 'tel' || t === 'url' || t === 'email' || t === 'password' || t === 'number');
    \\    return JSON.stringify({ kind: typeable ? 'typeable' : 'direct', readOnly: !!element.readOnly });
    \\  }
    \\  if (tag === 'TEXTAREA') {
    \\    return JSON.stringify({ kind: 'typeable', readOnly: !!element.readOnly });
    \\  }
    \\  if (role === 'checkbox' || role === 'radio' || role === 'switch') {
    \\    return JSON.stringify({ kind: 'toggle', checked: element.getAttribute('aria-checked') === 'true', readOnly: false });
    \\  }
    \\  if (element.isContentEditable) {
    \\    return JSON.stringify({ kind: 'typeable', readOnly: false });
    \\  }
    \\  return JSON.stringify({ kind: 'unsupported' });
    \\}
    \\//# sourceURL=pptr:internal
    \\
;

const select_value_js =
    \\(element, value) => {
    \\  let matched = false;
    \\  for (const opt of element.options) {
    \\    if (opt.value === value) {
    \\      matched = true;
    \\      break;
    \\    }
    \\  }
    \\  if (!matched) return 'missing';
    \\  if (element.multiple) {
    \\    for (const opt of element.options) opt.selected = (opt.value === value);
    \\  } else {
    \\    for (const opt of element.options) {
    \\      if (opt.value === value) {
    \\        opt.selected = true;
    \\        break;
    \\      }
    \\    }
    \\  }
    \\  element.dispatchEvent(new Event('input', { bubbles: true }));
    \\  element.dispatchEvent(new Event('change', { bubbles: true }));
    \\  return 'ok';
    \\}
    \\//# sourceURL=pptr:internal
    \\
;

const prepare_typeable_js =
    \\(element, value) => {
    \\  element.focus();
    \\  if (element.tagName === 'INPUT' || element.tagName === 'TEXTAREA') {
    \\    const cur = element.value || '';
    \\    if (cur.length > 0 && value.startsWith(cur)) {
    \\      try { element.setSelectionRange(cur.length, cur.length); } catch {}
    \\      return String(cur.length);
    \\    }
    \\    if (cur.length > 0) {
    \\      element.value = '';
    \\      if (value.length === 0) {
    \\        element.dispatchEvent(new Event('input', { bubbles: true, composed: true }));
    \\        element.dispatchEvent(new Event('change', { bubbles: true }));
    \\        return 'done';
    \\      }
    \\    }
    \\    return '0';
    \\  }
    \\  // contenteditable
    \\  const cur = element.textContent || '';
    \\  if (cur.length > 0 && value.startsWith(cur)) {
    \\    const sel = element.ownerDocument.getSelection();
    \\    if (sel) { sel.selectAllChildren(element); sel.collapseToEnd(); }
    \\    return String(cur.length);
    \\  }
    \\  if (cur.length > 0) {
    \\    element.textContent = '';
    \\    if (value.length === 0) {
    \\      element.dispatchEvent(new Event('input', { bubbles: true, composed: true }));
    \\      return 'done';
    \\    }
    \\  }
    \\  const sel = element.ownerDocument.getSelection();
    \\  if (sel) { sel.selectAllChildren(element); sel.collapseToEnd(); }
    \\  return '0';
    \\}
    \\//# sourceURL=pptr:internal
    \\
;

const fill_directly_js =
    \\(element, value) => {
    \\  element.focus();
    \\  if (element.tagName === 'INPUT' || element.tagName === 'TEXTAREA') {
    \\    element.value = value;
    \\    if (element.value !== value) return 'rejected';
    \\  } else if (element.isContentEditable) {
    \\    element.textContent = value;
    \\  }
    \\  element.dispatchEvent(new Event('input', { bubbles: true, composed: true }));
    \\  element.dispatchEvent(new Event('change', { bubbles: true }));
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
