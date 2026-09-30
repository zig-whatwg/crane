//! Form-associated elements (HTML § 4.10.18 - 4.10.19): the algorithms the
//! form controls, the label and the form share. Everything here reaches the
//! elements through their interfaces; it keeps no state.
//!
//!   * tree order and element tests
//!   * the form owner (§ 4.10.18.3)
//!   * disabled form controls (§ 4.10.19.5)
//!   * buttons and submit buttons (§ 4.10.6, § 4.10.5.1.18-19)
//!   * labelable elements and a label's labeled control (§ 4.10.4)
//!   * the directionality (§ 3.2.6.4), for dirname (§ 4.10.19.2)
//!
//! Stated deviation - the form owner is COMPUTED on each read, by the steps
//! of "reset the form owner" (§ 4.10.18.3, steps 4-5), rather than stored and
//! reset at insertion, removal and attribute changes. The two agree on every
//! tree but one: a control the parser associated with its form element
//! pointer while not a descendant of that form (`<form><div></form><input>`
//! misnesting). Blink and Gecko store it; storing it needs insertion,
//! removal and id-change steps for every listed element, which is its own
//! piece of work.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dictionaries = @import("dictionaries");
const webidl = @import("webidl");
const enums = @import("enums");
const unicode_data = @import("url").idna.unicode_data_mod;
const engine = @import("engine");
const log = std.log.scoped(.forms);

const Instance = runtime.Instance;

// ============================================================================
// Tree order and element tests
// ============================================================================

pub fn parentOf(node: *Instance) ?*Instance {
    return interfaces.Node.get_parentNode(node) catch null;
}

/// Whether `node` is an element (only an element may be handed to
/// Element's members).
pub fn isElement(node: *Instance) bool {
    const node_type = interfaces.Node.get_nodeType(node) catch return false;
    return node_type == interfaces.Node.get_ELEMENT_NODE();
}

/// Whether `node` is an element with local name `name` (ASCII
/// case-insensitive: HTML elements' names are lower case).
pub fn isElementNamed(node: *Instance, comptime name: []const u8) bool {
    if (!isElement(node)) return false;
    var local = interfaces.Element.get_localName(node) catch return false;
    defer local.deinit(node.ctx.allocator);
    return std.ascii.eqlIgnoreCase(local.asSlice(), name);
}

pub fn isForm(node: *Instance) bool {
    return node.stateAs(interfaces.HTMLFormElement.State) != null;
}

pub fn isInput(node: *Instance) bool {
    return node.stateAs(interfaces.HTMLInputElement.State) != null;
}

pub fn isButton(node: *Instance) bool {
    return node.stateAs(interfaces.HTMLButtonElement.State) != null;
}

pub fn isSelect(node: *Instance) bool {
    return node.stateAs(interfaces.HTMLSelectElement.State) != null;
}

pub fn isTextArea(node: *Instance) bool {
    return node.stateAs(interfaces.HTMLTextAreaElement.State) != null;
}

pub fn hasAttribute(element: *Instance, comptime name: []const u8) bool {
    return interfaces.Element.call_hasAttribute(element, runtime.DOMString.initInterned(name)) catch false;
}

/// The attribute's value, owned by `allocator`, or null when the element has
/// no such attribute. Presence is asked separately: Element.getAttribute
/// answers "" for a missing attribute.
pub fn attributeValue(allocator: std.mem.Allocator, element: *Instance, comptime name: []const u8) !?[]u8 {
    if (!hasAttribute(element, name)) return null;
    var value = (try interfaces.Element.call_getAttribute(element, runtime.DOMString.initInterned(name))) orelse return null;
    defer value.deinit(element.ctx.allocator);
    return try allocator.dupe(u8, value.asSlice());
}

/// The node after `node` in tree order within `root`'s subtree, not
/// descending into `node` when `skip_children` is set.
pub fn nextInTree(node: *Instance, root: *Instance, skip_children: bool) ?*Instance {
    if (!skip_children) {
        if (interfaces.Node.get_firstChild(node) catch null) |child| return child;
    }
    var current = node;
    while (current != root) {
        if (interfaces.Node.get_nextSibling(current) catch null) |sibling| return sibling;
        current = parentOf(current) orelse return null;
    }
    return null;
}

