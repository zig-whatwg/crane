//! HTML select base appearance: trusted input, option focus and picker.
//! Key mapping follows Blink SelectType (HTML deliberately permits UA keys).
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const options = @import("options.zig");
const associated = @import("../form_associated.zig");
const focus = @import("../focus.zig");
const popover = @import("../popover.zig");
const Instance = runtime.Instance;

pub fn ownerSelect(option: *Instance) ?*Instance {
    var optgroup = false;
    var node = associated.parentOf(option);
    while (node) |ancestor| : (node = associated.parentOf(ancestor)) {
        if (ancestor.stateAs(interfaces.HTMLDataListElement.State) != null or
            ancestor.stateAs(interfaces.HTMLHRElement.State) != null or
            ancestor.stateAs(interfaces.HTMLOptionElement.State) != null) return null;
        if (ancestor.stateAs(interfaces.HTMLOptGroupElement.State) != null) {
            if (optgroup) return null;
            optgroup = true;
        }
        if (ancestor.stateAs(interfaces.HTMLSelectElement.State) != null) return ancestor;
    }
    return null;
}

pub fn isListbox(select: *Instance) bool {
    return associated.hasAttribute(select, "multiple") or (interfaces.HTMLSelectElement.get_size(select) catch 0) > 1;
}

pub fn baseAppearance(select: *Instance) bool {
    const style = (dom.style.computedStyle(select, null) catch null) orelse return false;
    return style.keyword(.appearance) == .base_select;
}

pub fn baseOptions(select: *Instance) bool {
    if (!baseAppearance(select)) return false;
    if (isListbox(select)) return true;
    const picker = (dom.style.computedStyle(select, "picker") catch null) orelse return false;
    return picker.keyword(.appearance) == .base_select;
}

pub fn optionFocusable(option: *Instance) bool {
    const select = ownerSelect(option) orelse return false;
    if (associated.isDisabled(select) or options.isDisabled(option) or !baseOptions(select)) return false;
    if (!isListbox(select) and !dom.form_controls.pickerOpen(select)) return false;
    const style = (dom.style.computedStyle(option, null) catch null) orelse return false;
    return style.keyword(.visibility) == .visible and (dom.style.isBeingRendered(option) catch false);
}

pub fn firstFocusable(select: *Instance, prefer_selected: bool) ?*Instance {
    var list: std.ArrayListUnmanaged(*Instance) = .empty;
    defer list.deinit(select.ctx.allocator);
    options.collect(select, select.ctx.allocator, &list) catch return null;
    var first: ?*Instance = null;
    for (list.items) |option| {
        if (!optionFocusable(option)) continue;
        if (first == null) first = option;
        if (prefer_selected and (interfaces.HTMLOptionElement.get_selected(option) catch false)) return option;
    }
    return first;
}

pub fn focusPicker(select: *Instance) void {
    // HTML's selected-option policy. Blink instead delegates focus for its
    // IsInDialogMode content-model violations; Safari 27 does not. The two
    // shipping pickers split on select-dialog-mode-focus.optional.html
    // (wpt.fyi df642c4142), so the spec decides (row61 Q40).
    if (firstFocusable(select, true)) |option| focus.focusingSteps(option, null, .other);
}

pub fn show(select: *Instance) !void {
    if (associated.isDisabled(select) or isListbox(select) or !baseOptions(select)) return;
    try popover.showPicker(select);
}

fn owningButton(button: *Instance) ?*Instance {
    if (button.stateAs(interfaces.HTMLButtonElement.State) == null) return null;
    const select = associated.parentOf(button) orelse return null;
    if (select.stateAs(interfaces.HTMLSelectElement.State) == null) return null;
    // The button occupies the first ELEMENT child slot. Text and comments
    // do not count; another element before it makes it ordinary content.
    var child = interfaces.Node.get_firstChild(select) catch null;
    while (child) |node| : (child = interfaces.Node.get_nextSibling(node) catch null) {
        if ((interfaces.Node.get_nodeType(node) catch return null) == interfaces.Node.get_ELEMENT_NODE()) return if (node == button) select else null;
    }
    return null;
}

/// HTML 4.10.6: any select's first element child, when a button, is inert.
/// Share the picker-target slot rule without consulting style or open state.
pub fn isSelectButton(element: *Instance) bool {
    return owningButton(element) != null;
}

