//! HTML 3.2.7: the innerText and outerText properties.
//! Spec: https://html.spec.whatwg.org/multipage/dom.html#the-innertext-and-outertext-properties

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const infra = @import("infra");
const interfaces = @import("interfaces");
const dom = @import("dom");
const NodeBase = dom.NodeBase;
const css = dom.style.css;
const Keyword = css.style_values.Keyword;
const Display = css.style_values.Display;
const TextTransform = css.style_values.TextTransform;

/// HTML "get the text steps". The traversal and its scratch storage exist
/// only during this call; ordinary DOM mutation pays no innerText cost.
pub fn getText(element: *runtime.Instance) !runtime.DOMString {
    const node = dom.instance_bridge.getNodeBase(element) orelse return .empty;
    // Step 1. display:contents uses collection too: all three browsers do
    // this (WHATWG/html#1837), even though the element has no box of its own.
    if (!try rootParticipates(element, node)) return (try interfaces.Node.get_textContent(element)) orelse .empty;
    var collector = Collector{ .allocator = element.ctx.allocator };
    defer collector.deinit();
    try collector.collect(node);
    try collector.transformText();
    // Steps 4-7: ignore empty text, collapse adjacent required counts by
    // maximum, and discard only leading/trailing *required* line breaks.
    var result = TextResult{ .allocator = element.ctx.allocator };
    defer result.deinit();
    for (collector.tokens.items) |token| switch (token) {
        .nothing => {},
        .required => |boundary| result.requireBreaks(boundary.count),
        .literal => |byte| try result.literal(byte),
        .open_atomic => try result.openAtomic(),
        .close_atomic => result.closeAtomic(),
        .context_break => result.lineBoundary(),
        .text => |text| try result.textRun(text.bytes, text.whitespace, text.visible),
    };
    return .initOwned(try result.bytes.toOwnedSlice(result.allocator));
}

/// The rendered-text collection algorithm with optional DOM Range bounds.
/// Selection stringification uses rendered text, not Range's raw descendant
/// text. Blink DomSelection::toString -> TextIterator::HandleTextNodeInRange
/// applies the offsets to rendered runs; CSS collapsing and casing still see
/// the original surrounding text. No range metadata is allocated by innerText.
pub fn getRenderedText(common: *runtime.Instance, bounds: ?dom.range_boundaries.Boundaries) !runtime.DOMString {
    const selected = bounds orelse return getText(common);
    if (selected.start_container == selected.end_container and selected.start_offset == selected.end_offset) return .empty;
    const range = TextRange.from(selected) orelse return .empty;
    const context = try selectionContext(common) orelse return .empty;
    const element = instanceOf(context.style_node) orelse return .empty;
    if (!try rootParticipates(element, context.style_node)) return .empty;
    var collector = Collector{ .allocator = common.ctx.allocator, .range = range };
    defer collector.deinit();
    if (context.node == context.style_node) {
        try collector.enter(context.node, null, true);
    } else {
        const style = (try Style.read(element, true)) orelse return .empty;
        try collector.frames.append(collector.allocator, .{
            .node = context.node,
            .style = style,
            .next_child = if (style.skips_contents) null else context.node.first_child,
            .language = ownLanguage(element) orelse inheritedLanguage(context.style_node),
            .used_user_select = usedUserSelect(element, style.user_select, try inheritedUserSelect(context.style_node)),
        });
    }
    try collector.collectFrames(true);
    try collector.transformTextForRange(true);
    var result = TextResult{ .allocator = common.ctx.allocator };
    defer result.deinit();
    for (collector.tokens.items, collector.spans.items) |token, span| switch (token) {
        .nothing => {},
        .required => |boundary| if (span.empty()) result.lineBoundary() else result.requireBreaks(boundary.count),
        .literal => |byte| if (span.empty()) result.lineBoundary() else try result.literal(byte),
        .open_atomic => try result.openAtomic(),
        .close_atomic => result.closeAtomic(),
        .context_break => result.lineBoundary(),
        .text => |text| try renderBoundedText(&result, text, span),
    };
    return .initOwned(try result.bytes.toOwnedSlice(result.allocator));
}

const TextSpan = struct {
    start: usize = 0,
    end: usize = std.math.maxInt(usize),

    fn empty(self: TextSpan) bool {
        return self.start == self.end;
    }
};

const TextRange = struct {
    start: *NodeBase,
    start_offset: u32,
    end: *NodeBase,
    end_offset: u32,

    fn from(bounds: dom.range_boundaries.Boundaries) ?TextRange {
        return .{
            .start = dom.instance_bridge.getNodeBase(bounds.start_container) orelse return null,
            .start_offset = bounds.start_offset,
            .end = dom.instance_bridge.getNodeBase(bounds.end_container) orelse return null,
            .end_offset = bounds.end_offset,
        };
    }

    fn textSpan(self: TextRange, node: *NodeBase, data: []const u8) TextSpan {
        const length: u32 = @intCast(infra.wtf8.codeUnitLength(data));
        if (dom.boundary_points.position(TextTree, self.end, self.end_offset, node, 0) != .after or
            dom.boundary_points.position(TextTree, self.start, self.start_offset, node, length) != .before) return .{ .end = 0 };
        return .{
            .start = if (self.start == node) @min(self.start_offset, length) else 0,
            .end = if (self.end == node) @min(self.end_offset, length) else length,
        };
    }

    fn boundarySpan(self: TextRange, node: *NodeBase, after: bool) TextSpan {
        const parent = node.parent_node orelse return .{ .end = 0 };
        const offset = TextTree.index(node) + @as(u32, @intFromBool(after));
        const starts = dom.boundary_points.position(TextTree, self.start, self.start_offset, parent, offset);
        const ends = dom.boundary_points.position(TextTree, parent, offset, self.end, self.end_offset);
        return if (starts != .after and ends == .before) .{} else .{ .end = 0 };
    }
};

const TextTree = struct {
    pub const Node = *NodeBase;
    pub fn parent(node: Node) ?Node {
        return node.parent_node;
    }
    pub fn index(node: Node) u32 {
        var count: u32 = 0;
        var previous = node.previous_sibling;
        while (previous) |sibling| : (previous = sibling.previous_sibling) count += 1;
        return count;
    }
};

/// An inline common ancestor needs its surrounding block's text context.
/// A Document or ShadowRoot supplies children, with its element/host style.
fn selectionContext(common: *runtime.Instance) !?struct { node: *NodeBase, style_node: *NodeBase } {
    var node = dom.instance_bridge.getNodeBase(common) orelse return null;
    while (true) {
        if (node.node_type == NodeBase.ELEMENT_NODE) {
            const element = instanceOf(node) orelse return null;
            const style = (try Style.read(element, false)) orelse return null;
            if (style.display.box == .none or style.display.isBlockLevel() or node.parent_node == null)
                return .{ .node = node, .style_node = node };
        } else if (node.node_type == NodeBase.DOCUMENT_NODE) {
            var child = node.first_child;
            while (child) |element| : (child = element.next_sibling) {
                if (element.node_type == NodeBase.ELEMENT_NODE) return .{ .node = node, .style_node = element };
            }
            return null;
        } else if (node.node_type == NodeBase.DOCUMENT_FRAGMENT_NODE) {
            const root = instanceOf(node) orelse return null;
            if (root.stateAs(interfaces.ShadowRoot.State) == null) return null;
            const host = try interfaces.ShadowRoot.get_host(root);
            return .{ .node = node, .style_node = dom.instance_bridge.getNodeBase(host) orelse return null };
        }
        node = node.parent_node orelse return null;
    }
}

