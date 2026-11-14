//! Implementation for Node interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-node
//! WHATWG DOM Standard §4.4
//!
//! Node is the primary datatype for the entire DOM. It represents a single node
//! in the document tree. Node extends EventTarget, so all nodes can receive events.

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const infra = @import("infra");
const Node = interfaces.Node;

// Import DOM module for unified tree implementation
// Note: We alias as dom_module to avoid conflict with local `dom` declarations
const dom_module = @import("dom");
const instance_bridge = dom_module.instance_bridge;
const NodeBase = dom_module.NodeBase;

pub const State = Node.State;

const log = std.log.scoped(.node);
const refcount_log = std.log.scoped(.refcount);

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    HierarchyRequestError,
    NotFoundError,
    OutOfMemory,
};

/// DOM §4.4 Node types
/// https://dom.spec.whatwg.org/#node
pub const NodeType = struct {
    pub const ELEMENT_NODE: u16 = 1;
    pub const ATTRIBUTE_NODE: u16 = 2;
    pub const TEXT_NODE: u16 = 3;
    pub const CDATA_SECTION_NODE: u16 = 4;
    pub const ENTITY_REFERENCE_NODE: u16 = 5; // legacy
    pub const ENTITY_NODE: u16 = 6; // legacy
    pub const PROCESSING_INSTRUCTION_NODE: u16 = 7;
    pub const COMMENT_NODE: u16 = 8;
    pub const DOCUMENT_NODE: u16 = 9;
    pub const DOCUMENT_TYPE_NODE: u16 = 10;
    pub const DOCUMENT_FRAGMENT_NODE: u16 = 11;
    pub const NOTATION_NODE: u16 = 12; // legacy
};

/// Document position flags for compareDocumentPosition
/// https://dom.spec.whatwg.org/#dom-node-comparedocumentposition
pub const DocumentPosition = struct {
    pub const DISCONNECTED: u16 = 0x01;
    pub const PRECEDING: u16 = 0x02;
    pub const FOLLOWING: u16 = 0x04;
    pub const CONTAINS: u16 = 0x08;
    pub const CONTAINED_BY: u16 = 0x10;
    pub const IMPLEMENTATION_SPECIFIC: u16 = 0x20;
};

/// Internal state for Node implementation
/// Uses NodeBase for tree structure - single source of truth in src/dom/
/// Tree operations delegate to src/dom/mutation.zig
pub const InternalState = struct {
    /// Kept by value in this interface's own State (runtime.OwnState, the
    /// State's `_embedded`; lane perf2 batch 5, Z7): a node is one block.
    pub const embedded_in_state = true;

    /// This is the node's state: an instance whose chain keeps it is a
    /// counted node - its wrapper owns a reference, and its NodeBase holds
    /// the wrapper slot (runtime.lifetime.countedOf reads this declaration).
    pub const counted_node = true;

    // No allocator copy (lane perf2 batch 6): what the node allocates comes
    // from its Browser's allocator, runtime.allocatorOf(instance) - the one it
    // was made with, asserted in initOwn.

    // No pointer to its own NodeBase and no second node type (lane nm1's
    // layout batch; node-memory-plan-v2 section 6 items 4-5, the design's
    // N4): `node_base` was always `&base` while the node lived and null
    // once its teardown released it - which is exactly this level's live bit
    // (runtime.OwnState: `releaseNodeBase` clears it), so a holder of this
    // state holds a live NodeBase - and `node_type` was a copy of the
    // NodeBase's. 16 bytes a node.

    /// The node's NodeBase, by value (lane perf2 batch 5, Z7): with this
    /// state in the node's State block, the tree node is in that block too -
    /// one allocation per node, as a Blink or WebKit Node is one object. Its
    /// address lives as long as the block: released by the node's teardown,
    /// its bytes go back with the block (gc.releaseStorage, after the
    /// destruction chain).
    base: NodeBase,

    // No local name, namespace, prefix or node value here (lane perf2 b5:
    // 128 bytes on every node, set on 186 of 6.07 M - and never read): an
    // element's names are its ElementData's, a CharacterData's value its
    // data, an Attr's value its own state, a PI's target its own.

    /// The owner document for this node
    /// Document nodes return null from ownerDocument getter
    owner_document: ?*runtime.Instance = null,
    /// `owner_document`'s slab generation when it was set: the net under the
    /// rule that a node keeps its document (its referencing-node count, and
    /// for its wrappers the walk's D6 rule, dom.wrapper_tracing).
    /// A document freed under a node that names it - a hole in that rule -
    /// reads as an error and a log line, never as the freed object.
    owner_document_generation: u64 = 0,

    // No childNodes list here (lane nm1): the interface's [SameObject] cache
    // (the generated State's `cached_childNodes`) is the one copy; this
    // state kept a second pointer to the same list. 8 bytes a node.

    // isConnected reads NodeBase.is_connected, kept by the insertion and
    // removing steps; this state kept a copy nothing set.

    /// Owns nothing: the NodeBase is released by `releaseNodeBase`.
    pub fn deinit(self: *InternalState) void {
        _ = self;
    }
};

// Its internal state, in its own generated State (`own._internal`): runtime.OwnState.
const utils = @import("webidl").utils;
const Registry = runtime.OwnState(State, InternalState);

/// Get the internal state from an instance
fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const internal = Registry.get(instance) orelse return null;
    // Refcount step 6: a read of a node step 7 would have freed is reported.
    if (dom_module.refcount_audit.on()) dom_module.refcount_audit.checkRead(&internal.base, .node_state, @returnAddress());
    return internal;
}

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    // Its states and NodeBases left at its Browser's end (Browser.deinit).
    dom_module.teardown_sweeps.install(.nodes, &sweepRemaining);
    // dom.instance_bridge reaches a node's NodeBase through its state here,
    // before any node exists.
    instance_bridge.install(.{ .node_base_of = &nodeBaseOf });
    // Every other node creator sets a node document through
    // `dom.node_document`, never through this impl. The hook is installed
    // here, before anything can hold this node to set its document.
    dom_module.node_document.install(.{ .set = &setNodeDocumentHook });
    // The reference counts reach a node's live node document through here.
    dom_module.refcount.install(.{ .node_document_counts = &nodeDocumentCounts, .child_nodes_freed = &childNodesFreed });
    // And a parser's DOM adapter frees a node it made and never inserted
    // through `dom.node_creation`, as the tree teardown frees a child.
    dom_module.node_creation.installNode(.{
        .destroy_uninserted = &destroyUninsertedHook,
        .clone = &cloneANode,
        .set_local_name = &setLocalNameHook,
    });
    // A realm's end frees the orphans its removals recorded (dom.mutation's
    // orphanRemoved), each through its own teardown as a tree frees a child.
    runtime.orphan_roots.install(.{ .still_orphan = &stillOrphan, .free = &deinitNodeByType });
}

/// dom.instance_bridge's `node_base_of`: the NodeBase in `instance`'s own
/// Node state, or null when it is no node or its NodeBase is gone.
fn nodeBaseOf(instance: *runtime.Instance) ?*NodeBase {
    const internal = Registry.get(instance) orelse return null;
    return &internal.base;
}

/// runtime.orphan_roots' check, for a recorded root whose generation and
/// cleanup flags still name it: still parentless, and still reached by no
/// wrapper - not wrapped since its removal, in any realm ([wrap_tracking]) -
/// nor any node of its tree. Since the wrapper redesign's P7 a wrap reaches
/// no ancestor, so a node of the tree can be wrapped under an unwrapped
/// root: its wrapper's reference holds the tree, and the counts (refcount
/// step 7) free it once that wrapper goes. Only a wrapper refuses: a tree
/// held by holders' counts alone is freed here as before P7 (dom.mutation
/// orphanRemoved says why; refcount step 7b owns that drain).
fn stillOrphan(instance: *runtime.Instance) bool {
    const internal = Registry.get(instance) orelse return false;
    const node_base = &internal.base;
    if (node_base.parent_node != null or !node_base.wrapper.isEmpty()) return false;
    if (dom_module.wrapper_tracing.holdsWrapper(node_base)) return false;
    return runtime.instance_lifecycle.provablyUnwrapped(engine.capabilities.wrap_tracking != .unsupported, instance);
}

/// Node's own construction steps: the generated chain runs EventTarget's
/// first.
///
/// The node type is a construction fact: the interface the node implements,
/// read off the most-derived State at comptime (`nodeTypeOf`) and stored
/// once - WebKit passes it to Node's constructor, `Node(Document&, NodeType,
/// ...)`, and its `nodeType()` is not virtual. No creation path sets it
/// afterwards.
///
/// Its internal state - the NodeBase in it - is kept by value in this level's
/// own State (`_embedded`, runtime.OwnState): the node is one block.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = args;
    const node_type = comptime nodeTypeOf(StateType);

    // Node's internal state, by value in its own State (runtime.OwnState),
    // and in it the NodeBase - the unified tree structure: one block for the
    // whole node, made zeroed by Instance.init (lane perf2 batch 5, Z7). One
    // write of the whole state, no field left `undefined` (a fill in safe
    // builds).
    const internal = try Registry.create(instance);
    errdefer Registry.remove(instance);
    // Everything the node allocates later, and every free, goes through its
    // Browser's allocator, runtime.allocatorOf (its NodeBase's `allocator()`),
    // found from its address: so the allocator it is made with must BE that
    // one - true in a Browser, whose realms are given its scope's allocator;
    // a test realm is given its scope's too (lane perf2 batch 6;
    // docs/lessons/architecture-a-nodes-creation-allocator-is-its-browsers-
    // only-inside-a-browser.md). Asserted in every safe build: the unit tests
    // and the WPT runner.
    if (std.debug.runtime_safety and !runtime.isScopeAllocator(instance, allocator))
        std.debug.panic("a node ({s}) made with an allocator that is not its Browser's (runtime.allocatorOf would free through another)", .{instance.vtable.name});
    internal.* = .{
        .base = .{
            .node_type = node_type,
            .parent_node = null,
            .first_child = null,
            .previous_or_last = null,
            .next_sibling = null,
            .owner_document = null,
            .is_connected = false,
            // Born with one reference, its creator's (rc_one), which it offers to
            // whoever takes it on first (NodeBase.RcFlags.creator; refcount7) -
            // a Document too, since refcount step 5i (lane refcount8): the
            // holder it is made for (a Window, a template's owner, a resource
            // cache) or its first wrapper takes it over.
            .rc_flags = .{},
        },
    };

    // Register the Instance <-> NodeBase mapping
    try instance_bridge.register(instance, &internal.base);
}

/// DOM 4.4: the node type of a node whose most-derived State is
/// `StateType` - the first node interface on its chain, walking up from the
/// most-derived (so a CDATASection, which is a Text, is CDATA_SECTION_NODE).
/// A State on no node interface's chain (Node or CharacterData made
/// directly, which nothing does) gets ELEMENT_NODE, the default it always had.
fn nodeTypeOf(comptime StateType: type) u16 {
    if (StateType == interfaces.Element.State) return NodeType.ELEMENT_NODE;
    if (StateType == interfaces.Attr.State) return NodeType.ATTRIBUTE_NODE;
    if (StateType == interfaces.CDATASection.State) return NodeType.CDATA_SECTION_NODE;
    if (StateType == interfaces.Text.State) return NodeType.TEXT_NODE;
    if (StateType == interfaces.ProcessingInstruction.State) return NodeType.PROCESSING_INSTRUCTION_NODE;
    if (StateType == interfaces.Comment.State) return NodeType.COMMENT_NODE;
    if (StateType == interfaces.Document.State) return NodeType.DOCUMENT_NODE;
    if (StateType == interfaces.DocumentType.State) return NodeType.DOCUMENT_TYPE_NODE;
    if (StateType == interfaces.DocumentFragment.State) return NodeType.DOCUMENT_FRAGMENT_NODE;
    if (!@hasField(StateType, "base") or @FieldType(StateType, "base") == void) return NodeType.ELEMENT_NODE;
    return nodeTypeOf(@FieldType(StateType, "base"));
}

