//! NodeBase - Base type for WebIDL interface inheritance (Node hierarchy)
//!
//! This provides a flat memory layout for the Node inheritance hierarchy,
//! enabling safe downcasting between Node types (Node, Element, CharacterData, etc.)
//!
//! Design Pattern: Flat Memory Layout with Type Header
//! - All concrete node types (Element, CharacterData, etc.) have NodeBase as FIRST field
//! - This allows safe @ptrCast between NodeBase* and concrete types
//! - Runtime type checking via node_type ensures type safety
//!
//! Spec: https://dom.spec.whatwg.org/#interface-node

const std = @import("std");
const infra = @import("infra");
const runtime = @import("runtime");
const engine = @import("engine");
const Allocator = std.mem.Allocator;
const interfaces = @import("interfaces");
const custom_elements = @import("custom_elements.zig");

// Forward declarations at file scope
const DocumentType = interfaces.Document;
pub const RegisteredObserverType = @import("registered_observer.zig").RegisteredObserver;

/// A node's own data: the tree links, the node document, the type and flags,
/// the counts, the wrapper slot. Every node type's State keeps one by value
/// (Node's embedded state), at `offset_in_state` of its block.
///
/// An `extern struct` (lane nm1's layout batch; tmp/redesign/
/// node-memory-plan-v2.md X4, I1, I3): its field order is this declaration's,
/// whatever Zig's auto layout would choose - code computes into the block
/// (`ofState`, the planned 32-bit links and folded Instance), and an auto
/// struct's order is a sort by alignment that Zig does not promise (the deep
/// review's Z2). Every offset is pinned in tests/dom/
/// nm1_node_layout_pins_test.zig; a new field is added THERE first.
///
/// The order is by use, in 32-byte windows, each half a cache line (the
/// research review's R5: on x86-64 a cold scattered walk ran 1.1-1.8x faster
/// with its fields in one window than spread over 40 bytes; Chilimbi,
/// Davidson and Larus, PLDI 1999; Blink reordered Node's fields for the same
/// reason after pointer compression, Chrome 108):
///
///     +0  the WALK: parent, first child, next sibling, then 8 bytes of
///         type and flags - what `querySelector`, a collection, a tree
///         walker and a mutation's ancestor checks read on every node
///     +32 what a link, an adoption and a wrap read: the previous link, the
///         node document, the rare data, the wrapper slot
///     +64 the owner and the two counts
///
/// The type and flags stay bytes of their own, at pinned offsets: one packed
/// 32-bit word (the plan's N7) saves nothing until the links are 32-bit, and
/// `traces_held` must not share a word the node's thread rewrites while a
/// collector reads it (the deep review's Z7).
pub const NodeBase = extern struct {
    // ========================================================================
    // +0: the walk's window
    // ========================================================================

    // Parent pointer. Written only through `setParent`.
    parent_node: ?*NodeBase = null,

    // The tree links. `first_child` and `next_sibling` are what they say;
    // there is no `last_child` (lane perf2 batch 6): a node's previous link
    // holds its previous sibling, or - for a first child - its parent's LAST
    // child, as Gecko's nsIContent::mPreviousOrLastSibling does
    // (nsINode::GetLastChild reads mFirstChild->mPreviousOrLastSibling;
    // GetPreviousSibling returns null when the link's target has no next
    // sibling, which only the last child lacks). 8 bytes a node. Read
    // through `previousSibling()` and `lastChild()`, written only by
    // `linkChildBefore` and `unlinkChild`.
    first_child: ?*NodeBase = null,
    next_sibling: ?*NodeBase = null,

    // No child list (lane perf2 batch 5, R6 part 2): the links above ARE the
    // children, as in Blink, WebKit, Gecko and Lightpanda - `children()`,
    // `childCount()`, `childAt()`, `index()`. Script's indexed reads
    // (childNodes, children, every collection) go through
    // live_collections.IndexCache over the links (Blink's
    // CollectionIndexCache): sequential reads are O(1) each.

    node_type: u16,

    /// Connection status - true when root is a document
    /// Used by isConnected getter
    is_connected: bool = false,

    /// Whether this element is a shadow host: set by "attach a shadow root"
    /// (Element's attachShadow, the one step every shadow root attaches
    /// through), never cleared - a shadow root is never detached. A guard
    /// for the insert and remove steps' slot steps, so a tree with no shadow
    /// root pays a field test for them (Blink's HasShadowRoot bit); the
    /// shadow root itself is the Element state's, which stays the source of
    /// truth (dom.shadow_hosts.rootForHost).
    is_shadow_host: bool = false,

    /// Whether this node's type holds nodes for script itself - its
    /// VTable's `trace_held_nodes` (the wrapper redesign's P6: a Document's
    /// active parser, top layer and autofocus candidates, a dialog's saved
    /// focus) - so the walk (dom.wrapper_tracing) asks it for them where it
    /// visits the node, with no VTable read for every other node. Set once,
    /// when the node is registered (dom.instance_bridge.register). A byte
    /// of its own: nothing rewrites it while a collector's walk reads it.
    traces_held: bool = false,

    /// The reference counting state that is not a number (see RcFlags).
    rc_flags: RcFlags = .{},

    /// An element's flags (`ElementBits`): the custom element state, where
    /// its registry is, click()'s in-progress flag. All zero on every other
    /// node. Element's impl reads and writes them (`elementBits`); they are
    /// here, not in Element's own state, because five bytes there cost 8
    /// with its padding and one byte here costs none - Blink keeps the
    /// custom element state in Node::node_flags_ (kCustomElementStateMask),
    /// WebKit an element's state flags in Node (Node::ElementStateFlag).
    element: ElementBits = .{},

    /// Not used. Named, so the struct has no padding and a pin fails when
    /// something takes it (tests/dom/nm1_node_layout_pins_test.zig).
    spare: u8 = 0,

    // ========================================================================
    // +32: links, document, rare data, wrapper
    // ========================================================================

    previous_or_last: ?*NodeBase = null,

    /// The node document, in ONE word (lane nm1's layout batch; the design's
    /// N4). Read through `documentInstance`, `documentBase`, `documentKey`;
    /// written through `setDocumentInstance` (Node's impl, the one setter of
    /// a platform node's document) and `setDocumentBase` (owner-less trees).
    ///
    /// - 0: none (a Document, which is its own; a node not yet given one).
    /// - bit 0 set: the Document's runtime.Instance, for a node an Instance
    ///   owns. With bit 1 too: the Document had no live NodeBase when it was
    ///   set - `documentBase` then answers null, as the NodeBase copy this
    ///   word replaced was null there.
    /// - bit 0 clear: the Document's NodeBase, for an owner-less tree (the
    ///   tests' fixtures and the test-only WithBase types), whose document is
    ///   no Instance.
    ///
    /// It was two fields: this one as the Document's NodeBase, which
    /// src/dom's algorithms read with no check, and the Document's Instance
    /// in Node's own state, with a slab generation as the net under "a node
    /// keeps its document". One setter wrote both. Blink and WebKit keep one
    /// (Node::tree_scope_, Node::m_treeScope), Gecko one (the NodeInfo's).
    document_word: usize = 0,

    /// The fields few nodes use - the registered observer list, the node
    /// name - or null while none has been needed (NodeRareData).
    rare: ?*NodeRareData = null,

    /// The node's one wrapper per agent, whatever realm asks for it (DOM
    /// identity: `===` across realms, a MutationObserver's addedNodes[0] the
    /// element script made) - the engine's own inline slot
    /// (engine.NodeWrapperSlot; the wrapper redesign's P1,
    /// tmp/redesign/wrapper-redesign-design.md section 3.3). The node owns
    /// the bytes and asks only `wrapper.isEmpty()` ("is it wrapped"); the
    /// engine adapter owns what is in them and reaches them only through
    /// runtime.lifetime.slotOf (dom.refcount's hook). Blink keeps the main
    /// world's wrapper on the object (ScriptWrappable::wrapper_), WebKit
    /// likewise (ScriptWrappable::m_wrapper).
    wrapper: engine.NodeWrapperSlot = .empty,

    // ========================================================================
    // +64: the owner and the counts
    // ========================================================================

    /// Who owns this NodeBase, in one word (lane perf2 batch 6): the
    /// runtime.Instance whose node it is (`ownerInstance`), or - for a
    /// NodeBase built outside the WebIDL layer, the tests' fixtures and the
    /// test-only WithBase types - the allocator it allocates from, tagged in
    /// bit 0 (`ownerless`), or 0 for neither (a node before its registration
    /// and after its release).
    ///
    /// The owner is a property OF the node, so it belongs on the node: it
    /// replaced the global `nodebase_to_instance` map in
    /// src/dom/instance_bridge.zig (process-wide, on page_allocator, "NOT
    /// thread-safe", consulted 37 times on the DOM hot path), and it dies
    /// with the node. It also names the node's allocator, so the node keeps
    /// no copy of one (`allocator`): an owned node's is its Browser's, found
    /// from the Instance's address (runtime.allocatorOf), which is the
    /// allocator it was made with - asserted where every node is made
    /// (Node's initOwn). 16 bytes a node.
    owner: usize = 0,

    /// The reference count word, WebKit's encoding (Source/WebCore/dom/Node.h
    /// `m_refCountAndParentBit`): bit 0 is the parent bit (this node has a
    /// parent), the rest is the count of references held through `Ref`, in
    /// units of `rc_one`. A node is born with one reference, its creator's.
    /// Maintained only through src/dom/refcount.zig; nothing reads it for
    /// lifetime yet (tmp/plans/refcount-design.md, steps 2 to 6: shadow mode).
    /// Non-atomic: nodes belong to one agent's thread.
    rc: u32 = rc_one,

    /// The number of held nodes - nodes whose count is not zero - in this
    /// node's host-including subtree, itself included: decision D1 (a held node
    /// keeps its whole tree) as arithmetic. A tree is garbage when its root's
    /// total is 0. A node is born held (`rc_one`), so it starts at 1.
    subtree_holds: u32 = 1,

    /// The slab generation of the node document's Instance when
    /// `document_word` was set to it: the net under the rule that a node
    /// keeps its document (its referencing-node count, and for its wrappers
    /// the walk's D6 rule, dom.wrapper_tracing). A document freed under a
    /// node that names it - a hole in that rule - reads as none
    /// (`documentBase`, Node's ownerDocument), never as the freed object or
    /// whatever took its slot. It was Node's own field, beside the Instance
    /// pointer; with the pointer here, src/dom's readers pass the net too.
    /// 0 for an owner-less tree's document.
    document_generation: u64 = 0,

    comptime {
        // The tests pin every offset; these two are what this file itself
        // computes with.
        std.debug.assert(@sizeOf(NodeBase) == 88);
        std.debug.assert(@alignOf(NodeBase) == 8);
    }

    /// An element's flags, in NodeBase's `element` byte. Zero is an element
    /// as its State block is made: custom element state "undefined" (HTML
    /// "create an element" sets it), no registry place, nothing in progress.
    pub const ElementBits = packed struct(u8) {
        /// HTML: the element's custom element state, as
        /// dom.custom_elements.State's integer value (`customElementState`).
        custom_element_state: u3 = 0,
        /// Whether a custom element reaction was ever enqueued for the
        /// element (its queue must be cancelled at its teardown).
        custom_element_ever_enqueued: bool = false,
        /// Set only while Element's `appendAttributeHook` appends a style
        /// attribute copied by cloning, and consumed by the style
        /// attribute's change steps, which then skip their CSP check.
        appending_clone: bool = false,
        /// DOM: where the element's custom element registry is - none, its
        /// node document's, or its rare data's association
        /// (dom.custom_elements.RegistryPlace, lane perf3 E1).
        registry_place: custom_elements.RegistryPlace = .none,
        /// HTMLElement's: HTML click() steps 2-5's "click in progress flag"
        /// (lane rare1: the one bool that would make a rare block on its
        /// own; Blink and WebKit keep it out of the element too -
        /// EventDispatcher::DispatchSimulatedClick's and simulateClick's
        /// set of elements).
        click_in_progress: bool = false,

        comptime {
            std.debug.assert(@typeInfo(custom_elements.State).@"enum".field_names.len <= 8);
        }

        pub fn customElementState(self: ElementBits) custom_elements.State {
            return @fromBackingInt(@intCast(self.custom_element_state));
        }

        pub fn setCustomElementState(self: *ElementBits, state: custom_elements.State) void {
            self.custom_element_state = @backingInt(state);
        }
    };

    /// The address of click()'s in-progress flag in an element's NodeBase
    /// (`&node.element.click_in_progress`): a bit - bit 7 of its one-byte
    /// host - so a bit pointer.
    pub const ClickInProgress = *align(1:7:1) bool;

    // ========================================================================
    // Reference counting (tmp/plans/refcount-design.md section 1)
    // ========================================================================

    /// One reference in `rc`'s units (WebKit `s_refCountIncrement`).
    pub const rc_one: u32 = 2;
    /// `rc`'s parent bit (WebKit `s_refCountMask` is its complement).
    pub const rc_parent_bit: u32 = 1;

    /// The booleans the count machinery keeps beside the numbers.
    pub const RcFlags = packed struct(u8) {
        /// The node is the root of a tree whose total reached zero and which
        /// is queued for teardown: a `Ref` taken on it is a bug, and a
        /// `WeakRef` reads it as gone.
        garbage: bool = false,
        /// The node is being torn down (WebKit
        /// `applyRefDuringDestructionCheck`): a `Ref` taken on it is a bug.
        destroying: bool = false,
        /// A parentless shadow root or template contents whose host is
        /// alive: its holds count in its host's chain (design 1.4, the
        /// host-including chain). Set and cleared only by refcount.zig.
        hosted: bool = false,
        /// A parentless, unhosted node that is not a Document and has a
        /// node document: the root of a detached tree, whose
        /// `subtree_holds` count in its document's `foreign_holds`
        /// (decision D6). Set and cleared only by refcount.zig.
        foreign: bool = false,
        /// The reference the node was born with (`rc_one`) is still its
        /// creator's, offered to whoever takes the node on first
        /// (refcount7; refcount design 1.2, "the creator of a node until it
        /// hands the node on"): its first wrapper adopts it - WebKit's
        /// binding moves the `Ref` a create function returned into the new
        /// wrapper (bindings/js/JSDOMWrapperCache.h `createWrapper`,
        /// "domObject is moved into the wrapper") - or, inserted first, the
        /// tree takes the node over and the creator's reference ends, as a
        /// WebKit creator's `Ref` ends at its scope after the append (the
        /// parent bit keeps the node). A Document offers it too (refcount
        /// step 5i): the holder it is made for takes it over
        /// (`refcount.takeOverCreatorReference`: a Window, a template's
        /// owner document's holder, an SVG resource), or its first wrapper
        /// does. Cleared once a creator that hands its reference on itself
        /// has claimed it (the HTML parser, decision D-A). Set and cleared
        /// only by refcount.zig.
        creator: bool = true,
        /// The zombie audit (refcount step 6, dom.refcount_audit): the root
        /// of a tree the counts called garbage, queued for its re-check at
        /// the agent's next teardown slice. Set and cleared only there.
        audit_pending: bool = false,
        /// The zombie audit: a node of a tree that re-check found garbage -
        /// one step 7 would have freed. A read of it is reported.
        zombie: bool = false,
        /// A remover holds the node across what follows its removal: one
        /// counted reference taken at the unlink (`refcount.unlinkChildHeld`;
        /// WebKit's `Ref protectedOldChild`, insert's NodeVector of
        /// Ref<Node>), ended by its next link (`refcount.linkChild`) or by
        /// the remover (`refcount.endRemovalHold`). Set and cleared only by
        /// refcount.zig.
        removal_held: bool = false,
    };

    // ========================================================================
    // The node document (lane nm1: one word)
    // ========================================================================

    /// `document_word` names a Document's Instance (else its NodeBase, or none).
    const document_instance_tag: usize = 1;
    /// With `document_instance_tag`: the Document had no live NodeBase when
    /// the word was set.
    const document_no_base_tag: usize = 2;
    const document_tags: usize = document_instance_tag | document_no_base_tag;

    /// The node document's Instance - what Node's impl hands script and every
    /// caller outside src/dom - or null: none set, or an owner-less tree's
    /// document, which no Instance owns. NOT checked against the net: Node's
    /// impl checks `documentIsLive` where it did before.
    pub inline fn documentInstance(self: *const NodeBase) ?*runtime.Instance {
        const word = self.document_word;
        if (word & document_instance_tag == 0) return null;
        return @ptrFromInt(word & ~document_tags);
    }

    /// Whether the node document's Instance is still the one that was set:
    /// its slot was not freed (or freed and reissued) under this node. True
    /// for a node that names no Instance.
    pub inline fn documentIsLive(self: *const NodeBase) bool {
        const instance = self.documentInstance() orelse return true;
        return runtime.SlabAllocator.generationOf(instance) == self.document_generation;
    }

    /// The node document's own NodeBase, for src/dom's algorithms, or null:
    /// none set, the document had no NodeBase when it was set, or - the net -
    /// its Instance was freed under this node (this was a dangling pointer
    /// then). A Document's own answer is null: `getNodeDocument` is DOM's
    /// "node document", which for a document is itself.
    pub inline fn documentBase(self: *const NodeBase) ?*NodeBase {
        const word = self.document_word;
        if (word & document_instance_tag == 0) return @ptrFromInt(word);
        if (word & document_no_base_tag != 0) return null;
        const instance: *const runtime.Instance = @ptrFromInt(word & ~document_tags);
        if (runtime.SlabAllocator.generationOf(instance) != self.document_generation) return null;
        return ofState(instance.state);
    }

    /// The node document's identity, for `==`, `!= 0` and cache keys: equal
    /// for two nodes exactly when `documentBase` named one document for both,
    /// and 0 where it was null. Reads nothing through the word and never
    /// asks the net, so the counts' bookkeeping at a teardown - where a
    /// document can go before a node that names it - compares what it always
    /// compared. A Document's own key is `keyAsDocument`.
    pub inline fn documentKey(self: *const NodeBase) usize {
        const word = self.document_word;
        if (word & document_instance_tag == 0) return word;
        if (word & document_no_base_tag != 0) return 0;
        return word & ~document_tags;
    }

    /// This node's key as a node document - what `documentKey` answers for
    /// the nodes that name it: its Instance for a Document an Instance owns,
    /// its own address for an owner-less one.
    pub inline fn keyAsDocument(self: *const NodeBase) usize {
        if (self.owner != 0 and self.owner & ownerless_tag == 0) return self.owner;
        return @intFromPtr(self);
    }

    /// Node's impl, the one setter of a platform node's document: name
    /// `document`'s Instance, with its generation. `has_base` is whether the
    /// document has a live NodeBase now (its Node state is made and not torn
    /// down); without one `documentBase` answers null.
    pub fn setDocumentInstance(self: *NodeBase, document: ?*runtime.Instance, has_base: bool) void {
        const instance = document orelse {
            self.document_word = 0;
            self.document_generation = 0;
            return;
        };
        std.debug.assert(@intFromPtr(instance) & document_tags == 0);
        self.document_word = @intFromPtr(instance) | document_instance_tag | if (has_base) @as(usize, 0) else document_no_base_tag;
        self.document_generation = runtime.SlabAllocator.generationOf(instance);
    }

    /// An owner-less tree's node document: `document`'s NodeBase, or none.
    /// For a Document an Instance owns, the Instance is named (so every
    /// reader of the word agrees) - src/dom's adopt on a platform tree goes
    /// through dom.node_document, which calls `setDocumentInstance`.
    pub fn setDocumentBase(self: *NodeBase, document: ?*NodeBase) void {
        const base = document orelse {
            self.document_word = 0;
            self.document_generation = 0;
            return;
        };
        if (base.ownerInstance()) |raw| {
            self.setDocumentInstance(@ptrCast(@alignCast(raw)), true);
            return;
        }
        std.debug.assert(@intFromPtr(base) & document_tags == 0);
        self.document_word = @intFromPtr(base);
        self.document_generation = 0;
    }

    // ========================================================================
    // The owner word (lane perf2 batch 6)
    // ========================================================================

    /// The runtime.Instance this node is, or null: a node not yet
    /// registered, one its teardown released, or one no Instance owns.
    /// Typed `?*anyopaque` to keep src/dom free of a hard dependency on the
    /// concrete runtime.Instance type, matching the bridge API it replaces.
    pub inline fn ownerInstance(self: *const NodeBase) ?*anyopaque {
        if (self.owner & ownerless_tag != 0) return null;
        return @ptrFromInt(self.owner);
    }

    /// dom.instance_bridge's register and unregister: the Instance this
    /// node is from now on, or none.
    pub fn setOwnerInstance(self: *NodeBase, instance: ?*anyopaque) void {
        const address = @intFromPtr(instance);
        std.debug.assert(address & ownerless_tag == 0);
        self.owner = address;
    }

    /// The owner word of a NodeBase no Instance owns, which allocates from
    /// `allocator_of_node` - borrowed: it must outlive the node (the tests
    /// pass `&std.testing.allocator`, a WithBase type its own field).
    pub fn ownerless(allocator_of_node: *const Allocator) usize {
        const address = @intFromPtr(allocator_of_node);
        std.debug.assert(address & ownerless_tag == 0);
        return address | ownerless_tag;
    }

    /// The allocator an owner-less NodeBase's owner word names
    /// (`ownerless`), for a WithBase type that makes a part of its own with
    /// it (an attribute node).
    pub fn ownerlessAllocator(self: *const NodeBase) *const Allocator {
        std.debug.assert(self.owner & ownerless_tag != 0);
        return @ptrFromInt(self.owner & ~ownerless_tag);
    }

    /// What this node allocates and frees from - its rare data, its observer
    /// records, a mutation's scratch lists: its Browser's allocator for an
    /// owned node (runtime.allocatorOf, the allocator it was made with), the
    /// one its owner word names for an owner-less one. Never called on a
    /// node with no owner (before its registration, after its release).
    pub fn allocator(self: *const NodeBase) Allocator {
        if (self.owner & ownerless_tag != 0) {
            const named: *const Allocator = @ptrFromInt(self.owner & ~ownerless_tag);
            return named.*;
        }
        if (self.owner == 0) @panic("a NodeBase with no owner allocates: not registered yet, or released");
        const instance: *const runtime.Instance = @ptrFromInt(self.owner);
        return runtime.allocatorOf(instance);
    }

    /// The owner word's tag: set for an allocator, clear for an Instance.
    /// Both are 8-byte aligned, so bit 0 is free.
    const ownerless_tag: usize = 1;

    // ========================================================================
    // Rare data (lane perf2 batch 4, R6 part 1)
    // ========================================================================

    /// The node's rare data, or null when none was ever needed.
    pub fn rareData(self: *const NodeBase) ?*NodeRareData {
        return self.rare;
    }

    /// The node's rare data, made on first use (WebKit `ensureRareData`) and
    /// kept, never moved, until the node's teardown (`deinitRareData`).
    /// Public for dom.slot_helpers' writers' path (a Text node's slottable
    /// state, lane perf3 E1); every other field has its writer here.
    pub fn ensureRareData(self: *NodeBase) error{OutOfMemory}!*NodeRareData {
        if (self.rare) |rare| return rare;
        const rare = try self.allocator().create(NodeRareData);
        rare.* = .{};
        self.rare = rare;
        if (self.domMemory()) |memory| memory.add(@sizeOf(NodeRareData));
        return rare;
    }

    /// The DOM memory of this node's Browser (runtime.BrowserScope.dom_memory),
    /// which counts what the node holds so V8 can schedule collections by it
    /// (runtime.own_state.nodeDomMemory): its rare data and its registered
    /// observer entries are counted here, as they are made and freed. Null for
    /// a NodeBase no Instance owns (the test-only WithBase types), and after
    /// the node's teardown unregistered it - nothing is counted for it then.
    fn domMemory(self: *const NodeBase) ?*runtime.gc.ExternalMemory {
        const owner = self.ownerInstance() orelse return null;
        const instance: *const runtime.Instance = @ptrCast(@alignCast(owner));
        return &runtime.BrowserScope.ofInstance(instance).dom_memory;
    }

    /// The node's teardown, after its registered observers were released
    /// (dom.observer_registrations.releaseList): frees an owned node name and
    /// the block. Nothing may be registered on the node any more.
    pub fn deinitRareData(self: *NodeBase) void {
        const rare = self.rare orelse return;
        std.debug.assert(rare.registered_observers.first == null);
        if (rare.node_name_allocated) self.allocator().free(rare.node_name);
        self.allocator().destroy(rare);
        self.rare = null;
        if (self.domMemory()) |memory| memory.sub(@sizeOf(NodeRareData));
    }

    /// The node name a node type gave its NodeBase, or "" - every node but
    /// the HTML and SVG script, iframe, embed, object and frame elements
    /// (and the test-only WithBase types). Not DOM's nodeName: a brand the
    /// insertion, removing and post-connection steps dispatch on. Read only
    /// through here, so a tag of its own (Z4/R12) changes only this.
    pub fn nodeName(self: *const NodeBase) []const u8 {
        const rare = self.rare orelse return "";
        return rare.node_name;
    }

    /// Whether the node owns its name (`setOwnedNodeName`).
    pub fn hasOwnedNodeName(self: *const NodeBase) bool {
        const rare = self.rare orelse return false;
        return rare.node_name_allocated;
    }

    /// Name the node with `name`, which outlives it (a literal).
    pub fn setStaticNodeName(self: *NodeBase, name: []const u8) error{OutOfMemory}!void {
        const rare = try self.ensureRareData();
        if (rare.node_name_allocated) self.allocator().free(rare.node_name);
        rare.node_name = name;
        rare.node_name_allocated = false;
    }

    /// Name the node with `name`, allocated from the node's allocator: the
    /// node owns it from here and frees it with its rare data. On failure
    /// the caller still owns it.
    pub fn setOwnedNodeName(self: *NodeBase, name: []const u8) error{OutOfMemory}!void {
        const rare = try self.ensureRareData();
        if (rare.node_name_allocated) self.allocator().free(rare.node_name);
        rare.node_name = name;
        rare.node_name_allocated = true;
    }

    /// DOM 4.3: the node's registered observer list, in order - registration
    /// order, transient registered observers appended like any other.
    pub fn registeredObservers(self: *const NodeBase) RegisteredObserverIterator {
        const rare = self.rare orelse return .{ .next_link = null };
        return .{ .next_link = rare.registered_observers.first };
    }

    /// Whether anything is registered on the node.
    pub fn hasRegisteredObservers(self: *const NodeBase) bool {
        const rare = self.rare orelse return false;
        return rare.registered_observers.first != null;
    }

    /// Append `registered` to the node's registered observer list (observe()
    /// step 8, "remove" step 15): one record, allocated from the node's
    /// allocator, that stays where it is until it is removed.
    pub fn appendRegisteredObserver(self: *NodeBase, registered: RegisteredObserverType) error{OutOfMemory}!*RegisteredObserverType {
        const rare = try self.ensureRareData();
        const record = try self.allocator().create(ObserverRegistration);
        record.* = .{ .registered = registered };
        rare.registered_observers.append(&record.link);
        if (self.domMemory()) |memory| memory.add(@sizeOf(ObserverRegistration));
        return &record.registered;
    }

    /// Remove `registered` - one of this node's - from its registered
    /// observer list and free its record. Constant time.
    pub fn removeRegisteredObserver(self: *NodeBase, registered: *RegisteredObserverType) void {
        const rare = self.rare.?;
        const record: *ObserverRegistration = @fieldParentPtr("registered", registered);
        rare.registered_observers.remove(&record.link);
        self.allocator().destroy(record);
        if (self.domMemory()) |memory| memory.sub(@sizeOf(ObserverRegistration));
    }

    /// The one write of `parent_node` (WebKit `Node::setParentNode`): the
    /// pointer and the parent bit of `rc` together. The holds a link moves
    /// are refcount.zig's (`linkChild`, `unlinkChild`, `moveChild`); this is
    /// only the write, which `zig build lint-refcount` allows nowhere else.
    pub fn setParent(self: *NodeBase, parent: ?*NodeBase) void {
        self.parent_node = parent;
        self.rc = (self.rc & ~rc_parent_bit) | @intFromBool(parent != null);
    }

    // ========================================================================
    // Children: the sibling links (lane perf2 batch 5, R6 part 2)
    // ========================================================================

    /// DOM: the node's previous sibling, or null for a first child (or a
    /// node with no parent): the previous link of a first child is its
    /// parent's last child, the one child with no next sibling (Gecko's
    /// nsINode::GetPreviousSibling, "do not expose circular linked list").
    pub inline fn previousSibling(self: *const NodeBase) ?*NodeBase {
        const link = self.previous_or_last orelse return null;
        if (link.next_sibling == null) return null;
        return link;
    }

    /// DOM: the node's last child, or null: its first child's previous link
    /// (Gecko's nsINode::GetLastChild).
    pub inline fn lastChild(self: *const NodeBase) ?*NodeBase {
        const first = self.first_child orelse return null;
        return first.previous_or_last;
    }

    /// Link `child` - in no tree's links - into this node's children before
    /// `before` (one of them), or after the last with null. The links only:
    /// the parent pointer and its holds are the caller's (`setParent`,
    /// refcount.linkChild). Constant time.
    pub fn linkChildBefore(self: *NodeBase, child: *NodeBase, before: ?*NodeBase) void {
        std.debug.assert(child.previous_or_last == null and child.next_sibling == null);
        if (before) |next| {
            std.debug.assert(next.parent_node == self);
            child.next_sibling = next;
            if (next.previousSibling()) |previous| {
                previous.next_sibling = child;
                child.previous_or_last = previous;
            } else {
                // `child` becomes the first child: its previous link holds
                // the last child, which `next`'s held until now.
                child.previous_or_last = next.previous_or_last;
                self.first_child = child;
            }
            next.previous_or_last = child;
            return;
        }
        if (self.first_child) |first| {
            const last = first.previous_or_last.?;
            last.next_sibling = child;
            child.previous_or_last = last;
            first.previous_or_last = child;
        } else {
            // The only child is its own last child.
            self.first_child = child;
            child.previous_or_last = child;
        }
    }

    /// Unlink `child` - one of this node's children - from its siblings. The
    /// links only: the parent pointer is the caller's. Constant time.
    pub fn unlinkChild(self: *NodeBase, child: *NodeBase) void {
        const first = self.first_child.?;
        const next = child.next_sibling;
        if (child == first) {
            self.first_child = next;
            // The new first child holds the last child (null if none left).
            if (next) |n| n.previous_or_last = child.previous_or_last;
        } else {
            const previous = child.previous_or_last.?;
            previous.next_sibling = next;
            if (next) |n| {
                n.previous_or_last = previous;
            } else {
                // `child` was the last: the first child holds the new last.
                first.previous_or_last = previous;
            }
        }
        child.previous_or_last = null;
        child.next_sibling = null;
    }

    /// The node's children in tree order, read off its links. The next child
    /// is read before the current one is yielded, so a walk may remove or
    /// move the child it is at - not a later one.
    pub fn children(self: *const NodeBase) ChildIterator {
        return .{ .next_child = self.first_child };
    }

    /// The node's children in reverse tree order; the previous child is read
    /// before the current one is yielded.
    pub fn childrenReversed(self: *const NodeBase) ReverseChildIterator {
        return .{ .previous_child = self.lastChild() };
    }

    /// DOM 4.2.1: how many children the node has - a walk of its links.
    pub fn childCount(self: *const NodeBase) usize {
        var count: usize = 0;
        var child = self.first_child;
        while (child) |c| : (child = c.next_sibling) count += 1;
        return count;
    }

    /// The node's child at `index` in tree order, or null past the last one:
    /// a walk of its links.
    pub fn childAt(self: *const NodeBase, index_wanted: usize) ?*NodeBase {
        var at: usize = 0;
        var child = self.first_child;
        while (child) |c| : (child = c.next_sibling) {
            if (at == index_wanted) return c;
            at += 1;
        }
        return null;
    }

    /// DOM 4.2.1: "the index of an object is its number of preceding
    /// siblings, or 0 if it has none" - a walk of its previous links, counted
    /// only where the spec asks for an index (live ranges, positions).
    pub fn index(self: *const NodeBase) usize {
        var count: usize = 0;
        var sibling = self.previousSibling();
        while (sibling) |s| : (sibling = s.previousSibling()) count += 1;
        return count;
    }

    pub const ChildIterator = struct {
        next_child: ?*NodeBase,

        pub fn next(self: *ChildIterator) ?*NodeBase {
            const child = self.next_child orelse return null;
            self.next_child = child.next_sibling;
            return child;
        }
    };

    pub const ReverseChildIterator = struct {
        previous_child: ?*NodeBase,

        pub fn next(self: *ReverseChildIterator) ?*NodeBase {
            const child = self.previous_child orelse return null;
            self.previous_child = child.previousSibling();
            return child;
        }
    };

    // ========================================================================
    // Node Type Constants (DOM Spec §5.1)
    // ========================================================================

    pub const ELEMENT_NODE: u16 = 1;
    pub const ATTRIBUTE_NODE: u16 = 2;
    pub const TEXT_NODE: u16 = 3;
    pub const CDATA_SECTION_NODE: u16 = 4;
    pub const ENTITY_REFERENCE_NODE: u16 = 5; // Historical
    pub const ENTITY_NODE: u16 = 6; // Historical
    pub const PROCESSING_INSTRUCTION_NODE: u16 = 7;
    pub const COMMENT_NODE: u16 = 8;
    pub const DOCUMENT_NODE: u16 = 9;
    pub const DOCUMENT_TYPE_NODE: u16 = 10;
    pub const DOCUMENT_FRAGMENT_NODE: u16 = 11;
    pub const NOTATION_NODE: u16 = 12; // Historical

    // ========================================================================
    // Document Position Constants (DOM Spec §5.8)
    // ========================================================================

    pub const DOCUMENT_POSITION_DISCONNECTED: u16 = 0x01;
    pub const DOCUMENT_POSITION_PRECEDING: u16 = 0x02;
    pub const DOCUMENT_POSITION_FOLLOWING: u16 = 0x04;
    pub const DOCUMENT_POSITION_CONTAINS: u16 = 0x08;
    pub const DOCUMENT_POSITION_CONTAINED_BY: u16 = 0x10;
    pub const DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC: u16 = 0x20;

    // ========================================================================
    // Safe Downcasting Utilities
    // ========================================================================

    /// Safely cast NodeBase to Element (using ElementWithBase temporarily)
    pub fn asElement(node: *NodeBase) ?*Element {
        if (node.node_type != ELEMENT_NODE) return null;
        // Safe: Element has NodeBase as first field, so addresses are identical
        return @ptrCast(node);
    }

    /// Safely cast const NodeBase to const Element
    pub fn asElementConst(node: *const NodeBase) ?*const Element {
        if (node.node_type != ELEMENT_NODE) return null;
        return @ptrCast(node);
    }

    /// Safely cast NodeBase to CharacterData
    /// Returns null if node is not a CharacterData-based node
    pub fn asCharacterData(node: *NodeBase) ?*CharacterData {
        const is_text_like = node.node_type == TEXT_NODE or
            node.node_type == CDATA_SECTION_NODE or
            node.node_type == COMMENT_NODE;
        if (!is_text_like) return null;
        return @ptrCast(node);
    }

    /// Safely cast const NodeBase to const CharacterData
    pub fn asCharacterDataConst(node: *const NodeBase) ?*const CharacterData {
        const is_text_like = node.node_type == TEXT_NODE or
            node.node_type == CDATA_SECTION_NODE or
            node.node_type == COMMENT_NODE;
        if (!is_text_like) return null;
        return @ptrCast(node);
    }

    /// Safely cast NodeBase to Text
    pub fn asText(node: *NodeBase) ?*Text {
        if (node.node_type != TEXT_NODE) return null;
        return @ptrCast(node);
    }

    /// Safely cast NodeBase to Comment
    pub fn asComment(node: *NodeBase) ?*Comment {
        if (node.node_type != COMMENT_NODE) return null;
        return @ptrCast(node);
    }

    /// Safely cast NodeBase to Attr (using AttrWithBase temporarily)
    pub fn asAttr(node: *NodeBase) ?*AttrWithBase {
        if (node.node_type != ATTRIBUTE_NODE) return null;
        return @ptrCast(node);
    }

    /// Safely cast const NodeBase to const Attr
    pub fn asAttrConst(node: *const NodeBase) ?*const AttrWithBase {
        if (node.node_type != ATTRIBUTE_NODE) return null;
        return @ptrCast(node);
    }

    /// Safely cast NodeBase to Document
    pub fn asDocument(node: *NodeBase) ?*DocumentType {
        if (node.node_type != DOCUMENT_NODE) return null;
        return @ptrCast(node);
    }

    // ========================================================================
    // Common Node Operations
    // ========================================================================

    /// Get the root node (walk up to parent until we reach the root)
    /// DOM Spec: https://dom.spec.whatwg.org/#concept-tree-root
    pub fn getRoot(self: *NodeBase) *NodeBase {
        var current = self;
        while (current.parent_node) |parent| {
            current = parent;
        }
        return current;
    }

    /// Check if this node contains another node
    /// DOM Spec: https://dom.spec.whatwg.org/#dom-node-contains
    pub fn contains(self: *const NodeBase, other: ?*const NodeBase) bool {
        if (other == null) return false;
        const other_node = other.?;
        if (self == other_node) return true;

        var current = other_node.parent_node;
        while (current) |parent| {
            if (parent == self) return true;
            current = parent.parent_node;
        }
        return false;
    }

    /// Check if node is connected (root is a document)
    /// DOM Spec: https://dom.spec.whatwg.org/#connected
    pub fn isConnected(self: *const NodeBase) bool {
        var current = self;
        while (current.parent_node) |parent| {
            current = parent;
        }
        return current.node_type == DOCUMENT_NODE;
    }

    /// DOM "node document" (https://dom.spec.whatwg.org/#concept-node-document),
    /// as its own NodeBase: a Document's is itself, every other node's is the
    /// one it was given at creation and that only "adopt" changes
    /// (`documentBase`). Null before a node is given one, and for a document
    /// freed under its node.
    pub fn getNodeDocument(self: *NodeBase) ?*NodeBase {
        if (self.node_type == DOCUMENT_NODE) return self;
        return self.documentBase();
    }

    /// `getNodeDocument` for a const node.
    pub fn getNodeDocumentConst(self: *const NodeBase) ?*const NodeBase {
        if (self.node_type == DOCUMENT_NODE) return self;
        return self.documentBase();
    }
};

