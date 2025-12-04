//! Layout Backend Adapter
//!
//! Provides adapters between the old LayoutBackend interface and the new
//! unified LayoutVTable (C ABI compatible) interface.
//!
//! ## Migration Path
//!
//! 1. Existing code uses `LayoutBackend` (Zig-native VTable with runtime.Instance)
//! 2. New embedders implement `LayoutVTable` (C ABI compatible with OpaquePtr)
//! 3. Adapters bridge between the two interfaces
//!
//! ## Usage
//!
//! ```zig
//! // Wrap old LayoutBackend for new unified system
//! const adapter = LayoutVTableAdapter.init(allocator, old_backend);
//! const vtable = LayoutVTableAdapter.getVTable();
//!
//! // Wrap new LayoutVTable for existing code
//! const backend = LayoutBackendAdapter.fromVTable(vtable, user_context);
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");

const vtables = @import("vtables.zig");
const LayoutVTable = vtables.LayoutVTable;
const CDOMRect = vtables.CDOMRect;
const OpaquePtr = vtables.OpaquePtr;

const layout_backend = @import("layout_backend.zig");
const LayoutBackend = layout_backend.LayoutBackend;
const DOMRect = layout_backend.DOMRect;

// =============================================================================
// LayoutVTable -> LayoutBackend Adapter
// =============================================================================

/// Adapter that wraps a LayoutVTable and provides a LayoutBackend interface.
///
/// This allows new C ABI embedder implementations to be used with existing
/// Zig code that expects a LayoutBackend.
pub const LayoutBackendAdapter = struct {
    /// The wrapped VTable
    vtable: *const LayoutVTable,
    /// User context passed to VTable functions
    user_context: OpaquePtr,
    /// Allocator for internal operations
    allocator: Allocator,

    const Self = @This();

    /// Create an adapter from a LayoutVTable.
    pub fn init(
        allocator: Allocator,
        vtable: *const LayoutVTable,
        user_context: OpaquePtr,
    ) !*Self {
        const self = try allocator.create(Self);
        self.* = Self{
            .vtable = vtable,
            .user_context = user_context,
            .allocator = allocator,
        };
        return self;
    }

    /// Get a LayoutBackend interface.
    pub fn backend(self: *Self) LayoutBackend {
        return LayoutBackend{
            .ptr = self,
            .vtable = &backend_vtable,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.destroy(self);
    }

    const backend_vtable = LayoutBackend.VTable{
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
        .getViewportScrollX = getViewportScrollXImpl,
        .getViewportScrollY = getViewportScrollYImpl,
        .setViewportScroll = setViewportScrollImpl,
        .deinit = deinitImpl,
    };

    fn getOffsetWidthImpl(ptr: *anyopaque, element: *runtime.Instance) f64 {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.vtable.get_offsetWidth(self.user_context, element);
    }

    fn getOffsetHeightImpl(ptr: *anyopaque, element: *runtime.Instance) f64 {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.vtable.get_offsetHeight(self.user_context, element);
    }

    fn getOffsetTopImpl(ptr: *anyopaque, element: *runtime.Instance) f64 {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.vtable.get_offsetTop(self.user_context, element);
    }

    fn getOffsetLeftImpl(ptr: *anyopaque, element: *runtime.Instance) f64 {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.vtable.get_offsetLeft(self.user_context, element);
    }

    fn getOffsetParentImpl(ptr: *anyopaque, element: *runtime.Instance) ?*runtime.Instance {
        const self: *Self = @ptrCast(@alignCast(ptr));
        const result = self.vtable.get_offsetParent(self.user_context, element);
        return @ptrCast(@alignCast(result));
    }

    fn getClientWidthImpl(ptr: *anyopaque, element: *runtime.Instance) f64 {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.vtable.get_clientWidth(self.user_context, element);
    }

    fn getClientHeightImpl(ptr: *anyopaque, element: *runtime.Instance) f64 {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.vtable.get_clientHeight(self.user_context, element);
    }

    fn getClientTopImpl(ptr: *anyopaque, element: *runtime.Instance) f64 {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.vtable.get_clientTop(self.user_context, element);
    }

    fn getClientLeftImpl(ptr: *anyopaque, element: *runtime.Instance) f64 {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.vtable.get_clientLeft(self.user_context, element);
    }

    fn getScrollWidthImpl(ptr: *anyopaque, element: *runtime.Instance) f64 {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.vtable.get_scrollWidth(self.user_context, element);
    }

    fn getScrollHeightImpl(ptr: *anyopaque, element: *runtime.Instance) f64 {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.vtable.get_scrollHeight(self.user_context, element);
    }

    fn getScrollTopImpl(ptr: *anyopaque, element: *runtime.Instance) f64 {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.vtable.get_scrollTop(self.user_context, element);
    }

    fn setScrollTopImpl(ptr: *anyopaque, element: *runtime.Instance, value: f64) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.vtable.set_scrollTop(self.user_context, element, value);
    }

    fn getScrollLeftImpl(ptr: *anyopaque, element: *runtime.Instance) f64 {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.vtable.get_scrollLeft(self.user_context, element);
    }

    fn setScrollLeftImpl(ptr: *anyopaque, element: *runtime.Instance, value: f64) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.vtable.set_scrollLeft(self.user_context, element, value);
    }

    fn getBoundingClientRectImpl(ptr: *anyopaque, element: *runtime.Instance) DOMRect {
        const self: *Self = @ptrCast(@alignCast(ptr));
        var c_rect: CDOMRect = undefined;
        self.vtable.call_getBoundingClientRect(self.user_context, element, &c_rect);
        return DOMRect{
            .x = c_rect.x,
            .y = c_rect.y,
            .width = c_rect.width,
            .height = c_rect.height,
        };
    }

    fn getClientRectsImpl(_: *anyopaque, _: *runtime.Instance, allocator: Allocator) layout_backend.DOMRectList {
        // Not supported through C ABI - would need additional VTable methods
        return layout_backend.DOMRectList.empty(allocator);
    }

    fn getRenderedTextImpl(_: *anyopaque, _: *runtime.Instance, _: Allocator) ?[]const u8 {
        // Not supported through C ABI - would need additional VTable methods
        return null;
    }

    fn isElementRenderedImpl(ptr: *anyopaque, element: *runtime.Instance) bool {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.vtable.isElementRendered(self.user_context, element);
    }

    fn getCaretRectAtPositionImpl(_: *anyopaque, _: *runtime.Instance, _: u32) ?DOMRect {
        // Not supported through C ABI
        return null;
    }

    fn markDirtyImpl(ptr: *anyopaque, element: *runtime.Instance) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.vtable.markDirty(self.user_context, element);
    }

    fn forceLayoutImpl(ptr: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.vtable.forceLayout(self.user_context);
    }

    fn getViewportScrollXImpl(_: *anyopaque, _: *runtime.Instance) f64 {
        // Not in C ABI VTable
        return 0;
    }

    fn getViewportScrollYImpl(_: *anyopaque, _: *runtime.Instance) f64 {
        // Not in C ABI VTable
        return 0;
    }

    fn setViewportScrollImpl(_: *anyopaque, _: *runtime.Instance, _: f64, _: f64) void {
        // Not in C ABI VTable
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};