/// `node`'s root (not shadow-including).
pub fn rootOf(node: *Instance) *Instance {
    return interfaces.Node.call_getRootNode(node, webidl.Opt(dictionaries.GetRootNodeOptions).notPassed()) catch node;
}

/// "The first element in `root`'s tree, in tree order, to have an ID that is
/// identical to `id`" - `root` included.
pub fn firstElementWithId(root: *Instance, id: []const u8) ?*Instance {
    if (id.len == 0) return null;
    const node_type = interfaces.Node.get_nodeType(root) catch return null;
    const key = runtime.DOMString.initInterned(id);
    if (node_type == interfaces.Node.get_DOCUMENT_NODE()) {
        return interfaces.Document.call_getElementById(root, key) catch null;
    }
    if (node_type == interfaces.Node.get_DOCUMENT_FRAGMENT_NODE()) {
        return interfaces.DocumentFragment.call_getElementById(root, key) catch null;
    }
    // A tree rooted at an element (not connected): walk it.
    var node: ?*Instance = root;
    while (node) |n| : (node = nextInTree(n, root, false)) {
        if (!isElement(n)) continue;
        var element_id = interfaces.Element.get_id(n) catch continue;
        defer element_id.deinit(n.ctx.allocator);
        if (std.mem.eql(u8, element_id.asSlice(), id)) return n;
    }
    return null;
}

// ============================================================================
// Form owner (§ 4.10.18.3)
// ============================================================================

/// The element's form owner, by "reset the form owner" steps 4-5 (see the
/// stated deviation at the top of this file):
///
/// 4. If element has a form content attribute and element is connected,
///    then: if the first element in element's tree, in tree order, to have
///    an ID that is identical to element's form content attribute's value,
///    is a form element, then associate the element with that form element.
/// 5. Otherwise, if element has an ancestor form element, then associate
///    element with the nearest such ancestor form element.
pub fn formOwner(element: *Instance) ?*Instance {
    const connected = interfaces.Node.get_isConnected(element) catch false;
    if (connected and hasAttribute(element, "form")) {
        var value = (interfaces.Element.call_getAttribute(element, runtime.DOMString.initInterned("form")) catch null) orelse return null;
        defer value.deinit(element.ctx.allocator);
        const found = firstElementWithId(rootOf(element), value.asSlice()) orelse return null;
        return if (isForm(found)) found else null;
    }
    var ancestor = parentOf(element);
    while (ancestor) |a| : (ancestor = parentOf(a)) {
        if (isForm(a)) return a;
    }
    return null;
}

// ============================================================================
// Disabled (§ 4.10.19.5)
// ============================================================================

/// The first `legend` element child of `fieldset`, if any.
fn firstLegendChild(fieldset: *Instance) ?*Instance {
    var child = interfaces.Node.get_firstChild(fieldset) catch null;
    while (child) |c| : (child = interfaces.Node.get_nextSibling(c) catch null) {
        if (isElementNamed(c, "legend")) return c;
    }
    return null;
}

/// Whether `node` is `ancestor` or one of its descendants.
fn isInclusiveDescendant(node: *Instance, ancestor: *Instance) bool {
    var current: ?*Instance = node;
    while (current) |n| : (current = parentOf(n)) {
        if (n == ancestor) return true;
    }
    return false;
}

/// "A form control is disabled if any of the following are true: the element
/// is a button, input, select, textarea, or form-associated custom element,
/// and the disabled attribute is specified on this element; the element is a
/// descendant of a fieldset element whose disabled attribute is specified,
/// and is not a descendant of that fieldset element's first legend element
/// child, if any."
pub fn isDisabled(field: *Instance) bool {
    if (hasAttribute(field, "disabled")) return true;
    var ancestor = parentOf(field);
    while (ancestor) |a| : (ancestor = parentOf(a)) {
        if (!isElementNamed(a, "fieldset") or !hasAttribute(a, "disabled")) continue;
        const legend = firstLegendChild(a) orelse return true;
        if (!isInclusiveDescendant(field, legend)) return true;
    }
    return false;
}

// ============================================================================
// Buttons (§ 4.10.6; input's Submit, Image, Reset and Button states)
// ============================================================================

/// A button element's type attribute state. "The attribute's missing value
/// default and invalid value default are both the Auto state."
pub const ButtonType = enum { auto, submit, reset, button };

