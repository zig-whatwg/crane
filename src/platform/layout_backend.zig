//! Platform Layout Backend Abstraction
//!
//! Spec: https://drafts.csswg.org/cssom-view/
//! CSSOM View Module
//!
//! Provides a pluggable interface for layout engine operations, allowing the DOM
//! to work with different layout implementations (real CSS layout engines, stub
//! backends for testing, etc.).
//!
//! The layout backend is responsible for:
//! - Computing box metrics (offset*, client*, scroll*)
//! - Getting computed styles
//! - Determining rendered text content (for innerText)
//! - Determining element visibility (display: none, etc.)
//!
//! ## Usage
//!
//! ```zig
//! const layout_backend = @import("platform/layout_backend.zig");
//!
//! // Create a stub backend for testing (returns defaults)
//! const stub = try StubLayoutBackend.init(allocator);
//! defer stub.deinit();
//!
//! // Get layout interface
//! const layout = stub.backend();
//!
//! // Use layout methods
//! const width = layout.getOffsetWidth(element);
//! const rect = layout.getBoundingClientRect(element);
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");

/// DOMRect struct for getBoundingClientRect
/// Spec: https://drafts.csswg.org/geometry/#domrect
pub const DOMRect = struct {
    x: f64,
    y: f64,
    width: f64,
    height: f64,

    pub fn init(x: f64, y: f64, width: f64, height: f64) DOMRect {
        return .{
            .x = x,
            .y = y,
            .width = width,
            .height = height,
        };
    }

    pub fn empty() DOMRect {
        return init(0, 0, 0, 0);
    }

    /// Get the top edge (y coordinate)
    pub fn top(self: DOMRect) f64 {
        return self.y;
    }

    /// Get the right edge (x + width)
    pub fn right(self: DOMRect) f64 {
        return self.x + self.width;
    }

    /// Get the bottom edge (y + height)
    pub fn bottom(self: DOMRect) f64 {
        return self.y + self.height;
    }

    /// Get the left edge (x coordinate)
    pub fn left(self: DOMRect) f64 {
        return self.x;
    }
};