fn renderBoundedText(result: *TextResult, text: @FieldType(Token, "text"), span: TextSpan) !void {
    const start = infra.wtf8.positionOfCodeUnit(text.bytes, span.start);
    const end = infra.wtf8.positionOfCodeUnit(text.bytes, span.end);
    var pieces: infra.wtf8.Pieces = .{};
    pieces.substring(text.bytes, .{ .byte = 0 }, start);
    for (pieces.items[0..pieces.count]) |part| try result.textRun(part, text.whitespace, false);
    pieces.substring(text.bytes, start, end);
    for (pieces.items[0..pieces.count]) |part| try result.textRun(part, text.whitespace, text.visible);
    pieces.substring(text.bytes, end, .{ .byte = text.bytes.len });
    for (pieces.items[0..pieces.count]) |part| try result.textRun(part, text.whitespace, false);
}

const html_namespace = "http://www.w3.org/1999/xhtml";
const svg_namespace = "http://www.w3.org/2000/svg";

fn instanceOf(node: *NodeBase) ?*runtime.Instance {
    return dom.instance_bridge.getInstanceTyped(runtime.Instance, node);
}

fn isHtml(element: *runtime.Instance, name: []const u8) bool {
    const names = dom.node_creation.elementNames(element) orelse return false;
    return std.mem.eql(u8, names.namespace orelse "", html_namespace) and std.mem.eql(u8, names.local_name, name);
}

fn hasAttribute(element: *runtime.Instance, name: []const u8) bool {
    const data = dom.element_data.of(element) orelse return false;
    return dom.element_data.hasAttribute(data, name);
}

fn parentElement(node: *NodeBase) ?*NodeBase {
    if (dom.slot_helpers.slottable(node)) |slottable| {
        if (slottable.state.assignedSlot()) |slot| return slot;
    }
    const parent = node.parent_node orelse return null;
    if (parent.node_type == NodeBase.ELEMENT_NODE) return parent;
    if (parent.node_type != NodeBase.DOCUMENT_FRAGMENT_NODE) return null;
    const instance = instanceOf(parent) orelse return null;
    if (instance.vtable != &interfaces.ShadowRoot.vtable) return null;
    const host = interfaces.ShadowRoot.get_host(instance) catch return null;
    return dom.instance_bridge.getNodeBase(host);
}

/// CSS UI 4 section 6.1's editable element is an editing host or a mutable
/// textual form control, rather than every descendant inheriting editability.
fn editableElement(element: *runtime.Instance) bool {
    if (isHtml(element, "input") or isHtml(element, "textarea"))
        return dom.html_pseudo_classes.matches(element, .read_write);
    if (element.stateAs(interfaces.HTMLElement.State) == null) return false;
    if (dom.element_data.of(element)) |data| {
        if (dom.element_data.hasAttribute(data, "contenteditable")) {
            const value = dom.element_data.getAttributeValue(data, "contenteditable", null);
            if (value.len == 0 or std.ascii.eqlIgnoreCase(value, "true") or
                std.ascii.eqlIgnoreCase(value, "plaintext-only")) return true;
        }
    }
    const node = dom.instance_bridge.getNodeBase(element) orelse return false;
    const parent = node.parent_node orelse return false;
    if (parent.node_type != NodeBase.DOCUMENT_NODE) return false;
    const document = instanceOf(parent) orelse return false;
    var mode = interfaces.Document.get_designMode(document) catch return false;
    defer mode.deinit(document.ctx.allocator);
    return std.mem.eql(u8, mode.asSlice(), "on");
}

fn usedUserSelect(element: *runtime.Instance, specified: Keyword, parent: Keyword) Keyword {
    // Used-value exceptions 1-2; contain/all constrain interactive selection
    // but do not expand an explicit script-created Range (row 118 Q11).
    if (editableElement(element)) return .contain;
    if (specified != .auto) return specified;
    return if (parent == .none or parent == .all) parent else .text;
}

/// The starting frame can be below an unvisited none/all ancestor, and a
/// slotted node's inheritance parent can differ from its DOM traversal parent.
fn inheritedUserSelect(node: *NodeBase) !Keyword {
    var ancestor = parentElement(node);
    while (ancestor) |parent| : (ancestor = parentElement(parent)) {
        const element = instanceOf(parent) orelse return .text;
        if (editableElement(element)) return .text; // contain is not inherited
        const style = (try Style.read(element, false)) orelse return .text;
        switch (style.user_select) {
            .auto => {},
            .none, .all => return style.user_select,
            else => return .text,
        }
    }
    return .text;
}

fn firstSummary(details: *NodeBase) ?*NodeBase {
    var child = details.first_child;
    while (child) |node| : (child = node.next_sibling) {
        if (instanceOf(node)) |element| if (isHtml(element, "summary")) return node;
    }
    return null;
}

fn ignoresChildren(element: *runtime.Instance) bool {
    inline for (.{ "input", "textarea", "img", "canvas", "video", "audio", "iframe", "embed", "object" }) |name| {
        if (isHtml(element, name)) return true;
    }
    return false;
}

fn rootParticipates(element: *runtime.Instance, node: *NodeBase) !bool {
    if (!try dom.style.hasComputedStyle(element)) return false;
    const computed = (try dom.style.computedStyle(element, null)) orelse return false;
    const display = computed.display();
    if (display.box == .none) return false;
    // An audio element without controls has no rendered box, even when
    // author CSS sets display:block. Its root getter falls back to textContent.
    if (isHtml(element, "audio") and !hasAttribute(element, "controls")) return false;
    if (display.box == .contents and ignoresChildren(element)) return false;
    if (!try dom.style.engine.isBeingRenderedOrDelegating(element)) return false;
    var child = node;
    var ancestor = parentElement(child);
    while (ancestor) |parent| {
        const e = instanceOf(parent) orelse return false;
        if (ignoresChildren(e)) return false;
        if (isHtml(e, "details") and !hasAttribute(e, "open") and firstSummary(parent) != child) return false;
        // For a contents root, validate the first ancestor that has its own
        // box; isBeingRendered checks the rest of the flat-tree lineage.
        if (display.box == .contents) {
            const s = (try dom.style.computedStyle(e, null)) orelse return false;
            if (s.display().box != .contents and !try dom.style.isBeingRendered(e)) return false;
        }
        child = parent;
        ancestor = parentElement(parent);
    }
    return true;
}

/// Copy values immediately: resolving a volatile descendant style can evict
/// an ancestor's cached ComputedStyle. No borrowed style escapes read().
const Style = struct {
    display: Display,
    visible: bool,
    whitespace: Keyword,
    transform: TextTransform,
    position: Keyword,
    floating: Keyword,
    user_select: Keyword,
    skips_contents: bool,
    selectable: bool,

    fn read(element: *runtime.Instance, comptime bounded: bool) !?Style {
        const style = (try dom.style.computedStyle(element, null)) orelse return null;
        return .{
            .display = style.display(),
            .visible = style.keyword(.visibility) == .visible,
            .whitespace = style.keyword(.white_space_collapse),
            .transform = style.textTransform(),
            .position = style.keyword(.position),
            .floating = style.keyword(.float),
            .user_select = style.keyword(.user_select),
            .skips_contents = dom.style.content_visibility.contentsSkipped(element, style),
            // UI 4 §6.3: only Selection consults inertness. Host inertness
            // cannot be undone by an explicit interactivity:auto child.
            // Copy scalars; no borrowed style survives another style read.
            .selectable = !bounded or (style.keyword(.interactivity) != .inert and
                !@import("focus.zig").isHostInert(element)),
        };
    }
};

