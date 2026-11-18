//! HTML 6.7 keyboard shortcuts: the `accesskey` attribute's assigned access
//! key (6.7.3) and the command an access key triggers (4.11.3).
//!
//! An element's assigned access key is derived from its accesskey attribute
//! when the key is pressed (6.7.3 runs the derivation "whenever the
//! attribute is set, changed, or removed"; reading it at the press gives the
//! same key): the first token of the value that is exactly one code point.
//! The modifiers are the platform's access key combination, as Blink's
//! KeyboardEventManager / EventHandler::HandleAccessKey (kAccessKeyModifiers,
//! Shift ignored) and WebKit's EventHandler::accessKeyModifiers choose them:
//! Control+Option on a Mac platform, Alt elsewhere - what
//! resources/accesskey.js presses (Control+Option on a navigator.userAgent
//! with "Mac", Shift+Alt otherwise).
//!
//! The access key is handled before the keydown is dispatched, and a matched
//! one ends the key's processing after its keydown (no keypress, no default
//! action), as Blink's KeyboardEventManager::KeyEvent and WebKit's
//! EventHandler::internalKeyEvent (`matchedAnAccessKey`) do.
//!
//! The commands (4.11.3): an `a` with an href, a `button` and an `input` of
//! a button-like, checkbox or radio type fire a click event at the element;
//! an `option` in a select picks it, or toggles it in a select with multiple
//! (4.11.3.5 - Safari Technology Preview 256 passes the
//! commands/option/option-accesskey*.html files with exactly this, the
//! change WebKit made for WebKit bug 327130; Chrome 157 toggles in every
//! select, Firefox 160 has no option access keys); a `legend` delegates to
//! its fieldset's first other command; any other element runs the focusing
//! steps for itself and fires a click event at it (4.11.3.7).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const form_associated = @import("form_associated.zig");
const focus = @import("focus.zig");
const select_picker = @import("forms/select_picker.zig");
const select_options = @import("forms/options.zig");
const Instance = runtime.Instance;

const html_namespace = "http://www.w3.org/1999/xhtml";

const user_input = @import("user_input.zig");
const Modifiers = user_input.Modifiers;

/// Whether `modifiers` are the platform's access key combination (Shift
/// ignored): Control+Option on a Mac platform, Alt alone elsewhere.
pub fn isAccessKeyCombination(modifiers: Modifiers) bool {
    const mac = std.mem.startsWith(u8, @import("platform").identity.navigator_platform.slice(), "Mac");
    if (modifiers.meta) return false;
    return if (mac) modifiers.ctrl and modifiers.alt else modifiers.alt and !modifiers.ctrl;
}

/// The key `key` (a KeyboardEvent key value) pressed with the access key
/// combination in `document`: trigger the command of the first element in
/// tree order whose assigned access key it is. Whether one matched.
pub fn handle(document: *Instance, key: []const u8, click_modifiers: Modifiers) bool {
    const pressed = singleCodePoint(key) orelse return false;
    const element = elementWithAccessKey(document, pressed) orelse return false;
    var hold: dom.node_holds.TaskHold = .{};
    hold.take(element);
    defer hold.release();
    runCommand(element, click_modifiers);
    return true;
}

/// `text` as one code point, case-folded for ASCII, or null.
fn singleCodePoint(text: []const u8) ?u21 {
    if (text.len == 0) return null;
    const len = std.unicode.utf8ByteSequenceLength(text[0]) catch return null;
    if (len != text.len) return null;
    const code_point = std.unicode.utf8Decode(text) catch return null;
    return foldCase(code_point);
}

fn foldCase(code_point: u21) u21 {
    if (code_point < 128) return std.ascii.toLower(@intCast(code_point));
    return code_point;
}

/// 6.7.3: an element's assigned access key - "split the attribute's value on
/// ASCII whitespace"; the first token that is "a string exactly one code
/// point in length" is assigned (every key is taken to be on the keyboard).
fn assignedAccessKey(element: *Instance) ?u21 {
    const data = dom.element_data.of(element) orelse return null;
    const value = dom.element_data.getAttributeByNamespaceAndLocalName(data, null, "accesskey") orelse return null;
    var tokens = std.mem.tokenizeAny(u8, value.value, "\t\n\x0C\r ");
    while (tokens.next()) |token| {
        if (singleCodePoint(token)) |code_point| return code_point;
    }
    return null;
}

/// The first HTML element in `document`'s tree order whose assigned access
/// key is `key`.
fn elementWithAccessKey(document: *Instance, key: u21) ?*Instance {
    const root = dom.instance_bridge.getNodeBase(document) orelse return null;
    var current = root.firstChild();
    while (current) |node| {
        if (node.node_type == dom.NodeBase.ELEMENT_NODE) {
            if (dom.instance_bridge.getInstance(node)) |raw| {
                const element: *Instance = @ptrCast(@alignCast(raw));
                if (isHtml(element)) if (assignedAccessKey(element)) |assigned| {
                    if (assigned == key) return element;
                };
            }
        }
        current = nextInTreeOrder(node, root);
    }
    return null;
}

fn nextInTreeOrder(node: *dom.NodeBase, root: *dom.NodeBase) ?*dom.NodeBase {
    if (node.firstChild()) |child| return child;
    var current: ?*dom.NodeBase = node;
    while (current) |n| {
        if (n == root) return null;
        if (n.next_sibling) |sibling| return sibling;
        current = n.parent_node;
    }
    return null;
}

