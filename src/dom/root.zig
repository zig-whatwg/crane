//! WHATWG DOM Standard Implementation
//!
//! Spec: https://dom.spec.whatwg.org/

const std = @import("std");

// Dependencies
pub const infra = @import("infra");
pub const webidl = @import("webidl");

// WebIDL generated interfaces
pub const AbortSignal = @import("abort_signal").AbortSignal;
pub const AbortController = @import("abort_controller").AbortController;
pub const EventTarget = @import("event_target").EventTarget;
pub const Event = @import("event").Event;
pub const Node = @import("node").Node;
pub const NodeList = @import("node_list").NodeList;
pub const NamedNodeMap = @import("named_node_map").NamedNodeMap;
pub const Element = @import("element").Element;
pub const CharacterData = @import("character_data").CharacterData;
pub const Text = @import("text").Text;
pub const Comment = @import("comment").Comment;
pub const ProcessingInstruction = @import("processing_instruction").ProcessingInstruction;
pub const CDATASection = @import("cdata_section").CDATASection;
pub const DocumentType = @import("document_type").DocumentType;
pub const DocumentFragment = @import("document_fragment").DocumentFragment;
pub const DOMTokenList = @import("dom_token_list").DOMTokenList;
pub const Attr = @import("attr").Attr;
pub const DOMImplementation = @import("dom_implementation").DOMImplementation;
pub const Document = @import("document").Document;
pub const Range = @import("range").Range;
pub const NodeFilter = @import("node_filter").NodeFilter;
pub const NodeIterator = @import("node_iterator").NodeIterator;
pub const TreeWalker = @import("tree_walker").TreeWalker;
pub const MutationRecord = @import("mutation_record").MutationRecord;

// DOM implementation algorithms
pub const tree = @import("tree.zig");
pub const tree_helpers = @import("tree_helpers.zig");
pub const mutation = @import("mutation.zig");
pub const selectors = @import("selectors_mock.zig");
pub const fast_path = @import("fast_path.zig");
pub const html_mock = @import("html_mock.zig");

test {
    std.testing.refAllDecls(@This());
}