/// Get Node's internal state
pub fn getInternalState(instance: *runtime.Instance) ?*InternalState {
    const internal = Registry.get(instance) orelse return null;
    // Refcount step 6: a read of a node step 7 would have freed is reported.
    if (dom_module.refcount_audit.on()) dom_module.refcount_audit.checkRead(&internal.base, .node_state, @returnAddress());
    return internal;
}

/// Deinitialize instance
///
/// This frees the node's whole subtree - every descendant, leaves first,
/// without recursion (dom.tree_teardown.freeAllDescendants) - before cleaning
/// up this node's own resources, so the entire subtree is freed when a node
/// is destroyed: its children are no longer reachable through the tree.
pub fn deinit(instance: *runtime.Instance) void {
    // Check if cleanup was already marked as started. A tree's teardown
    // (deinitNodeByType) marks it before the node's own deinit runs; any
    // other caller - the collector's onObjectFreed, a direct call, the
    // realm end's orphaned-iframe phase through HTMLIFrameElement.deinit -
    // may not have, and it is marked now.
    // This handles both cases:
    // 1. Called through type-specific deinit chain: already marked, proceed with cleanup
    // 2. Called directly (e.g., for Text nodes): mark now and proceed
    if (!runtime.instance_lifecycle.isBeingCleanedUp(instance)) {
        // Not yet marked, mark it now
        if (!runtime.instance_lifecycle.markCleanupStarted(instance)) {
            return; // Race condition - someone else started cleanup
        }
    }

    // The host is freeing the node: its wrapper must not free it again.
    // When Document.deinit triggers this cleanup, we're cleaning up the DOM
    // tree, and the engine's wrapper cache also references these nodes;
    // unmarked, its teardown would run deinit again (a double free).
    engine.platformObjectDestroyed(instance);

    // No intersection observer observes it from here on; one whose last
    // target it was lets go of its hold.
    dom_module.intersection_targets.targetDestroyed(instance);

    // First, every descendant goes - leaves first, each unlinked from its
    // parent and torn down only once it has no children left
    // (dom.tree_teardown.freeAllDescendants): the teardown a tree runs for a
    // child, deinitNodeByType, in constant stack at any depth. Calling each
    // child's teardown from here - its Node.deinit calling its children's -
    // took one set of frames per tree level: a 10,000-deep tree overflowed
    // the stack at its teardown (lane crash1). WebKit unlinks each child
    // before its last reference goes (ContainerNodeAlgorithms.cpp
    // removeDetachedChildrenInContainer) and its earlier deletion queue,
    // Blink's until Oilpan, destroyed no node inside its parent's
    // destruction; Oilpan finalizes each node alone.
    //
    // This node's own type-specific teardown has run (the chain reaches here
    // last); its descendants' each run in full, children first. A descendant
    // whose teardown another path began already is unlinked and left to
    // that path (deinitNodeByType's markCleanupStarted), as before.
    if (Registry.get(instance)) |internal| {
        _ = dom_module.tree_teardown.freeAllDescendants(&internal.base, &deinitNodeByType);
        // Releases the NodeBase and clears this level's live bit.
        releaseNodeBase(instance, internal, .with_document_counts);
    }

    // Clean up its internal state
    Registry.remove(instance);

    // Record that cleanup is complete - and keep recording it. While the
    // wrapper cache is tearing down, platformObjectDestroyed cannot flag the
    // entry, so this record is the only thing that stops the cache running
    // this deinit a second time. A reissued slot starts fresh (Instance.init).
    runtime.instance_lifecycle.markCleanupComplete(instance);

    // EventTarget cleanup happens via inheritance chain
    interfaces.EventTarget.deinitChain(instance);
}

/// `dom.node_creation.destroyUninserted` (and `destroyRoot`): the creator
/// drops `instance` neither wrapped nor inserted, so its born reference ends
/// first (refcount7's hand-on point H4; shadow mode frees it now, as before -
/// step 7 makes the release the free's cause), then the node is torn down.
fn destroyUninsertedHook(instance: *runtime.Instance) void {
    if (instance_bridge.getNodeBase(instance)) |base| dom_module.refcount.releaseCreatorReference(base);
    deinitNodeByType(instance);
}

/// Deinitialize a node based on its node type.
/// This dispatches to the appropriate interface's deinit function.
///
/// This is called from Node.deinit's subtree walk (dom.tree_teardown.freeAllDescendants)
/// for each descendant once it has no children left. The type-specific deinit
/// (e.g., Element.deinit) chains back to Node.deinit, which finds no subtree
/// to walk: a tree of any depth is freed in constant stack.
///
/// Also used by DomTreeAdapter to clean up orphaned nodes that were never attached
/// to the document tree.
pub fn deinitNodeByType(instance: *runtime.Instance) void {
    const generation = runtime.SlabAllocator.generationOf(instance);
    if (generation == runtime.SlabAllocator.dead_generation) return;
    const ctx = instance.ctx;
    const teardown_started = runtime.cleanup_coordinator.isContextTearingDown();
    // The teardown is recorded FIRST, before anything of the node runs - and
    // this is the check that it has not begun already (a collection's and a
    // tree's, or two trees'). platformObjectDestroyed below arms the node's
    // wrapper weak, and the node's own deinit runs before Node.deinit's part:
    // a collection inside that window found a teardown that had "not
    // started", and its finalizer ran the node's deinit again, under itself
    // (tests/v8/teardown_gc_window_test.zig). A node with a parent was its
    // tree's anyway (wrapper_cache treeOwns); a root - the parser's adapter
    // frees one through dom.node_creation.destroyUninserted - was not.
    if (!runtime.instance_lifecycle.markCleanupStarted(instance)) return;

    // Whether script can be proven never to have reached this node, read
    // before its teardown frees the NodeBase: no wrap marked it in any realm
    // ([wrap_tracking]) and it has no bound wrapper. The safe default - an
    // engine that does not track wraps, a node with no state to read - is
    // "it may have been".
    var provably_unwrapped = false;

    // A collected child's wrapper can leave its native storage to the tree.
    // Return that storage after the complete type-specific resource teardown,
    // only while the captured generation still names this same instance.
    // Cached wrappers retain their existing storage owner until collection.
    //
    // Never query a wrapper cache during coordinated teardown: its map can
    // still contain already-disposed entries. A retired originating realm
    // also cannot prove absence of wrappers in another live realm. It keeps
    // its agent identity after hasEngine becomes false (ContextData.agent,
    // V8 retireEntry), unlike an engine-less native parser/test context.
    //
    // A node no wrapper ever reached needs no such query: nothing in any
    // realm can reach its slot. During a realm's coordinated teardown its
    // storage goes to the coordinator, which returns it once the teardown's
    // last phase is done (CleanupCoordinator.releaseDeferredStorage) - so
    // nothing the later phases read changes. It used to stay until the
    // Browser ended: every page's unwrapped nodes kept their slots (lane
    // unwrapped1; WebKit's unreferenced children die with their container,
    // ContainerNodeAlgorithms.cpp removeDetachedChildrenInContainer).
    defer {
        if (runtime.SlabAllocator.generationOf(instance) == generation and
            runtime.instance_lifecycle.isCleanedUp(instance))
        {
            if (!teardown_started and !runtime.cleanup_coordinator.isContextTearingDown()) {
                // A retired realm (no engine left, its agent kept) can ask no
                // wrapper cache, and could not prove that no OTHER realm wraps
                // the node - so it kept every slot. The slot's wrap mark is
                // that proof, for every realm ([wrap_tracking]: no engine
                // object bound now). Without it - JavaScriptCore, QuickJS, the
                // test adapter: provably_unwrapped is false - the slot stays,
                // as before. A frame's retired realms' documents, torn down by
                // the deferred teardown queue after their realm lost its
                // engine, kept their html, head and body until the Browser
                // ended (lane pageretention1: 52 of each a pass of 42
                // browsing-the-web files).
                if (if (ctx.hasEngine()) !engine.hasWrapper(instance) else (ctx.agent == null or provably_unwrapped))
                    runtime.gc.releaseStorage(instance);
            } else if (provably_unwrapped and runtime.cleanup_coordinator.isContextTearingDown()) {
                runtime.cleanup_coordinator.deferStorageRelease(instance, generation);
            }
        }
    }

    // Its wrapper must not free it again (engine.platformObjectDestroyed).
    engine.platformObjectDestroyed(instance);

    const internal = Registry.get(instance) orelse {
        // No internal state found, try generic EventTarget cleanup
        interfaces.EventTarget.deinitChain(instance);
        return;
    };
    provably_unwrapped = runtime.instance_lifecycle.provablyUnwrapped(engine.capabilities.wrap_tracking != .unsupported, instance) and
        internal.base.wrapper.isEmpty();

    // Dispatch based on node type to call the appropriate interface's deinit.
    // Each interface's deinit chains back to Node.deinit, which frees the
    // node's subtree (if it still has one: a root) through its links - so
    // DO NOT clear the child links here.
    switch (internal.base.node_type) {
        NodeType.TEXT_NODE => {
            interfaces.Text.deinit(instance);
        },
        NodeType.COMMENT_NODE => {
            interfaces.Comment.deinit(instance);
        },
        NodeType.DOCUMENT_TYPE_NODE => {
            interfaces.DocumentType.deinit(instance);
        },
        NodeType.DOCUMENT_FRAGMENT_NODE => {
            interfaces.DocumentFragment.deinit(instance);
        },
        NodeType.PROCESSING_INSTRUCTION_NODE => {
            interfaces.ProcessingInstruction.deinit(instance);
        },
        NodeType.CDATA_SECTION_NODE => {
            interfaces.CDATASection.deinit(instance);
        },
        NodeType.ELEMENT_NODE => deinitElement(instance),
        NodeType.DOCUMENT_NODE => {
            // Document nodes - this shouldn't typically happen in child iteration
            // but handle it for completeness
            interfaces.Document.deinit(instance);
        },
        else => {
            // For unknown types, do generic Node cleanup
            // (this handles ATTRIBUTE_NODE and legacy types)
            Registry.remove(instance);
            interfaces.EventTarget.deinitChain(instance);
        },
    }
}

/// An element's teardown is its OWN: the deinit its interface's vtable names
/// - the function the collector's finalizer runs for a collected root
/// (gc_integration.onObjectFreed) - which chains through its ancestors'
/// deinits to Node.deinit, and from there to its children. Blink and WebKit
/// destroy a node through its own virtual destructor the same way.
///
/// It used to be chosen by local name, with Element.deinit for every element
/// it did not name: HTMLElement's state (an element's inline style) and the
/// element type's own (an input's dirty value, a textarea's raw value, an
/// object's content navigable) stayed in their address-keyed registries, to
/// be overwritten - leaked - or inherited by the next element the slab put at
/// the address (docs/lessons/architecture-an-address-keyed-entry-a-teardown-misses-is-inherited.md).
///
/// The default is the safe answer: a deinit that never reaches Node's - a
/// codegen stub that does not chain, or none at all - is completed as an
/// Element, so a type nobody audited loses at most its own state, never its
/// node state or its subtree. Every element a tree can hold today chains
/// (tests/html/element_teardown_test.zig makes each one the HTML factory can).
fn deinitElement(instance: *runtime.Instance) void {
    if (instance.vtable.deinit) |own_deinit| own_deinit(instance);
    if (!runtime.instance_lifecycle.isCleanedUp(instance)) {
        log.debug("{s}'s deinit did not reach Node's: completed as an Element", .{instance.vtable.name});
        interfaces.Element.deinit(instance);
    }
}

// =============================================================================
// Getters
// =============================================================================

/// Getter for nodeType
/// https://dom.spec.whatwg.org/#dom-node-nodetype
/// Returns an integer corresponding to the type of the node
pub fn get_nodeType(instance: *runtime.Instance) anyerror!u16 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.base.node_type;
}