pub fn buttonType(button: *Instance) ButtonType {
    var buffer: [8]u8 = undefined;
    const value = smallAttribute(button, "type", &buffer) orelse return .auto;
    if (std.ascii.eqlIgnoreCase(value, "submit")) return .submit;
    if (std.ascii.eqlIgnoreCase(value, "reset")) return .reset;
    if (std.ascii.eqlIgnoreCase(value, "button")) return .button;
    return .auto;
}

/// An attribute value that fits `buffer`; null when absent or longer (no
/// keyword this file matches is longer than its buffer).
fn smallAttribute(element: *Instance, comptime name: []const u8, buffer: []u8) ?[]const u8 {
    if (!hasAttribute(element, name)) return null;
    var value = (interfaces.Element.call_getAttribute(element, runtime.DOMString.initInterned(name)) catch null) orelse return null;
    defer value.deinit(element.ctx.allocator);
    const slice = value.asSlice();
    if (slice.len > buffer.len) return buffer[0..0];
    @memcpy(buffer[0..slice.len], slice);
    return buffer[0..slice.len];
}

/// An input element's type attribute, canonical ("text" when missing or
/// unknown), as its IDL getter reads it. Owned by the caller's `buffer`.
pub fn inputType(input: *Instance, buffer: []u8) []const u8 {
    var value = interfaces.HTMLInputElement.get_type(input) catch return "text";
    defer value.deinit(input.ctx.allocator);
    const slice = value.asSlice();
    const n = @min(slice.len, buffer.len);
    @memcpy(buffer[0..n], slice[0..n]);
    return buffer[0..n];
}

/// A button element "is a submit button" when its type attribute is in the
/// Submit Button state, or in the Auto state with neither a command nor a
/// commandfor attribute and a parent that is not a select element; an input
/// element is one in the Submit Button or Image Button state.
pub fn isSubmitButton(element: *Instance) bool {
    if (isButton(element)) {
        return switch (buttonType(element)) {
            .submit => true,
            .auto => !hasAttribute(element, "command") and !hasAttribute(element, "commandfor") and
                !(if (parentOf(element)) |p| isSelect(p) else false),
            else => false,
        };
    }
    if (isInput(element)) {
        var buffer: [16]u8 = undefined;
        const t = inputType(element, &buffer);
        return std.mem.eql(u8, t, "submit") or std.mem.eql(u8, t, "image");
    }
    return false;
}

/// "Buttons": button elements, and input elements in the Submit Button,
/// Image Button, Reset Button and Button states.
pub fn isButtonControl(element: *Instance) bool {
    if (isButton(element)) return true;
    if (!isInput(element)) return false;
    var buffer: [16]u8 = undefined;
    const t = inputType(element, &buffer);
    return std.mem.eql(u8, t, "submit") or std.mem.eql(u8, t, "image") or
        std.mem.eql(u8, t, "reset") or std.mem.eql(u8, t, "button");
}

// ============================================================================
// Labels (§ 4.10.4)
// ============================================================================

/// "Labelable elements": button, input (not in the Hidden state), meter,
/// output, progress, select, textarea, and form-associated custom elements.
/// (Form-associated custom elements are not implemented.)
pub fn isLabelable(element: *Instance) bool {
    if (isInput(element)) {
        var buffer: [16]u8 = undefined;
        return !std.mem.eql(u8, inputType(element, &buffer), "hidden");
    }
    return isButton(element) or isSelect(element) or isTextArea(element) or
        element.stateAs(interfaces.HTMLMeterElement.State) != null or
        element.stateAs(interfaces.HTMLOutputElement.State) != null or
        element.stateAs(interfaces.HTMLProgressElement.State) != null;
}

/// A label element's labeled control: with a for attribute, the first
/// element in the label's tree whose ID is its value, when that element is
/// labelable; without one, the label's first labelable descendant in tree
/// order.
pub fn labeledControl(label: *Instance) ?*Instance {
    if (hasAttribute(label, "for")) {
        var value = (interfaces.Element.call_getAttribute(label, runtime.DOMString.initInterned("for")) catch null) orelse return null;
        defer value.deinit(label.ctx.allocator);
        const found = firstElementWithId(rootOf(label), value.asSlice()) orelse return null;
        return if (isLabelable(found)) found else null;
    }
    var node = nextInTree(label, label, false);
    while (node) |n| : (node = nextInTree(n, label, false)) {
        if (isElement(n) and isLabelable(n)) return n;
    }
    return null;
}

