//! Element interface per WHATWG DOM Standard
//! Spec: https://dom.spec.whatwg.org/#interface-element

const std = @import("std");
const webidl = @import("webidl");
const infra = @import("infra");

const Allocator = std.mem.Allocator;
const Node = @import("node").Node;
const ChildNode = @import("ChildNode.zig").ChildNode;
const NonDocumentTypeChildNode = @import("NonDocumentTypeChildNode.zig").NonDocumentTypeChildNode;
const ParentNode = @import("ParentNode.zig").ParentNode;

/// Element WebIDL interface
/// DOM Spec: interface Element : Node
pub const Element = webidl.interface(struct {
    pub const extends = Node;
    pub const includes = .{ ChildNode, NonDocumentTypeChildNode, ParentNode };

    allocator: Allocator,
    tag_name: []const u8,
    namespace_uri: ?[]const u8,
    attributes: infra.List(Attr),

    const Attr = @import("attr").Attr;

    pub fn init(allocator: Allocator, tag_name: []const u8) !Element {
        // NOTE: Parent Node fields will be flattened by codegen
        return .{
            .allocator = allocator,
            .tag_name = tag_name,
            .namespace_uri = null,
            .attributes = infra.List(Attr).init(allocator),
            // TODO: Initialize Node parent fields (will be added by codegen)
        };
    }

    pub fn deinit(self: *Element) void {
        // NOTE: Parent Node cleanup will be handled by codegen
        self.attributes.deinit();
        // TODO: Call parent Node deinit (will be added by codegen)
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
}, .{
    .exposed = &.{.Window},
});