/// Where a node's NodeBase sits in its State block: in Node's embedded state,
/// which every node interface's State nests at offset 0. One number for all
/// of them - tests/dom/nm1_node_layout_pins_test.zig pins it over every node
/// interface (Zig alone promises neither part: the deep review's Z2).
pub const offset_in_state: usize = @offsetOf(interfaces.Node.State, "_embedded") +
    @offsetOf(@FieldType(interfaces.Node.State, "_embedded"), "base");

/// The NodeBase of the node whose State block starts at `state` - any level's
/// State of a node, since each starts at the block's first byte. Only for a
/// State the caller knows is a node's (an impl holding its own node's
/// state): nothing is checked.
pub inline fn ofState(state: *const anyopaque) *NodeBase {
    return @ptrFromInt(@intFromPtr(state) + offset_in_state);
}

/// The fields few nodes ever use, kept out of every NodeBase (WebKit
/// NodeRareData, Blink NodeRareData, Gecko nsINode::nsSlots): allocated once,
/// on first use, from the node's allocator, and never moved or reallocated -
/// Blink 601c5205e1d5 fixed a corruption from rare data that reallocated
/// while a caller held a pointer into it. Freed by the node's own teardown
/// (NodeBase.deinitRareData).
pub const NodeRareData = struct {
    /// DOM 4.3: "Each node has a registered observer list (a list of zero or
    /// more registered observers), which is initially empty." Intrusive:
    /// one ObserverRegistration per entry, appended at the tail, removed in
    /// constant time - the order is the list's.
    registered_observers: std.DoublyLinkedList = .{},
    /// NodeBase.nodeName's, and whether the node owns it.
    node_name: []const u8 = "",
    node_name_allocated: bool = false,
    /// DOM 4.2.2.2: a Text node as a slottable - its assigned slot and its
    /// manual slot assignment (an Element's are in its ElementRareData).
    /// Written only through dom.slot_helpers.ensureSlottable, for a node a
    /// slot assigns; readers of a node with no rare data read
    /// dom.slot_helpers.unassigned (lane perf3 E1; Blink's FlatTreeNodeData,
    /// kFlatTreeNodeData in NodeRareData; WebKit's m_manuallyAssignedSlot in
    /// NodeRareData). Owns nothing.
    slottable: @import("slot_helpers.zig").SlottableState = .{},
};