/// The label elements in `element`'s tree whose labeled control is
/// `element`, in tree order. The list is the caller's.
pub fn labelsOf(allocator: std.mem.Allocator, element: *Instance) ![]*Instance {
    var out: std.ArrayListUnmanaged(*Instance) = .empty;
    errdefer out.deinit(allocator);
    const root = rootOf(element);
    var node: ?*Instance = root;
    while (node) |n| : (node = nextInTree(n, root, false)) {
        if (n.stateAs(interfaces.HTMLLabelElement.State) == null) continue;
        if (labeledControl(n) == element) try out.append(allocator, n);
    }
    return out.toOwnedSlice(allocator);
}

// ============================================================================
// Directionality (§ 3.2.6.4)
// ============================================================================

pub const Direction = enum { ltr, rtl };

/// The dir attribute's state: an enumerated attribute whose missing and
/// invalid value defaults are the Undefined state.
const DirState = enum { ltr, rtl, auto, undefined };

fn dirState(element: *Instance) DirState {
    var buffer: [4]u8 = undefined;
    const value = smallAttribute(element, "dir", &buffer) orelse return .undefined;
    if (std.ascii.eqlIgnoreCase(value, "ltr")) return .ltr;
    if (std.ascii.eqlIgnoreCase(value, "rtl")) return .rtl;
    if (std.ascii.eqlIgnoreCase(value, "auto")) return .auto;
    return .undefined;
}

/// "The auto-directionality form-associated elements": input elements in
/// the Hidden, Text, Search, Telephone, URL, Email, Password, Submit Button,
/// Reset Button or Button state, and textarea elements.
pub fn isAutoDirectionalityFormAssociated(element: *Instance) bool {
    if (isTextArea(element)) return true;
    if (!isInput(element)) return false;
    var buffer: [16]u8 = undefined;
    const t = inputType(element, &buffer);
    const states = [_][]const u8{ "hidden", "text", "search", "tel", "url", "email", "password", "submit", "reset", "button" };
    for (states) |s| {
        if (std.mem.eql(u8, t, s)) return true;
    }
    return false;
}

/// "The directionality" of `element`.
pub fn directionality(element: *Instance) Direction {
    // A bound on the parent walk: no real tree is anywhere near this deep.
    var current = element;
    var depth: usize = 0;
    while (depth < 8192) : (depth += 1) {
        switch (dirState(current)) {
            .ltr => return .ltr,
            .rtl => return .rtl,
            .auto => return autoDirectionality(current) orelse .ltr,
            .undefined => {
                // bdi: its auto directionality, or 'ltr'.
                if (isElementNamed(current, "bdi")) return autoDirectionality(current) orelse .ltr;
                // An input in the Telephone state: 'ltr'.
                if (isInput(current)) {
                    var buffer: [16]u8 = undefined;
                    if (std.mem.eql(u8, inputType(current, &buffer), "tel")) return .ltr;
                }
                // Otherwise the parent directionality: a shadow root's host's,
                // an element parent's, or 'ltr'.
                const parent = parentOf(current) orelse return .ltr;
                if (parent.stateAs(interfaces.ShadowRoot.State) != null) {
                    current = (interfaces.ShadowRoot.get_host(parent) catch null) orelse return .ltr;
                    continue;
                }
                if (!isElement(parent)) return .ltr;
                current = parent;
            },
        }
    }
    return .ltr;
}

/// "The auto directionality" of `element` (slots excepted: assigned nodes
/// are not consulted).
fn autoDirectionality(element: *Instance) ?Direction {
    // 1. An auto-directionality form-associated element: from its value.
    if (isAutoDirectionalityFormAssociated(element)) {
        const allocator = element.ctx.allocator;
        var value = (if (isTextArea(element))
            interfaces.HTMLTextAreaElement.get_value(element)
        else
            interfaces.HTMLInputElement.get_value(element)) catch return null;
        defer value.deinit(allocator);
        // 1.1-1.2: the first strong character decides; a value with none
        // that is not empty is 'ltr'.
        if (firstStrongDirection(value.asSlice())) |d| return d;
        if (value.asSlice().len > 0) return .ltr;
        return null;
    }
    // 3. The contained text auto directionality, canExcludeRoot false.
    return containedTextAutoDirectionality(element);
}