/// Getter for nodeName
/// https://dom.spec.whatwg.org/#dom-node-nodename
/// Returns a string appropriate for the type of node
pub fn get_nodeName(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    return switch (internal.base.node_type) {
        NodeType.ELEMENT_NODE => blk: {
            // For Element: its HTML-uppercased qualified name - which is
            // exactly what Element.tagName is defined as (DOM 4.9), so this
            // delegates rather than reimplementing the namespace and prefix
            // rules.
            //
            // It must NOT read `internal.local_name`: an element's local name
            // lives in ELEMENT's state, not Node's, so that field is null for
            // every element and `nodeName` came back "" while `localName` was
            // correct. Same shape as CharacterData data living in
            // CharacterData rather than Node.node_value.
            break :blk interfaces.Element.get_tagName(instance) catch
                runtime.DOMString.initEmpty();
        },
        // Attr: its qualified name - the Attr impl's, cloned for the caller.
        NodeType.ATTRIBUTE_NODE => interfaces.Attr.get_name(instance) catch runtime.DOMString.initEmpty(),
        NodeType.TEXT_NODE => runtime.DOMString.initInterned("#text"),
        NodeType.CDATA_SECTION_NODE => runtime.DOMString.initInterned("#cdata-section"),
        // ProcessingInstruction: its target - ProcessingInstruction's, read
        // through its IDL member as Element's tagName is above (Node's
        // local_name is never set for one, so nodeName came back "").
        NodeType.PROCESSING_INSTRUCTION_NODE => interfaces.ProcessingInstruction.get_target(instance) catch runtime.DOMString.initEmpty(),
        NodeType.COMMENT_NODE => runtime.DOMString.initInterned("#comment"),
        NodeType.DOCUMENT_NODE => runtime.DOMString.initInterned("#document"),
        NodeType.DOCUMENT_TYPE_NODE => interfaces.DocumentType.get_name(instance) catch runtime.DOMString.initEmpty(),
        NodeType.DOCUMENT_FRAGMENT_NODE => runtime.DOMString.initInterned("#document-fragment"),
        else => runtime.DOMString.initEmpty(),
    };
}

/// Getter for baseURI
/// Spec: https://dom.spec.whatwg.org/#dom-node-baseuri - "this's node
/// document's document base URL, serialized".
///
/// HTML "document base URL": the frozen base URL of the first `base` element
/// with an `href` attribute in tree order, and otherwise the document's
/// fallback base URL: its about base URL - what an about:srcdoc or
/// about:blank document inherits from its creator - or else its URL.
///
/// The binding frees the returned string.
pub fn get_baseURI(instance: *runtime.Instance) anyerror!runtime.USVString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const document = if (internal.base.node_type == NodeType.DOCUMENT_NODE)
        instance
    else
        internal.owner_document orelse return error.InvalidStateError;
    const allocator = instance.ctx.allocator;

    // HTML document base URL step 1: the first base[href]'s URL is frozen
    // by its mutation steps, not re-resolved against a later history URL.
    if (@import("dom").document_internals.getFrozenBaseURL(document)) |frozen| {
        return allocator.dupe(u8, frozen);
    }
    // Step 2 TODO(DOM clone owner): the base URL override set by DOM's
    // "clone a single node" Document step 2 has no producer yet.
    // Step 3: return the fallback.

    // The fallback base URL: step 1, an about:blank or iframe srcdoc
    // document's about base URL - its creator's base - when it has one, and
    // otherwise (step 2) the document's URL. The getter clones into the
    // document's allocator.
    const url = try interfaces.Document.get_URL(document);
    defer document.ctx.allocator.free(url);
    const fallback = @import("dom").document_lifecycle.aboutFallbackBaseUrl(document) orelse url;

    return allocator.dupe(u8, fallback);
}

/// Getter for isConnected
/// https://dom.spec.whatwg.org/#dom-node-isconnected
/// Returns true if the node is connected (its shadow-including root is a document)
///
/// Per DOM spec, a node is connected if its root is a document. For shadow trees,
/// we must follow the shadow host chain to determine connection status:
/// - If root is a Document, the node is connected
/// - If root is a ShadowRoot, check if its host element is connected
///
/// This implementation first checks the cached is_connected flag, then falls back
/// to dynamic computation for shadow DOM nodes where the flag may not be set correctly.
pub fn get_isConnected(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const node_base = &internal.base;

    // Fast path: if cached value is true, we're connected
    if (node_base.is_connected) {
        return true;
    }

    // Slow path: compute dynamically for shadow DOM support
    // Walk up to find the root and check shadow hosts
    return isConnectedThroughShadow(instance, node_base);
}

/// Compute isConnected dynamically, following shadow hosts
/// This handles cases where a node is in a shadow tree whose host is connected
fn isConnectedThroughShadow(instance: *runtime.Instance, node_base: *NodeBase) bool {
    _ = instance;

    // Find the root node
    var current: *const NodeBase = node_base;
    while (current.parent_node) |parent| {
        current = parent;
    }

    // If root is a Document, we're connected
    if (current.node_type == NodeType.DOCUMENT_NODE) {
        return true;
    }

    // If root is a DocumentFragment, check if it's a ShadowRoot with a connected host
    if (current.node_type == NodeType.DOCUMENT_FRAGMENT_NODE) {
        // Get the runtime.Instance for this DocumentFragment
        const root_opaque = instance_bridge.getInstance(@constCast(current)) orelse return false;
        const root_instance: *runtime.Instance = @ptrCast(@alignCast(root_opaque));

        // A ShadowRoot (its host getter answers; a plain DocumentFragment,
        // or a shadow root whose host is gone, has none): check whether its
        // host is connected.
        if (root_instance.stateAs(interfaces.ShadowRoot.State) != null) {
            if (interfaces.ShadowRoot.get_host(root_instance) catch null) |host| {
                // Recursively check if the host element is connected
                if (getInternal(host)) |host_internal| {
                    const host_node_base = &host_internal.base;
                    // Check cached value first
                    if (host_node_base.is_connected) {
                        return true;
                    }
                    // Recurse to follow further shadow hosts
                    return isConnectedThroughShadow(host, host_node_base);
                }
            }
        }
    }

    return false;
}

/// Getter for ownerDocument
/// https://dom.spec.whatwg.org/#dom-node-ownerdocument
/// Returns the document that the node belongs to, or null for Document nodes
pub fn get_ownerDocument(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Document nodes return null
    if (internal.base.node_type == NodeType.DOCUMENT_NODE) {
        return null;
    }

    return liveOwnerDocument(internal);
}

/// `internal`'s node document, through the net (`owner_document_generation`):
/// a document freed under the node that names it is never handed out. A node
/// keeps its document, so a freed one is a bug, logged.
fn liveOwnerDocument(internal: *const InternalState) error{InvalidStateError}!?*runtime.Instance {
    const document = internal.owner_document orelse return null;
    if (runtime.SlabAllocator.generationOf(document) != internal.owner_document_generation) {
        log.warn("a node's document was freed while the node named it (node type {d})", .{internal.base.node_type});
        return error.InvalidStateError;
    }
    return document;
}

/// Getter for parentNode
/// https://dom.spec.whatwg.org/#dom-node-parentnode
pub fn get_parentNode(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const node_base = &internal.base;
    const parent_base = node_base.parent_node orelse return null;
    const parent_opaque = instance_bridge.getInstance(parent_base) orelse return null;
    return @ptrCast(@alignCast(parent_opaque));
}

/// Getter for parentElement
/// https://dom.spec.whatwg.org/#dom-node-parentelement
/// Returns parent if parent is an Element, otherwise null
pub fn get_parentElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const node_base = &internal.base;
    const parent_base = node_base.parent_node orelse return null;

    // Check if parent is an Element (node_type == ELEMENT_NODE)
    if (parent_base.node_type == NodeType.ELEMENT_NODE) {
        const parent_opaque = instance_bridge.getInstance(parent_base) orelse return null;
        return @ptrCast(@alignCast(parent_opaque));
    }

    return null;
}

/// dom.refcount's hook: `list`, `node`'s childNodes list, is being freed.
/// The node's cache of it - the generated interface's [SameObject] one - is
/// raw (the list holds the node, never the reverse: refcount design section
/// 3), and lets it go: the next read makes a new list.
fn childNodesFreed(node: *runtime.Instance, list: *runtime.Instance) void {
    const state = node.getState(State);
    if (state.own.cached_childNodes == list) state.own.cached_childNodes = null;
}

/// Getter for childNodes
/// https://dom.spec.whatwg.org/#dom-node-childnodes
/// Returns a live NodeList of child nodes.
/// [SameObject]: the generated interface caches what this makes
/// (`cached_childNodes`, the one copy; `childNodesFreed` clears it) and calls
/// here only while it holds none - so this makes the list and keeps nothing.
pub fn get_childNodes(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = getInternal(instance) orelse return error.InvalidStateError;

    // Create a live NodeList for this node's children: made through its
    // interface, made live over them by NodeList's step (dom.node_lists).
    const list = try interfaces.NodeList.init(runtime.allocatorOf(instance), instance.ctx);
    errdefer interfaces.NodeList.deinit(list);
    try dom_module.node_lists.childNodes(list, instance);

    return list;
}

/// Getter for firstChild
/// https://dom.spec.whatwg.org/#dom-node-firstchild
pub fn get_firstChild(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const node_base = &internal.base;
    const first = node_base.first_child orelse return null;
    const first_opaque = instance_bridge.getInstance(first) orelse return null;
    return @ptrCast(@alignCast(first_opaque));
}

/// Getter for lastChild
/// https://dom.spec.whatwg.org/#dom-node-lastchild
pub fn get_lastChild(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const node_base = &internal.base;
    const last = node_base.lastChild() orelse return null;
    const last_opaque = instance_bridge.getInstance(last) orelse return null;
    return @ptrCast(@alignCast(last_opaque));
}

/// Getter for previousSibling
/// https://dom.spec.whatwg.org/#dom-node-previoussibling
pub fn get_previousSibling(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const node_base = &internal.base;
    const prev = node_base.previousSibling() orelse return null;
    const prev_opaque = instance_bridge.getInstance(prev) orelse return null;
    return @ptrCast(@alignCast(prev_opaque));
}

/// Getter for nextSibling
/// https://dom.spec.whatwg.org/#dom-node-nextsibling
pub fn get_nextSibling(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const node_base = &internal.base;
    const next = node_base.next_sibling orelse return null;
    const next_opaque = instance_bridge.getInstance(next) orelse return null;
    return @ptrCast(@alignCast(next_opaque));
}

/// Getter for nodeValue
/// https://dom.spec.whatwg.org/#dom-node-nodevalue
/// Returns/sets the value of the node depending on node type
pub fn get_nodeValue(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    return switch (internal.base.node_type) {
        NodeType.TEXT_NODE,
        NodeType.CDATA_SECTION_NODE,
        NodeType.PROCESSING_INSTRUCTION_NODE,
        NodeType.COMMENT_NODE,
        => blk: {
            // For CharacterData nodes, the data is stored in CharacterData's internal state
            const data_slice = dom_module.character_data.dataOf(instance) orelse {
                break :blk runtime.DOMString.initEmpty();
            };
            break :blk runtime.DOMString.initInterned(data_slice);
        },
        // Attr: this's value - the Attr impl's, which reads its element's
        // list while it has one. Cloned for the caller, who frees it.
        NodeType.ATTRIBUTE_NODE => interfaces.Attr.get_value(instance) catch runtime.DOMString.initEmpty(),
        // DOM 4.4 nodeValue: "Otherwise: Null" - an Element, Document,
        // DocumentType or DocumentFragment has none (it returned "", which
        // every createElementNS and createDocument case asserting
        // `element.nodeValue === null` failed on).
        else => null,
    };
}

