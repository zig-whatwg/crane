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
pub const retarget = @import("retarget.zig");
pub const html_pseudo_classes = @import("html_pseudo_classes.zig");
pub const tree_helpers = @import("tree_helpers.zig");
pub const mutation = @import("mutation.zig");
pub const abort_algorithms = @import("abort_algorithms.zig");
pub const crypto_keys = @import("crypto_keys.zig");
pub const dom_exceptions = @import("dom_exceptions.zig");
pub const fire_event = @import("fire_event.zig");
pub const message_ports = @import("message_ports.zig");
/// Message channels whose two ends may live on two threads: the port
/// message queues and entanglement MessagePort and a worker's implicit
/// ports share.
pub const port_channels = @import("port_channels.zig");
pub const cloning_steps = @import("cloning_steps.zig");
pub const selection = @import("selection.zig");
pub const range_boundaries = @import("range_boundaries.zig");
/// A list the mutation algorithms walk while its entries may leave it: a
/// document's live ranges and NodeIterators.
pub const live_range_list = @import("live_range_list.zig");
pub const node_document = @import("node_document.zig");
pub const template_contents = @import("template_contents.zig");
pub const navigable_container = @import("navigable_container.zig");
pub const document_lifecycle = @import("document_lifecycle.zig");
pub const document_fetches = @import("document_fetches.zig");
/// Fire-and-forget fetches (sendBeacon, Reporting uploads, hyperlink
/// auditing): self-freeing, accepted or rejected synchronously.
pub const keepalive_fetch = @import("keepalive_fetch.zig");
/// fetchLater()'s deferred fetch records: queued in their fetch group,
/// sent when it is terminated, cached, or their activateAfter comes.
pub const deferred_fetches = @import("deferred_fetches.zig");
/// HTML's origin as the object documents share, reference counted.
pub const origin_record = @import("origin_record.zig");
pub const document_origin = @import("document_origin.zig");
pub const document_language = @import("document_language.zig");
pub const window_documents = @import("window_documents.zig");
pub const child_navigables = @import("child_navigables.zig");
pub const cross_origin = @import("cross_origin.zig");
pub const window_globals = @import("window_globals.zig");
pub const content_navigables = @import("content_navigables.zig");
pub const style_sheet_owners = @import("style_sheet_owners.zig");
pub const attribute_change_steps = @import("attribute_change_steps.zig");
pub const adopting_steps = @import("adopting_steps.zig");
pub const document_rendering = @import("document_rendering.zig");
pub const update_the_rendering = @import("update_the_rendering.zig");
pub const finish_parsing_children = @import("finish_parsing_children.zig");
pub const script_elements = @import("script_elements.zig");
pub const activation = @import("activation.zig");
pub const form_controls = @import("form_controls.zig");
pub const selected_content = @import("selected_content.zig");
pub const top_layer = @import("top_layer.zig");
pub const dialog = @import("dialog.zig");
pub const form_submission = @import("form_submission.zig");
pub const form_past_names = @import("form_past_names.zig");
pub const node_lists = @import("node_lists.zig");
/// Node holds: native references that keep nodes alive without a wrapper
/// per node, and the removing steps that rescue a held tree's root.
pub const node_holds = @import("node_holds.zig");
pub const teardown_sweeps = @import("teardown_sweeps.zig");
/// A node type's own state block with both of its exits: its deinit's, and
/// its type's sweep for an orphan no deinit reaches.
pub const orphan_states = @import("orphan_states.zig");
pub const unloading_cleanup = @import("unloading_cleanup.zig");
pub const editor_states = @import("editor_states.zig");
pub const idle_periods = @import("idle_periods.zig");
pub const document_activity = @import("document_activity.zig");
pub const document_autofocus = @import("document_autofocus.zig");
/// A Document's back/forward cache state: "make document unsalvageable", its
/// bfcache blocking details, and building not restored reasons.
pub const bfcache = @import("bfcache.zig");
pub const process_start = @import("process_start.zig");
pub const event_construction = @import("event_construction.zig");
pub const navigables = @import("navigables.zig");
pub const navigation_api = @import("navigation_api.zig");
pub const navigation_objects = @import("navigation_objects.zig");
pub const top_level_traversables = @import("top_level_traversables.zig");
pub const intersection_targets = @import("intersection_targets.zig");
pub const navigation_history_entries = @import("navigation_history_entries.zig");
pub const history_traversal = @import("history_traversal.zig");
pub const auxiliary_navigables = @import("auxiliary_navigables.zig");
pub const global_settings = @import("global_settings.zig");
pub const extract_origin = @import("extract_origin.zig");
pub const client_message_queues = @import("client_message_queues.zig");
pub const service_worker_clients = @import("service_worker_clients.zig");
/// Origin-Agent-Cluster and each browsing context group's historical agent
/// cluster key map: whether a window's agent cluster is origin-keyed.
pub const agent_cluster_keys = @import("agent_cluster_keys.zig");
/// The Browser's web state a realm reaches through its scope.
pub const browser_state = @import("browser_state.zig");
/// A blob URL's storage partition outside the store: a frame's blob:
/// navigation's key, and the blob-URL noopener rule.
pub const blob_partition = @import("blob_partition.zig");
/// The fetches of a realm's agent, which its event loop pumps.
pub const agent_fetches = @import("agent_fetches.zig");
/// The CookieStores that hear their Browser's cookie jar, on any thread.
pub const cookie_change_listeners = @import("cookie_change_listeners.zig");
/// The Performance Timeline: each global's entry buffers and registered
/// performance observers, kept by its Performance object.
pub const performance_timeline = @import("performance_timeline.zig");
pub const policy_containers = @import("policy_containers.zig");
/// CSP 5.5 report a violation: the securitypolicyviolation event at the
/// global's side.
pub const csp_violations = @import("csp_violations.zig");
pub const sri_reporting = @import("sri_reporting.zig");
pub const reporting = @import("reporting.zig");
/// Trusted Types enforcement: get trusted type compliant string, the
/// default policy, compliant attribute values.
pub const trusted_types = @import("trusted_types.zig");
pub const fetch_objects = @import("fetch_objects.zig");
pub const blob_bytes = @import("blob_bytes.zig");
pub const text_stream = @import("text_stream.zig");
/// A CharacterData node's data, read in place by the tree's own algorithms.
pub const character_data = @import("character_data.zig");
pub const geometry_storage = @import("geometry_storage.zig");
pub const names = @import("names.zig");
pub const pi_attributes = @import("pi_attributes.zig");
/// HTML's document-relative URL parsing with its character encoding.
pub const encoding_parse = @import("encoding_parse.zig");
pub const element_attributes = @import("element_attributes.zig");
pub const reflected_with_fallback = @import("reflected_with_fallback.zig");
/// An element's attribute list, ID, classes and qualified name, read in
/// place by the tree's own algorithms (WebKit's ElementData).
pub const element_data = @import("element_data.zig");
/// HTML's algorithms for reflecting content attributes in IDL attributes.
pub const reflection = @import("reflection.zig");
/// The generated [SameObject] caches' edges: an owner keeps the child it
/// cached, whoever read it first (binding3 item 9h).
pub const same_object_cache = @import("same_object_cache.zig");
pub const observer_registrations = @import("observer_registrations.zig");
pub const attr_nodes = @import("attr_nodes.zig");
pub const traversal = @import("traversal.zig");
pub const live_collections = @import("live_collections.zig");
/// A tree scope's maps from IDs - and a document's, from its named
/// properties' names - to its elements (getElementById, named access).
pub const tree_ordered_map = @import("tree_ordered_map.zig");
pub const token_lists = @import("token_lists.zig");
pub const mutation_observer_algorithms = @import("mutation_observer_algorithms.zig");
pub const shadow_dom_algorithms = @import("shadow_dom_algorithms.zig");
pub const range_tracking = @import("range_tracking.zig");
pub const event_dispatch = @import("event_dispatch.zig");
/// DOM 2.9 dispatch steps 4-6.11: building an event's path across shadow
/// trees (retargeting, the shadow-tree booleans, activationTarget,
/// clearTargets).
pub const event_path = @import("event_path.zig");
pub const selectors = @import("selectors.zig");
/// querySelector / matches / closest over platform objects.
pub const selector_matching = @import("selector_matching.zig");
/// The elements a Document's :hover and :active rest on.
pub const pointer_states = @import("pointer_states.zig");
pub const fast_path = @import("fast_path.zig");
pub const html_mock = @import("html_mock.zig");
pub const attribute_algorithms = @import("attribute_algorithms.zig");
pub const dom_token_list = @import("dom_token_list.zig");
pub const DOMTokenListImpl = dom_token_list.DOMTokenList;
pub const range_mutations = @import("range_mutations.zig");
pub const slot_helpers = @import("slot_helpers.zig");
pub const cookie_change_event = @import("cookie_change_event.zig");
pub const document_internals = @import("document_internals.zig");
pub const document_last_modified = @import("document_last_modified.zig");
/// The CSSOM's model: what CSSStyleSheet, CSSRuleList and the CSSRule
/// objects wrap.
/// The style engine: cascade and computed style (src/dom/style/).
pub const style = @import("style/root.zig");
/// A Document's script lists, currentScript and what the script processing
/// model asks of it - its ScriptRunner - and its module and import maps.
pub const document_scripts = @import("document_scripts.zig");
pub const document_modules = @import("document_modules.zig");
/// A Document's browsing context's window, as a frame's parser sets it.
pub const document_browsing_context = @import("document_browsing_context.zig");
pub const element_references = @import("element_references.zig");
pub const accessibility = @import("accessibility.zig");
/// What the parsers' tree construction sets on the nodes it makes where no
/// IDL member fits: an element's names, a doctype's identifiers.
pub const node_creation = @import("node_creation.zig");
/// Freeing a detached tree a bounded number of nodes at a time, leaves first
/// (the agent's deferred teardown queue, runtime.gc.DeferredTeardown).
pub const tree_teardown = @import("tree_teardown.zig");
pub const custom_elements = @import("custom_elements.zig");
/// HTML's user activation timestamps, the focused area of a document and a
/// document's visibility state: the hooks the user input algorithms reach
/// Window's and Document's state through (src/html/user_activation.zig,
/// focus.zig).
pub const user_activation_state = @import("user_activation_state.zig");
/// HTML 6.10.2: each Window's close watcher manager (src/html/close_watchers.zig).
pub const close_watcher_manager = @import("close_watcher_manager.zig");
pub const focused_area = @import("focused_area.zig");
pub const visibility_state = @import("visibility_state.zig");
pub const focus_matching = @import("focus_matching.zig");
/// A FileList's contents, set natively by its owners (an input's selected
/// files, a DataTransfer's files): the hook FileList installs.
pub const file_lists = @import("file_lists.zig");
/// HTML 6.11.2 the drag data store a DataTransfer owns, and the hooks its
/// item list and items are made through.
pub const drag_data_store = @import("drag_data_store.zig");

