//! Element interface per WHATWG DOM Standard
//! Spec: https://dom.spec.whatwg.org/#interface-element

const std = @import("std");
const webidl = @import("webidl");
const infra = @import("infra");

const Allocator = std.mem.Allocator;
const Node = @import("node").Node;

/// Element WebIDL interface
pub const Element = webidl.interface(struct {
    allocator: Allocator,
    node: Node,
    tag_name: []const u8,
    namespace_uri: ?[]const u8,
    attributes: std.ArrayList(Attr),

    const Attr = @import("attr").Attr;

    pub fn init(allocator: Allocator, tag_name: []const u8) !Element {
        return .{
            .allocator = allocator,
            .node = try Node.init(allocator, Node.ELEMENT_NODE, tag_name),
            .tag_name = tag_name,
            .namespace_uri = null,
            .attributes = std.ArrayList(Attr).init(allocator),
        };
    }

    pub fn deinit(self: *Element) void {
        self.node.deinit();
        self.attributes.deinit();
    }

    /// getAttribute(qualifiedName)
    /// Spec: https://dom.spec.whatwg.org/#dom-element-getattribute
    pub fn call_getAttribute(self: *const Element, qualified_name: []const u8) ?[]const u8 {
        for (self.attributes.items) |attr| {
            if (std.mem.eql(u8, attr.name, qualified_name)) {
                return attr.value;
            }
        }
        return null;
    }

    /// setAttribute(qualifiedName, value)
    /// Spec: https://dom.spec.whatwg.org/#dom-element-setattribute
    pub fn call_setAttribute(self: *Element, qualified_name: []const u8, value: []const u8) !void {
        for (self.attributes.items) |*attr| {
            if (std.mem.eql(u8, attr.name, qualified_name)) {
                attr.value = value;
                return;
            }
        }
        try self.attributes.append(Attr{
            .name = qualified_name,
            .value = value,
        });
    }

    /// removeAttribute(qualifiedName)
    /// Spec: https://dom.spec.whatwg.org/#dom-element-removeattribute
    pub fn call_removeAttribute(self: *Element, qualified_name: []const u8) void {
        for (self.attributes.items, 0..) |attr, i| {
            if (std.mem.eql(u8, attr.name, qualified_name)) {
                _ = self.attributes.orderedRemove(i);
                return;
            }
        }
    }

    /// hasAttribute(qualifiedName)
    /// Spec: https://dom.spec.whatwg.org/#dom-element-hasattribute
    pub fn call_hasAttribute(self: *const Element, qualified_name: []const u8) bool {
        for (self.attributes.items) |attr| {
            if (std.mem.eql(u8, attr.name, qualified_name)) {
                return true;
            }
        }
        return false;
    }

    /// Getters
    pub fn get_tagName(self: *const Element) []const u8 {
        return self.tag_name;
    }

    pub fn get_namespaceURI(self: *const Element) ?[]const u8 {
        return self.namespace_uri;
    }
});