/// Helper to recursively collect text content from descendants
fn collectTextContent(node: *runtime.Instance, allocator: std.mem.Allocator, result: *std.ArrayListUnmanaged(u8)) !void {
    const node_internal = getInternal(node) orelse return;

    // If this is a text node, add its content from CharacterData storage
    if (node_internal.base.node_type == NodeType.TEXT_NODE or
        node_internal.base.node_type == NodeType.CDATA_SECTION_NODE)
    {
        if (dom_module.character_data.dataOf(node)) |data_slice| {
            try result.appendSlice(allocator, data_slice);
        }
        return;
    }

    // Otherwise, recursively collect from children using NodeBase
    const node_base = &node_internal.base;
    var child_base = node_base.first_child;
    while (child_base) |c| {
        const child_opaque = instance_bridge.getInstance(c) orelse {
            child_base = c.next_sibling;
            continue;
        };
        const child_instance: *runtime.Instance = @ptrCast(@alignCast(child_opaque));
        try collectTextContent(child_instance, allocator, result);
        child_base = c.next_sibling;
    }
}

/// Getter for textContent
/// https://dom.spec.whatwg.org/#dom-node-textcontent
/// Returns the text content of the node and its descendants
pub fn get_textContent(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    return switch (internal.base.node_type) {
        NodeType.DOCUMENT_NODE, NodeType.DOCUMENT_TYPE_NODE => {
            // Returns null
            return null;
        },
        NodeType.TEXT_NODE,
        NodeType.CDATA_SECTION_NODE,
        NodeType.PROCESSING_INSTRUCTION_NODE,
        NodeType.COMMENT_NODE,
        => blk: {
            // DOM 4.4: returns this's data, which CharacterData owns.
            const data_slice = dom_module.character_data.dataOf(instance) orelse {
                break :blk runtime.DOMString.initEmpty();
            };
            break :blk runtime.DOMString.initInterned(data_slice);
        },
        // Attr: this's value, as for nodeValue.
        NodeType.ATTRIBUTE_NODE => interfaces.Attr.get_value(instance) catch runtime.DOMString.initEmpty(),
        NodeType.ELEMENT_NODE, NodeType.DOCUMENT_FRAGMENT_NODE => {
            // IMPORTANT: Use instance.ctx.allocator for returned DOMStrings
            // The V8 callback will free returned strings using instance.ctx.allocator
            // Note: This returns ?runtime.DOMString so may not be auto-cleaned, but we use
            // ctx.allocator for consistency and to prevent issues if cleanup behavior changes
            const allocator = instance.ctx.allocator;

            // Returns concatenation of descendant text content
            var result = std.ArrayListUnmanaged(u8).empty;
            errdefer result.deinit(allocator);

            // Recursively collect text from all descendants
            try collectTextContent(instance, allocator, &result);

            if (result.items.len == 0) {
                return runtime.DOMString.initEmpty();
            }

            // Create DOMString from collected text - take ownership of the array
            return runtime.DOMString.initOwned(result.toOwnedSlice(allocator) catch return runtime.DOMString.initEmpty());
        },
        else => runtime.DOMString.initEmpty(),
    };
}

// =============================================================================
// Setters
// =============================================================================

/// Setter for nodeValue
/// https://dom.spec.whatwg.org/#dom-node-nodevalue
pub fn set_nodeValue(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    switch (internal.base.node_type) {
        // DOM 4.4: for CharacterData, "replace data with node this, offset 0,
        // count this's length, and data the given value". That lives in
        // CharacterData's own state and must go through replace data so live
        // ranges are updated; Node.node_value is not read for these types.
        NodeType.TEXT_NODE,
        NodeType.CDATA_SECTION_NODE,
        NodeType.PROCESSING_INSTRUCTION_NODE,
        NodeType.COMMENT_NODE,
        => {
            // Step 1: If the given value is null, act as if it was the empty string.
            try interfaces.CharacterData.set_data(instance, value orelse runtime.DOMString.initEmpty());
        },
        // For Attr, set an existing attribute value; Attr keeps its value in its own state.
        // Attr: "set an existing attribute value" with this and the given
        // value (null becomes the empty string) - through the Attr impl, which
        // changes the attribute in its element's list when it has one.
        NodeType.ATTRIBUTE_NODE => {
            try interfaces.Attr.set_value(instance, value orelse runtime.DOMString.initEmpty());
        },
        // For Element, Document, etc: do nothing
        else => {},
    }
}

/// Setter for textContent
/// https://dom.spec.whatwg.org/#dom-node-textcontent
pub fn set_textContent(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    switch (internal.base.node_type) {
        NodeType.DOCUMENT_NODE, NodeType.DOCUMENT_TYPE_NODE => {
            // Do nothing
        },
        NodeType.TEXT_NODE,
        NodeType.CDATA_SECTION_NODE,
        NodeType.PROCESSING_INSTRUCTION_NODE,
        NodeType.COMMENT_NODE,
        => {
            // DOM 4.4: "Replace data with node this, offset 0, count this's
            // length, and data the given value" (null acts as "").
            try interfaces.CharacterData.set_data(instance, value orelse runtime.DOMString.initEmpty());
        },
        // Attr: "set an existing attribute value", as for nodeValue.
        NodeType.ATTRIBUTE_NODE => {
            try interfaces.Attr.set_value(instance, value orelse runtime.DOMString.initEmpty());
        },
        NodeType.ELEMENT_NODE, NodeType.DOCUMENT_FRAGMENT_NODE => {
            // DOM "string replace all" with the given value within this.
            const node_base = &internal.base;

            // Step 1: "Let node be null."
            // Step 2: "If string is not the empty string, then set node to a
            // new Text node whose data is string and node document is
            // parent's node document."
            const slice = if (value) |v| v.asSlice() else "";
            var text_base: ?*NodeBase = null;
            if (slice.len > 0) {
                const text_node = try interfaces.Text.initWith(
                    instance.ctx.allocator,
                    instance.ctx,
                    .{ .data = slice },
                );
                errdefer interfaces.Text.deinit(text_node);
                if (internal.owner_document) |owner_doc| {
                    try setOwnerDocument(text_node, owner_doc);
                }
                text_base = instance_bridge.getNodeBase(@ptrCast(text_node)) orelse return error.InvalidStateError;
            }

            // Step 3: "Replace all with node within parent." One tree
            // mutation record for the whole change: removing the children one
            // by one queued a record per child and another for the text.
            try dom_module.mutation.replaceAll(text_base, node_base);
        },
        else => {},
    }
}

// =============================================================================
// Operations
// =============================================================================

/// Operation: hasChildNodes
/// https://dom.spec.whatwg.org/#dom-node-haschildnodes
pub fn call_hasChildNodes(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const node_base = &internal.base;
    return node_base.first_child != null;
}

/// Operation: getRootNode
/// https://dom.spec.whatwg.org/#dom-node-getrootnode
pub fn call_getRootNode(instance: *runtime.Instance, options: webidl.Opt(dictionaries.GetRootNodeOptions)) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const node_base = &internal.base;

    // Walk up the tree to find the root using NodeBase
    var current_base = node_base;
    while (current_base.parent_node) |parent_base| {
        current_base = parent_base;
    }

    // Convert root NodeBase back to Instance
    const root_opaque = instance_bridge.getInstance(current_base) orelse return instance;
    var root: *runtime.Instance = @ptrCast(@alignCast(root_opaque));
    // DOM: the shadow-including root is a shadow root's host's
    // shadow-including root, otherwise the ordinary root. Slot assignment
    // does not change either ancestry relation.
    if (options.was_passed and (options.value.composed orelse false)) {
        while (root.stateAs(interfaces.ShadowRoot.State) != null) {
            const host = try interfaces.ShadowRoot.get_host(root);
            root = try call_getRootNode(host, .notPassed());
        }
    }
    return root;
}

/// Operation: contains
/// https://dom.spec.whatwg.org/#dom-node-contains
/// Returns true if other is an inclusive descendant of this node
pub fn call_contains(instance: *runtime.Instance, other: ?*runtime.Instance) anyerror!bool {
    // A node contains itself
    if (instance == other) return true;

    const other_instance = other orelse return false;

    // Get NodeBase for both nodes
    const internal = getInternal(instance) orelse return false;
    const self_base = &internal.base;

    const other_internal = getInternal(other_instance) orelse return false;
    const other_base = &other_internal.base;

    // Walk up from other to see if we find self
    var current: ?*NodeBase = other_base;
    while (current) |curr| {
        if (curr == self_base) return true;
        current = curr.parent_node;
    }

    return false;
}

/// Operation: compareDocumentPosition
/// https://dom.spec.whatwg.org/#dom-node-comparedocumentposition
pub fn call_compareDocumentPosition(instance: *runtime.Instance, other: *runtime.Instance) anyerror!u16 {
    // Step 1: Identical nodes compare equal, including unattached attributes.
    if (instance == other) return 0;

    // Steps 2-5: Attributes participate at their owner element's position.
    var node1: ?*runtime.Instance = other;
    var node2: ?*runtime.Instance = instance;
    const attr1 = try interfaces.Node.get_nodeType(other) == NodeType.ATTRIBUTE_NODE;
    const attr2 = try interfaces.Node.get_nodeType(instance) == NodeType.ATTRIBUTE_NODE;
    if (attr1) node1 = try interfaces.Attr.get_ownerElement(other);
    if (attr2) {
        node2 = try interfaces.Attr.get_ownerElement(instance);
        if (attr1 and node1 != null and node1 == node2) {
            // Step 5.2: Iterate the actual attribute list. Both input Attr
            // nodes already exist; reading their order must not create a
            // NamedNodeMap or materialize the list's other Attr nodes.
            // An element has only one attribute per (namespace, local name),
            // so equality within this list is identity of the cached Attr.
            const owner = node1.?;
            for (0..dom_module.element_attributes.count(owner)) |i| {
                const attr = dom_module.element_attributes.existingNodeAt(owner, i) orelse continue;
                if (attr == other) return DocumentPosition.IMPLEMENTATION_SPECIFIC | DocumentPosition.PRECEDING;
                if (attr == instance) return DocumentPosition.IMPLEMENTATION_SPECIFIC | DocumentPosition.FOLLOWING;
            }
        }
    }

    // Reuse the same iterative tree-order algorithm as Range. Parent and
    // index are borrowed reads through the Node interface, with no storage.
    const Tree = struct {
        pub const Node = *runtime.Instance;
        pub fn parent(node: @This().Node) ?@This().Node {
            return interfaces.Node.get_parentNode(node) catch null;
        }
        pub fn index(node: @This().Node) u32 {
            var result: u32 = 0;
            var sibling = interfaces.Node.get_previousSibling(node) catch null;
            while (sibling) |s| : (sibling = interfaces.Node.get_previousSibling(s) catch null) result += 1;
            return result;
        }
        fn root(node: @This().Node) @This().Node {
            var current = node;
            while (parent(current)) |p| current = p;
            return current;
        }
    };

    // Step 6: Disconnected trees (and ownerless attributes) have a consistent
    // implementation-specific order, based on the original nodes' addresses.
    if (node1 == null or node2 == null or Tree.root(node1.?) != Tree.root(node2.?)) {
        const order = if (@intFromPtr(instance) < @intFromPtr(other)) DocumentPosition.FOLLOWING else DocumentPosition.PRECEDING;
        return DocumentPosition.DISCONNECTED | DocumentPosition.IMPLEMENTATION_SPECIFIC | order;
    }
    const a = node1.?;
    const b = node2.?;
    const points = dom_module.boundary_points;

    // Steps 7-8: Attributes follow their owner and precede its children, but
    // an attribute does not contain its owner's descendants.
    if ((!attr1 and points.isAncestor(Tree, a, b)) or (a == b and attr2))
        return DocumentPosition.CONTAINS | DocumentPosition.PRECEDING;
    if ((!attr2 and points.isAncestor(Tree, b, a)) or (a == b and attr1))
        return DocumentPosition.CONTAINED_BY | DocumentPosition.FOLLOWING;

    // Steps 9-10: Distinct branches compare by tree order, never FOLLOWING
    // in both directions. The latter made the Range WPT oracle's recursive
    // swap overflow before it reached Range.compareBoundaryPoints itself.
    // WebKit Node::compareDocumentPosition likewise normalizes Attr owners
    // then uses treeOrder: Source/WebCore/dom/Node.cpp.
    return if (points.isFollowing(Tree, b, a)) DocumentPosition.PRECEDING else DocumentPosition.FOLLOWING;
}