// Re-export CookieChangeEvent
pub const CookieChangeEvent = cookie_change_event.CookieChangeEvent;
pub const CookieChangeEventInit = cookie_change_event.CookieChangeEventInit;

// Re-export selector functions
pub const scopeMatchSelectorsString = selectors.scopeMatchSelectorsString;

// Base types for interface inheritance (NodeBase pattern)
pub const node_base = @import("node_base.zig");
/// Reference counting for nodes: `Ref`, `GCReachableRef`, `WeakRef` and the
/// agent's ledger (lane rc12, tmp/plans/refcount-design.md). Unused by
/// production code until step 3.
pub const refcount = @import("refcount.zig");
/// Refcount step 6, the zombie audit (CRANE_REFCOUNT_AUDIT; lane refcount7).
pub const refcount_audit = @import("refcount_audit.zig");
pub const NodeBase = node_base.NodeBase;

// Instance bridge for runtime.Instance <-> NodeBase conversion
pub const instance_bridge = @import("instance_bridge.zig");
/// One element type's inline state in its Browser's side table, keyed by
/// address, with its tombstones kept in check (HTMLOptionElement's and
/// HTMLTextAreaElement's StateMaps).
pub const InstanceStateMap = @import("instance_state_map.zig").InstanceStateMap;

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
pub const ancestor_revealing = @import("ancestor_revealing.zig");
pub const shadow_hosts = @import("shadow_hosts.zig");
pub const declarative_shadow = @import("declarative_shadow.zig");

pub const indexeddb = @import("indexeddb.zig");
pub const string_lists = @import("string_lists.zig");
pub const event_handlers = @import("event_handlers.zig");
/// Whether an event target has a listener of a type (EventTarget's step):
/// a service worker's set of event types to handle.
pub const event_listener_types = @import("event_listener_types.zig");
/// A URLPattern object's associated URL pattern (URLPattern's step): a
/// router condition's urlPattern.
pub const url_patterns = @import("url_patterns.zig");
/// HTML 7.1.5 sandboxing flag sets: parsing, CSP-derived and creation flags.
pub const sandboxing = @import("sandboxing.zig");

test {
    std.testing.refAllDecls(@This());
}

pub const indexeddb_keys = @import("indexeddb_keys.zig");

/// HTML media owner algorithms without an IDL member.
pub const media_elements = @import("media_elements.zig");
pub const image_sources = @import("image_sources.zig");

/// CSS Scoping tree identities, owned by Document and ShadowRoot.
pub const tree_scope = @import("tree_scope.zig");
