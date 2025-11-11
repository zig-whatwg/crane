//! Document interface per WHATWG DOM Standard
//! Spec: https://dom.spec.whatwg.org/#interface-document

const std = @import("std");
const webidl = @import("webidl");
const Node = @import("node").Node;
const Element = @import("element").Element;
const ParentNode = @import("ParentNode.zig").ParentNode;

const Allocator = std.mem.Allocator;

pub const Document = webidl.interface(struct {
    pub const includes = .{ParentNode};
    allocator: Allocator,
    node: Node,

    pub fn init(allocator: Allocator) !Document {
        return .{
            .allocator = allocator,
            .node = try Node.init(allocator, Node.DOCUMENT_NODE, "#document"),
        };
    }

    pub fn deinit(self: *Document) void {
        self.node.deinit();
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