/// Operation: isSameNode
/// https://dom.spec.whatwg.org/#dom-node-issamenode
/// Returns true if other is the same node (reference equality)
pub fn call_isSameNode(instance: *runtime.Instance, otherNode: ?*runtime.Instance) anyerror!bool {
    return instance == otherNode;
}

/// Operation: isEqualNode
/// https://dom.spec.whatwg.org/#dom-node-isequalnode
/// Returns true if nodes are equal (same type, attributes, children)
pub fn call_isEqualNode(instance: *runtime.Instance, otherNode: ?*runtime.Instance) anyerror!bool {
    const other_node = otherNode orelse return false;
    // DOM 4.4 "A node A equals a node B": A's and B's own data are equal
    // (`equalsShallow`), they have the same number of children, and each
    // child of A equals the child of B at the same index. That definition
    // recurses once per tree level, and so did this (lane crash1 b2: a
    // 30,000-deep tree overflowed the stack); both trees are walked here in
    // one lockstep pre-order over their links instead - no recursion, no
    // allocation - comparing each pair as it is reached, so the answer and the
    // order of the comparisons are the recursion's.
    if (!try equalsShallow(instance, other_node)) return false;
    const self_root = &(getInternal(instance) orelse return false).base;
    const other_root = &(getInternal(other_node) orelse return false).base;
    var a: *NodeBase = self_root;
    var b: *NodeBase = other_root;
    while (true) {
        if (a.first_child) |a_child| {
            // Both have children: compare the first ones next.
            a = a_child;
            b = b.first_child orelse return false;
        } else {
            if (b.first_child != null) return false;
            // A leaf pair: on to the next sibling pair, climbing while both
            // lists end at once - the same shape so far, so `b` climbs back
            // to its root as `a` does.
            while (true) {
                if (a == self_root) return true;
                if (a.next_sibling) |a_next| {
                    a = a_next;
                    b = b.next_sibling orelse return false;
                    break;
                }
                if (b.next_sibling != null) return false;
                a = a.parent_node orelse return false;
                b = b.parent_node orelse return false;
            }
        }
        const a_instance: *runtime.Instance = @ptrCast(@alignCast(instance_bridge.getInstance(a) orelse return false));
        const b_instance: *runtime.Instance = @ptrCast(@alignCast(instance_bridge.getInstance(b) orelse return false));
        if (!try equalsShallow(a_instance, b_instance)) return false;
    }
}

/// DOM 4.4 "equals" for `instance` and `other_node` themselves - their
/// type and the type's own fields - without their children.
fn equalsShallow(instance: *runtime.Instance, other_node: *runtime.Instance) !bool {
    const self_internal = getInternal(instance) orelse return false;
    const other_internal = getInternal(other_node) orelse return false;

    // Must be same node type
    if (self_internal.base.node_type != other_internal.base.node_type) return false;

    // DOM "equals": compare the interface's own fields, not Node's legacy
    // copies. Like WebKit Node::isEqualNode, compare attributes independent
    // of their list order (and without their namespace prefixes).
    switch (self_internal.base.node_type) {
        NodeType.DOCUMENT_TYPE_NODE => {
            if (!try equalStringMember(interfaces.DocumentType.get_name, instance, other_node) or
                !try equalStringMember(interfaces.DocumentType.get_publicId, instance, other_node) or
                !try equalStringMember(interfaces.DocumentType.get_systemId, instance, other_node)) return false;
        },
        NodeType.ELEMENT_NODE => {
            const a = dom_module.node_creation.elementNames(instance) orelse return false;
            const b = dom_module.node_creation.elementNames(other_node) orelse return false;
            if (!equalOptionalBytes(a.namespace, b.namespace) or !equalOptionalBytes(a.prefix, b.prefix) or
                !std.mem.eql(u8, a.local_name, b.local_name)) return false;
            if (dom_module.element_attributes.count(instance) != dom_module.element_attributes.count(other_node)) return false;
            var i: usize = 0;
            while (dom_module.element_attributes.at(instance, i)) |attribute| : (i += 1) {
                var j: usize = 0;
                var found = false;
                while (dom_module.element_attributes.at(other_node, j)) |other| : (j += 1) {
                    if (equalOptionalBytes(attribute.namespace, other.namespace) and
                        std.mem.eql(u8, attribute.local_name, other.local_name) and
                        std.mem.eql(u8, attribute.value, other.value))
                    {
                        found = true;
                        break;
                    }
                }
                if (!found) return false;
            }
        },
        NodeType.ATTRIBUTE_NODE => {
            var a = try interfaces.Attr.get_namespaceURI(instance);
            defer if (a) |*value| value.deinit(instance.ctx.allocator);
            var b = try interfaces.Attr.get_namespaceURI(other_node);
            defer if (b) |*value| value.deinit(other_node.ctx.allocator);
            if (!equalOptionalBytes(if (a) |value| value.asSlice() else null, if (b) |value| value.asSlice() else null)) return false;
            if (!try equalStringMember(interfaces.Attr.get_localName, instance, other_node) or
                !try equalStringMember(interfaces.Attr.get_value, instance, other_node)) return false;
        },
        NodeType.PROCESSING_INSTRUCTION_NODE => {
            if (!try equalStringMember(interfaces.ProcessingInstruction.get_target, instance, other_node)) return false;
            if (!std.mem.eql(u8, dom_module.character_data.dataOf(instance) orelse "", dom_module.character_data.dataOf(other_node) orelse "")) return false;
        },
        NodeType.TEXT_NODE, NodeType.CDATA_SECTION_NODE, NodeType.COMMENT_NODE => {
            if (!std.mem.eql(u8, dom_module.character_data.dataOf(instance) orelse "", dom_module.character_data.dataOf(other_node) orelse "")) return false;
        },
        else => {},
    }

    return true;
}

/// IDL getters transfer their strings to the caller, including native callers.
fn equalStringMember(comptime getter: anytype, a: *runtime.Instance, b: *runtime.Instance) !bool {
    var left = try getter(a);
    defer left.deinit(a.ctx.allocator);
    var right = try getter(b);
    defer right.deinit(b.ctx.allocator);
    return std.mem.eql(u8, left.asSlice(), right.asSlice());
}

/// Operation: cloneNode
/// https://dom.spec.whatwg.org/#dom-node-clonenode
/// Spec steps:
/// 1. If this is a shadow root, throw NotSupportedError
/// 2. Return clone of this with subtree set to deep
pub fn call_cloneNode(instance: *runtime.Instance, subtree: webidl.Opt(bool)) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Step 1: If this is a shadow root, throw NotSupportedError
    if (instance.stateAs(interfaces.ShadowRoot.State) != null) return error.NotSupportedError;

    // Step 2: "Return the result of cloning a node given this with subtree
    // set to subtree" - document defaulting to this's node document, which
    // for a document is itself.
    const deep = if (subtree.was_passed) subtree.value else false;
    const document = if (internal.base.node_type == NodeType.DOCUMENT_NODE) instance else internal.owner_document;
    return dom_module.node_creation.clone(instance, document, deep, null);
}

/// DOM "clone a node", including fallbackRegistry and clonable shadow trees.
/// Spec: https://dom.spec.whatwg.org/#concept-node-clone
pub fn cloneANode(
    node: *runtime.Instance,
    document: ?*runtime.Instance,
    subtree: bool,
    parent: ?*runtime.Instance,
    fallback_registry: ?*runtime.Instance,
) !*runtime.Instance {
    const node_internal = getInternal(node) orelse return error.InvalidStateError;

    // Step 2: "Let copy be the result of cloning a single node given node,
    // document, and fallbackRegistry."
    const copy = try cloneSingleNode(node, document, fallback_registry);
    // Until step 4 hands the copy to its parent, nothing else holds it.
    var attached = false;
    errdefer if (!attached) runtime.Instance.deinit(copy);

    // Step 3: "Run any cloning steps defined for node in other applicable
    // specifications and pass node, copy, and subtree as parameters." A
    // script's copy inherits "already started" here, so a clone of a script
    // that has run does not run again when it is inserted.
    try dom_module.cloning_steps.run(node, copy, subtree);

    // Step 4: "If parent is non-null, then append copy to parent."
    if (parent) |p| {
        _ = try call_appendChild(p, copy);
        attached = true;
    }

    // Step 5: "If subtree is true, then for each child of node's children, in
    // tree order: clone a node given child with document set to document,
    // subtree set to subtree, parent set to copy".
    //
    // A document's children are made in the COPY: "clone a single node" step
    // 5 sets document to copy when node is a document, and Blink creates each
    // child in the clone's own document (ContainerNode::CloneChildNodesFrom).
    if (subtree) {
        const children_document = if (node_internal.base.node_type == NodeType.DOCUMENT_NODE) copy else document;
        const node_base = &node_internal.base;
        var child_base = node_base.first_child;
        while (child_base) |c| : (child_base = c.next_sibling) {
            const child_opaque = instance_bridge.getInstance(c) orelse continue;
            const child_instance: *runtime.Instance = @ptrCast(@alignCast(child_opaque));
            _ = try cloneANode(child_instance, children_document, subtree, copy, fallback_registry);
        }
    }

    // Step 6 clones a clonable shadow tree even for a shallow host clone.
    if (dom_module.custom_elements.shadowRootOf(node)) |shadow| {
        if (try interfaces.ShadowRoot.get_clonable(shadow)) {
            var registry = try interfaces.ShadowRoot.get_customElementRegistry(shadow);
            if (registry) |value| if (!dom_module.custom_elements.isScoped(value)) {
                const target = document orelse node_internal.owner_document orelse return error.InvalidStateError;
                registry = dom_module.custom_elements.effectiveGlobal(try interfaces.Document.get_customElementRegistry(target));
            };
            const shadow_copy = try dom_module.custom_elements.attachShadow(copy, .{
                .mode = try interfaces.ShadowRoot.get_mode(shadow),
                .delegatesFocus = try interfaces.ShadowRoot.get_delegatesFocus(shadow),
                .serializable = try interfaces.ShadowRoot.get_serializable(shadow),
                .slotAssignment = try interfaces.ShadowRoot.get_slotAssignment(shadow),
                .clonable = true,
            }, registry);
            dom_module.custom_elements.cloneShadowFlags(shadow, shadow_copy);
            var child = try interfaces.Node.get_firstChild(shadow);
            while (child) |value| {
                _ = try cloneANode(value, document, true, shadow_copy, null);
                child = try interfaces.Node.get_nextSibling(value);
            }
        }
    }
    return copy;
}