/// The direction of the first code point of bidirectional type L, AL or R
/// in `text` (UTF-8), or null when it has none - "the text node
/// directionality" of text with that data.
pub fn firstStrongDirection(text: []const u8) ?Direction {
    var view = std.unicode.Utf8View.init(text) catch return null;
    var it = view.iterator();
    while (it.nextCodepoint()) |cp| {
        switch (unicode_data.lookupBidiClass(cp)) {
            .L => return .ltr,
            .R, .AL => return .rtl,
            else => {},
        }
    }
    return null;
}

/// "The contained text auto directionality" of `element`, canExcludeRoot
/// false: the first Text descendant with a strong character, skipping
/// every subtree rooted at a bdi, script, style or textarea element or an
/// element whose dir attribute is not in the Undefined state.
fn containedTextAutoDirectionality(element: *Instance) ?Direction {
    var node = nextInTree(element, element, false);
    while (node) |n| {
        if (isElement(n)) {
            const skip = isElementNamed(n, "bdi") or isElementNamed(n, "script") or
                isElementNamed(n, "style") or isElementNamed(n, "textarea") or dirState(n) != .undefined;
            node = nextInTree(n, element, skip);
            continue;
        }
        const node_type = interfaces.Node.get_nodeType(n) catch 0;
        if (node_type == interfaces.Node.get_TEXT_NODE()) {
            var data = interfaces.CharacterData.get_data(n) catch runtime.DOMString.initEmpty();
            defer data.deinit(n.ctx.allocator);
            if (firstStrongDirection(data.asSlice())) |d| return d;
        }
        node = nextInTree(n, element, false);
    }
    return null;
}

// ============================================================================
// Text control selections (§ 4.10.20)
// ============================================================================

/// A text control's "selection direction".
pub const SelectionDirection = enum {
    none,
    forward,
    backward,

    pub fn keyword(self: SelectionDirection) []const u8 {
        return switch (self) {
            .none => "none",
            .forward => "forward",
            .backward => "backward",
        };
    }

    /// "If direction is not identical to either "backward" or "forward" ...
    /// set direction to "none"" - identical, so case-sensitive.
    pub fn parse(text: []const u8) SelectionDirection {
        if (std.mem.eql(u8, text, "forward")) return .forward;
        if (std.mem.eql(u8, text, "backward")) return .backward;
        return .none;
    }
};

/// setRangeText()'s SelectionMode.
pub const SelectionMode = enum { select, start, end, preserve };

/// The SelectionMode argument of setRangeText(replacement, start, end,
/// selectionMode): "preserve" when not given.
pub fn selectionModeOf(mode: webidl.Opt(enums.SelectionMode)) SelectionMode {
    if (!mode.was_passed) return .preserve;
    return switch (mode.value) {
        ._select_ => .select,
        ._start_ => .start,
        ._end_ => .end,
        ._preserve_ => .preserve,
    };
}

/// A text control's selection, in UTF-16 code units of its relevant value.
/// A collapsed selection is the text entry cursor position.
pub const TextSelection = struct {
    start: u32 = 0,
    end: u32 = 0,
    direction: SelectionDirection = .none,

    /// The selection as it reads now that the relevant value is `length`
    /// code units long: "whenever the relevant value changes", a start or end
    /// past its end is set to its end. Applied on read, which is the same
    /// for every reader.
    pub fn clamped(self: TextSelection, length: u32) TextSelection {
        return .{ .start = @min(self.start, length), .end = @min(self.end, length), .direction = self.direction };
    }

    /// "Set the selection range" with `start` and `end` (null: 0; an end
    /// past the value, "infinity" included, is its end) and `direction`
    /// (null: not given), over a relevant value `length` code units long.
    /// Returns whether the selection changed, in extent or direction - step
    /// 6, where the caller queues the select event.
    pub fn setRange(self: *TextSelection, start: ?u32, end: ?u32, direction: ?[]const u8, length: u32) bool {
        const before = self.clamped(length);
        // 1-2: null is 0.
        const given_start = @min(start orelse 0, length);
        const given_end = @min(end orelse 0, length);
        // 3: an end at or before the start collapses both to the end.
        if (given_end <= given_start) {
            self.start = given_end;
            self.end = given_end;
        } else {
            self.start = given_start;
            self.end = given_end;
        }
        // 4-5: the direction.
        self.direction = if (direction) |d| SelectionDirection.parse(d) else .none;
        return before.start != self.start or before.end != self.end or before.direction != self.direction;
    }
};