fn buttonSelectOfTarget(target: *Instance) ?*Instance {
    var current: ?*Instance = target;
    while (current) |node| : (current = associated.parentOf(node)) {
        if (node.stateAs(interfaces.HTMLSelectElement.State) != null) return null;
        if (owningButton(node)) |select| return select;
    }
    return null;
}

fn isControlTarget(target: *Instance, select: *Instance) bool {
    return target == select or optionOfTarget(target) != null or buttonSelectOfTarget(target) == select;
}

fn toggle(select: *Instance) void {
    if (dom.form_controls.pickerOpen(select)) popover.hidePicker(select, true) catch {} else show(select) catch {};
}

fn selectOfTarget(target: *Instance) ?*Instance {
    var node: ?*Instance = target;
    while (node) |element| : (node = associated.parentOf(element)) {
        if (element.stateAs(interfaces.HTMLSelectElement.State) != null) return element;
        if (element.stateAs(interfaces.HTMLOptionElement.State) != null) return ownerSelect(element);
    }
    return null;
}

fn optionOfTarget(target: *Instance) ?*Instance {
    var node: ?*Instance = target;
    while (node) |element| : (node = associated.parentOf(element)) {
        if (element.stateAs(interfaces.HTMLOptionElement.State) != null) return element;
        if (element.stateAs(interfaces.HTMLSelectElement.State) != null) return null;
    }
    return null;
}

/// Called only after an uncanceled trusted primary mousedown and its
/// normal focus default action. Opening then moves focus into the picker.
pub fn mouseDown(target: *Instance, button: u3) void {
    if (button != 0 or optionOfTarget(target) != null) return;
    const select = selectOfTarget(target) orelse return;
    if (target != select and buttonSelectOfTarget(target) != select) return;
    if (baseOptions(select) and !isListbox(select)) toggle(select);
}

pub fn mouseUp(target: *Instance, button: u3) void {
    if (button != 0) return;
    const option = optionOfTarget(target) orelse return;
    const select = ownerSelect(option) orelse return;
    if (!optionFocusable(option)) return;
    pick(select, option);
}

fn pick(select: *Instance, option: *Instance) void {
    if (associated.isDisabled(select) or options.isDisabled(option)) return;
    dom.form_controls.pickOption(select, option, isListbox(select)) catch return;
    // TODO(unwrapped task holder, row 52 Q9 / row 61 Q3(c)): send select
    // update notifications, including selectedcontent and input/change,
    // on the user-interaction task source. Do not substitute an IDL setter.
    if (!isListbox(select)) popover.hidePicker(select, true) catch {};
}

fn keyIs(key: []const u8, name: []const u8) bool {
    return std.mem.eql(u8, key, name);
}

pub fn enterOpensPicker(platform_name: []const u8) bool {
    return !std.mem.startsWith(u8, platform_name, "Mac");
}

/// Keydown defaults run BEFORE keypress; canceling keypress cannot cancel
/// "pick an option" (select-pick-option-keydown.html).
pub fn keyDown(target: *Instance, key: []const u8, shortcut: bool) bool {
    const select = selectOfTarget(target) orelse return false;
    if (!isControlTarget(target, select) or !baseOptions(select)) return false;
    if (associated.isDisabled(select)) return true;
    const option = optionOfTarget(target);
    if (!isListbox(select) and !dom.form_controls.pickerOpen(select)) {
        if (std.mem.startsWith(u8, key, "Arrow") or (!shortcut and (keyIs(key, " ") or
            (keyIs(key, "Enter") and enterOpensPicker(@import("platform").identity.navigator_platform.slice())))))
        {
            show(select) catch {};
            return true;
        }
        return false;
    }
    if (keyIs(key, "Tab")) {
        if (!isListbox(select)) popover.hidePicker(select, true) catch {};
        return false; // the existing sequential-navigation default continues
    }
    // Escape is CloseWatcher's close request, not a private select handler.
    if (keyIs(key, "Escape")) return true;
    if (keyIs(key, " ") or keyIs(key, "Enter")) {
        // Blink and WebKit both reserve modified Space/Enter for shortcuts.
        if (shortcut) return false;
        if (option) |selected| pick(select, selected);
        return true;
    }
    const direction = arrowDirection(select, key);
    // PageUp/PageDown need viewport geometry (row61 Q29), not an alias for
    // Home/End. Ordinary printable keys must reach an uncanceled keypress.
    if (direction == 0 and !keyIs(key, "Home") and !keyIs(key, "End")) return false;
    var list: std.ArrayListUnmanaged(*Instance) = .empty;
    defer list.deinit(select.ctx.allocator);
    options.collect(select, select.ctx.allocator, &list) catch return true;
    if (list.items.len == 0) return true;
    var current: ?usize = null;
    for (list.items, 0..) |item, i| if (item == option) {
        current = i;
        break;
    };
    var next: ?*Instance = null;
    if (keyIs(key, "Home") or direction == -1) {
        var i: usize = if (direction == -1) current orelse list.items.len else list.items.len;
        if (direction != -1) {
            for (list.items) |item| if (optionFocusable(item)) {
                next = item;
                break;
            };
        } else {
            while (i != 0) {
                i -= 1;
                if (optionFocusable(list.items[i])) {
                    next = list.items[i];
                    break;
                }
            }
        }
    } else if (keyIs(key, "End")) {
        var i = list.items.len;
        while (i != 0) {
            i -= 1;
            if (optionFocusable(list.items[i])) {
                next = list.items[i];
                break;
            }
        }
    } else if (direction == 1) {
        const start = if (current) |i| i + 1 else 0;
        for (list.items[start..]) |item| if (optionFocusable(item)) {
            next = item;
            break;
        };
    }
    if (next) |item| focus.focusingSteps(item, null, .other);
    return true;
}