const Token = union(enum) {
    nothing,
    required: struct { count: u2, word_boundary: bool = true },
    literal: u8,
    open_atomic,
    close_atomic,
    context_break: bool,
    text: struct {
        bytes: []const u8,
        whitespace: Keyword,
        transform: TextTransform = .{},
        language: []const u8 = "",
        visible: bool = true,
        owned: bool = false,
        start: usize = 0,
        end: usize = 0,
    },
};

const Frame = struct {
    node: *NodeBase,
    style: Style,
    next_child: ?*NodeBase,
    only_child: bool = false,
    language: []const u8 = "",
    breaks: u2 = 0,
    atomic: bool = false,
    context_break: bool = false,
    word_boundary: bool = true,
    text_allowed: bool = true,
    selection: enum { none, select, optgroup } = .none,
    used_user_select: Keyword = .text,
    table: ?usize = null,
    row: ?usize = null,
    last_row_end: ?usize = null,
    last_cell_end: ?usize = null,
    suffix: enum { none, cell, row } = .none,
    suffix_context: usize = 0,
};

const Collector = struct {
    allocator: Allocator,
    tokens: std.ArrayList(Token) = .empty,
    frames: std.ArrayList(Frame) = .empty,
    // Only the bounded specialization fills this parallel array. Keeping
    // it separate preserves the ordinary innerText token size and traversal.
    range: ?TextRange = null,
    spans: std.ArrayList(TextSpan) = .empty,
    current_span: TextSpan = .{},

    fn deinit(self: *Collector) void {
        for (self.tokens.items) |token| {
            if (token == .text and token.text.owned) self.allocator.free(token.text.bytes);
        }
        self.tokens.deinit(self.allocator);
        self.frames.deinit(self.allocator);
        self.spans.deinit(self.allocator);
    }

    fn emit(self: *Collector, token: Token) !void {
        try self.tokens.append(self.allocator, token);
    }

    fn emitForRange(self: *Collector, comptime bounded: bool, token: Token) !void {
        if (bounded) try self.spans.append(self.allocator, self.current_span);
        errdefer if (bounded) {
            _ = self.spans.pop();
        };
        try self.emit(token);
    }

    fn collect(self: *Collector, root: *NodeBase) !void {
        try self.enter(root, null, false);
        try self.collectFrames(false);
    }

    fn collectFrames(self: *Collector, comptime bounded: bool) !void {
        while (self.frames.items.len > 0) {
            const index = self.frames.items.len - 1;
            if (self.frames.items[index].next_child) |child| {
                self.frames.items[index].next_child = if (self.frames.items[index].only_child) null else child.next_sibling;
                // HTML collection uses DOM children, never shadow-tree
                // expansion. Unassigned light children produce no text box.
                var assigned_text_style: ?Style = null;
                var assigned_user_select: ?Keyword = null;
                if (self.frames.items[index].node.is_shadow_host) {
                    const slottable = dom.slot_helpers.slottable(child) orelse continue;
                    const slot = slottable.state.assignedSlot() orelse continue;
                    const slot_element = instanceOf(slot) orelse continue;
                    // A slot hidden by display:none (including an ancestor)
                    // produces no boxes for either assigned Text or elements.
                    if (!try rootParticipates(slot_element, slot)) continue;
                    if (child.node_type == NodeBase.TEXT_NODE) {
                        // CSS Shadow 1 §4.1: Text inherits from its assigned
                        // slot. This resolves the visited Text's inheritance
                        // parent; it does not collect the shadow tree.
                        assigned_text_style = (try Style.read(slot_element, bounded)) orelse continue;
                        if (assigned_text_style.?.skips_contents) continue;
                        if (bounded) assigned_user_select = usedUserSelect(slot_element, assigned_text_style.?.user_select, try inheritedUserSelect(slot));
                    }
                }
                if (child.node_type == NodeBase.TEXT_NODE or child.node_type == NodeBase.CDATA_SECTION_NODE) {
                    const frame = self.frames.items[index];
                    if (!frame.text_allowed or frame.selection != .none) continue;
                    const text_node = instanceOf(child) orelse continue;
                    const data = dom.character_data.dataOf(text_node) orelse continue;
                    const text_style = assigned_text_style orelse frame.style;
                    // CSS Tables suppresses whitespace-only anonymous table
                    // children, including when white-space is preserved.
                    if (tableContainer(text_style.display) and allCssWhitespace(data)) continue;
                    if (bounded) self.current_span = self.range.?.textSpan(child, data);
                    try self.emitForRange(bounded, .{
                        .text = .{
                            .bytes = data,
                            .whitespace = text_style.whitespace,
                            .transform = text_style.transform,
                            .language = frame.language,
                            // Keep CSS whitespace context while omitting the
                            // unselectable run, as Blink's TextIterator does.
                            .visible = text_style.visible and (!bounded or (text_style.selectable and
                                (assigned_user_select orelse frame.used_user_select) != .none)),
                        },
                    });
                } else if (child.node_type == NodeBase.ELEMENT_NODE) {
                    try self.enter(child, index, bounded);
                }
            } else {
                const frame = self.frames.items[index];
                if (bounded) self.current_span = self.range.?.boundarySpan(frame.node, true);
                if (frame.suffix != .none) {
                    const marker = self.tokens.items.len;
                    const visible = frame.style.visible and (!bounded or (frame.style.selectable and frame.used_user_select != .none));
                    if (visible) try self.emitForRange(bounded, .nothing);
                    const value: ?usize = if (visible) marker else null;
                    switch (frame.suffix) {
                        .cell => self.frames.items[frame.suffix_context].last_cell_end = value,
                        .row => self.frames.items[frame.suffix_context].last_row_end = value,
                        .none => unreachable,
                    }
                }
                if (frame.atomic) try self.emitForRange(bounded, .close_atomic);
                if (frame.breaks > 0) try self.emitForRange(bounded, .{ .required = .{ .count = frame.breaks, .word_boundary = frame.word_boundary } });
                if (frame.context_break) try self.emitForRange(bounded, .{ .context_break = frame.word_boundary });
                _ = self.frames.pop();
            }
        }
    }

    fn enter(self: *Collector, node: *NodeBase, parent_index: ?usize, comptime bounded: bool) !void {
        const element = instanceOf(node) orelse return;
        const style = (try Style.read(element, bounded)) orelse return;
        // Steps 1-3: a display:none subtree has no rendered descendants.
        if (style.display.box == .none) return;
        if (isHtml(element, "audio") and !hasAttribute(element, "controls")) return;
        if (bounded) self.current_span = self.range.?.boundarySpan(node, false);
        const parent: ?Frame = if (parent_index) |index| self.frames.items[index] else null;
        const names = dom.node_creation.elementNames(element) orelse return;
        const is_svg = std.mem.eql(u8, names.namespace orelse "", svg_namespace);
        var frame = Frame{ .node = node, .style = style, .next_child = node.first_child };
        if (bounded) {
            const inherited = if (parent != null and parentElement(node) == parent.?.node)
                parent.?.used_user_select
            else
                try inheritedUserSelect(node);
            frame.used_user_select = usedUserSelect(element, style.user_select, inherited);
        }
        // CSS Text 4 §2.1.1: out-of-flow boundaries do not split words,
        // even though HTML emits required line breaks around their boxes.
        // WebKit previousCharacter and Gecko CanTextCrossFrameBoundary
        // include floats here (browser majority; no newer spec, Q13).
        const flex_or_grid_item = if (parent) |p| p.style.display.box == .normal and
            (p.style.display.inner == .flex or p.style.display.inner == .grid) else false;
        frame.word_boundary = style.position != .absolute and style.position != .fixed and
            (style.floating == .none or flex_or_grid_item);
        frame.language = ownLanguage(element) orelse if (parent) |p| p.language else inheritedLanguage(node);
        if (parent) |p| {
            frame.table = p.table;
            frame.row = p.row;
            frame.selection = p.selection;
        }
        frame.text_allowed = !is_svg or std.mem.eql(u8, names.local_name, "text") or
            std.mem.eql(u8, names.local_name, "tspan") or std.mem.eql(u8, names.local_name, "textPath");
        const visible = style.visible and (!bounded or (style.selectable and frame.used_user_select != .none));
        const has_box = visible and style.display.box != .contents;
        const option = isHtml(element, "option");
        // Chrome 151/Safari 27 expose no Selection text for select-owned
        // options in either widget mode; Firefox 158 agrees for size=1.
        // Integrator's 2026-10-22 Q21 probe. This does not affect innerText
        // or Range.toString, nor add Firefox's minority option UA style.
        if (bounded and option and @import("forms/select_picker.zig").ownerSelect(element) != null) return;
        const optgroup = isHtml(element, "optgroup");
        const select = isHtml(element, "select");
        // HTML step 3's synthetic select boxes. Arbitrary wrappers are
        // traversed for option descendants but do not contribute own text.
        if (frame.selection == .optgroup and optgroup) return;
        if (select) frame.selection = .select;
        if (optgroup and frame.selection != .none) frame.selection = .optgroup;
        const selected_wrapper = parent != null and parent.?.selection != .none and !option and !optgroup;
        if (has_box and !selected_wrapper) {
            if (select) {
                // The select's synthetic box is inline, regardless of the
                // widget's actual display mode.
            } else if (option or optgroup) {
                frame.breaks = if (parent_index != null) 1 else 0;
            } else if (parent_index != null) {
                // Steps 8-9. A paragraph's two breaks subsume a block's one.
                if (isHtml(element, "p")) {
                    frame.breaks = 2;
                } else if (style.display.isBlockLevel() or isInternal(style.display, .table_caption)) {
                    frame.breaks = 1;
                }
            }
            if (frame.breaks > 0) try self.emitForRange(bounded, .{ .required = .{ .count = frame.breaks, .word_boundary = frame.word_boundary } });
            // CSS atomic inlines are independent whitespace contexts. Their
            // presence also preserves an outer space on either side, even
            // when the element's own text is empty (e.g. an img).
            frame.atomic = parent_index != null and frame.breaks == 0 and !select and !option and !optgroup and
                (ignoresChildren(element) or (style.display.box == .normal and style.display.outer == .inline_ and style.display.inner != .flow and style.display.inner != .ruby));
            if (frame.atomic) try self.emitForRange(bounded, .open_atomic);
        }
        // A hidden box still participates in CSS text processing, even
        // though HTML collection contributes none of its own strings or
        // required breaks. Its visible descendants remain collectible.
        if (!visible and style.display.box != .contents and !selected_wrapper and !select and parent_index != null) {
            frame.context_break = style.display.isBlockLevel() or isInternal(style.display, .table_caption) or option or optgroup;
            if (frame.context_break) try self.emitForRange(bounded, .{ .context_break = frame.word_boundary });
            frame.atomic = !frame.context_break and (ignoresChildren(element) or
                (style.display.box == .normal and style.display.outer == .inline_ and style.display.inner != .flow and style.display.inner != .ruby));
            if (frame.atomic) try self.emitForRange(bounded, .open_atomic);
        }
        if (style.display.box == .normal and style.display.inner == .table) {
            frame.table = self.frames.items.len;
            frame.row = null;
        }
        if (isInternal(style.display, .table_row)) {
            if (parent_index) |pi| {
                const context = frame.table orelse pi;
                if (self.frames.items[context].last_row_end) |marker| self.tokens.items[marker] = .{ .literal = '\n' };
                self.frames.items[context].last_row_end = null;
                frame.suffix = .row;
                frame.suffix_context = context;
            }
            frame.row = self.frames.items.len;
        }
        if (isInternal(style.display, .table_cell)) {
            if (parent_index) |pi| {
                const context = frame.row orelse frame.table orelse pi;
                if (self.frames.items[context].last_cell_end) |marker| self.tokens.items[marker] = .{ .literal = '\t' };
                self.frames.items[context].last_cell_end = null;
                frame.suffix = .cell;
                frame.suffix_context = context;
            }
            // A cell starts a new text line even though its separator is a tab.
            if (!frame.atomic) {
                frame.atomic = true;
                try self.emitForRange(bounded, .open_atomic);
            }
        }
        if (style.skips_contents) {
            // CSS Contain 2 section 4: its own box remains; none of its
            // skipped descendants contributes rendered text.
            frame.next_child = null;
        } else if (has_box and option) {
            // Blink/WebKit's longstanding option-text mechanism (HTML#3797):
            // the label attribute is ignored, nested blocks add no breaks.
            if (bounded) {
                // Preserve DOM positions while collecting the option's
                // HTML-aware descendant text; the getter has already lost
                // that provenance after stripping/collapsing its whitespace.
                try self.collectOptionText(node);
            } else {
                var text = try interfaces.HTMLOptionElement.get_text(element);
                // The getter allocates in this option's context, which can
                // differ from the collector's context after adoption.
                defer text.deinit(element.ctx.allocator);
                const owned = try self.allocator.dupe(u8, text.asSlice());
                errdefer self.allocator.free(owned);
                try self.emitForRange(false, .{ .text = .{ .bytes = owned, .whitespace = .preserve, .owned = true } });
            }
            frame.next_child = null;
        } else if (ignoresChildren(element) or isHtml(element, "br")) {
            frame.next_child = null;
            // Step 5 applies to descendants only: a br root returns empty.
            if (parent_index != null and isHtml(element, "br") and style.display.box != .contents) {
                if (has_box) try self.emitForRange(bounded, .{ .literal = '\n' }) else try self.emitForRange(bounded, .{ .context_break = true });
            }
        } else if (isHtml(element, "details") and !hasAttribute(element, "open")) {
            // Closed details has only its first summary's rendered subtree.
            // Mark that one child below; sibling iteration stops after it.
            frame.next_child = firstSummary(node);
            frame.only_child = true;
        }
        try self.frames.append(self.allocator, frame);
    }

    fn collectOptionText(self: *Collector, root: *NodeBase) !void {
        // HTML get-HTML-aware-text-content steps 2-3, retaining the source
        // node of each run so partial ranges can use UTF-16 DOM offsets.
        // The shared TextResult performs stripping/collapsing. Form feed is
        // ASCII whitespace here although CSS Text ordinarily preserves it.
        var current = root.first_child;
        while (current) |node| {
            var skip_children = false;
            if (instanceOf(node)) |instance| {
                if (node.node_type == NodeBase.TEXT_NODE or node.node_type == NodeBase.CDATA_SECTION_NODE) {
                    if (dom.character_data.dataOf(instance)) |data| {
                        self.current_span = self.range.?.textSpan(node, data);
                        const owned = std.mem.indexOfScalar(u8, data, 0x0c) != null;
                        const bytes = if (owned) try self.allocator.dupe(u8, data) else data;
                        errdefer if (owned) self.allocator.free(bytes);
                        if (owned) for (@constCast(bytes)) |*byte| {
                            if (byte.* == 0x0c) byte.* = ' ';
                        };
                        // Q21 probe: a body option gives C151="", F158="c",
                        // S27="abcd". With no majority, UI 4 §6.1's used
                        // user-select rule decides: "acd", restoring text
                        // explicitly selected inside a none descendant.
                        const selectable = selection_allowed: {
                            const parent_node = parentElement(node) orelse break :selection_allowed false;
                            const parent_element = instanceOf(parent_node) orelse break :selection_allowed false;
                            const parent_style = (try Style.read(parent_element, true)) orelse break :selection_allowed false;
                            const inherited = if (parent_style.user_select == .auto) try inheritedUserSelect(parent_node) else .text;
                            break :selection_allowed parent_style.selectable and usedUserSelect(parent_element, parent_style.user_select, inherited) != .none;
                        };
                        try self.emitForRange(true, .{ .text = .{ .bytes = bytes, .whitespace = .collapse, .owned = owned, .visible = selectable } });
                    }
                } else if (dom.node_creation.elementNames(instance)) |names| {
                    const ns = names.namespace orelse "";
                    skip_children = (std.mem.eql(u8, names.local_name, "script") and
                        (std.mem.eql(u8, ns, html_namespace) or std.mem.eql(u8, ns, svg_namespace))) or isHtml(instance, "img");
                }
            }
            if (!skip_children) if (node.first_child) |child| {
                current = child;
                continue;
            };
            var previous = node;
            while (previous != root and previous.next_sibling == null) previous = previous.parent_node orelse return;
            current = if (previous == root) null else previous.next_sibling;
        }
    }

    fn transformText(self: *Collector) !void {
        return self.transformTextForRange(false);
    }

    fn transformTextForRange(self: *Collector, comptime bounded: bool) !void {
        const needs_transform = for (self.tokens.items) |token| {
            if (token == .text and token.text.visible and transforms(token.text.transform)) break true;
        } else false;
        if (!needs_transform) return;
        // Capitalize word boundaries span inline nodes. Build the original
        // sequence once, retaining each text node's separate casing context.
        var original: std.ArrayList(u21) = .empty;
        defer original.deinit(self.allocator);
        for (self.tokens.items) |*token| switch (token.*) {
            .text => |*text| {
                text.start = original.items.len;
                var codepoints = (try std.unicode.Wtf8View.init(text.bytes)).iterator();
                while (codepoints.nextCodepoint()) |cp| try original.append(self.allocator, cp);
                text.end = original.items.len;
            },
            .required => |boundary| if (boundary.word_boundary) try original.append(self.allocator, '\n'),
            .context_break => |word_boundary| if (word_boundary) try original.append(self.allocator, '\n'),
            .literal => |byte| try original.append(self.allocator, byte),
            else => {},
        };
        for (self.tokens.items, 0..) |*token, token_index| {
            if (token.* != .text or !token.text.visible or !transforms(token.text.transform)) continue;
            const text = &token.text;
            var mapped: std.ArrayList(u8) = .empty;
            defer mapped.deinit(self.allocator);
            var source_units: usize = 0;
            var mapped_units: usize = 0;
            var mapped_start: ?usize = null;
            var mapped_end: ?usize = null;
            for (text.start..text.end) |index| {
                const cp = original.items[index];
                const previous_mapped = mapped_units;
                const mode: ?infra.unicode_case.CaseMode = switch (text.transform.case) {
                    .uppercase => .upper,
                    .lowercase => .lower,
                    .capitalize => if (shouldCapitalize(original.items, index, text.language)) .title else null,
                    .none => null,
                };
                // Browser majority, no newer spec: Blink LayoutText::
                // TransformAndSecureText -> ComputedStyle::ApplyTextTransform
                // and WebKit RenderText.cpp applyTextTransform case-map each
                // original Text separately. Only capitalize's word boundary
                // sees preceding inline text (WHATWG/CSS Text, ruling Q8).
                const mapping = if (mode) |m| infra.unicode_case.map(original.items[text.start..text.end], index - text.start, m, text.language) else infra.unicode_case.Mapping.identity(cp);
                for (mapping.points[0..mapping.len]) |cased| {
                    // CSS Text 4 2.1: the case transformation first, then
                    // full-width, then full-size-kana. Stated: math-auto
                    // (MathML Core 4.2) maps nothing here.
                    var point = cased;
                    // full-width maps the space that survives collapsing
                    // (css-text text-transform-fullwidth-006), and these
                    // tokens are not collapsed yet: collapsible white space
                    // is left as it is. Stated: so the surviving space stays
                    // U+0020, where Chrome and Safari give U+3000.
                    if (text.transform.full_width and !((text.whitespace == .collapse or text.whitespace == .preserve_breaks) and isAsciiWhitespace(point))) point = infra.unicode_case.fullWidth(point);
                    if (text.transform.full_size_kana) point = css.text_transform.fullSizeKana(point);
                    var encoded: [4]u8 = undefined;
                    const length = try std.unicode.wtf8Encode(point, &encoded);
                    try infra.wtf8.appendJoined(self.allocator, &mapped, encoded[0..length]);
                    if (bounded) mapped_units += if (point > 0xffff) @as(usize, 2) else 1;
                }
                if (bounded) {
                    const source_length: usize = if (cp > 0xffff) 2 else 1;
                    const span = self.spans.items[token_index];
                    if (mapped_start == null) mapped_start = mappedOffset(span.start, source_units, source_length, previous_mapped, mapped_units);
                    if (mapped_end == null) mapped_end = mappedOffset(span.end, source_units, source_length, previous_mapped, mapped_units);
                    source_units += source_length;
                }
            }
            const bytes = try mapped.toOwnedSlice(self.allocator);
            if (text.owned) self.allocator.free(text.bytes);
            text.bytes = bytes;
            text.owned = true;
            if (bounded) self.spans.items[token_index] = .{ .start = mapped_start orelse mapped_units, .end = mapped_end orelse mapped_units };
        }
    }
};