// =============================================================================
// LayoutBackend -> LayoutVTable Adapter
// =============================================================================

/// Context for LayoutVTable that wraps a LayoutBackend.
///
/// This allows existing Zig LayoutBackend implementations (like StubLayoutBackend)
/// to be used with the new unified PlatformBackend system.
pub const LayoutVTableAdapter = struct {
    /// The wrapped backend
    backend: LayoutBackend,
    /// Allocator for cleanup
    allocator: Allocator,

    const Self = @This();

    /// Create an adapter context.
    pub fn init(allocator: Allocator, backend: LayoutBackend) !*Self {
        const self = try allocator.create(Self);
        self.* = Self{
            .backend = backend,
            .allocator = allocator,
        };
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.destroy(self);
    }

    /// Get a pointer to the static VTable.
    pub fn getVTable() *const LayoutVTable {
        return &vtable;
    }

    /// Get the user context pointer (pass this to PlatformBackend.user_context).
    pub fn getUserContext(self: *Self) OpaquePtr {
        return self;
    }

    const vtable = LayoutVTable{
        .get_offsetWidth = getOffsetWidthImpl,
        .get_offsetHeight = getOffsetHeightImpl,
        .get_offsetTop = getOffsetTopImpl,
        .get_offsetLeft = getOffsetLeftImpl,
        .get_offsetParent = getOffsetParentImpl,
        .get_clientWidth = getClientWidthImpl,
        .get_clientHeight = getClientHeightImpl,
        .get_clientTop = getClientTopImpl,
        .get_clientLeft = getClientLeftImpl,
        .get_scrollWidth = getScrollWidthImpl,
        .get_scrollHeight = getScrollHeightImpl,
        .get_scrollTop = getScrollTopImpl,
        .set_scrollTop = setScrollTopImpl,
        .get_scrollLeft = getScrollLeftImpl,
        .set_scrollLeft = setScrollLeftImpl,
        .call_getBoundingClientRect = getBoundingClientRectImpl,
        .isElementRendered = isElementRenderedImpl,
        .markDirty = markDirtyImpl,
        .forceLayout = forceLayoutImpl,
    };

    fn getOffsetWidthImpl(user_context: OpaquePtr, element: OpaquePtr) callconv(.c) f64 {
        const self: *Self = @ptrCast(@alignCast(user_context));
        const elem: *runtime.Instance = @ptrCast(@alignCast(element));
        return self.backend.getOffsetWidth(elem);
    }

    fn getOffsetHeightImpl(user_context: OpaquePtr, element: OpaquePtr) callconv(.c) f64 {
        const self: *Self = @ptrCast(@alignCast(user_context));
        const elem: *runtime.Instance = @ptrCast(@alignCast(element));
        return self.backend.getOffsetHeight(elem);
    }

    fn getOffsetTopImpl(user_context: OpaquePtr, element: OpaquePtr) callconv(.c) f64 {
        const self: *Self = @ptrCast(@alignCast(user_context));
        const elem: *runtime.Instance = @ptrCast(@alignCast(element));
        return self.backend.getOffsetTop(elem);
    }

    fn getOffsetLeftImpl(user_context: OpaquePtr, element: OpaquePtr) callconv(.c) f64 {
        const self: *Self = @ptrCast(@alignCast(user_context));
        const elem: *runtime.Instance = @ptrCast(@alignCast(element));
        return self.backend.getOffsetLeft(elem);
    }

    fn getOffsetParentImpl(user_context: OpaquePtr, element: OpaquePtr) callconv(.c) OpaquePtr {
        const self: *Self = @ptrCast(@alignCast(user_context));
        const elem: *runtime.Instance = @ptrCast(@alignCast(element));
        const parent = self.backend.getOffsetParent(elem);
        return parent;
    }

    fn getClientWidthImpl(user_context: OpaquePtr, element: OpaquePtr) callconv(.c) f64 {
        const self: *Self = @ptrCast(@alignCast(user_context));
        const elem: *runtime.Instance = @ptrCast(@alignCast(element));
        return self.backend.getClientWidth(elem);
    }

    fn getClientHeightImpl(user_context: OpaquePtr, element: OpaquePtr) callconv(.c) f64 {
        const self: *Self = @ptrCast(@alignCast(user_context));
        const elem: *runtime.Instance = @ptrCast(@alignCast(element));
        return self.backend.getClientHeight(elem);
    }

    fn getClientTopImpl(user_context: OpaquePtr, element: OpaquePtr) callconv(.c) f64 {
        const self: *Self = @ptrCast(@alignCast(user_context));
        const elem: *runtime.Instance = @ptrCast(@alignCast(element));
        return self.backend.getClientTop(elem);
    }

    fn getClientLeftImpl(user_context: OpaquePtr, element: OpaquePtr) callconv(.c) f64 {
        const self: *Self = @ptrCast(@alignCast(user_context));
        const elem: *runtime.Instance = @ptrCast(@alignCast(element));
        return self.backend.getClientLeft(elem);
    }

    fn getScrollWidthImpl(user_context: OpaquePtr, element: OpaquePtr) callconv(.c) f64 {
        const self: *Self = @ptrCast(@alignCast(user_context));
        const elem: *runtime.Instance = @ptrCast(@alignCast(element));
        return self.backend.getScrollWidth(elem);
    }

    fn getScrollHeightImpl(user_context: OpaquePtr, element: OpaquePtr) callconv(.c) f64 {
        const self: *Self = @ptrCast(@alignCast(user_context));
        const elem: *runtime.Instance = @ptrCast(@alignCast(element));
        return self.backend.getScrollHeight(elem);
    }

    fn getScrollTopImpl(user_context: OpaquePtr, element: OpaquePtr) callconv(.c) f64 {
        const self: *Self = @ptrCast(@alignCast(user_context));
        const elem: *runtime.Instance = @ptrCast(@alignCast(element));
        return self.backend.getScrollTop(elem);
    }

    fn setScrollTopImpl(user_context: OpaquePtr, element: OpaquePtr, value: f64) callconv(.c) void {
        const self: *Self = @ptrCast(@alignCast(user_context));
        const elem: *runtime.Instance = @ptrCast(@alignCast(element));
        self.backend.setScrollTop(elem, value);
    }

    fn getScrollLeftImpl(user_context: OpaquePtr, element: OpaquePtr) callconv(.c) f64 {
        const self: *Self = @ptrCast(@alignCast(user_context));
        const elem: *runtime.Instance = @ptrCast(@alignCast(element));
        return self.backend.getScrollLeft(elem);
    }

    fn setScrollLeftImpl(user_context: OpaquePtr, element: OpaquePtr, value: f64) callconv(.c) void {
        const self: *Self = @ptrCast(@alignCast(user_context));
        const elem: *runtime.Instance = @ptrCast(@alignCast(element));
        self.backend.setScrollLeft(elem, value);
    }

    fn getBoundingClientRectImpl(user_context: OpaquePtr, element: OpaquePtr, out_rect: *CDOMRect) callconv(.c) void {
        const self: *Self = @ptrCast(@alignCast(user_context));
        const elem: *runtime.Instance = @ptrCast(@alignCast(element));
        const rect = self.backend.getBoundingClientRect(elem);
        out_rect.* = CDOMRect{
            .x = rect.x,
            .y = rect.y,
            .width = rect.width,
            .height = rect.height,
        };
    }

    fn isElementRenderedImpl(user_context: OpaquePtr, element: OpaquePtr) callconv(.c) bool {
        const self: *Self = @ptrCast(@alignCast(user_context));
        const elem: *runtime.Instance = @ptrCast(@alignCast(element));
        return self.backend.isElementRendered(elem);
    }

    fn markDirtyImpl(user_context: OpaquePtr, element: OpaquePtr) callconv(.c) void {
        const self: *Self = @ptrCast(@alignCast(user_context));
        const elem: *runtime.Instance = @ptrCast(@alignCast(element));
        self.backend.markDirty(elem);
    }

    fn forceLayoutImpl(user_context: OpaquePtr) callconv(.c) void {
        const self: *Self = @ptrCast(@alignCast(user_context));
        self.backend.forceLayout();
    }
};