/// Blink GetFocusDirectionFromKeyboardEvent, also shipped by WebKit:
/// Up/Down always work; horizontal arrows follow the block writing direction.
fn arrowDirection(select: *Instance, key: []const u8) i2 {
    if (keyIs(key, "ArrowUp")) return -1;
    if (keyIs(key, "ArrowDown")) return 1;
    if (!keyIs(key, "ArrowLeft") and !keyIs(key, "ArrowRight")) return 0;
    const style = (dom.style.computedStyle(select, null) catch null) orelse return 0;
    const next_right = switch (style.keyword(.writing_mode)) {
        .vertical_lr, .sideways_lr => true,
        .vertical_rl, .sideways_rl => false,
        else => return 0,
    };
    return if (keyIs(key, "ArrowRight") == next_right) 1 else -1;
}

/// UA typeahead runs only after an uncanceled printable keypress, without
/// Ctrl/Alt/Meta (Blink TypeAhead::ShouldHandleKeyboardEvent, row61 Q27).
pub fn typeAhead(target: *Instance, typed: []const u8) bool {
    const select = selectOfTarget(target) orelse return false;
    if (typed.len == 0 or !isControlTarget(target, select) or !baseOptions(select)) return false;
    if (associated.isDisabled(select)) return true;
    var list: std.ArrayListUnmanaged(*Instance) = .empty;
    defer list.deinit(select.ctx.allocator);
    options.collect(select, select.ctx.allocator, &list) catch return true;
    if (list.items.len == 0) return true;
    const closed = !isListbox(select) and !dom.form_controls.pickerOpen(select);
    var current: ?usize = if (closed) dom.form_controls.selectedIndex(select) catch null else null;
    if (!closed) {
        const focused = optionOfTarget(target);
        for (list.items, 0..) |item, i| if (item == focused) {
            current = i;
            break;
        };
    }
    const prefix = dom.form_controls.selectTypeahead(select, typed) catch return true;
    // A longer prefix first searches the current match; one character
    // (including repeated-character cycling) starts after it and wraps once.
    const start = if (current) |i| (i + @as(usize, if (prefix.len > typed.len) 0 else 1)) % list.items.len else 0;
    for (0..list.items.len) |offset| {
        const item = list.items[(start + offset) % list.items.len];
        if (if (closed) options.isDisabled(item) else !optionFocusable(item)) continue;
        var label = interfaces.HTMLOptionElement.get_label(item) catch continue;
        defer label.deinit(select.ctx.allocator);
        const value = std.mem.trimStart(u8, label.asSlice(), " \t\n\r\x0c");
        // TODO(row61 Q27): shared Unicode case/accent folding and whitespace
        // trimming. Blink type_ahead.cc:54-115 compares accent-insensitively;
        // the existing HTML label algorithm and this match are ASCII only.
        if (value.len < prefix.len or !std.ascii.eqlIgnoreCase(value[0..prefix.len], prefix)) continue;
        if (closed) {
            // HTML pick an option through another mechanism. Its queued
            // notifications share the task-holder dependency noted above.
            dom.form_controls.pickOption(select, item, false) catch {};
        } else focus.focusingSteps(item, null, .other);
        break;
    }
    return true;
}