fn mappedOffset(offset: usize, source: usize, length: usize, mapped_from: usize, mapped_to: usize) ?usize {
    if (offset < source or offset >= source + length) return null;
    return mapped_from + @min(offset - source, mapped_to - mapped_from);
}

fn isAsciiWhitespace(cp: u21) bool {
    return cp == ' ' or cp == '\t' or cp == '\n' or cp == '\r' or cp == 0x0C;
}

/// Whether `transform` changes any code point innerText reads.
fn transforms(transform: TextTransform) bool {
    return transform.case != .none or transform.full_width or transform.full_size_kana;
}

/// CSS Text 4 permits a UA-defined word boundary. Letters, numbers, marks,
/// connector punctuation and format characters continue a word; other
/// punctuation separates words. An inline element boundary never does.
fn isWordStart(original: []const u21, index: usize) bool {
    if (!infra.unicode_case.isLetterOrNumber(original[index])) return false;
    // A mark/connector/format prefix can start the word without being its
    // first typographic letter unit. A preceding number does occupy it.
    var before = index;
    while (before > 0) {
        before -= 1;
        const cp = original[before];
        if (!infra.unicode_case.isWordCharacter(cp)) return true;
        if (infra.unicode_case.isLetterOrNumber(cp)) return false;
    }
    return true;
}