/// Clone a single node without children
/// Creates a new node with the same type and properties
fn cloneSingleNode(node: *runtime.Instance, document: ?*runtime.Instance, fallback_registry: ?*runtime.Instance) !*runtime.Instance {
    const node_internal = getInternal(node) orelse return error.InvalidStateError;

    // The node's Browser's allocator (runtime.allocatorOf): the one it was
    // made with.
    const allocator = runtime.allocatorOf(node);

    // DOM 4.4 "clone a node" step 2: copy must implement the same interfaces as
    // node. A CharacterData copy built as a bare Node has no CharacterData
    // state, so every later data access on it fails with InvalidStateError and
    // its data is silently lost. Build those through their own interfaces, which
    // also keeps them off `Registry.createIn` (see AGENTS.md: createIn hands out
    // a block the arena will reissue).
    switch (node_internal.base.node_type) {
        NodeType.TEXT_NODE,
        NodeType.CDATA_SECTION_NODE,
        NodeType.COMMENT_NODE,
        NodeType.PROCESSING_INSTRUCTION_NODE,
        => {
            // Clone a single node step 4 / create a node step 2: the copy is
            // created in the destination node document's relevant realm.
            const copy_ctx = if (document orelse node_internal.owner_document) |owner| owner.ctx else node.ctx;
            var data_str = try interfaces.CharacterData.get_data(node);
            defer data_str.deinit(node.ctx.allocator);

            const copy = switch (node_internal.base.node_type) {
                NodeType.TEXT_NODE => try interfaces.Text.initWith(
                    copy_ctx.allocator,
                    copy_ctx,
                    .{ .data = data_str.asSlice() },
                ),
                NodeType.COMMENT_NODE => try interfaces.Comment.initWith(
                    copy_ctx.allocator,
                    copy_ctx,
                    .{ .data = data_str.asSlice() },
                ),
                NodeType.CDATA_SECTION_NODE => blk: {
                    const cdata = try interfaces.CDATASection.init(copy_ctx.allocator, copy_ctx);
                    errdefer runtime.Instance.deinit(cdata);
                    try interfaces.CharacterData.set_data(cdata, data_str);
                    break :blk cdata;
                },
                // Clone-a-single-node step 5 copies target/data without the
                // factory's validation: later data mutations can contain ?>.
                else => blk: {
                    // These getters CLONE and hand ownership to the caller (the
                    // interface layer frees them when script is the caller), so
                    // calling one from Zig means freeing it here.
                    var target = try interfaces.ProcessingInstruction.get_target(node);
                    defer target.deinit(node.ctx.allocator);
                    break :blk try interfaces.ProcessingInstruction.initWith(copy_ctx.allocator, copy_ctx, .{
                        .target = target.asSlice(),
                        .data = data_str.asSlice(),
                    });
                },
            };
            errdefer runtime.Instance.deinit(copy);

            if (document orelse node_internal.owner_document) |owner_doc| {
                try setOwnerDocument(copy, owner_doc);
            }
            return copy;
        },
        // DOM 4.4 "clone a node" step 2: "let copy be the result of creating an
        // element, given document, node's local name, node's namespace, node's
        // namespace prefix, and is value" - then step 3 copies the attributes.
        // A bare Node copy has no Element state, so every later attribute or
        // name access on the clone fails with InvalidStateError.
        NodeType.ELEMENT_NODE => {
            const owner = document orelse node_internal.owner_document orelse
                return error.InvalidStateError;
            // These getters BORROW the element's own name record (lane nd2
            // N2, dom.element_name): valid while `node` lives, and their
            // deinit frees nothing. They stay DOMStrings with a deinit, so a
            // getter that copies again needs no change here.
            const instance_allocator = node.ctx.allocator;

            var namespace_owned = try interfaces.Element.get_namespaceURI(node);
            defer if (namespace_owned) |*n| n.deinit(instance_allocator);
            var local_name_owned = try interfaces.Element.get_localName(node);
            defer local_name_owned.deinit(instance_allocator);
            var prefix_owned = try interfaces.Element.get_prefix(node);
            defer if (prefix_owned) |*pfx| pfx.deinit(instance_allocator);

            // Clone-single-node steps 1.1–1.2: use the internal is value,
            // independently of any is attribute, and enqueue an asynchronous
            // upgrade. Attributes and descendants are copied before it runs.
            const custom = dom_module.custom_elements.get(node);
            var registry = (try interfaces.Element.get_customElementRegistry(node)) orelse fallback_registry;
            if (registry) |value| if (!dom_module.custom_elements.isScoped(value)) {
                registry = dom_module.custom_elements.effectiveGlobal(try interfaces.Document.get_customElementRegistry(owner));
            };
            // Step 1.1 copies the namespace prefix, which is null when absent.
            // The legacy getter returns an empty string for that case; preserve
            // the old createElementNS caller's empty-to-null normalization.
            const prefix = if (prefix_owned) |value|
                (if (value.asSlice().len != 0) value.asSlice() else null)
            else
                null;
            const copy = try dom_module.custom_elements.create(.{
                .document = owner,
                .local_name = local_name_owned.asSlice(),
                .namespace = if (namespace_owned) |value| value.asSlice() else null,
                .prefix = prefix,
                .is_value = if (custom) |value| value.is_value else null,
                .registry = .{ .explicit = registry },
            });
            errdefer runtime.Instance.deinit(copy);

            // Step 3: "For each attribute of node's attribute list: let
            // copyAttribute be the result of cloning a single node given
            // attribute, document, and null; append copyAttribute to copy."
            // Copied exactly through the list's own hook: going through
            // setAttributeNS would validate and reject names the list
            // legitimately holds, and `attributes` makes an Attr node each.
            // The copy SHARES node's list until either writes it (lane nd2
            // batch 4; Blink Element::CloneAttributesFrom, WebKit Element::
            // cloneAttributesFromElement); each attribute's change steps run
            // as a copied attribute's (the style attribute skips its CSP
            // check, as all three browsers do: Element).
            try dom_module.element_attributes.cloneFrom(copy, node);

            try setOwnerDocument(copy, owner);
            return copy;
        },
        // DOM §4.4 "clone a single node" step 3: "let copy be a node that
        // implements the same interfaces as node". Each type below used to fall
        // through to `Instance.init(allocator, State, node.vtable, ...)` - Node's
        // State under the subtype's vtable. `onObjectFreed` later freed that block
        // at the vtable's LARGER state_size, so an undersized block landed on the
        // arena's 1024-byte free list; the next Document.InternalState was carved
        // from it and overlapped its live neighbours. That was the SEGV at 0x0 in
        // Node.init under custom-elements/Document-createElement.html.
        NodeType.DOCUMENT_NODE => {
            // "Document: set copy's encoding, content type, URL, origin, type,
            // and mode to those of node." The copy is a real Document, with its
            // registry state, so createElement and friends work on it. The six
            // fields are Document internals with no interface delegate to set
            // them, so they keep Document.init's defaults - a stated deviation.
            // TODO(dom-clone): a codegen-generated `cloneInternalsFrom` delegate
            // is the boundary-clean way to copy them.
            // "Let copy be a node that implements the same interfaces as
            // node": an XMLDocument's copy is an XMLDocument.
            const copy = if (node.stateAs(interfaces.XMLDocument.State) != null)
                try interfaces.XMLDocument.init(allocator, node.ctx)
            else
                try interfaces.Document.init(allocator, node.ctx);
            errdefer runtime.Instance.deinit(copy);
            if (try interfaces.Document.get_customElementRegistry(node)) |registry| {
                if (dom_module.custom_elements.isScoped(registry)) try dom_module.custom_elements.setDocumentRegistry(copy, registry);
            }
            // A clone goes to script (cloneNode) or into nothing: its first
            // wrapper takes its born reference over (refcount7, 5i).
            return copy;
        },
        NodeType.DOCUMENT_TYPE_NODE => {
            // "DocumentType: set copy's name, public ID, and system ID to those
            // of node." Built by the owner's DOMImplementation, which is the one
            // factory the interfaces expose for a doctype.
            const owner = document orelse node_internal.owner_document orelse
                return error.InvalidStateError;
            const instance_allocator = node.ctx.allocator;
            // Getters clone; the caller frees (AGENTS.md, "Interface getters clone").
            var name = try interfaces.DocumentType.get_name(node);
            defer name.deinit(instance_allocator);
            var public_id = try interfaces.DocumentType.get_publicId(node);
            defer public_id.deinit(instance_allocator);
            var system_id = try interfaces.DocumentType.get_systemId(node);
            defer system_id.deinit(instance_allocator);
            const implementation = try interfaces.Document.get_implementation(owner);
            const copy = try interfaces.DOMImplementation.call_createDocumentType(
                implementation,
                name,
                public_id,
                system_id,
            );
            try setOwnerDocument(copy, owner);
            return copy;
        },
        NodeType.ATTRIBUTE_NODE => {
            // "Attr: set copy's namespace, namespace prefix, local name, and
            // value to those of node." Field for field through the Attr hook:
            // createAttributeNS would validate, and reject a name an attribute
            // made by setAttribute legitimately holds ("a:b" as a local name).
            const owner = document orelse node_internal.owner_document orelse
                return error.InvalidStateError;
            const instance_allocator = node.ctx.allocator;
            var namespace = try interfaces.Attr.get_namespaceURI(node);
            defer if (namespace) |*n| n.deinit(instance_allocator);
            var prefix = try interfaces.Attr.get_prefix(node);
            defer if (prefix) |*pfx| pfx.deinit(instance_allocator);
            var local_name = try interfaces.Attr.get_localName(node);
            defer local_name.deinit(instance_allocator);
            var value = try interfaces.Attr.get_value(node);
            defer value.deinit(instance_allocator);
            const copy = try interfaces.Attr.init(allocator, owner.ctx);
            errdefer interfaces.Attr.deinit(copy);
            try setOwnerDocument(copy, owner);
            try dom_module.attr_nodes.name(
                copy,
                if (namespace) |n| n.asSlice() else null,
                if (prefix) |pfx| pfx.asSlice() else null,
                local_name.asSlice(),
            );
            try interfaces.Attr.set_value(copy, value);
            return copy;
        },
        NodeType.DOCUMENT_FRAGMENT_NODE => {
            // "Otherwise: do nothing." A fragment carries no fields; it only has
            // to be a fragment of the right document.
            const owner = document orelse node_internal.owner_document orelse
                return error.InvalidStateError;
            const copy = try interfaces.Document.call_createDocumentFragment(owner);
            try setOwnerDocument(copy, owner);
            return copy;
        },
        else => {},
    }

    // Every interface the algorithm names is handled above. Anything else has
    // a State this function cannot size, and sizing it as Node's State is the
    // corruption described at DOCUMENT_NODE - so it is refused, not guessed.
    return error.NotSupported;
}

/// Operation: normalize
/// https://dom.spec.whatwg.org/#dom-node-normalize
///
/// "The normalize() method steps are to run these steps for each descendant
/// exclusive Text node node of this". The walk is live: a merge removes the
/// Text nodes after node, so the next node in tree order is found after each
/// one is done with.
pub fn call_normalize(instance: *runtime.Instance) anyerror!void {
    var current: ?*runtime.Instance = interfaces.Node.get_firstChild(instance) catch null;
    while (current) |node| {
        if (!isExclusiveText(node)) {
            current = followingInTree(node, instance, true);
            continue;
        }
        const parent = (interfaces.Node.get_parentNode(node) catch null) orelse return error.InvalidStateError;

        // Step 1: "Let length be node's length."
        var length = try interfaces.CharacterData.get_length(node);

        // Step 2: "If length is zero, then remove node and continue with the
        // next exclusive Text node, if any."
        if (length == 0) {
            const next = followingInTree(node, instance, false);
            _ = try interfaces.Node.call_removeChild(parent, node);
            current = next;
            continue;
        }

        // Step 3: "Let data be the concatenation of the data of node's
        // contiguous exclusive Text nodes (excluding itself), in tree order."
        // A run's earlier nodes were merged into its first one already, so
        // only the nodes after node remain in it.
        const allocator = instance.ctx.allocator;
        var data: std.ArrayListUnmanaged(u8) = .empty;
        defer data.deinit(allocator);
        var sibling = interfaces.Node.get_nextSibling(node) catch null;
        while (sibling) |s| : (sibling = interfaces.Node.get_nextSibling(s) catch null) {
            if (!isExclusiveText(s)) break;
            var piece = try interfaces.CharacterData.get_data(s);
            defer piece.deinit(s.ctx.allocator);
            try data.appendSlice(allocator, piece.asSlice());
        }

        // Step 4: "Replace data of node with length, 0, and data."
        try interfaces.CharacterData.call_replaceData(node, length, 0, runtime.DOMString.initInterned(data.items));

        // Step 5: "Let currentNode be node's next sibling."
        var current_node = interfaces.Node.get_nextSibling(node) catch null;
        // Step 6: "While currentNode is an exclusive Text node:"
        while (current_node) |merged| {
            if (!isExclusiveText(merged)) break;
            // Steps 6.1-6.4: the live ranges in or at currentNode move into
            // node.
            dom_module.mutation.runLiveRangeNormalizeSteps(node, merged, length);
            // Step 6.5: "Add currentNode's length to length."
            length += try interfaces.CharacterData.get_length(merged);
            // Step 6.6: "Set currentNode to its next sibling."
            current_node = interfaces.Node.get_nextSibling(merged) catch null;
        }

        // Step 7: "Remove node's contiguous exclusive Text nodes (excluding
        // itself), in tree order."
        while (interfaces.Node.get_nextSibling(node) catch null) |merged| {
            if (!isExclusiveText(merged)) break;
            _ = try interfaces.Node.call_removeChild(parent, merged);
        }

        current = followingInTree(node, instance, false);
    }
}

