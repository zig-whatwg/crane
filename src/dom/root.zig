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
pub const ShadowRoot = @import("shadow_root").ShadowRoot;
pub const ShadowRootMode = @import("shadow_root").ShadowRootMode;
pub const SlotAssignmentMode = @import("shadow_root").SlotAssignmentMode;
pub const ShadowRootInit = @import("shadow_root_init").ShadowRootInit;
pub const HTMLSlotElement = @import("html_slot_element").HTMLSlotElement;
pub const DOMTokenList = @import("dom_token_list").DOMTokenList;
pub const Attr = @import("attr").Attr;
pub const DOMImplementation = @import("dom_implementation").DOMImplementation;
pub const Document = @import("document").Document;
pub const AbstractRange = @import("abstract_range").AbstractRange;
pub const StaticRange = @import("static_range").StaticRange;
pub const Range = @import("range").Range;
pub const NodeFilter = @import("node_filter").NodeFilter;
pub const NodeIterator = @import("node_iterator").NodeIterator;
pub const TreeWalker = @import("tree_walker").TreeWalker;
pub const MutationRecord = @import("mutation_record").MutationRecord;
pub const MutationObserver = @import("mutation_observer").MutationObserver;
pub const MutationObserverInit = @import("mutation_observer_init").MutationObserverInit;
pub const RegisteredObserver = @import("registered_observer").RegisteredObserver;
pub const TransientRegisteredObserver = @import("registered_observer").TransientRegisteredObserver;

// XPath interfaces
pub const XPathResult = @import("xpath_result").XPathResult;
pub const XPathExpression = @import("xpath_expression").XPathExpression;
pub const XPathEvaluator = @import("xpath_evaluator").XPathEvaluator;

// DOM implementation algorithms
pub const tree = @import("tree.zig");
pub const tree_helpers = @import("tree_helpers.zig");
pub const mutation = @import("mutation.zig");
pub const mutation_observer_algorithms = @import("mutation_observer_algorithms.zig");
pub const shadow_dom_algorithms = @import("shadow_dom_algorithms.zig");
pub const selectors = @import("selectors.zig");
pub const fast_path = @import("fast_path.zig");
pub const html_mock = @import("html_mock.zig");

// Base types for interface inheritance (NodeBase pattern)
pub const node_base = @import("node_base.zig");
pub const NodeBase = node_base.NodeBase;

// Temporary bridge types with NodeBase pattern (until codegen is updated)
pub const element_with_base = @import("element_with_base.zig");
pub const ElementWithBase = element_with_base.ElementWithBase;
pub const text_with_base = @import("text_with_base.zig");
pub const TextWithBase = text_with_base.TextWithBase;
pub const CommentWithBase = text_with_base.CommentWithBase;
pub const attr_with_base = @import("attr_with_base.zig");
pub const AttrWithBase = attr_with_base.AttrWithBase;

// XPath 1.0 implementation
pub const xpath = struct {
    pub const tokenizer = @import("xpath/tokenizer.zig");
    pub const ast = @import("xpath/ast.zig");
    pub const parser = @import("xpath/parser.zig");
    pub const value = @import("xpath/value.zig");
    pub const context = @import("xpath/context.zig");
    pub const functions = @import("xpath/functions.zig");
    pub const evaluator = @import("xpath/evaluator.zig");
};

test {
    std.testing.refAllDecls(@This());
}