/// One entry of a node's registered observer list: its link and the
/// registered observer (or transient registered observer). A separate
/// allocation of the node's, so an entry never moves while the list grows.
pub const ObserverRegistration = struct {
    link: std.DoublyLinkedList.Node = .{},
    registered: RegisteredObserverType,
};

/// A walk of a node's registered observer list, head to tail. It reads each
/// entry's successor before handing the entry out, so the entry it handed out
/// last may be removed (NodeBase.removeRegisteredObserver) during the walk.
pub const RegisteredObserverIterator = struct {
    next_link: ?*std.DoublyLinkedList.Node,

    pub fn next(self: *RegisteredObserverIterator) ?*RegisteredObserverType {
        const link = self.next_link orelse return null;
        self.next_link = link.next;
        const record: *ObserverRegistration = @fieldParentPtr("link", link);
        return &record.registered;
    }
};

// Forward declarations for concrete types we cast to
// Using the WithBase variants until codegen is updated for XPath/selectors
const Element = @import("element_with_base.zig").ElementWithBase;
const Text = @import("text_with_base.zig").TextWithBase;
const Comment = @import("text_with_base.zig").CommentWithBase;
const AttrWithBase = @import("attr_with_base.zig").AttrWithBase;

// CharacterData from generated WebIDL interfaces
// Has NodeBase as first field, enabling safe downcasting
pub const CharacterData = interfaces.CharacterData;

// ============================================================================
// Tests
// ============================================================================
// NodeBase is tested via the concrete node types (Element, CharacterData, etc.)
// See tests/dom/ for comprehensive node hierarchy tests
