//! Attr interface per WHATWG DOM Standard
//! Spec: https://dom.spec.whatwg.org/#interface-attr
//! DOM §4.9

const std = @import("std");
const webidl = @import("webidl");
const Node = @import("node").Node;
const Element = @import("element").Element;

/// DOM §4.9 - Attr interface
/// Attr nodes represent attributes.
/// Attributes have a namespace, namespace prefix, local name, value, and element.
pub const Attr = webidl.interface(struct {
    pub const extends = Node;

    allocator: std.mem.Allocator,
    /// The attribute's namespace (null or a non-empty string)
    namespace_uri: ?[]const u8,
    /// The attribute's namespace prefix (null or a non-empty string)
    prefix: ?[]const u8,
    /// The attribute's local name (a non-empty string)
    local_name: []const u8,
    /// The attribute's value (a string)
    value: []u8,
    /// The element this attribute belongs to (null or an element)
    owner_element: ?*Element,

    pub fn init(
        allocator: std.mem.Allocator,
        namespace_uri: ?[]const u8,
        prefix: ?[]const u8,
        local_name: []const u8,
        value: []const u8,
    ) !Attr {
        return .{
            .allocator = allocator,
            .namespace_uri = if (namespace_uri) |ns| try allocator.dupe(u8, ns) else null,
            .prefix = if (prefix) |p| try allocator.dupe(u8, p) else null,
            .local_name = try allocator.dupe(u8, local_name),
            .value = try allocator.dupe(u8, value),
            .owner_element = null,
            // TODO: Initialize Node parent fields (will be added by codegen)
        };
    }

    pub fn deinit(self: *Attr) void {
        if (self.namespace_uri) |ns| self.allocator.free(ns);
        if (self.prefix) |p| self.allocator.free(p);
        self.allocator.free(self.local_name);
        self.allocator.free(self.value);
        // NOTE: Parent Node cleanup will be handled by codegen
    }

    /// DOM §4.9 - namespaceURI getter
    /// Returns this's namespace.
    pub fn get_namespaceURI(self: *const Attr) ?[]const u8 {
        return self.namespace_uri;
    }

    /// DOM §4.9 - prefix getter
    /// Returns this's namespace prefix.
    pub fn get_prefix(self: *const Attr) ?[]const u8 {
        return self.prefix;
    }

    /// DOM §4.9 - localName getter
    /// Returns this's local name.
    pub fn get_localName(self: *const Attr) []const u8 {
        return self.local_name;
    }

    /// DOM §4.9 - name getter
    /// Returns this's qualified name.
    /// The qualified name is local name if namespace prefix is null,
    /// otherwise it's prefix + ":" + local name.
    pub fn get_name(self: *const Attr) ![]const u8 {
        if (self.prefix) |p| {
            // Qualified name: prefix + ":" + localName
            const qualified = try std.fmt.allocPrint(
                self.allocator,
                "{s}:{s}",
                .{ p, self.local_name },
            );
            return qualified;
        }
        // No prefix, just return local name
        return self.local_name;
    }

    /// DOM §4.9 - value getter
    /// Returns this's value.
    pub fn get_value(self: *const Attr) []const u8 {
        return self.value;
    }

    /// DOM §4.9 - value setter
    /// Sets this's value.
    /// Steps: Set an existing attribute value with this and the given value.
    pub fn set_value(self: *Attr, new_value: []const u8) !void {
        // If attribute's element is null, just set the value
        if (self.owner_element == null) {
            self.allocator.free(self.value);
            self.value = try self.allocator.dupe(u8, new_value);
            return;
        }

        // Otherwise, change attribute (requires mutation handling)
        // TODO: Implement full "change attribute" algorithm with mutations
        self.allocator.free(self.value);
        self.value = try self.allocator.dupe(u8, new_value);
    }

    /// DOM §4.9 - ownerElement getter
    /// Returns this's element.
    pub fn get_ownerElement(self: *const Attr) ?*Element {
        return self.owner_element;
    }

    /// DOM §4.9 - specified getter
    /// Always returns true (this is a legacy attribute).
    pub fn get_specified(self: *const Attr) bool {
        _ = self;
        return true;
    }
}, .{
    .exposed = &.{.Window},
});
