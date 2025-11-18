//! WHATWG DOM Standard Implementation
//!
//! Spec: https://dom.spec.whatwg.org/

const std = @import("std");

// Dependencies
pub const infra = @import("infra");
pub const webidl = @import("webidl");

// WebIDL interface definitions (from src/interfaces/)
// These use the runtime system for VTable dispatch and memory management
const interfaces = @import("interfaces");

pub const AbortSignal = interfaces.AbortSignal;
pub const AbortController = interfaces.AbortController;
pub const EventTarget = interfaces.EventTarget;
pub const Event = interfaces.Event;
pub const Node = interfaces.Node;
pub const NodeList = interfaces.NodeList;
pub const NamedNodeMap = interfaces.NamedNodeMap;
pub const Element = interfaces.Element;
pub const CharacterData = interfaces.CharacterData;
pub const Text = interfaces.Text;
pub const Comment = interfaces.Comment;
pub const ProcessingInstruction = interfaces.ProcessingInstruction;
pub const CDATASection = interfaces.CDATASection;
pub const DocumentType = interfaces.DocumentType;
pub const DocumentFragment = interfaces.DocumentFragment;
pub const ShadowRoot = interfaces.ShadowRoot;
pub const HTMLSlotElement = interfaces.HTMLSlotElement;
pub const DOMTokenList = interfaces.DOMTokenList;
pub const Attr = interfaces.Attr;
pub const DOMImplementation = interfaces.DOMImplementation;
pub const Document = interfaces.Document;
pub const AbstractRange = interfaces.AbstractRange;
pub const StaticRange = interfaces.StaticRange;
pub const Range = interfaces.Range;
pub const NodeFilter = interfaces.NodeFilter;
pub const NodeIterator = interfaces.NodeIterator;
pub const TreeWalker = interfaces.TreeWalker;
pub const MutationRecord = interfaces.MutationRecord;
pub const MutationObserver = interfaces.MutationObserver;

// XPath interfaces
pub const XPathResult = interfaces.XPathResult;
pub const XPathExpression = interfaces.XPathExpression;
pub const XPathEvaluator = interfaces.XPathEvaluator;

// DOM implementation algorithms
pub const tree = @import("tree.zig");
pub const tree_helpers = @import("tree_helpers.zig");
pub const mutation = @import("mutation.zig");
pub const mutation_observer_algorithms = @import("mutation_observer_algorithms.zig");
pub const shadow_dom_algorithms = @import("shadow_dom_algorithms.zig");
pub const range_tracking = @import("range_tracking.zig");
pub const event_dispatch = @import("event_dispatch.zig");
pub const selectors = @import("selectors.zig");
pub const fast_path = @import("fast_path.zig");
pub const html_mock = @import("html_mock.zig");
pub const attribute_algorithms = @import("attribute_algorithms.zig");
pub const dom_token_list = @import("dom_token_list.zig");
pub const DOMTokenListImpl = dom_token_list.DOMTokenList;
pub const range_mutations = @import("range_mutations.zig");
pub const slot_helpers = @import("slot_helpers.zig");

// Re-export slot_helpers functions
pub const isElement = slot_helpers.isElement;
pub const asElement = slot_helpers.asElement;

// Re-export selector functions
pub const scopeMatchSelectorsString = selectors.scopeMatchSelectorsString;

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
