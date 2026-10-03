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
pub const HTMLCollection = interfaces.HTMLCollection;
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
pub const abort_algorithms = @import("abort_algorithms.zig");
pub const fire_event = @import("fire_event.zig");
pub const message_ports = @import("message_ports.zig");
pub const cloning_steps = @import("cloning_steps.zig");
pub const range_boundaries = @import("range_boundaries.zig");
pub const node_document = @import("node_document.zig");
pub const navigable_container = @import("navigable_container.zig");
pub const document_lifecycle = @import("document_lifecycle.zig");
pub const document_fetches = @import("document_fetches.zig");
pub const document_origin = @import("document_origin.zig");
pub const window_documents = @import("window_documents.zig");
pub const child_navigables = @import("child_navigables.zig");
pub const window_globals = @import("window_globals.zig");
pub const content_navigables = @import("content_navigables.zig");
pub const style_sheet_owners = @import("style_sheet_owners.zig");
pub const attribute_change_steps = @import("attribute_change_steps.zig");
pub const script_elements = @import("script_elements.zig");
pub const activation = @import("activation.zig");
pub const form_controls = @import("form_controls.zig");
pub const form_submission = @import("form_submission.zig");
pub const node_lists = @import("node_lists.zig");
pub const teardown_sweeps = @import("teardown_sweeps.zig");
pub const unloading_cleanup = @import("unloading_cleanup.zig");
pub const process_start = @import("process_start.zig");
pub const event_construction = @import("event_construction.zig");
pub const navigables = @import("navigables.zig");
pub const navigation_api = @import("navigation_api.zig");
pub const navigation_objects = @import("navigation_objects.zig");
pub const top_level_navigation = @import("top_level_navigation.zig");
pub const intersection_targets = @import("intersection_targets.zig");
pub const navigation_history_entries = @import("navigation_history_entries.zig");
pub const history_traversal = @import("history_traversal.zig");
pub const auxiliary_navigables = @import("auxiliary_navigables.zig");
pub const global_settings = @import("global_settings.zig");
pub const fetch_objects = @import("fetch_objects.zig");
pub const blob_bytes = @import("blob_bytes.zig");
pub const names = @import("names.zig");
pub const element_attributes = @import("element_attributes.zig");
pub const observer_registrations = @import("observer_registrations.zig");
pub const attr_nodes = @import("attr_nodes.zig");
pub const traversal = @import("traversal.zig");
pub const live_collections = @import("live_collections.zig");
pub const token_lists = @import("token_lists.zig");
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
pub const cookie_change_event = @import("cookie_change_event.zig");
pub const document_internals = @import("document_internals.zig");
/// The CSSOM's model: what CSSStyleSheet, CSSRuleList and the CSSRule
/// objects wrap.
pub const cssom = @import("cssom.zig");
/// A Document's script lists, currentScript and what the script processing
/// model asks of it - its ScriptRunner - and its module and import maps.
pub const document_scripts = @import("document_scripts.zig");
pub const document_modules = @import("document_modules.zig");
/// A Document's browsing context's window, as a frame's parser sets it.
pub const document_browsing_context = @import("document_browsing_context.zig");
/// What the parsers' tree construction sets on the nodes it makes where no
/// IDL member fits: an element's names, a doctype's identifiers.
pub const node_creation = @import("node_creation.zig");
/// HTML's user activation timestamps, the focused area of a document and a
/// document's visibility state: the hooks the user input algorithms reach
/// Window's and Document's state through (src/html/user_activation.zig,
/// focus.zig).
pub const user_activation_state = @import("user_activation_state.zig");
pub const focused_area = @import("focused_area.zig");
pub const visibility_state = @import("visibility_state.zig");
pub const focus_matching = @import("focus_matching.zig");

// Re-export slot_helpers functions
pub const isElement = slot_helpers.isElement;
pub const isSlottable = slot_helpers.isSlottable;
pub const isSlot = slot_helpers.isSlot;

// Re-export CookieChangeEvent
pub const CookieChangeEvent = cookie_change_event.CookieChangeEvent;
pub const CookieChangeEventInit = cookie_change_event.CookieChangeEventInit;

// Re-export selector functions
pub const scopeMatchSelectorsString = selectors.scopeMatchSelectorsString;

// Base types for interface inheritance (NodeBase pattern)
pub const node_base = @import("node_base.zig");
pub const NodeBase = node_base.NodeBase;

// Instance bridge for runtime.Instance <-> NodeBase conversion
pub const instance_bridge = @import("instance_bridge.zig");

// Opaque handle types for breaking circular imports
pub const handles = @import("handles.zig");

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

pub const boundary_points = @import("boundary_points.zig");
pub const target_element = @import("target_element.zig");
pub const fragment_scroll = @import("fragment_scroll.zig");
pub const shadow_hosts = @import("shadow_hosts.zig");

pub const indexeddb = @import("indexeddb.zig");
pub const string_lists = @import("string_lists.zig");
pub const event_handlers = @import("event_handlers.zig");

test {
    std.testing.refAllDecls(@This());
}

pub const indexeddb_keys = @import("indexeddb_keys.zig");
