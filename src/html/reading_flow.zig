//! CSS Display 4 §4 reading flow, as sequential focus navigation reads it
//! (whatwg/html#10613, "Add support for CSS reading-flow").
//!
//! A reading flow container is a block, flex or grid container whose
//! reading-flow is valid for it and not normal; a reading-flow-ordered scope
//! owner is a reading flow container, or an element with display: contents
//! whose CSS parent box is one; a reading flow item is an element whose
//! parent element is a reading-flow-ordered scope owner. Owners and items
//! are focus navigation scope owners, and an owner's scope is ordered by the
//! "reading flow order" - the container's rendering-defined sibling reading
//! flow - not by tabindex (focus_navigation.zig).
//!
//! Golden rule 2: CSS Display 4 defines reading-flow and reading-order; the
//! HTML side is whatwg/html#10613, open, with implementer bugs open in all
//! three engines (Chromium 40932006, Gecko 1854017, WebKit 285029). Chrome
//! ships it (shadow-dom/focus-navigation/reading-flow/source-order-valid.html:
//! Chrome 157 5/5, Firefox 160 0/5, Safari 27.2 0/5, wpt.fyi runs
//! 4786307730243584, 4877168468033536, 6479119966273536): the newer spec.
//!
//! Without a renderer, the rendering-defined sibling reading flow is the
//! container's box children in their order-modified document order (CSS
//! Display 4 §3.1: `order` for a flex or grid container's items), then
//! stably by reading-order.
//! flex-visual, grid-rows and grid-columns order items by where layout puts
//! them, which only a renderer answers: here they take the order-modified
//! document order (stated; no worklist file reads them).
//!
//! Spec: https://drafts.csswg.org/css-display-4/#reading-flow
//! Spec: https://github.com/whatwg/html/pull/10613

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const css = @import("css");
const dom = @import("dom");

const Instance = runtime.Instance;
const ComputedStyle = css.computed_style.ComputedStyle;

/// `element`'s computed style, HELD: release it (dom.style.HeldStyle).
fn styleOf(element: *Instance) ?dom.style.HeldStyle {
    return dom.style.engine.computedStyle(element, null) catch null;
}

fn isElement(node: *Instance) bool {
    return (interfaces.Node.get_nodeType(node) catch 0) == interfaces.Node.get_ELEMENT_NODE();
}

fn parentElement(node: *Instance) ?*Instance {
    const p = (interfaces.Node.get_parentNode(node) catch null) orelse return null;
    return if (isElement(p)) p else null;
}

/// CSS Display 4 §4: whether `style` makes its element a reading flow
/// container - a block, flex or grid container (Blink LayoutBox::
/// IsReadingFlowContainer: a block flow, a flexible box or a grid) whose
/// reading-flow applies to it and is not normal.
fn isContainerStyle(style: *const ComputedStyle) bool {
    const display = style.display();
    if (display.box != .normal and !(display.box == .internal and display.internal == .table_cell)) return false;
    const flex = display.inner == .flex;
    const grid = display.inner == .grid;
    const block = display.box == .internal or display.inner == .flow_root or (display.inner == .flow and display.outer == .block);
    return switch (style.keyword(.reading_flow)) {
        .source_order => flex or grid or block,
        .flex_visual, .flex_flow => flex,
        .grid_rows, .grid_columns, .grid_order => grid,
        else => false,
    };
}

/// Whether `element` is a reading flow container.
pub fn isContainer(element: *Instance) bool {
    const style_hold = styleOf(element) orelse return false;
    defer style_hold.release();
    const style = style_hold.style;
    return isContainerStyle(style);
}

/// The reading flow container associated with `element`, a
/// reading-flow-ordered scope owner: itself, or - display: contents - its
/// CSS parent box's element. Null when `element` is no such owner.
pub fn containerOf(element: *Instance) ?*Instance {
    var current = element;
    var hops: usize = 0;
    while (hops < 256) : (hops += 1) {
        const style_hold = styleOf(current) orelse return null;
        defer style_hold.release();
        const style = style_hold.style;
        if (style.display().box != .contents) return if (isContainerStyle(style)) current else null;
        // display: contents: the CSS parent box is the nearest ancestor
        // that generates a box.
        current = parentElement(current) orelse return null;
    }
    return null;
}

/// whatwg/html#10613: whether `element` is a reading-flow-ordered scope
/// owner - a reading flow container, or an element delegating its rendering
/// to its children whose CSS parent box is a reading flow container.
pub fn isScopeOwner(element: *Instance) bool {
    return containerOf(element) != null;
}

