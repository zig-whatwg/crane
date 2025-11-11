//! Document interface per WHATWG DOM Standard
//! Spec: https://dom.spec.whatwg.org/#interface-document

const std = @import("std");
const webidl = @import("webidl");
const Node = @import("node").Node;
const Element = @import("element").Element;
const ParentNode = @import("ParentNode.zig").ParentNode;

const Allocator = std.mem.Allocator;

/// DOM Spec: interface Document : Node
pub const Document = webidl.interface(struct {
    pub const extends = Node;
    pub const includes = .{ParentNode};

    allocator: Allocator,

    pub fn init(allocator: Allocator) !Document {
        // NOTE: Parent Node fields will be flattened by codegen
        return .{
            .allocator = allocator,
            // TODO: Initialize Node parent fields (will be added by codegen)
        };
    }

    pub fn deinit(self: *Document) void {
        _ = self;
        // NOTE: Parent Node cleanup will be handled by codegen
        // TODO: Call parent Node deinit (will be added by codegen)
    }

    /// createElement(localName)
    /// Spec: https://dom.spec.whatwg.org/#dom-document-createelement
    pub fn call_createElement(self: *Document, local_name: []const u8) !*Element {
        const element = try self.allocator.create(Element);
        element.* = try Element.init(self.allocator, local_name);
        return element;
    }

    /// createTextNode(data)
    /// Spec: https://dom.spec.whatwg.org/#dom-document-createtextnode
    pub fn call_createTextNode(self: *Document, data: []const u8) !*Text {
        _ = data;
        const text = try self.allocator.create(Text);
        text.* = try Text.init(self.allocator);
        return text;
    }

    const Text = @import("text").Text;
}, .{
    .exposed = &.{.Window},
});