/// The length of `text` (UTF-8) in UTF-16 code units, which is how WebIDL
/// and the selection APIs measure strings.
pub fn utf16Length(text: []const u8) u32 {
    const units = std.unicode.calcUtf16LeLen(text) catch return @intCast(text.len);
    return @intCast(units);
}

/// The byte offset in `text` (UTF-8) of the code point starting at UTF-16
/// offset `units`, or text.len past the end. An offset inside a surrogate
/// pair - half a code point, which UTF-8 cannot hold - rounds down.
pub fn byteOffsetOfUtf16(text: []const u8, units: u32) usize {
    var counted: u32 = 0;
    var i: usize = 0;
    while (i < text.len) {
        const len = std.unicode.utf8ByteSequenceLength(text[i]) catch 1;
        const width: u32 = if (len == 4) 2 else 1;
        if (counted + width > units) return i;
        counted += width;
        i += len;
    }
    return text.len;
}

/// The outcome of setRangeText() steps 3-13 over a relevant value.
pub const RangeTextResult = struct {
    /// The new relevant value, owned by the caller.
    value: []u8,
    selection_start: u32,
    selection_end: u32,
};

/// setRangeText() steps 3-13, given the relevant value `value` (UTF-8), the
/// current selection, `replacement`, the range - null for the one-argument
/// form, which replaces the selection - and the selection mode (null for the
/// one-argument form). IndexSizeError when start is greater than end.
pub fn setRangeText(allocator: std.mem.Allocator, value: []const u8, selection: TextSelection, replacement: []const u8, range: ?[2]u32, mode: ?SelectionMode) !RangeTextResult {
    const length = utf16Length(value);
    const current = selection.clamped(length);
    // 3: the one-argument form replaces the selection.
    var start: u32 = if (range) |r| r[0] else current.start;
    var end: u32 = if (range) |r| r[1] else current.end;
    // 4.
    if (start > end) return error.IndexSizeError;
    // 5-6.
    start = @min(start, length);
    end = @min(end, length);
    // 7-8.
    var selection_start = current.start;
    var selection_end = current.end;
    // 9-10: delete [start, end) and insert the replacement at start.
    const start_byte = byteOffsetOfUtf16(value, start);
    const end_byte = byteOffsetOfUtf16(value, end);
    const new_value = try std.mem.concat(allocator, u8, &.{ value[0..start_byte], replacement, value[end_byte..] });
    // 11-12.
    const new_length = utf16Length(replacement);
    const new_end = start + new_length;
    // 13.
    switch (mode orelse .preserve) {
        .select => {
            selection_start = start;
            selection_end = new_end;
        },
        .start => {
            selection_start = start;
            selection_end = start;
        },
        .end => {
            selection_start = new_end;
            selection_end = new_end;
        },
        .preserve => {
            const old_length: i64 = @as(i64, end) - start;
            const delta: i64 = @as(i64, new_length) - old_length;
            if (selection_start > end) {
                selection_start = @intCast(@max(0, @as(i64, selection_start) + delta));
            } else if (selection_start > start) {
                selection_start = start;
            }
            if (selection_end > end) {
                selection_end = @intCast(@max(0, @as(i64, selection_end) + delta));
            } else if (selection_end > start) {
                selection_end = new_end;
            }
        },
    }
    return .{ .value = new_value, .selection_start = selection_start, .selection_end = selection_end };
}

// ============================================================================
// The select event (§ 4.10.20 "set the selection range" step 6)
// ============================================================================

/// Where an element keeps its count of select tasks still queued. Asked
/// again each time: a table the count lives in can move.
pub const PendingSelectTasks = *const fn (element: *Instance) ?*u32;