/// "An exclusive Text node is a Text node that is not a CDATASection node."
fn isExclusiveText(node: *runtime.Instance) bool {
    const node_type = interfaces.Node.get_nodeType(node) catch return false;
    return node_type == interfaces.Node.get_TEXT_NODE();
}

/// The node after `node` in tree order within `root`'s descendants, or null:
/// its first child when `descend`, else the next sibling of it or of its
/// nearest ancestor below `root` that has one.
fn followingInTree(node: *runtime.Instance, root: *runtime.Instance, descend: bool) ?*runtime.Instance {
    if (descend) {
        if (interfaces.Node.get_firstChild(node) catch null) |child| return child;
    }
    var current = node;
    while (current != root) {
        if (interfaces.Node.get_nextSibling(current) catch null) |next| return next;
        current = (interfaces.Node.get_parentNode(current) catch null) orelse return null;
    }
    return null;
}

// =============================================================================
// Tree Mutation Operations - ALL delegated to src/dom/mutation.zig
// =============================================================================
//
// IMPORTANT: Tree manipulation code lives in src/dom/mutation.zig
// This file should NOT contain tree manipulation logic.
// Use dom_module.mutation.* functions for all tree operations.

// TODO: Iframe insertion steps should be registered as a callback with
// dom_module.mutation.registerInsertionStepsCallback() to handle
// iframe-specific insertion per HTML Standard §4.8.5

/// Find the owner document for a node (walking up the tree if needed)
fn findOwnerDocument(node: *runtime.Instance) ?*runtime.Instance {
    const internal = getInternal(node) orelse return null;

    // If this is a Document, return it
    if (internal.base.node_type == NodeType.DOCUMENT_NODE) {
        return node;
    }

    // Otherwise, return the ownerDocument
    return internal.owner_document;
}

/// Operation: appendChild
/// https://dom.spec.whatwg.org/#dom-node-appendchild
/// Delegates to src/dom/mutation.zig - THE single source of truth for tree operations
pub fn call_appendChild(instance: *runtime.Instance, node: *runtime.Instance) anyerror!*runtime.Instance {
    const parent_internal = getInternal(instance) orelse return error.InvalidStateError;
    const node_internal = getInternal(node) orelse return error.InvalidStateError;

    const parent_base = &parent_internal.base;
    const node_base = &node_internal.base;

    // Delegate to src/dom/mutation.zig - single source of truth
    _ = dom_module.mutation.append(node_base, parent_base) catch |err| {
        return switch (err) {
            error.HierarchyRequestError => error.HierarchyRequestError,
            error.NotFoundError => error.NotFoundError,
            else => error.InvalidStateError,
        };
    };

    return node;
}

/// Operation: insertBefore
/// https://dom.spec.whatwg.org/#dom-node-insertbefore
/// Delegates to src/dom/mutation.zig - THE single source of truth for tree operations
pub fn call_insertBefore(instance: *runtime.Instance, node: *runtime.Instance, child: ?*runtime.Instance) anyerror!*runtime.Instance {
    const parent_internal = getInternal(instance) orelse return error.InvalidStateError;
    const node_internal = getInternal(node) orelse return error.InvalidStateError;

    const parent_base = &parent_internal.base;
    const node_base = &node_internal.base;

    const child_base: ?*NodeBase = if (child) |c| blk: {
        const c_internal = getInternal(c) orelse break :blk null;
        break :blk &c_internal.base;
    } else null;

    // Delegate to src/dom/mutation.zig - single source of truth
    _ = dom_module.mutation.preInsert(node_base, parent_base, child_base) catch |err| {
        return switch (err) {
            error.HierarchyRequestError => error.HierarchyRequestError,
            error.NotFoundError => error.NotFoundError,
            else => error.InvalidStateError,
        };
    };

    return node;
}

/// Operation: removeChild
/// https://dom.spec.whatwg.org/#dom-node-removechild
/// Delegates to src/dom/mutation.zig - THE single source of truth for tree operations
pub fn call_removeChild(instance: *runtime.Instance, child: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const child_internal = getInternal(child) orelse return error.InvalidStateError;
    const parent_base = &internal.base;
    const child_base = &child_internal.base;

    // Delegate to src/dom/mutation.zig - single source of truth
    // preRemove checks that child's parent is parent and throws NotFoundError if not
    _ = dom_module.mutation.preRemove(child_base, parent_base) catch |err| {
        return switch (err) {
            error.HierarchyRequestError => error.HierarchyRequestError,
            error.NotFoundError => error.NotFoundError,
            else => error.InvalidStateError,
        };
    };

    return child;
}

/// Operation: replaceChild
/// https://dom.spec.whatwg.org/#dom-node-replacechild
/// Delegates to src/dom/mutation.zig - THE single source of truth for tree operations
pub fn call_replaceChild(instance: *runtime.Instance, node: *runtime.Instance, child: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const child_internal = getInternal(child) orelse return error.InvalidStateError;
    const node_internal = getInternal(node) orelse return error.InvalidStateError;

    const parent_base = &internal.base;
    const child_base = &child_internal.base;
    const node_base = &node_internal.base;

    // Delegate to src/dom/mutation.zig - single source of truth
    _ = dom_module.mutation.replace(child_base, node_base, parent_base) catch |err| {
        return switch (err) {
            error.HierarchyRequestError => error.HierarchyRequestError,
            error.NotFoundError => error.NotFoundError,
            else => error.InvalidStateError,
        };
    };

    return child;
}

// =============================================================================
// Namespace Operations
// =============================================================================

/// Operation: lookupPrefix
/// https://dom.spec.whatwg.org/#dom-node-lookupprefix
pub fn call_lookupPrefix(instance: *runtime.Instance, namespace: ?runtime.DOMString) anyerror!?runtime.DOMString {
    // lookupPrefix step 1: an absent/empty namespace has no prefix.
    const ns = namespace orelse return null;
    if (ns.len() == 0) return null;
    var element = try namespaceElement(instance);
    while (element) |e| : (element = try interfaces.Node.get_parentElement(e)) {
        const names = dom_module.node_creation.elementNames(e) orelse return null;
        // Locate a namespace prefix, steps 1-2: own prefix, then the first
        // xmlns-prefixed attribute whose value matches.
        if (equalOptionalBytes(names.namespace, ns.asSlice())) {
            if (names.prefix) |prefix| return try runtime.DOMString.initDupe(instance.ctx.allocator, prefix);
        }
        var i: usize = 0;
        while (dom_module.element_attributes.at(e, i)) |attribute| : (i += 1) {
            if (equalOptionalBytes(attribute.prefix, "xmlns") and std.mem.eql(u8, attribute.value, ns.asSlice()))
                return try runtime.DOMString.initDupe(instance.ctx.allocator, attribute.local_name);
        }
        // Step 3: continue at the parent element. Step 4: null at the root.
    }
    return null;
}

/// The interface switch shared by locate-a-namespace and lookupPrefix.
/// A Document's *element* matters: a preceding PI/comment must not recurse
/// back into the Document. Attr starts at its owner, other nodes at a parent
/// element, and fragments/doctypes have no namespace context.
fn namespaceElement(instance: *runtime.Instance) !?*runtime.Instance {
    return switch (try get_nodeType(instance)) {
        NodeType.ELEMENT_NODE => instance,
        NodeType.DOCUMENT_NODE => try interfaces.Document.get_documentElement(instance),
        NodeType.ATTRIBUTE_NODE => try interfaces.Attr.get_ownerElement(instance),
        NodeType.DOCUMENT_TYPE_NODE, NodeType.DOCUMENT_FRAGMENT_NODE => null,
        else => try interfaces.Node.get_parentElement(instance),
    };
}

fn equalOptionalBytes(a: ?[]const u8, b: ?[]const u8) bool {
    if (a) |left| return if (b) |right| std.mem.eql(u8, left, right) else false;
    return b == null;
}

/// DOM locate-a-namespace. The result is borrowed; neither walking nor
/// isDefaultNamespace needs to allocate. Only the IDL string getter copies.
fn locateNamespace(instance: *runtime.Instance, prefix: ?[]const u8) !?[]const u8 {
    var element = try namespaceElement(instance);
    while (element) |e| : (element = try interfaces.Node.get_parentElement(e)) {
        // Element steps 1-2: reserved prefixes (on an element context only).
        if (equalOptionalBytes(prefix, "xml")) return "http://www.w3.org/XML/1998/namespace";
        if (equalOptionalBytes(prefix, "xmlns")) return "http://www.w3.org/2000/xmlns/";
        const names = dom_module.node_creation.elementNames(e) orelse return null;
        // Step 3: the element's own non-null namespace and matching prefix.
        if (names.namespace != null and equalOptionalBytes(names.prefix, prefix)) return names.namespace;
        // Step 4: an xmlns attribute, including an explicit undeclaration.
        var i: usize = 0;
        while (dom_module.element_attributes.at(e, i)) |attribute| : (i += 1) {
            if (!equalOptionalBytes(attribute.namespace, "http://www.w3.org/2000/xmlns/")) continue;
            const matches = if (prefix) |p|
                equalOptionalBytes(attribute.prefix, "xmlns") and std.mem.eql(u8, attribute.local_name, p)
            else
                attribute.prefix == null and std.mem.eql(u8, attribute.local_name, "xmlns");
            if (matches) return if (attribute.value.len == 0) null else attribute.value;
        }
        // Steps 5-6: continue at the parent element, or return null.
    }
    return null;
}

/// https://dom.spec.whatwg.org/#dom-node-lookupnamespaceuri
pub fn call_lookupNamespaceURI(instance: *runtime.Instance, prefix: ?runtime.DOMString) anyerror!?runtime.DOMString {
    // Step 1 normalizes the empty prefix to null; step 2 locates it.
    const p: ?[]const u8 = if (prefix) |value| (if (value.len() == 0) null else value.asSlice()) else null;
    const namespace = try locateNamespace(instance, p) orelse return null;
    return try runtime.DOMString.initDupe(instance.ctx.allocator, namespace);
}

/// https://dom.spec.whatwg.org/#dom-node-isdefaultnamespace
pub fn call_isDefaultNamespace(instance: *runtime.Instance, namespace: ?runtime.DOMString) anyerror!bool {
    // Steps 1-3: normalize, locate the null prefix, compare the namespaces.
    const ns: ?[]const u8 = if (namespace) |value| (if (value.len() == 0) null else value.asSlice()) else null;
    return equalOptionalBytes(try locateNamespace(instance, null), ns);
}

// =============================================================================
// Helper Functions for External Use
// =============================================================================

/// `dom.node_creation.setNodeLocalName`: `setLocalName`, with the declared
/// error set a function pointer needs.
fn setLocalNameHook(instance: *runtime.Instance, name: runtime.DOMString) dom_module.node_creation.Error!void {
    return setLocalName(instance, name);
}