fn shouldCapitalize(original: []const u21, index: usize, language: []const u8) bool {
    if (!isWordStart(original, index)) return false;
    // CSS capitalize leaves an already-uppercase initial unchanged (e.g.
    // uppercase DZ must not become the titlecase Dz digraph).
    const upper = infra.unicode_case.map(original, index, .upper, language);
    return upper.len != 1 or upper.points[0] != original[index];
}

fn ownLanguage(element: *runtime.Instance) ?[]const u8 {
    const data = dom.element_data.of(element) orelse return null;
    if (dom.element_data.getAttributeByNamespaceAndLocalName(data, "http://www.w3.org/XML/1998/namespace", "lang")) |attr| return attr.value;
    const names = dom.node_creation.elementNames(element) orelse return null;
    const namespace = names.namespace orelse "";
    if (std.mem.eql(u8, namespace, html_namespace) or std.mem.eql(u8, namespace, svg_namespace)) {
        if (dom.element_data.getAttributeByNamespaceAndLocalName(data, null, "lang")) |attr| return attr.value;
    }
    return null;
}

fn inheritedLanguage(node: *NodeBase) []const u8 {
    // HTML language inherits through parent elements and a shadow root's
    // host, not through CSS's slot-based inheritance parent.
    var current = node.parent_node;
    while (current) |parent| {
        if (instanceOf(parent)) |element| {
            if (ownLanguage(element)) |language| return language;
            if (element.vtable == &interfaces.ShadowRoot.vtable) {
                const host = interfaces.ShadowRoot.get_host(element) catch return "";
                if (ownLanguage(host)) |language| return language;
                current = (dom.instance_bridge.getNodeBase(host) orelse return "").parent_node;
                continue;
            }
        }
        current = parent.parent_node;
    }
    return "";
}