/// whatwg/html#10613: whether `element` is a reading flow item - its parent
/// element is a reading-flow-ordered scope owner.
pub fn isItem(element: *Instance) bool {
    const parent = parentElement(element) orelse return false;
    return isScopeOwner(parent);
}

const Item = struct { element: *Instance, order: i32, reading_order: i32, index: usize };

/// The box children of `container` in tree order: its element children,
/// those with display: contents replaced by their own box children, those
/// with display: none left out.
fn collectBoxChildren(allocator: Allocator, node: *Instance, out: *std.ArrayList(Item), depth: usize) Allocator.Error!void {
    if (depth > 64) return;
    var child = interfaces.Node.get_firstChild(node) catch null;
    while (child) |c| : (child = interfaces.Node.get_nextSibling(c) catch null) {
        if (!isElement(c)) continue;
        const style_hold = styleOf(c) orelse continue;
        defer style_hold.release();
        const style = style_hold.style;
        switch (style.display().box) {
            .none => continue,
            .contents => try collectBoxChildren(allocator, c, out, depth + 1),
            else => try out.append(allocator, .{
                .element = c,
                .order = integerOf(style, .order),
                .reading_order = integerOf(style, .reading_order),
                .index = out.items.len,
            }),
        }
    }
}

fn integerOf(style: *const ComputedStyle, longhand: css.properties.Longhand) i32 {
    const value = style.get(longhand);
    return if (value == .integer) value.integer else 0;
}

/// CSS Display 4 §4: `container`'s rendering-defined sibling reading flow,
/// as far as no renderer is needed (the module comment).
fn siblingReadingFlow(allocator: Allocator, container: *Instance, out: *std.ArrayList(Item)) Allocator.Error!void {
    try collectBoxChildren(allocator, container, out, 0);
    const style_hold = styleOf(container) orelse return;
    defer style_hold.release();
    const style = style_hold.style;
    const reading_flow = style.keyword(.reading_flow);
    // §3.1: a flex or grid container lays its items out in order-modified
    // document order; source-order follows the document.
    if (reading_flow != .source_order) {
        std.mem.sort(Item, out.items, {}, struct {
            fn lessThan(_: void, a: Item, b: Item) bool {
                if (a.order != b.order) return a.order < b.order;
                return a.index < b.index;
            }
        }.lessThan);
        // flex-flow "follows the flex-flow direction": the order-modified
        // document order, whatever the flex direction (flex-flow.html's
        // row-reverse wrap-reverse case expects D, A, B, C for an `order:
        // -1` D: Chrome 157).
        for (out.items, 0..) |*item, i| item.index = i;
    }
    // §4.1: "Sibling elements are ordered starting from the lowest numbered
    // ordinal group and going up. If the reading order of two items is
    // equivalent, the reading-flow property breaks the tie."
    std.mem.sort(Item, out.items, {}, struct {
        fn lessThan(_: void, a: Item, b: Item) bool {
            if (a.reading_order != b.reading_order) return a.reading_order < b.reading_order;
            return a.index < b.index;
        }
    }.lessThan);
}

/// whatwg/html#10613 "reading flow order" of the reading-flow-ordered focus
/// navigation scope of `owner`, whose scope is its element children: those
/// children in the order of the container's rendering-defined sibling reading
/// flow - each item's first inclusive ancestor in the scope - then the rest of
/// them in tree order. OWNED by the caller.
pub fn readingFlowOrder(allocator: Allocator, owner: *Instance) Allocator.Error![]*Instance {
    var output: std.ArrayList(*Instance) = .empty;
    errdefer output.deinit(allocator);
    // 2-4. owner's reading flow container, and its items.
    const container = containerOf(owner) orelse return output.toOwnedSlice(allocator);
    var items: std.ArrayList(Item) = .empty;
    defer items.deinit(allocator);
    try siblingReadingFlow(allocator, container, &items);
    // 6. For each item: while item is not container, if scope contains item
    // (it is a child element of owner), append it once; else go up.
    for (items.items) |item| {
        var current: ?*Instance = item.element;
        while (current) |node| {
            if (node == container) break;
            const parent = parentElement(node);
            if (parent == owner) {
                if (std.mem.indexOfScalar(*Instance, output.items, node) == null) try output.append(allocator, node);
                break;
            }
            current = parent;
        }
    }
    // 7. Each child of owner in tree order, in scope and not yet in output.
    var child = interfaces.Node.get_firstChild(owner) catch null;
    while (child) |c| : (child = interfaces.Node.get_nextSibling(c) catch null) {
        if (!isElement(c)) continue;
        if (std.mem.indexOfScalar(*Instance, output.items, c) == null) try output.append(allocator, c);
    }
    return output.toOwnedSlice(allocator);
}