/// Set the local name (used by Element, Attr, etc.)
/// Also names the NodeBase (NodeBase.nodeName) for DOM operations.
pub fn setLocalName(instance: *runtime.Instance, name: runtime.DOMString) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Also name the NodeBase for DOM operations (post-connection steps, etc.):
    // the uppercase of the local name, owned by the node (its rare data).
    {
        const node_base = &internal.base;
        const name_slice = name.asSlice();
        // The NodeBase owns it, and frees it with its own allocator.
        const upper_name = try node_base.allocator().alloc(u8, name_slice.len);
        errdefer node_base.allocator().free(upper_name);
        for (name_slice, 0..) |c, i| {
            upper_name[i] = std.ascii.toUpper(c);
        }
        try node_base.setOwnedNodeName(upper_name);
    }
}

/// Set the owner document
/// `dom.node_document`'s implementation: the same step, with the declared
/// error set a function pointer needs.
fn setNodeDocumentHook(node: *runtime.Instance, document: ?*runtime.Instance) dom_module.node_document.Error!void {
    try setOwnerDocument(node, document);
    if (document != null) dom_module.template_contents.establish(node) catch |err| return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        else => error.InvalidStateError,
    };
}

pub fn setOwnerDocument(instance: *runtime.Instance, doc: ?*runtime.Instance) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const previous = internal.owner_document;
    const previous_counts = liveDocumentCounts(internal);
    internal.owner_document = doc;
    internal.owner_document_generation = if (doc) |document| runtime.SlabAllocator.generationOf(document) else 0;

    // The tree algorithms in src/dom read the node document off the NodeBase,
    // as the document's own NodeBase. Both copies name the same document:
    // `insert` adopts into it, and adopting is what removes a node from its
    // old parent, so a NodeBase with no document made every move into a node
    // built through the DOM API leave the moved node in two child lists.
    {
        const base = &internal.base;
        base.owner_document = null;
        if (doc) |document| {
            if (getInternal(document)) |document_internal| {
                base.owner_document = @ptrCast(@alignCast(&document_internal.base));
            }
        }
        if (doc != previous) {
            // The node's reference - and, a detached root, its holds - move
            // to the new document's counts (refcount design 1.5, D6).
            dom_module.refcount.nodeDocumentChanged(base, previous_counts, if (doc) |document| dom_module.refcount.documentCounts(document) else null);
        }
    }
}

/// The counts of the node document `internal` names, or null when it names
/// none - or one freed under it (its slot's generation moved on), whose
/// counts went with it.
fn liveDocumentCounts(internal: *InternalState) ?*dom_module.refcount.DocumentCounts {
    const document = internal.owner_document orelse return null;
    if (runtime.SlabAllocator.generationOf(document) != internal.owner_document_generation) return null;
    return dom_module.refcount.documentCounts(document);
}

/// dom.refcount: the counts of `node`'s live node document.
fn nodeDocumentCounts(node: *runtime.Instance) ?*dom_module.refcount.DocumentCounts {
    const internal = getInternal(node) orelse return null;
    return liveDocumentCounts(internal);
}

/// The node is being freed: its node document's counts let it go (refcount
/// design 1.5). A document freed before its node - the realm-end teardown
/// order lane ownerdoc found (a template's inert document before its
/// contents) - has no counts left to update; that is the case step 7's
/// referencing-node count makes impossible, by keeping the document's
/// storage until the count is zero.
fn releaseDocumentCounts(internal: *InternalState, base: *NodeBase) void {
    const counts = liveDocumentCounts(internal);
    if (counts == null and internal.owner_document != null and
        runtime.SlabAllocator.generationOf(internal.owner_document.?) != internal.owner_document_generation)
    {
        if (dom_module.refcount.diagnosticsOn()) refcount_log.warn("a node outlived its node document's storage (node type {d})", .{base.node_type});
    }
    dom_module.refcount.nodeFreed(base, counts);
}

/// Get the node type
pub fn getNodeType(instance: *runtime.Instance) ?u16 {
    const internal = getInternal(instance) orelse return null;
    return internal.base.node_type;
}

/// Get the parent node (returns null if no parent or instance has no state)
/// This is a convenience helper for Range and other impls that need nullable parent access
pub fn getParent(instance: *runtime.Instance) ?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    const node_base = &internal.base;
    const parent_base = node_base.parent_node orelse return null;
    const parent_opaque = instance_bridge.getInstance(parent_base) orelse return null;
    return @ptrCast(@alignCast(parent_opaque));
}

/// Get the first child (returns null if no children or instance has no state)
/// This is a convenience helper for iterating children
pub fn getFirstChild(instance: *runtime.Instance) ?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    const node_base = &internal.base;
    const first_base = node_base.first_child orelse return null;
    const first_opaque = instance_bridge.getInstance(first_base) orelse return null;
    return @ptrCast(@alignCast(first_opaque));
}

/// Get the next sibling (returns null if no sibling or instance has no state)
/// This is a convenience helper for iterating children
pub fn getNextSibling(instance: *runtime.Instance) ?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    const node_base = &internal.base;
    const next_base = node_base.next_sibling orelse return null;
    const next_opaque = instance_bridge.getInstance(next_base) orelse return null;
    return @ptrCast(@alignCast(next_opaque));
}

/// Get the previous sibling (returns null if no sibling or instance has no state)
/// This is a convenience helper for traversing siblings backwards
pub fn getPreviousSibling(instance: *runtime.Instance) ?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    const node_base = &internal.base;
    const prev_base = node_base.previousSibling() orelse return null;
    const prev_opaque = instance_bridge.getInstance(prev_base) orelse return null;
    return @ptrCast(@alignCast(prev_opaque));
}

/// Get the last child (returns null if no children or instance has no state)
/// This is a convenience helper for reverse child iteration
pub fn getLastChild(instance: *runtime.Instance) ?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    const node_base = &internal.base;
    const last_base = node_base.lastChild() orelse return null;
    const last_opaque = instance_bridge.getInstance(last_base) orelse return null;
    return @ptrCast(@alignCast(last_opaque));
}

/// Check if node has any children
/// This is a convenience helper for tree traversal
pub fn hasChildren(instance: *runtime.Instance) bool {
    const internal = getInternal(instance) orelse return false;
    const node_base = &internal.base;
    return node_base.first_child != null;
}

/// Get the number of child nodes
/// This is a convenience helper for Range and other impls
pub fn getChildCount(instance: *runtime.Instance) u32 {
    const internal = getInternal(instance) orelse return 0;
    const node_base = &internal.base;
    var count: u32 = 0;
    var child = node_base.first_child;
    // Safety limit to prevent infinite loops from corrupted DOM trees
    // A typical DOM tree shouldn't have more than 1M direct children
    const max_iterations: u32 = 1_000_000;
    while (child) |c| {
        count += 1;
        if (count >= max_iterations) {
            // Likely a cycle in the tree - return current count to avoid hang
            return count;
        }
        child = c.next_sibling;
    }
    return count;
}

/// Get the owner document (returns null if this is a Document or no state)
/// Per DOM spec: "The ownerDocument getter steps are to return null, if this
/// is a document; otherwise this's node document."
/// https://dom.spec.whatwg.org/#dom-node-ownerdocument
pub fn getOwnerDocument(instance: *runtime.Instance) ?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    // Document nodes have no owner document (they ARE the document)
    if (internal.base.node_type == NodeType.DOCUMENT_NODE) return null;
    return liveOwnerDocument(internal) catch null;
}

/// Append a node as the last child
/// This is a public helper for DOMImplementation and other impls
pub fn appendChild(parent: *runtime.Instance, node: *runtime.Instance) !*runtime.Instance {
    return call_appendChild(parent, node);
}

/// How `releaseNodeBase` treats the node document's counts.
const DocumentCounts = enum { with_document_counts, without_document_counts };

/// The one exit of a node's NodeBase - its deinit, that deinit's
/// out-of-memory branch, and the final teardown sweep of nodes still alive -
/// so they cannot drift apart (the sweep once freed the NodeBase and not its
/// name: one leak per element alive at exit). In the order its links need
/// (lane perf2 batch 4):
/// 1. every registered observer is told and its entry freed
///    (dom.observer_registrations.releaseList), while the bridge still names
///    the node;
/// 2. the rare data that held them goes, an owned node name with it;
/// 3. its teardown is marked begun (instance_lifecycle.markCleanupStarted,
///    which Node.deinit made already; the final sweep's release makes it
///    here): the slab generation can outlive the NodeBase, and a hold on
///    the node (dom.node_holds) reads it as gone from here and forgets its
///    reference - the redesign's P6 deleted the per-node chain of holds;
/// 4. the node document's counts let it go (not in the final sweep, whose
///    documents go in no order);
/// 5. the bridge forgets the node - an observer's `liveNode` reads null from
///    here - and the NodeBase is freed.
///
/// Before any of it, in a Debug build: the node's wrapper slot is empty. No
/// node is released while its engine wrapper is bound - an engine's
/// reference to the slot (V8's node anchor, `slot_`) would outlive the bytes
/// it names (tmp/redesign/wrapper-redesign-design.md 4.9 "Browser end": "a
/// Debug check in the batch free asserts every slot is empty"; risk 8 of
/// tmp/redesign/node-memory-architecture.md). A node's own teardown ends its
/// wrapper first (engine.platformObjectDestroyed); the Browser's end ends
/// every one (engine.releaseNodeWrappers) before its sweeps reach
/// `sweepOne`. Debug only (`builtin.optimize`, never std.debug.assert, which
/// ReleaseSafe keeps: the deep review's Z3).
fn releaseNodeBase(instance: *runtime.Instance, internal: *InternalState, counts: DocumentCounts) void {
    const node_base = &internal.base;
    if (@import("builtin").optimize == .debug and !node_base.wrapper.isEmpty())
        std.debug.panic("Node: a {s} was released with its wrapper slot still bound - its wrapper must end first (engine.platformObjectDestroyed; at the Browser's end engine.releaseNodeWrappers, before the teardown sweeps)", .{instance.vtable.name});
    dom_module.observer_registrations.releaseList(instance, node_base);
    node_base.deinitRareData();
    _ = runtime.instance_lifecycle.markCleanupStarted(instance);
    if (counts == .with_document_counts) releaseDocumentCounts(internal, node_base);
    instance_bridge.unregister(instance);
    // The NodeBase is the State block's (`InternalState.base`): released, not
    // freed - its bytes go back with the block. Poisoned as the tests' and the
    // WPT correctness runner's allocators poison a freed block (Debug builds,
    // and a Browser that asked: runtime.BrowserScope.poisonsReleasedNodes), so
    // a read of a released NodeBase still faults the way a read of the freed
    // one did.
    if (runtime.BrowserScope.ofInstance(instance).poisonsReleasedNodes())
        @memset(std.mem.asBytes(node_base), runtime.ArenaAllocator.poison_byte);
    // "The node has no NodeBase from here": this level's live bit, which
    // every reader of this state passes first (Registry.get). It was a null
    // `node_base` pointer; both of the callers cleared the bit right after.
    Registry.remove(instance);
}

/// dom.teardown_sweeps: clean up ALL of `scope`'s remaining Node internal
/// states AND their NodeBases, at its Browser's end.
/// It catches any leaked nodes
/// that were removed from the tree (via removeChild) but never explicitly deinited.
///
/// This function properly frees:
/// 1. NodeBase (the tree structure)
/// 2. InternalState owned strings
/// 3. Unregisters from instance_bridge
fn sweepRemaining(scope: *runtime.BrowserScope) void {
    // Every node of the Browser whose state no deinit removed (a slab walk,
    // runtime.OwnState.sweep), its field cleared after.
    Registry.sweep(scope, {}, sweepOne);
}

fn sweepOne(_: void, instance: *runtime.Instance, internal: *InternalState) void {
    releaseNodeBase(instance, internal, .without_document_counts);
}