fn isInternal(display: Display, internal: Display.Internal) bool {
    return display.box == .internal and display.internal == internal;
}

fn tableContainer(display: Display) bool {
    return (display.box == .normal and display.inner == .table) or
        isInternal(display, .table_row) or isInternal(display, .table_row_group) or
        isInternal(display, .table_header_group) or isInternal(display, .table_footer_group);
}

fn allCssWhitespace(text: []const u8) bool {
    for (text) |byte| switch (byte) {
        ' ', '\t', '\n', '\r' => {},
        else => return false,
    };
    return true;
}

/// HTML required-break folding plus CSS Text 4 whitespace processing. A
/// collapsible space stays pending until another visible character confirms
/// that it is neither a leading nor a trailing space of its text line.
const TextResult = struct {
    allocator: Allocator,
    bytes: std.ArrayList(u8) = .empty,
    pending_breaks: u2 = 0,
    pending_space: bool = false,
    pending_space_at: usize = 0,
    pending_space_visible: bool = true,
    line_start: bool = true,

    fn deinit(self: *TextResult) void {
        self.bytes.deinit(self.allocator);
    }

    fn requireBreaks(self: *TextResult, count: u2) void {
        self.pending_space = false;
        self.line_start = true;
        if (self.bytes.items.len > 0) self.pending_breaks = @max(self.pending_breaks, count);
    }

    fn flushBreaks(self: *TextResult) !void {
        try self.bytes.appendNTimes(self.allocator, '\n', self.pending_breaks);
        self.pending_breaks = 0;
    }

    fn flushSpace(self: *TextResult) !void {
        if (self.pending_space) {
            if (self.pending_space_visible) {
                const count = self.pending_breaks;
                try self.flushBreaks();
                self.pending_space_at += count;
                try self.bytes.insert(self.allocator, self.pending_space_at, ' ');
            }
            self.pending_space = false;
        }
    }

    fn lineBoundary(self: *TextResult) void {
        self.pending_space = false;
        self.line_start = true;
    }

    fn literal(self: *TextResult, byte: u8) !void {
        self.pending_space = false;
        try self.flushBreaks();
        try self.bytes.append(self.allocator, byte);
        self.line_start = true;
    }

    fn openAtomic(self: *TextResult) !void {
        try self.flushSpace();
        self.line_start = true;
    }

    fn closeAtomic(self: *TextResult) void {
        self.pending_space = false;
        self.line_start = false;
    }

    fn text(self: *TextResult, input: []const u8, whitespace: Keyword) !void {
        try self.textRun(input, whitespace, true);
    }

    fn textRun(self: *TextResult, input: []const u8, whitespace: Keyword, visible: bool) !void {
        var index: usize = 0;
        while (index < input.len) : (index += 1) {
            var byte = input[index];
            if (byte >= 0x80) {
                const length = try std.unicode.utf8ByteSequenceLength(byte);
                if (index + length > input.len) return error.InvalidWtf8;
                const cp = try std.unicode.wtf8Decode(input[index..][0..length]);
                // CSS Text phase I ignores Bidi_Control for whitespace
                // collapsing. Keep its bytes without committing a space.
                if (cp == 0x61c or cp == 0x200e or cp == 0x200f or
                    (cp >= 0x202a and cp <= 0x202e) or (cp >= 0x2066 and cp <= 0x2069))
                {
                    if (visible) {
                        try self.flushBreaks();
                        try self.bytes.appendSlice(self.allocator, input[index..][0..length]);
                    }
                    index += length - 1;
                    continue;
                }
                try self.flushSpace();
                if (visible) {
                    try self.flushBreaks();
                    try infra.wtf8.appendJoined(self.allocator, &self.bytes, input[index..][0..length]);
                }
                self.line_start = false;
                index += length - 1;
                continue;
            }
            // HTML parsing has already normalized source newlines. A CR
            // supplied through the DOM is a space, not a segment break.
            if (byte == '\r') byte = ' ';
            const space = byte == ' ' or byte == '\t' or byte == '\n';
            if (space and whitespace == .discard) continue;
            if (byte == '\n' and (whitespace == .preserve_breaks or whitespace == .preserve or whitespace == .break_spaces)) {
                if (visible) try self.literal('\n') else self.lineBoundary();
            } else if (space and (whitespace == .collapse or whitespace == .preserve_breaks)) {
                if (!self.line_start and !self.pending_space) {
                    self.pending_space = true;
                    self.pending_space_at = self.bytes.items.len;
                    self.pending_space_visible = visible;
                }
            } else {
                try self.flushSpace();
                if (visible) {
                    try self.flushBreaks();
                    if (space and whitespace == .preserve_spaces) byte = ' ';
                    try self.bytes.append(self.allocator, byte);
                }
                self.line_start = byte == '\n';
            }
        }
    }
};

test "inline text shares whitespace state and required breaks fold by maximum" {
    var result = TextResult{ .allocator = std.testing.allocator };
    defer result.deinit();
    result.requireBreaks(2);
    try result.text(" a ", .collapse);
    try result.text(" \tb ", .collapse);
    result.requireBreaks(1);
    result.requireBreaks(2);
    try result.text(" \n ", .collapse);
    result.requireBreaks(1);
    try result.text("c ", .collapse);
    result.requireBreaks(2);
    try std.testing.expectEqualStrings("a b\n\nc", result.bytes.items);
}

test "pre-line newlines trim collapsible spaces but preserved text does not" {
    var result = TextResult{ .allocator = std.testing.allocator };
    defer result.deinit();
    try result.text(" a \n \tb ", .preserve_breaks);
    try result.literal('\n');
    try result.text(" c \n ", .preserve);
    try std.testing.expectEqualStrings("a\nb\n c \n ", result.bytes.items);
}

test "atomic inlines trim their own edges and preserve outside spaces" {
    var result = TextResult{ .allocator = std.testing.allocator };
    defer result.deinit();
    try result.text("a ", .collapse);
    try result.openAtomic();
    try result.text(" b ", .collapse);
    result.closeAtomic();
    try result.text(" c ", .collapse);
    try result.openAtomic();
    result.closeAtomic();
    try result.text(" d", .collapse);
    try std.testing.expectEqualStrings("a b c  d", result.bytes.items);
}

