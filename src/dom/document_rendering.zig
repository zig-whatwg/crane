//! HTML 3.1.6: the Document's render-blocking element set.
//! Document installs its state and eligibility answers; script preparation,
//! removal and the browser's rendering opportunity reach only this seam.
//! Elements are borrowed: their tree or prepared-script queue owns them.
//! Removing/discarding/destruction erases membership before that ownership ends.
//! Spec: https://html.spec.whatwg.org/multipage/dom.html#render-blocking-mechanism
//! lint-impls: hook for Document
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const document_lifecycle = @import("document_lifecycle.zig");

/// Implementation policy: render blocking expires 30 seconds after the
/// relevant global's time origin. It never changes membership or execution.
pub const timeout_ms: f64 = 30_000;

pub const ElementSet = struct {
    allocator: std.mem.Allocator,
    elements: std.ArrayList(*runtime.Instance) = .empty,

    pub fn init(allocator: std.mem.Allocator) ElementSet {
        return .{ .allocator = allocator };
    }
    pub fn deinit(self: *ElementSet) void {
        self.elements.deinit(self.allocator);
        // Document's other owners may release elements during teardown while
        // its registry entry still exists. They see an empty, usable set.
        self.elements = .empty;
    }
    pub fn contains(self: *const ElementSet, element: *runtime.Instance) bool {
        return std.mem.indexOfScalar(*runtime.Instance, self.elements.items, element) != null;
    }
    pub fn add(self: *ElementSet, element: *runtime.Instance) error{OutOfMemory}!void {
        if (!self.contains(element)) try self.elements.append(self.allocator, element);
    }
    pub fn remove(self: *ElementSet, element: *runtime.Instance) void {
        if (std.mem.indexOfScalar(*runtime.Instance, self.elements.items, element)) |index| {
            _ = self.elements.orderedRemove(index);
        }
    }
    pub fn clear(self: *ElementSet) void {
        self.elements.clearRetainingCapacity();
    }
    pub fn isBlocked(self: *const ElementSet, allows_adding: bool, now_ms: f64) bool {
        return (self.elements.items.len != 0 or allows_adding) and now_ms <= timeout_ms;
    }
};

/// HTML 2.5.8, blocking tokens set steps 1–4.
pub fn hasRenderToken(value: []const u8) bool {
    var tokens = std.mem.tokenizeAny(u8, value, " \t\n\r\x0c");
    while (tokens.next()) |token| {
        if (std.ascii.eqlIgnoreCase(token, "render")) return true;
    }
    return false;
}

pub fn allowsAdding(content_type: []const u8, has_body: bool) bool {
    return std.mem.eql(u8, content_type, "text/html") and !has_body;
}

pub const Implementation = struct {
    of: *const fn (*runtime.Instance) ?*ElementSet,
    allows_adding: *const fn (*runtime.Instance) bool,
    current_time_ms: *const fn (*runtime.Instance) f64,
};

pub fn contains(document: *runtime.Instance, element: *runtime.Instance) bool {
    const impl = document_lifecycle.renderingImplementation() orelse return false;
    const set = impl.of(document) orelse return false;
    return set.contains(element);
}

/// Block rendering steps 1–2. Repeated requests append once.
pub fn block(element: *runtime.Instance) error{OutOfMemory}!void {
    const document = (interfaces.Node.get_ownerDocument(element) catch return) orelse return;
    const impl = document_lifecycle.renderingImplementation() orelse return;
    if (!impl.allows_adding(document)) return;
    const set = impl.of(document) orelse return;
    try set.add(element);
}

/// Unblock rendering steps 1–2. Removal runs before adoption changes this
/// node document; abandoned queues additionally name their original document.
pub fn unblock(element: *runtime.Instance) void {
    const document = (interfaces.Node.get_ownerDocument(element) catch return) orelse return;
    remove(document, element);
}

pub fn remove(document: *runtime.Instance, element: *runtime.Instance) void {
    const impl = document_lifecycle.renderingImplementation() orelse return;
    const set = impl.of(document) orelse return;
    set.remove(element);
}

pub fn isBlocked(document: *runtime.Instance) bool {
    const impl = document_lifecycle.renderingImplementation() orelse return false;
    const set = impl.of(document) orelse return false;
    return set.isBlocked(impl.allows_adding(document), impl.current_time_ms(document));
}

pub fn isRenderBlocking(element: *runtime.Instance) bool {
    const document = (interfaces.Node.get_ownerDocument(element) catch return false) orelse return false;
    return contains(document, element) and isBlocked(document);
}