// =============================================================================
// Convenience Functions
// =============================================================================

/// Create a LayoutVTable adapter from a StubLayoutBackend.
pub fn createStubVTableAdapter(
    allocator: Allocator,
    stub: *layout_backend.StubLayoutBackend,
) !*LayoutVTableAdapter {
    return LayoutVTableAdapter.init(allocator, stub.backend());
}

// =============================================================================
// Tests
// =============================================================================

test "LayoutVTableAdapter - wraps StubLayoutBackend" {
    const allocator = std.testing.allocator;

    // Create stub backend
    const stub = try layout_backend.StubLayoutBackend.init(allocator);
    defer stub.allocator.destroy(stub);

    // Create adapter
    const adapter = try LayoutVTableAdapter.init(allocator, stub.backend());
    defer adapter.deinit();

    // Get VTable
    const vtable = LayoutVTableAdapter.getVTable();
    const ctx = adapter.getUserContext();

    // Test forceLayout (doesn't need an element)
    vtable.forceLayout(ctx);

    // Can't fully test element-based operations without a real runtime.Instance,
    // but we verify the vtable is properly constructed
    try std.testing.expect(@intFromPtr(vtable.get_offsetWidth) != 0);
    try std.testing.expect(@intFromPtr(vtable.call_getBoundingClientRect) != 0);
}

test "LayoutBackendAdapter - construction" {
    const allocator = std.testing.allocator;

    // Create stub backend first
    const stub = try layout_backend.StubLayoutBackend.init(allocator);
    defer stub.allocator.destroy(stub);

    // Create VTable adapter
    const vtable_adapter = try LayoutVTableAdapter.init(allocator, stub.backend());
    defer vtable_adapter.deinit();

    // Create backend adapter from VTable
    const backend_adapter = try LayoutBackendAdapter.init(
        allocator,
        LayoutVTableAdapter.getVTable(),
        vtable_adapter.getUserContext(),
    );
    defer backend_adapter.deinit();

    // Get LayoutBackend interface - verify it's constructable
    const backend = backend_adapter.backend();
    _ = backend;
}