test "text accumulator releases every allocation on failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationFailures, .{});
}

fn allocationFailures(allocator: Allocator) !void {
    var result = TextResult{ .allocator = allocator };
    defer result.deinit();
    try result.text("alpha ", .collapse);
    result.requireBreaks(2);
    try result.text("beta\n", .preserve);
    try result.openAtomic();
    result.closeAtomic();
    try result.text(" gamma", .collapse);
    try std.testing.expectEqualStrings("alpha\n\nbeta\n gamma", result.bytes.items);
}

test "casing stays within each text node and releases every failed allocation" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, transformAllocationFailures, .{});
}

fn transformAllocationFailures(allocator: Allocator) !void {
    var collector = Collector{ .allocator = allocator };
    defer collector.deinit();
    try collector.emit(.{ .text = .{ .bytes = "Ο", .whitespace = .collapse, .transform = .{ .case = .lowercase } } });
    try collector.emit(.{ .text = .{ .bytes = "Σ", .whitespace = .collapse, .transform = .{ .case = .lowercase } } });
    try collector.emit(.{ .literal = '\n' });
    try collector.emit(.{ .text = .{ .bytes = "I", .whitespace = .collapse, .transform = .{ .case = .lowercase }, .language = "lt" } });
    try collector.emit(.{ .text = .{ .bytes = "\u{301}", .whitespace = .collapse, .transform = .{ .case = .lowercase }, .language = "lt" } });
    try collector.transformText();
    try std.testing.expectEqualStrings("ο", collector.tokens.items[0].text.bytes);
    // Blink ApplyTextTransform and WebKit applyTextTransform map the one
    // original Text's string: no final-sigma or More_Above context crosses
    // this boundary. See the citations beside the mapping call (Q8).
    try std.testing.expectEqualStrings("σ", collector.tokens.items[1].text.bytes);
    try std.testing.expectEqualStrings("i", collector.tokens.items[3].text.bytes);
}

test "rendered text joins surrogate pairs split over text nodes" {
    var result = TextResult{ .allocator = std.testing.allocator };
    defer result.deinit();
    try result.text("\xed\xa0\xbd", .collapse);
    try result.text("\xed\xb8\x80", .collapse);
    try std.testing.expectEqualStrings("😀", result.bytes.items);
}

test "CSS whitespace treats DOM CR as space and ignores bidi controls when collapsing" {
    var result = TextResult{ .allocator = std.testing.allocator };
    defer result.deinit();
    try result.text(" a \u{202a} \u{202c} b\r\nc\x0cd", .collapse);
    try std.testing.expectEqualStrings("a \u{202a}\u{202c}b c\x0cd", result.bytes.items);
    var preserved = TextResult{ .allocator = std.testing.allocator };
    defer preserved.deinit();
    try preserved.text("a\r\nb", .preserve);
    try std.testing.expectEqualStrings("a \nb", preserved.bytes.items);
}

test "hidden text affects CSS whitespace while contributing no string" {
    // CSS Text 4 §4.3.1/2, HTML rendered text collection step 2: visibility
    // suppresses returned text, not the box's whitespace context (Q7).
    var result = TextResult{ .allocator = std.testing.allocator };
    defer result.deinit();
    try result.text("a ", .collapse);
    try result.textRun("x", .collapse, false);
    try result.text(" b", .collapse);
    try std.testing.expectEqualStrings("a  b", result.bytes.items);
}

test "hidden inline text affects capitalize but casing context remains per text node" {
    // CSS Text 4 §2.1.1/4.3.1; Blink ApplyTextTransform and WebKit
    // applyTextTransform (Q7/Q8). Native fixture: engine-source evidence.
    var collector = Collector{ .allocator = std.testing.allocator };
    defer collector.deinit();
    try collector.emit(.{ .text = .{ .bytes = "x", .whitespace = .collapse, .visible = false } });
    try collector.emit(.{ .text = .{ .bytes = "abc", .whitespace = .collapse, .transform = .{ .case = .capitalize } } });
    try collector.emit(.{ .literal = '\n' });
    try collector.emit(.{ .text = .{ .bytes = "ΟΣ", .whitespace = .collapse, .transform = .{ .case = .lowercase } } });
    try collector.emit(.{ .text = .{ .bytes = "Α", .whitespace = .collapse, .visible = false } });
    try collector.transformText();
    try std.testing.expectEqualStrings("abc", collector.tokens.items[1].text.bytes);
    try std.testing.expectEqualStrings("ος", collector.tokens.items[3].text.bytes);
}

test "capitalize chooses the first letter or number unit after nonletter word prefixes" {
    // CSS Text 4 §1.4 includes Numbers in typographic letter units; §2.1
    // capitalizes the first such unit of a word, not necessarily its first
    // codepoint. A leading mark is not itself a typographic letter unit.
    var collector = Collector{ .allocator = std.testing.allocator };
    defer collector.deinit();
    try collector.emit(.{ .text = .{
        .bytes = "_foo ⅰord 123abc \u{345}abc",
        .whitespace = .collapse,
        .transform = .{ .case = .capitalize },
    } });
    try collector.transformText();
    try std.testing.expectEqualStrings("_Foo Ⅰord 123abc \u{345}Abc", collector.tokens.items[0].text.bytes);
}

test "required line breaks and hidden box boundaries have separate capitalize context" {
    // HTML's output break count does not determine CSS's word boundary:
    // abspos/float boxes are invisible to word-boundary processing (Q13).
    for ([_]bool{ false, true }) |word_boundary| {
        var collector = Collector{ .allocator = std.testing.allocator };
        defer collector.deinit();
        try collector.emit(.{ .text = .{ .bytes = "p", .whitespace = .collapse, .transform = .{ .case = .capitalize } } });
        try collector.emit(.{ .required = .{ .count = 1, .word_boundary = word_boundary } });
        try collector.emit(.{ .context_break = word_boundary });
        try collector.emit(.{ .text = .{ .bytes = "ass", .whitespace = .collapse, .transform = .{ .case = .capitalize } } });
        try collector.transformText();
        try std.testing.expectEqualStrings(if (word_boundary) "Ass" else "ass", collector.tokens.items[3].text.bytes);
        var result = TextResult{ .allocator = std.testing.allocator };
        defer result.deinit();
        try result.text(collector.tokens.items[0].text.bytes, .collapse);
        result.requireBreaks(collector.tokens.items[1].required.count);
        try result.text(collector.tokens.items[3].text.bytes, .collapse);
        try std.testing.expectEqualStrings(if (word_boundary) "P\nAss" else "P\nass", result.bytes.items);
    }
}

/// HTML "set the inner text steps", inside the IDL setter's CEReactions
/// scope. A detached element uses exactly the same rendered-text fragment.
pub fn setInnerText(element: *runtime.Instance, value: runtime.DOMString) !void {
    const parent = dom.instance_bridge.getNodeBase(element) orelse return error.InvalidStateError;
    const document = (try interfaces.Node.get_ownerDocument(element)) orelse return error.InvalidStateError;
    // Step 1: make the rendered text fragment before changing the element.
    const fragment = try renderedTextFragment(document, value.asSlice());
    defer dom.node_creation.destroyUninserted(fragment);
    const contents = dom.instance_bridge.getNodeBase(fragment) orelse return error.InvalidStateError;
    // Step 2: replace all; do not open a nested IDL reaction scope.
    try dom.mutation.replaceAll(@as(?*NodeBase, contents), parent);
}

