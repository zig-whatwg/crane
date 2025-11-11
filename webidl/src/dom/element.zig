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

    /// DOM §4.10.1 - Element.id
    /// The id getter steps are to return the value of this's id content attribute.
    /// The id setter steps are to set the value of this's id content attribute to the given value.
    pub fn get_id(self: *const Element) []const u8 {
        return self.call_getAttribute("id") orelse "";
    }

    pub fn set_id(self: *Element, value: []const u8) !void {
        try self.call_setAttribute("id", value);
    }

    /// DOM §4.10.1 - Element.className
    /// The className getter steps are to return the value of this's class content attribute.
    /// The className setter steps are to set the value of this's class content attribute to the given value.
    pub fn get_className(self: *const Element) []const u8 {
        return self.call_getAttribute("class") orelse "";
    }

    pub fn set_className(self: *Element, value: []const u8) !void {
        try self.call_setAttribute("class", value);
    }

    /// DOM §4.10.1 - Element.classList
    /// The classList getter steps are to return a DOMTokenList object whose associated element
    /// is this and whose associated attribute's local name is class.
    /// TODO: Implement DOMTokenList
    /// For now, return error as DOMTokenList is not implemented
    pub fn get_classList(self: *const Element) !*DOMTokenList {
        _ = self;
        return error.NotImplemented;
    }

    /// DOM §4.10.1 - Element.slot
    /// The slot getter steps are to return the value of this's slot content attribute.
    /// The slot setter steps are to set the value of this's slot content attribute to the given value.
    pub fn get_slot(self: *const Element) []const u8 {
        return self.call_getAttribute("slot") orelse "";
    }

    pub fn set_slot(self: *Element, value: []const u8) !void {
        try self.call_setAttribute("slot", value);
    }

    /// Getters
    pub fn get_tagName(self: *const Element) []const u8 {
        return self.tag_name;
    }

    pub fn get_namespaceURI(self: *const Element) ?[]const u8 {
        return self.namespace_uri;
    }

    // Forward declaration for DOMTokenList (not yet implemented)
    const DOMTokenList = @import("DOMTokenList.zig").DOMTokenList;
}, .{
    .exposed = &.{.Window},
});
