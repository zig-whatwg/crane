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
        const text = try self.allocator.create(Text);
        text.* = try Text.init(self.allocator);
        // TODO: Set text.data = data when CharacterData has data field accessible
        _ = data;
        return text;
    }

    /// createComment(data)
    /// DOM §4.6.1 - The createComment(data) method steps are to return
    /// a new Comment node whose data is data and node document is this.
    pub fn call_createComment(self: *Document, data: []const u8) !*Comment {
        const comment = try self.allocator.create(Comment);
        comment.* = try Comment.init(self.allocator);
        // TODO: Set comment.data = data when CharacterData has data field accessible
        _ = data;
        return comment;
    }

    /// createDocumentFragment()
    /// DOM §4.6.1 - The createDocumentFragment() method steps are to return
    /// a new DocumentFragment node whose node document is this.
    pub fn call_createDocumentFragment(self: *Document) !*DocumentFragment {
        const fragment = try self.allocator.create(DocumentFragment);
        fragment.* = try DocumentFragment.init(self.allocator);
        return fragment;
    }

    /// createElementNS(namespace, qualifiedName)
    /// DOM §4.6.1 - Creates an element in the given namespace
    /// TODO: Implement full namespace handling and qualified name parsing
    pub fn call_createElementNS(
        self: *Document,
        namespace: ?[]const u8,
        qualified_name: []const u8,
    ) !*Element {
        const element = try self.allocator.create(Element);
        element.* = try Element.init(self.allocator, qualified_name);
        // TODO: Set namespace_uri from namespace parameter
        _ = namespace;
        return element;
    }

    /// createAttribute(localName)
    /// DOM §4.6.1 - Creates an Attr node with the given local name
    pub fn call_createAttribute(self: *Document, local_name: []const u8) !*Attr {
        _ = self;
        _ = local_name;
        return error.NotImplemented;
    }

    /// createAttributeNS(namespace, qualifiedName)
    /// DOM §4.6.1 - Creates an Attr node in the given namespace
    pub fn call_createAttributeNS(
        self: *Document,
        namespace: ?[]const u8,
        qualified_name: []const u8,
    ) !*Attr {
        _ = self;
        _ = namespace;
        _ = qualified_name;
        return error.NotImplemented;
    }

    // Forward declarations
    const Text = @import("text").Text;
    const Comment = @import("comment").Comment;
    const DocumentFragment = @import("DocumentFragment.zig").DocumentFragment;
    const Attr = @import("attr").Attr;
}, .{
    .exposed = &.{.Window},
});