/// HTML outerText setter: replace the element and merge only its immediate
/// text neighbors. In particular, this is not Node.normalize().
pub fn setOuterText(element: *runtime.Instance, value: runtime.DOMString) !void {
    const node = dom.instance_bridge.getNodeBase(element) orelse return error.InvalidStateError;
    // Step 1: a parentless element cannot be replaced.
    const parent = node.parent_node orelse return error.NoModificationAllowedError;
    // Keep the parent alive until the complete synchronous replacement ends,
    // including when the removed element supplied the tree's only wrapper.
    dom.refcount.holderRef(parent);
    defer dom.refcount.holderDeref(parent);
    // Steps 2-3: capture the immediate siblings before replacement.
    const next = node.next_sibling;
    const previous = node.previous_sibling;
    const document = (try interfaces.Node.get_ownerDocument(element)) orelse return error.InvalidStateError;
    // Step 4: make the rendered text fragment.
    const fragment = try renderedTextFragment(document, value.asSlice());
    defer dom.node_creation.destroyUninserted(fragment);
    const contents = dom.instance_bridge.getNodeBase(fragment) orelse return error.InvalidStateError;
    // Step 5: unlike innerText, an empty outerText creates an empty Text.
    if (contents.child_nodes.size() == 0) {
        try appendCreated(contents, try interfaces.Document.call_createTextNode(document, .empty));
    }
    // Step 6: replace this within its parent. The generated setter holds the
    // reaction scope through both merges, as WebKit's setOuterText does.
    _ = try dom.mutation.replace(node, contents, parent);
    // Step 7: merge the new last Text with the original next sibling.
    if (next) |following| {
        if (following.previous_sibling) |last| {
            if (last.node_type == NodeBase.TEXT_NODE) try mergeWithNextTextNode(last);
        }
    }
    // Step 8: merge the original previous Text with the new first Text.
    if (previous) |preceding| {
        if (preceding.node_type == NodeBase.TEXT_NODE) try mergeWithNextTextNode(preceding);
    }
}

/// HTML "rendered text fragment", steps 1-5. The caller owns this uninserted
/// fragment and destroys it after moving its children into their destination.
pub fn renderedTextFragment(document: *runtime.Instance, input: []const u8) !*runtime.Instance {
    // Step 1.
    const fragment = try interfaces.Document.call_createDocumentFragment(document);
    errdefer dom.node_creation.destroyUninserted(fragment);
    const parent = dom.instance_bridge.getNodeBase(fragment) orelse return error.InvalidStateError;
    // Steps 2-4: only CR/LF delimit the input; every other code unit survives.
    var position: usize = 0;
    while (position < input.len) {
        const start = position;
        while (position < input.len and input[position] != '\r' and input[position] != '\n') : (position += 1) {}
        // Steps 4.1-4.2: omit empty Text nodes between line breaks.
        if (position > start) {
            try appendCreated(parent, try interfaces.Document.call_createTextNode(document, runtime.DOMString.initInterned(input[start..position])));
        }
        // Step 4.3: CRLF is one break; lone CR and LF are each one break.
        while (position < input.len and (input[position] == '\r' or input[position] == '\n')) {
            if (input[position] == '\r' and position + 1 < input.len and input[position + 1] == '\n') position += 1;
            position += 1;
            const br = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned("br"), .notPassed());
            try appendCreated(parent, br);
        }
    }
    // Step 5.
    return fragment;
}

fn appendCreated(parent: *NodeBase, child: *runtime.Instance) !void {
    const base = dom.instance_bridge.getNodeBase(child) orelse return error.InvalidStateError;
    errdefer if (base.parent_node == null) dom.node_creation.destroyUninserted(child);
    _ = try dom.mutation.append(base, parent);
}

fn mergeWithNextTextNode(node: *NodeBase) !void {
    // HTML "merge with the next text node", steps 1-2.
    const next = node.next_sibling orelse return;
    if (next.node_type != NodeBase.TEXT_NODE) return;
    const instance = dom.instance_bridge.getInstanceTyped(runtime.Instance, node) orelse return error.InvalidStateError;
    const following = dom.instance_bridge.getInstanceTyped(runtime.Instance, next) orelse return error.InvalidStateError;
    const allocator = following.ctx.allocator;
    var data = try interfaces.CharacterData.get_data(following);
    defer data.deinit(allocator);
    // Step 3: appendData runs replace-data at the UTF-16 length, preserving
    // live ranges and mutation records through the CharacterData interface.
    try interfaces.CharacterData.call_appendData(instance, data);
    // Step 4.
    try dom.mutation.remove(next, false);
}

test "full-width and full-size-kana map after the case transformation" {
    // CSS Text 4 2.1: full-width puts a character in its <wide> form (or
    // from its <narrow> form), full-size-kana maps small Kana (Appendix G);
    // the case transformation comes first.
    var collector = Collector{ .allocator = std.testing.allocator };
    defer collector.deinit();
    try collector.emit(.{ .text = .{ .bytes = "ab 1!", .whitespace = .collapse, .transform = .{ .case = .uppercase, .full_width = true } } });
    try collector.emit(.{ .text = .{ .bytes = "ぁゃッｧ", .whitespace = .collapse, .transform = .{ .full_size_kana = true } } });
    try collector.emit(.{ .text = .{ .bytes = "ｧ", .whitespace = .collapse, .transform = .{ .full_width = true, .full_size_kana = true } } });
    try collector.emit(.{ .text = .{ .bytes = "x", .whitespace = .collapse, .transform = .{ .math_auto = true } } });
    try collector.transformText();
    try std.testing.expectEqualStrings("ＡＢ １！", collector.tokens.items[0].text.bytes);
    try std.testing.expectEqualStrings("あやツｱ", collector.tokens.items[1].text.bytes);
    // Half-width small A: full-width gives the full-width small ァ, which
    // full-size-kana then makes full-size ア.
    try std.testing.expectEqualStrings("ア", collector.tokens.items[2].text.bytes);
    try std.testing.expectEqualStrings("x", collector.tokens.items[3].text.bytes);
}

test "bounded rendered text keeps whitespace context and maps expanding case offsets" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, boundedTextAllocationFailures, .{});
}

fn boundedTextAllocationFailures(allocator: Allocator) !void {
    var collector = Collector{ .allocator = allocator };
    defer collector.deinit();
    collector.current_span = .{ .start = 3, .end = 4 };
    try collector.emitForRange(true, .{ .text = .{ .bytes = "one  two", .whitespace = .collapse } });
    collector.current_span = .{};
    try collector.emitForRange(true, .{ .required = .{ .count = 1 } });
    collector.current_span = .{ .start = 4, .end = 5 };
    try collector.emitForRange(true, .{ .text = .{ .bytes = "straßE", .whitespace = .collapse, .transform = .{ .case = .uppercase } } });
    try collector.transformTextForRange(true);
    try std.testing.expectEqual(@as(usize, 4), collector.spans.items[2].start);
    try std.testing.expectEqual(@as(usize, 6), collector.spans.items[2].end);
    var result = TextResult{ .allocator = allocator };
    defer result.deinit();
    try renderBoundedText(&result, collector.tokens.items[0].text, collector.spans.items[0]);
    try std.testing.expectEqualStrings(" ", result.bytes.items);
    result.requireBreaks(1);
    try renderBoundedText(&result, collector.tokens.items[2].text, collector.spans.items[2]);
    try std.testing.expectEqualStrings(" \nSS", result.bytes.items);
}