/// List of DOMRects for getClientRects
pub const DOMRectList = struct {
    rects: []DOMRect,
    allocator: Allocator,

    pub fn init(allocator: Allocator, rects: []DOMRect) DOMRectList {
        return .{
            .rects = rects,
            .allocator = allocator,
        };
    }

    pub fn empty(allocator: Allocator) DOMRectList {
        return .{
            .rects = &[_]DOMRect{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *DOMRectList) void {
        if (self.rects.len > 0) {
            self.allocator.free(self.rects);
        }
    }

    pub fn length(self: DOMRectList) usize {
        return self.rects.len;
    }

    pub fn item(self: DOMRectList, index: usize) ?DOMRect {
        if (index >= self.rects.len) return null;
        return self.rects[index];
    }
};

/// Abstract layout backend interface.
///
/// This uses a vtable pattern to allow different implementations
/// (real layout engines, stub/mock backends) to be swapped at runtime.
pub const LayoutBackend = struct {
    /// Implementation pointer.
    ptr: *anyopaque,

    /// Virtual function table.
    vtable: *const VTable,

    pub const VTable = struct {
        // === Box Metrics (CSSOM View) ===

        /// Get element's offsetWidth
        /// Spec: https://drafts.csswg.org/cssom-view/#dom-htmlelement-offsetwidth
        getOffsetWidth: *const fn (ptr: *anyopaque, element: *runtime.Instance) f64,

        /// Get element's offsetHeight
        /// Spec: https://drafts.csswg.org/cssom-view/#dom-htmlelement-offsetheight
        getOffsetHeight: *const fn (ptr: *anyopaque, element: *runtime.Instance) f64,

        /// Get element's offsetTop
        /// Spec: https://drafts.csswg.org/cssom-view/#dom-htmlelement-offsettop
        getOffsetTop: *const fn (ptr: *anyopaque, element: *runtime.Instance) f64,

        /// Get element's offsetLeft
        /// Spec: https://drafts.csswg.org/cssom-view/#dom-htmlelement-offsetleft
        getOffsetLeft: *const fn (ptr: *anyopaque, element: *runtime.Instance) f64,

        /// Get element's offsetParent
        /// Spec: https://drafts.csswg.org/cssom-view/#dom-htmlelement-offsetparent
        getOffsetParent: *const fn (ptr: *anyopaque, element: *runtime.Instance) ?*runtime.Instance,

        /// Get element's clientWidth
        /// Spec: https://drafts.csswg.org/cssom-view/#dom-element-clientwidth
        getClientWidth: *const fn (ptr: *anyopaque, element: *runtime.Instance) f64,

        /// Get element's clientHeight
        /// Spec: https://drafts.csswg.org/cssom-view/#dom-element-clientheight
        getClientHeight: *const fn (ptr: *anyopaque, element: *runtime.Instance) f64,

        /// Get element's clientTop
        /// Spec: https://drafts.csswg.org/cssom-view/#dom-element-clienttop
        getClientTop: *const fn (ptr: *anyopaque, element: *runtime.Instance) f64,

        /// Get element's clientLeft
        /// Spec: https://drafts.csswg.org/cssom-view/#dom-element-clientleft
        getClientLeft: *const fn (ptr: *anyopaque, element: *runtime.Instance) f64,

        /// Get element's scrollWidth
        /// Spec: https://drafts.csswg.org/cssom-view/#dom-element-scrollwidth
        getScrollWidth: *const fn (ptr: *anyopaque, element: *runtime.Instance) f64,

        /// Get element's scrollHeight
        /// Spec: https://drafts.csswg.org/cssom-view/#dom-element-scrollheight
        getScrollHeight: *const fn (ptr: *anyopaque, element: *runtime.Instance) f64,

        /// Get element's scrollTop
        /// Spec: https://drafts.csswg.org/cssom-view/#dom-element-scrolltop
        getScrollTop: *const fn (ptr: *anyopaque, element: *runtime.Instance) f64,

        /// Set element's scrollTop
        /// Spec: https://drafts.csswg.org/cssom-view/#dom-element-scrolltop
        setScrollTop: *const fn (ptr: *anyopaque, element: *runtime.Instance, value: f64) void,

        /// Get element's scrollLeft
        /// Spec: https://drafts.csswg.org/cssom-view/#dom-element-scrollleft
        getScrollLeft: *const fn (ptr: *anyopaque, element: *runtime.Instance) f64,

        /// Set element's scrollLeft
        /// Spec: https://drafts.csswg.org/cssom-view/#dom-element-scrollleft
        setScrollLeft: *const fn (ptr: *anyopaque, element: *runtime.Instance, value: f64) void,

        // === Bounding Rectangles ===

        /// Get element's bounding client rect
        /// Spec: https://drafts.csswg.org/cssom-view/#dom-element-getboundingclientrect
        getBoundingClientRect: *const fn (ptr: *anyopaque, element: *runtime.Instance) DOMRect,

        /// Get element's client rects
        /// Spec: https://drafts.csswg.org/cssom-view/#dom-element-getclientrects
        getClientRects: *const fn (ptr: *anyopaque, element: *runtime.Instance, allocator: Allocator) DOMRectList,

        // === Rendered Text (for innerText) ===

        /// Get rendered text content for innerText
        /// Spec: https://html.spec.whatwg.org/multipage/dom.html#the-innertext-idl-attribute
        ///
        /// This requires layout information to:
        /// - Exclude elements with display: none
        /// - Collapse whitespace appropriately
        /// - Insert line breaks for block elements
        getRenderedText: *const fn (ptr: *anyopaque, element: *runtime.Instance, allocator: Allocator) ?[]const u8,

        /// Check if element is rendered (not display: none, etc.)
        isElementRendered: *const fn (ptr: *anyopaque, element: *runtime.Instance) bool,

        // === Selection and Caret ===

        /// Get caret rect at a specific position in a node
        getCaretRectAtPosition: *const fn (ptr: *anyopaque, node: *runtime.Instance, offset: u32) ?DOMRect,

        // === Layout Lifecycle ===

        /// Mark element as needing layout recalculation
        markDirty: *const fn (ptr: *anyopaque, element: *runtime.Instance) void,

        /// Force synchronous layout computation
        forceLayout: *const fn (ptr: *anyopaque) void,

        /// Free backend resources
        deinit: *const fn (ptr: *anyopaque) void,
    };

    // === Convenience Methods ===

    pub fn getOffsetWidth(self: LayoutBackend, element: *runtime.Instance) f64 {
        return self.vtable.getOffsetWidth(self.ptr, element);
    }

    pub fn getOffsetHeight(self: LayoutBackend, element: *runtime.Instance) f64 {
        return self.vtable.getOffsetHeight(self.ptr, element);
    }

    pub fn getOffsetTop(self: LayoutBackend, element: *runtime.Instance) f64 {
        return self.vtable.getOffsetTop(self.ptr, element);
    }

    pub fn getOffsetLeft(self: LayoutBackend, element: *runtime.Instance) f64 {
        return self.vtable.getOffsetLeft(self.ptr, element);
    }

    pub fn getOffsetParent(self: LayoutBackend, element: *runtime.Instance) ?*runtime.Instance {
        return self.vtable.getOffsetParent(self.ptr, element);
    }

    pub fn getClientWidth(self: LayoutBackend, element: *runtime.Instance) f64 {
        return self.vtable.getClientWidth(self.ptr, element);
    }

    pub fn getClientHeight(self: LayoutBackend, element: *runtime.Instance) f64 {
        return self.vtable.getClientHeight(self.ptr, element);
    }

    pub fn getClientTop(self: LayoutBackend, element: *runtime.Instance) f64 {
        return self.vtable.getClientTop(self.ptr, element);
    }

    pub fn getClientLeft(self: LayoutBackend, element: *runtime.Instance) f64 {
        return self.vtable.getClientLeft(self.ptr, element);
    }

    pub fn getScrollWidth(self: LayoutBackend, element: *runtime.Instance) f64 {
        return self.vtable.getScrollWidth(self.ptr, element);
    }

    pub fn getScrollHeight(self: LayoutBackend, element: *runtime.Instance) f64 {
        return self.vtable.getScrollHeight(self.ptr, element);
    }

    pub fn getScrollTop(self: LayoutBackend, element: *runtime.Instance) f64 {
        return self.vtable.getScrollTop(self.ptr, element);
    }

    pub fn setScrollTop(self: LayoutBackend, element: *runtime.Instance, value: f64) void {
        self.vtable.setScrollTop(self.ptr, element, value);
    }

    pub fn getScrollLeft(self: LayoutBackend, element: *runtime.Instance) f64 {
        return self.vtable.getScrollLeft(self.ptr, element);
    }

    pub fn setScrollLeft(self: LayoutBackend, element: *runtime.Instance, value: f64) void {
        self.vtable.setScrollLeft(self.ptr, element, value);
    }

    pub fn getBoundingClientRect(self: LayoutBackend, element: *runtime.Instance) DOMRect {
        return self.vtable.getBoundingClientRect(self.ptr, element);
    }

    pub fn getClientRects(self: LayoutBackend, element: *runtime.Instance, allocator: Allocator) DOMRectList {
        return self.vtable.getClientRects(self.ptr, element, allocator);
    }

    pub fn getRenderedText(self: LayoutBackend, element: *runtime.Instance, allocator: Allocator) ?[]const u8 {
        return self.vtable.getRenderedText(self.ptr, element, allocator);
    }

    pub fn isElementRendered(self: LayoutBackend, element: *runtime.Instance) bool {
        return self.vtable.isElementRendered(self.ptr, element);
    }

    pub fn getCaretRectAtPosition(self: LayoutBackend, node: *runtime.Instance, offset: u32) ?DOMRect {
        return self.vtable.getCaretRectAtPosition(self.ptr, node, offset);
    }

    pub fn markDirty(self: LayoutBackend, element: *runtime.Instance) void {
        self.vtable.markDirty(self.ptr, element);
    }

    pub fn forceLayout(self: LayoutBackend) void {
        self.vtable.forceLayout(self.ptr);
    }

    pub fn deinit(self: LayoutBackend) void {
        self.vtable.deinit(self.ptr);
    }
};

/// Stub layout backend for testing and headless environments.
///
/// Returns sensible defaults for all layout queries:
/// - Box metrics return 0
/// - Bounding rect returns empty rect
/// - All elements are considered rendered
/// - innerText falls back to textContent
///
/// This allows DOM operations to work without a real layout engine,
/// though with reduced accuracy for layout-dependent properties.
pub const StubLayoutBackend = struct {
    allocator: Allocator,

    /// Initialize a new stub layout backend.
    pub fn init(allocator: Allocator) !*StubLayoutBackend {
        const self = try allocator.create(StubLayoutBackend);
        self.* = StubLayoutBackend{
            .allocator = allocator,
        };
        return self;
    }

    /// Create a LayoutBackend interface for this stub.
    pub fn backend(self: *StubLayoutBackend) LayoutBackend {
        return LayoutBackend{
            .ptr = self,
            .vtable = &vtable,
        };
    }

    const vtable = LayoutBackend.VTable{
        .getOffsetWidth = getOffsetWidthImpl,
        .getOffsetHeight = getOffsetHeightImpl,
        .getOffsetTop = getOffsetTopImpl,
        .getOffsetLeft = getOffsetLeftImpl,
        .getOffsetParent = getOffsetParentImpl,
        .getClientWidth = getClientWidthImpl,
        .getClientHeight = getClientHeightImpl,
        .getClientTop = getClientTopImpl,
        .getClientLeft = getClientLeftImpl,
        .getScrollWidth = getScrollWidthImpl,
        .getScrollHeight = getScrollHeightImpl,
        .getScrollTop = getScrollTopImpl,
        .setScrollTop = setScrollTopImpl,
        .getScrollLeft = getScrollLeftImpl,
        .setScrollLeft = setScrollLeftImpl,
        .getBoundingClientRect = getBoundingClientRectImpl,
        .getClientRects = getClientRectsImpl,
        .getRenderedText = getRenderedTextImpl,
        .isElementRendered = isElementRenderedImpl,
        .getCaretRectAtPosition = getCaretRectAtPositionImpl,
        .markDirty = markDirtyImpl,
        .forceLayout = forceLayoutImpl,
        .deinit = deinitImpl,
    };

    // === Stub Implementations ===

    fn getOffsetWidthImpl(_: *anyopaque, _: *runtime.Instance) f64 {
        return 0;
    }

    fn getOffsetHeightImpl(_: *anyopaque, _: *runtime.Instance) f64 {
        return 0;
    }

    fn getOffsetTopImpl(_: *anyopaque, _: *runtime.Instance) f64 {
        return 0;
    }

    fn getOffsetLeftImpl(_: *anyopaque, _: *runtime.Instance) f64 {
        return 0;
    }

    fn getOffsetParentImpl(_: *anyopaque, _: *runtime.Instance) ?*runtime.Instance {
        return null;
    }

    fn getClientWidthImpl(_: *anyopaque, _: *runtime.Instance) f64 {
        return 0;
    }

    fn getClientHeightImpl(_: *anyopaque, _: *runtime.Instance) f64 {
        return 0;
    }

    fn getClientTopImpl(_: *anyopaque, _: *runtime.Instance) f64 {
        return 0;
    }

    fn getClientLeftImpl(_: *anyopaque, _: *runtime.Instance) f64 {
        return 0;
    }

    fn getScrollWidthImpl(_: *anyopaque, _: *runtime.Instance) f64 {
        return 0;
    }

    fn getScrollHeightImpl(_: *anyopaque, _: *runtime.Instance) f64 {
        return 0;
    }

    fn getScrollTopImpl(_: *anyopaque, _: *runtime.Instance) f64 {
        return 0;
    }

    fn setScrollTopImpl(_: *anyopaque, _: *runtime.Instance, _: f64) void {
        // No-op in stub
    }

    fn getScrollLeftImpl(_: *anyopaque, _: *runtime.Instance) f64 {
        return 0;
    }

    fn setScrollLeftImpl(_: *anyopaque, _: *runtime.Instance, _: f64) void {
        // No-op in stub
    }

    fn getBoundingClientRectImpl(_: *anyopaque, _: *runtime.Instance) DOMRect {
        return DOMRect.empty();
    }

    fn getClientRectsImpl(_: *anyopaque, _: *runtime.Instance, allocator: Allocator) DOMRectList {
        return DOMRectList.empty(allocator);
    }

    fn getRenderedTextImpl(_: *anyopaque, element: *runtime.Instance, allocator: Allocator) ?[]const u8 {
        // Fallback: return textContent (not spec-compliant but usable)
        // A real implementation would check display:none, collapse whitespace, etc.
        const NodeImpl = @import("impls").Node;
        if (NodeImpl.getInternalState(element)) |_| {
            // Get text content via the tree traversal
            return NodeImpl.getTextContentInternal(element, allocator) catch null;
        }
        return null;
    }

    fn isElementRenderedImpl(_: *anyopaque, _: *runtime.Instance) bool {
        // Assume everything is rendered in stub mode
        return true;
    }

    fn getCaretRectAtPositionImpl(_: *anyopaque, _: *runtime.Instance, _: u32) ?DOMRect {
        return null;
    }

    fn markDirtyImpl(_: *anyopaque, _: *runtime.Instance) void {
        // No-op in stub
    }

    fn forceLayoutImpl(_: *anyopaque) void {
        // No-op in stub
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *StubLayoutBackend = @ptrCast(@alignCast(ptr));
        self.allocator.destroy(self);
    }
};

// ============================================================================
// Tests
// ============================================================================

test "StubLayoutBackend - basic operations" {
    const allocator = std.testing.allocator;

    const stub = try StubLayoutBackend.init(allocator);
    const layout = stub.backend();
    defer layout.deinit();

    // Verify the vtable is properly constructed with non-null function pointers
    try std.testing.expect(@intFromPtr(layout.vtable.getOffsetWidth) != 0);
    try std.testing.expect(@intFromPtr(layout.vtable.getBoundingClientRect) != 0);
    try std.testing.expect(@intFromPtr(layout.vtable.getRenderedText) != 0);
    try std.testing.expect(@intFromPtr(layout.vtable.isElementRendered) != 0);
}

test "DOMRect - basic properties" {
    const rect = DOMRect.init(10, 20, 100, 50);

    try std.testing.expectEqual(@as(f64, 10), rect.x);
    try std.testing.expectEqual(@as(f64, 20), rect.y);
    try std.testing.expectEqual(@as(f64, 100), rect.width);
    try std.testing.expectEqual(@as(f64, 50), rect.height);

    // Computed edges
    try std.testing.expectEqual(@as(f64, 20), rect.top());
    try std.testing.expectEqual(@as(f64, 110), rect.right());
    try std.testing.expectEqual(@as(f64, 70), rect.bottom());
    try std.testing.expectEqual(@as(f64, 10), rect.left());
}

test "DOMRect - empty" {
    const rect = DOMRect.empty();

    try std.testing.expectEqual(@as(f64, 0), rect.x);
    try std.testing.expectEqual(@as(f64, 0), rect.y);
    try std.testing.expectEqual(@as(f64, 0), rect.width);
    try std.testing.expectEqual(@as(f64, 0), rect.height);
}

test "DOMRectList - empty list" {
    const allocator = std.testing.allocator;

    var list = DOMRectList.empty(allocator);
    defer list.deinit();

    try std.testing.expectEqual(@as(usize, 0), list.length());
    try std.testing.expectEqual(@as(?DOMRect, null), list.item(0));
}
