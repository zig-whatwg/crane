//! Document interface per WHATWG DOM Standard
//! Spec: https://dom.spec.whatwg.org/#interface-document

const std = @import("std");
const webidl = @import("webidl");
const dom = @import("dom");
const Node = @import("node").Node;
const Element = @import("element").Element;
const ParentNode = @import("parent_node").ParentNode;
const NonElementParentNode = @import("non_element_parent_node").NonElementParentNode;
const NodeList = @import("node_list").NodeList;
const HTMLCollection = @import("html_collection").HTMLCollection;
const dom_types = @import("dom_types");
const ProcessingInstruction = @import("processing_instruction").ProcessingInstruction;
const CDATASection = @import("cdata_section").CDATASection;
const DocumentType = @import("document_type").DocumentType;

const Allocator = std.mem.Allocator;

/// DOM Spec: interface Document : Node
pub const Document = webidl.interface(struct {
    pub const extends = Node;
    pub const includes = .{ ParentNode, NonElementParentNode };

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

    /// createProcessingInstruction(target, data)
    /// DOM §4.6.1 - Creates a ProcessingInstruction node
    /// Returns a new ProcessingInstruction node whose target is target, data is data,
    /// and node document is this.
    pub fn call_createProcessingInstruction(
        self: *Document,
        target: []const u8,
        data: []const u8,
    ) !*ProcessingInstruction {
        const pi = try self.allocator.create(ProcessingInstruction);
        pi.* = try ProcessingInstruction.init(self.allocator, target, data);
        return pi;
    }

    /// createCDATASection(data)
    /// DOM §4.6.1 - Creates a CDATASection node
    /// Returns a new CDATASection node whose data is data and node document is this.
    pub fn call_createCDATASection(self: *Document, data: []const u8) !*CDATASection {
        const cdata = try self.allocator.create(CDATASection);
        cdata.* = try CDATASection.init(self.allocator, data);
        return cdata;
    }

    /// createDocumentType(qualifiedName, publicId, systemId)
    /// DOM §4.6.1 - Creates a DocumentType node
    /// Returns a new DocumentType node whose name is qualifiedName, public ID is publicId,
    /// system ID is systemId, and node document is this.
    pub fn call_createDocumentType(
        self: *Document,
        qualified_name: []const u8,
        public_id: []const u8,
        system_id: []const u8,
    ) !*DocumentType {
        const doctype = try self.allocator.create(DocumentType);
        doctype.* = try DocumentType.init(self.allocator, qualified_name, public_id, system_id);
        return doctype;
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

    /// importNode(node, deep)
    /// DOM §4.6.1 - Returns a copy of node imported into this document.
    /// If deep is true, the copy also includes the node's descendants.
    /// TODO: Implement full node cloning algorithm
    pub fn call_importNode(self: *Document, node: *Node, deep: bool) !*Node {
        _ = self;
        _ = node;
        _ = deep;
        return error.NotImplemented;
    }

    /// adoptNode(node)
    /// DOM §4.6.1 - Moves node from another document to this document.
    /// Removes node from its current document and changes its owner document to this.
    /// TODO: Implement full adoption algorithm with parent removal
    pub fn call_adoptNode(self: *Document, node: *Node) !*Node {
        _ = self;
        _ = node;
        return error.NotImplemented;
    }

    // Forward declarations
    const Text = @import("text").Text;
    const Comment = @import("comment").Comment;
    const DocumentFragment = @import("document_fragment").DocumentFragment;
    const Attr = @import("attr").Attr;
}, .{
    .exposed = &.{.Window},
});