fn isHtml(element: *Instance) bool {
    const data = dom.element_data.of(element) orelse return false;
    return std.mem.eql(u8, data.namespaceSlice() orelse "", html_namespace);
}

fn localNameIs(element: *Instance, name: []const u8) bool {
    const data = dom.element_data.of(element) orelse return false;
    return std.mem.eql(u8, data.localName(), name);
}

/// The input types whose element defines a command firing a click (4.11.3.4:
/// the Submit Button, Reset Button, Image Button, Button, Radio Button and
/// Checkbox states).
fn inputDefinesClickCommand(input: *Instance) bool {
    var buffer: [16]u8 = undefined;
    const input_type = form_associated.inputType(input, &buffer);
    for ([_][]const u8{ "submit", "reset", "image", "button", "radio", "checkbox" }) |t| {
        if (std.mem.eql(u8, input_type, t)) return true;
    }
    return false;
}

/// Run the Action of the command `element` defines, unless its Disabled
/// State is true.
fn runCommand(element: *Instance, click_modifiers: Modifiers) void {
    // 4.11.3.5: an option in a select.
    if (element.stateAs(interfaces.HTMLOptionElement.State) != null) {
        if (select_picker.ownerSelect(element)) |select| return optionCommand(element, select);
    }
    // 4.11.3.6: a legend child of a fieldset delegates to the fieldset's
    // first other descendant that defines a command.
    if (localNameIs(element, "legend")) {
        if (legendDelegatee(element)) |delegatee| return runCommand(delegatee, click_modifiers);
    }
    // Every command's Disabled State is true when the element or an ancestor
    // is inert.
    if (focus.isInertNode(element)) return;
    // 4.11.3.2-4: an a with an href, a button, a click-like input: fire a
    // click event at the element.
    const fires_click_only = (localNameIs(element, "a") and hasAttribute(element, "href")) or
        localNameIs(element, "button") or
        (localNameIs(element, "input") and inputDefinesClickCommand(element));
    if (fires_click_only) {
        // A disabled form control's command is disabled.
        if (!localNameIs(element, "a") and form_associated.isDisabled(element)) return;
        user_input.fireSyntheticClick(element, click_modifiers);
        return;
    }
    // 4.11.3.7: "1. Run the focusing steps for the element. 2. Fire a click
    // event at the element."
    focus.focusingSteps(element, null, .other);
    user_input.fireSyntheticClick(element, click_modifiers);
}

/// 4.11.3.5: "If the option's nearest ancestor select element has a
/// multiple attribute, the Action of the command is to toggle the option
/// element. Otherwise, the Action is to pick the option element." Its
/// Disabled State: the option is disabled, its select is, or it or an
/// ancestor is inert.
fn optionCommand(option: *Instance, select: *Instance) void {
    if (select_options.isDisabled(option) or form_associated.isDisabled(select) or focus.isInertNode(option)) return;
    const multiple = hasAttribute(select, "multiple");
    // "Pick an option" and "toggle an option" set the selectedness and the
    // dirtiness, then send select update notifications.
    dom.form_controls.pickOption(select, option, multiple) catch return;
    select_picker.sendSelectUpdateNotifications(select);
}

/// 4.11.3.6: "the legend element's accesskey delegatee": a descendant of the
/// legend's parent fieldset that defines a command and is neither a label
/// nor a legend - the first, in tree order.
fn legendDelegatee(legend: *Instance) ?*Instance {
    const legend_node = dom.instance_bridge.getNodeBase(legend) orelse return null;
    const fieldset_node = legend_node.parent_node orelse return null;
    const fieldset: *Instance = @ptrCast(@alignCast(dom.instance_bridge.getInstance(fieldset_node) orelse return null));
    if (!localNameIs(fieldset, "fieldset") or !isHtml(fieldset)) return null;
    var current = fieldset_node.firstChild();
    while (current) |node| : (current = nextInTreeOrder(node, fieldset_node)) {
        if (node.node_type != dom.NodeBase.ELEMENT_NODE) continue;
        const element: *Instance = @ptrCast(@alignCast(dom.instance_bridge.getInstance(node) orelse continue));
        if (!isHtml(element) or localNameIs(element, "label") or localNameIs(element, "legend")) continue;
        if (definesCommand(element)) return element;
    }
    return null;
}

/// Whether `element` defines a command (4.11.3.2-5 and 7).
fn definesCommand(element: *Instance) bool {
    if (localNameIs(element, "a")) return hasAttribute(element, "href") or assignedAccessKey(element) != null;
    if (localNameIs(element, "button")) return true;
    if (localNameIs(element, "input") and inputDefinesClickCommand(element)) return true;
    if (element.stateAs(interfaces.HTMLOptionElement.State) != null and select_picker.ownerSelect(element) != null) {
        const data = dom.element_data.of(element) orelse return false;
        const value = dom.element_data.getAttributeByNamespaceAndLocalName(data, null, "value") orelse return true;
        return value.value.len != 0;
    }
    return assignedAccessKey(element) != null;
}

fn hasAttribute(element: *Instance, name: []const u8) bool {
    const data = dom.element_data.of(element) orelse return false;
    return dom.element_data.getAttributeByNamespaceAndLocalName(data, null, name) != null;
}