/// A queued select event task.
const SelectTask = struct {
    element: *Instance,
    generation: u64,
    pending: PendingSelectTasks,
    allocator: std.mem.Allocator,

    fn run(data: ?*anyopaque) void {
        const self: *SelectTask = @ptrCast(@alignCast(data orelse return));
        defer self.finish();
        if (runtime.SlabAllocator.generationOf(self.element) != self.generation) return;
        // A realm retired by a navigation runs none of its tasks.
        if (self.element.ctx.engine_ctx == null) return;
        // A task runs from the event loop, in no realm: it runs in the
        // element's.
        engine.runTaskInRealm(self.element.ctx, steps, self) catch |err| {
            log.warn("select event task not run: {}", .{err});
        };
    }

    /// `Task.drop`: the loop is ending with the task still queued.
    fn drop(data: ?*anyopaque) void {
        const self: *SelectTask = @ptrCast(@alignCast(data orelse return));
        self.finish();
    }

    /// Fire an event named select at the element, with the bubbles attribute
    /// initialized to true.
    fn steps(data: ?*anyopaque) void {
        const self: *SelectTask = @ptrCast(@alignCast(data orelse return));
        fireSimpleEvent(self.element, "select", .{ .bubbles = true }) catch |err| {
            log.warn("select not fired: {}", .{err});
        };
    }

    /// The task has left the queue, run or not: the element needs keeping
    /// only while another select task waits.
    fn finish(self: *SelectTask) void {
        if (runtime.SlabAllocator.generationOf(self.element) == self.generation) {
            if (self.pending(self.element)) |count| {
                if (count.* > 0) count.* -= 1;
                if (count.* == 0) engine.releasePlatformObject(self.element);
            }
        }
        self.allocator.destroy(self);
    }
};

/// "Queue an element task on the user interaction task source given the
/// element to fire an event named select at the element, with the bubbles
/// attribute initialized to true." The queued task keeps the element alive,
/// as a browser's does: a detached control whose selection changed still
/// fires select at its onselect.
pub fn queueSelectEvent(element: *Instance, pending: PendingSelectTasks) void {
    const loop = element.ctx.getOptionalEventLoop() orelse {
        log.warn("select event not queued: the element's realm has no event loop", .{});
        return;
    };
    const count = pending(element) orelse return;
    const allocator = element.ctx.allocator;
    const task = allocator.create(SelectTask) catch |err| {
        log.warn("select event not queued: {}", .{err});
        return;
    };
    task.* = .{
        .element = element,
        .generation = runtime.SlabAllocator.generationOf(element),
        .pending = pending,
        .allocator = allocator,
    };
    // The hold is a flag, not a count: taken for the first waiting task and
    // ended with the last.
    if (count.* == 0) engine.keepPlatformObjectAlive(element);
    count.* += 1;
    loop.queueTask(.{ .callback = &SelectTask.run, .context = task, .drop = &SelectTask.drop });
}

/// DOM "fire an event" named `event_type` at `target`: a trusted Event with
/// `init`, made in the target's realm.
pub fn fireSimpleEvent(target: *Instance, comptime event_type: []const u8, init: dictionaries.EventInit) !void {
    const event = try interfaces.Event.call_constructor(
        target.ctx,
        runtime.DOMString.initInterned(event_type),
        webidl.Opt(dictionaries.EventInit).passed(init),
    );
    // A listener can keep the event; only one nothing wrapped is freed here.
    const generation = runtime.SlabAllocator.generationOf(event);
    defer event.releaseIfUnwrapped(generation);
    _ = try @import("dom").fire_event.dispatchTrusted(target, event);
}

// ============================================================================
// labels (§ 4.10.18 "labels")
// ============================================================================

/// A new NodeList of `element`'s labels, in tree order.
///
/// Stated deviation: the spec's list is live and the same object on every
/// read; this one is a snapshot made on each read, as Blink's was before its
/// LabelsNodeList.
pub fn labelsNodeList(element: *Instance) !*Instance {
    const allocator = element.ctx.allocator;
    const labels = try labelsOf(allocator, element);
    defer allocator.free(labels);
    const list = try interfaces.NodeList.init(allocator, element.ctx);
    errdefer list.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(list));
    try @import("dom").node_lists.setStatic(list, labels);
    return list;
}
