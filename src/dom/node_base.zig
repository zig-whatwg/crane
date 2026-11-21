//! NodeBase - a node's own data: the tree links, the node document, the type
//! and flags, the counts, the wrapper slot.
//!
//! One layout for every node type, kept BY VALUE in the node's State block
//! (Node's embedded state, at `offset_in_state` of the block): the block is
//! the node, as a Blink or WebKit Node is one object. A NodeBase exists
//! nowhere else - no test and no helper type builds one by value (lane wb1
//! retired the ElementWithBase / TextWithBase / AttrWithBase types and the
//! owner-less NodeBases: node-memory plan v2, X3), so a NodeBase is never
//! cast to or recovered from a surrounding struct. A node's type-specific
//! data is its interface's State, reached through its Instance
//! (`instance()`), never through the NodeBase's address.
//!
//! Spec: https://dom.spec.whatwg.org/#interface-node

const std = @import("std");
const builtin = @import("builtin");
const infra = @import("infra");
const runtime = @import("runtime");
const engine = @import("engine");
const Allocator = std.mem.Allocator;
const interfaces = @import("interfaces");
const custom_elements = @import("custom_elements.zig");
const rare_data = @import("node_rare_data.zig");
const event_listener_list = @import("event_listener_list.zig");

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
/// collector reads it (the deep review's Z7). The eight bytes are full: the
/// node type, the State chain's live bits (lane nm3), and six of flags.
pub const NodeBase = extern struct {
    // ========================================================================
    // +0: the walk's window
    // ========================================================================

    // Parent pointer. Written only through `setParent`.
    parent_node: ?*NodeBase = null,

    // The tree links. The first child and `next_sibling` are what they say;
    // there is no `last_child` (lane perf2 batch 6): a node's previous link
    // holds its previous sibling, or - for a first child - its parent's LAST
    // child, as Gecko's nsIContent::mPreviousOrLastSibling does
    // (nsINode::GetLastChild reads mFirstChild->mPreviousOrLastSibling;
    // GetPreviousSibling returns null when the link's target has no next
    // sibling, which only the last child lacks). 8 bytes a node. Read
    // through `previousSibling()` and `lastChild()`, written only by
    // `linkChildBefore` and `unlinkChild`.
    //
    // The first-child word is shared (lane nm2, the design's N9): a node
    // that can have children keeps its first child in it; a LEAF - a
    // CharacterData node, which DOM lets have none - keeps a word of its own
    // data there (`leaf`, `claimLeafWord`). So nothing reads it as a child
    // but `firstChild()`, which answers null for a leaf; the field's name
    // says so, and `zig build lint-refcount` holds that no file but this
    // one names it. Blink and WebKit keep the pointer in ContainerNode only
    // (ContainerNode::first_child_, m_firstChild) and their
    // Node::firstChild() answers null for any other node.
    child_or_leaf: ChildOrLeaf = .{ .first_child = null },
    next_sibling: ?*NodeBase = null,

    // No child list (lane perf2 batch 5, R6 part 2): the links above ARE the
    // children, as in Blink, WebKit, Gecko and Lightpanda - `children()`,
    // `childCount()`, `childAt()`, `index()`. Script's indexed reads
    // (childNodes, children, every collection) go through
    // live_collections.IndexCache over the links (Blink's
    // CollectionIndexCache): sequential reads are O(1) each.

    /// DOM 4.4 nodeType: 1 to 12 (the constants below), in one byte since
    /// lane nm3 - it was a u16 whose high byte was always 0. WebKit keeps it
    /// in four bits of a 16-bit word of flags (Node::m_typeBitFields).
    node_type: u8,

    /// The live bits of this node's State chain (runtime.OwnState): bit `d`
    /// is set while the level `d` steps above Node's (Node's own is bit 0,
    /// Element's or CharacterData's bit 1, ...) has its impl's state made
    /// and not torn down. The byte `node_type` gave up (lane nm3, plan v2
    /// I1): it was a 4-byte word of EventTarget's level, which a node's
    /// State no longer nests - Blink keeps such facts in Node::node_flags_.
    /// Nothing in src/dom reads it: Node's impl hands its address to the
    /// runtime (its InternalState's `liveBits`), and Node's release keeps it
    /// across the poison it writes over the rest of this struct.
    live: u8 = 0,

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
    /// its registry is, click()'s in-progress flag. On a Document, the same
    /// byte is the Document's own flags (`DocumentBits`, `documentBits`): a
    /// Document is never an element, and Element's impl reaches this byte
    /// only through an element's state. All zero on every other node.
    /// Element's impl reads and writes them (`elementBits`); they are
    /// here, not in Element's own state, because five bytes there cost 8
    /// with its padding and one byte here costs none - Blink keeps the
    /// custom element state in Node::node_flags_ (kCustomElementStateMask),
    /// WebKit an element's state flags in Node (Node::ElementStateFlag).
    element: ElementBits = .{},

    /// Whether this node is a LEAF: its first-child word (`child_or_leaf`)
    /// holds a word of the node's own data, not a child. Set once, by the
    /// node type that takes the word (`claimLeafWord`: CharacterData, at its
    /// construction), and never cleared - a node's type is fixed. False on
    /// every node that can have children. It took the spare byte: the struct
    /// still has no padding (tests/dom/nm1_node_layout_pins_test.zig).
    leaf: bool = false,

    // ========================================================================
    // +32: links, document, rare data, wrapper
    // ========================================================================

    previous_or_last: ?*NodeBase = null,

    /// The node document, in ONE word (lane nm1's layout batch; the design's
    /// N4). Read through `documentInstance`, `documentBase`, `documentKey`;
    /// written through `setDocumentInstance` (Node's impl, the one setter of
    /// a node's document).
    ///
    /// - 0: none (a Document, which is its own; a node not yet given one).
    /// - otherwise the Document's runtime.Instance. With bit 0 set too: the
    ///   Document had no live NodeBase when the word was set - `documentBase`
    ///   then answers null, as the NodeBase copy this word replaced was null
    ///   there.
    ///
    /// It was two fields: this one as the Document's NodeBase, which
    /// src/dom's algorithms read with no check, and the Document's Instance
    /// in Node's own state, with a slab generation as the net under "a node
    /// keeps its document". One setter wrote both. Blink and WebKit keep one
    /// (Node::tree_scope_, Node::m_treeScope), Gecko one (the NodeInfo's).
    /// Until lane wb1 the word had a third form, a bare NodeBase as the
    /// document of a tree no Instance owned (the tests' fixtures and the
    /// WithBase types), and a tag bit to tell it from an Instance.
    document_word: usize = 0,

    /// The node's ONE rare word (lane nm2): the fields few nodes use, in one
    /// sparse block (dom.node_rare_data) - the node's own (the registered
    /// observer list, the node name, a Text's slottable state) and, on an
    /// element, Element's and HTMLElement's - or empty while none has been
    /// needed. The block MOVES when it grows: read it by value, write it
    /// through this field's address, never keep a pointer into it. It was a
    /// pointer to a fixed 104-byte NodeRareData, beside a second rare word
    /// in every element's state. Blink keeps one (Node::data_), WebKit one
    /// (Node::m_rareDataWithBitfields).
    rare: rare_data.Holder = .{},

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

    /// The runtime.Instance whose node this is, in one word (lane perf2
    /// batch 6), or 0: a node before its registration and after its release
    /// (dom.instance_bridge's register and unregister write it). Read through
    /// `instance()` - by code that holds a live node - and
    /// `registeredInstance()`, the liveness test.
    ///
    /// The owner is a property OF the node, so it belongs on the node: it
    /// replaced the global `nodebase_to_instance` map in
    /// src/dom/instance_bridge.zig (process-wide, on page_allocator, "NOT
    /// thread-safe", consulted 37 times on the DOM hot path), and it dies
    /// with the node. It also names the node's allocator, so the node keeps
    /// no copy of one (`allocator`): its Browser's, found from the
    /// Instance's address (runtime.allocatorOf), which is the allocator it
    /// was made with - asserted where every node is made (Node's initOwn).
    /// 16 bytes a node.
    ///
    /// Until lane wb1 the word could also name an allocator, tagged in bit 0,
    /// for a NodeBase no Instance owned (the tests' fixtures and the WithBase
    /// types): every node is an Instance's now (node-memory plan v2, X3), and
    /// the plan's H3 folds the Instance into the node block, where this word
    /// becomes address arithmetic.
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
    /// 0 while the node names no document.
    document_generation: u64 = 0,

    comptime {
        // The tests pin every offset; these two are what this file itself
        // computes with.
        std.debug.assert(@sizeOf(NodeBase) == 88);
        std.debug.assert(@alignOf(NodeBase) == 8);
    }

    /// The first-child word: a container's first child, or a leaf's own
    /// word. `extern`, so it has no hidden tag in safe builds: 8 bytes.
    pub const ChildOrLeaf = extern union {
        first_child: ?*NodeBase,
        leaf_word: usize,
    };

    /// DOM: the node's first child, or null - for a node with no children,
    /// and for a leaf, whose word is its own data. The one read of the word
    /// as a child (Blink's Node::firstChild(): "DynamicTo<ContainerNode>",
    /// else nullptr; WebKit's the same).
    pub inline fn firstChild(self: *const NodeBase) ?*NodeBase {
        if (self.leaf) return null;
        return self.child_or_leaf.first_child;
    }

    /// The node type that owns this node's leaf word takes it, once, at the
    /// node's construction - before the node can be linked anywhere, so the
    /// word is still null: from here `firstChild()` answers null and the
    /// word is the caller's (CharacterData keeps its data's word in it:
    /// dom.character_data.Data). Zeroed.
    pub fn claimLeafWord(self: *NodeBase) *usize {
        std.debug.assert(!self.leaf and self.child_or_leaf.first_child == null);
        self.leaf = true;
        self.child_or_leaf = .{ .leaf_word = 0 };
        return &self.child_or_leaf.leaf_word;
    }

    /// A leaf's own word, for the node type that claimed it. The check is
    /// Debug only (`builtin.mode`, never std.debug.assert, which ReleaseSafe
    /// keeps: the deep review's Z3): every read of a text node's data
    /// passes here.
    pub inline fn leafWord(self: *NodeBase) *usize {
        if (builtin.mode == .debug and !self.leaf) @panic("NodeBase.leafWord on a node that claimed no leaf word");
        return &self.child_or_leaf.leaf_word;
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

    /// A Document's flags, in NodeBase's `element` byte (which only an
    /// element's state uses as ElementBits): read where a pointer load must
    /// do, with no lookup of the Document's state (Blink keeps such document
    /// facts as bits too, Document::document_classes_ and the like).
    pub const DocumentBits = packed struct(u8) {
        /// Whether the document ever had an element with a headingoffset or
        /// headingreset attribute (dom.heading_offsets; sticky): until it
        /// has, :heading skips HTML's computed heading offset walk.
        heading_offsets_seen: bool = false,
        _unused: u7 = 0,
    };

    /// A Document's flags (`DocumentBits`), in this node's `element` byte.
    /// The check is Debug only, as `leafWord`'s.
    pub inline fn documentBits(self: *NodeBase) *DocumentBits {
        if (builtin.mode == .debug and self.node_type != DOCUMENT_NODE) @panic("NodeBase.documentBits on a node that is not a Document");
        return @ptrCast(&self.element);
    }

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

    /// With the Document's Instance in `document_word`: the Document had no
    /// live NodeBase when the word was set. An Instance is 8-aligned, so the
    /// bit is free.
    const document_no_base_tag: usize = 1;

    /// The node document's Instance - what Node's impl hands script and every
    /// caller outside src/dom - or null when none is set. NOT checked against
    /// the net: Node's impl checks `documentIsLive` where it did before.
    pub inline fn documentInstance(self: *const NodeBase) ?*runtime.Instance {
        return @ptrFromInt(self.document_word & ~document_no_base_tag);
    }

    /// Whether the node document's Instance is still the one that was set:
    /// its slot was not freed (or freed and reissued) under this node. True
    /// for a node that names no document.
    pub inline fn documentIsLive(self: *const NodeBase) bool {
        const document = self.documentInstance() orelse return true;
        return runtime.SlabAllocator.generationOf(document) == self.document_generation;
    }

    /// The node document's own NodeBase, for src/dom's algorithms, or null:
    /// none set, the document had no NodeBase when it was set, or - the net -
    /// its Instance was freed under this node (this was a dangling pointer
    /// then). A Document's own answer is null: `getNodeDocument` is DOM's
    /// "node document", which for a document is itself.
    pub inline fn documentBase(self: *const NodeBase) ?*NodeBase {
        const word = self.document_word;
        if (word == 0 or word & document_no_base_tag != 0) return null;
        const document: *const runtime.Instance = @ptrFromInt(word);
        if (runtime.SlabAllocator.generationOf(document) != self.document_generation) return null;
        return ofState(document.state);
    }

    /// The node document's identity, for `==`, `!= 0` and cache keys: equal
    /// for two nodes exactly when `documentBase` named one document for both,
    /// and 0 where it was null. Reads nothing through the word and never
    /// asks the net, so the counts' bookkeeping at a teardown - where a
    /// document can go before a node that names it - compares what it always
    /// compared. A Document's own key is `keyAsDocument`.
    pub inline fn documentKey(self: *const NodeBase) usize {
        const word = self.document_word;
        if (word & document_no_base_tag != 0) return 0;
        return word;
    }

    /// This node's key as a node document - what `documentKey` answers for
    /// the nodes that name it: its Instance. For a Document already
    /// released, whose owner word no longer names one (a teardown's
    /// bookkeeping can still ask), its own address as before - a key no node
    /// names.
    pub inline fn keyAsDocument(self: *const NodeBase) usize {
        if (self.registeredInstance()) |document| return @intFromPtr(document);
        return @intFromPtr(self);
    }

    /// Node's impl, the one setter of a node's document: name `document`'s
    /// Instance, with its generation. `has_base` is whether the document has
    /// a live NodeBase now (its Node state is made and not torn down);
    /// without one `documentBase` answers null.
    pub fn setDocumentInstance(self: *NodeBase, document: ?*runtime.Instance, has_base: bool) void {
        const named = document orelse {
            self.document_word = 0;
            self.document_generation = 0;
            return;
        };
        std.debug.assert(@intFromPtr(named) & document_no_base_tag == 0);
        self.document_word = @intFromPtr(named) | if (has_base) @as(usize, 0) else document_no_base_tag;
        self.document_generation = runtime.SlabAllocator.generationOf(named);
    }

    // ========================================================================
    // The owner word (lane perf2 batch 6; one meaning since lane wb1)
    // ========================================================================

    /// Set in the owner word of no live node: an Instance is 8-aligned, and
    /// the poison the arena writes over a freed State block
    /// (runtime.ArenaAllocator.poison_byte) has it set - so a release build
    /// that poisons freed state never follows the poison as an Instance's
    /// address. It was the owner-less tag. A RELEASED node's word is 0 in
    /// every build since lane uaf1 (Node's release keeps it across its own
    /// poison), so the poison in this word means one thing, a freed block,
    /// and a Debug build panics on it (`freed_owner_word`). Pinned below and
    /// in tests/dom/wb1_withbase_retired_test.zig.
    const not_an_instance_bit: usize = 1;

    comptime {
        std.debug.assert(runtime.ArenaAllocator.poison_byte & not_an_instance_bit != 0);
        std.debug.assert(@alignOf(runtime.Instance) > not_an_instance_bit);
    }

    /// THE LIVENESS TEST: the Instance this node is, or null - a node not
    /// yet registered (inside Node's initOwn) or one its teardown released.
    /// For code that can be handed a node after its release and must do
    /// nothing then: the teardown's own bookkeeping, the collector's walk,
    /// the audit, and dom.instance_bridge.getInstance, whose callers ask
    /// exactly this. Everything else holds a live node and calls
    /// `instance()`. The plan's H3 (the Instance folded into the node block)
    /// makes this a "registered" bit of the block's stamp: the callers of
    /// this function are its list.
    pub inline fn registeredInstance(self: *const NodeBase) ?*runtime.Instance {
        self.checkBlockNotFreed();
        if (self.owner & not_an_instance_bit != 0) return null;
        return @ptrFromInt(self.owner);
    }

    // ========================================================================
    // A read of a FREED node block (lane uaf1)
    // ========================================================================

    /// The owner word of a node block the arena FREED, in a build that
    /// poisons freed state (runtime.ArenaAllocator.poison_freed: every Debug
    /// build, the bug-finding WPT runner): the poison byte in every byte.
    /// The three things the word says there:
    ///
    /// - an Instance's address: the node is registered;
    /// - 0: not registered - a node inside its construction, or one its
    ///   teardown RELEASED. Node's release keeps the 0 across the poison it
    ///   writes over the rest of the NodeBase (as it keeps `live`): the
    ///   block is still this node's own, and a holder of the address may
    ///   ask (the dispatch walk's `stands`, the teardown's own bookkeeping);
    /// - this word: the State block went back to the arena
    ///   (runtime.gc.releaseStorage). Whoever reads it kept a raw NodeBase
    ///   pointer past the node's free. In production the same read finds 0
    ///   until the arena reissues the block - at once, for the next node of
    ///   its size - and then the NEW node's Instance: "registered", as
    ///   another node.
    ///
    /// Before this lane a released node's word was poisoned too, and the
    /// poison's low bit read as "no Instance" (`not_an_instance_bit`): a
    /// liveness test of a freed block answered "gone" by accident, and no
    /// gate saw the read.
    pub const freed_owner_word: usize = @as(usize, runtime.ArenaAllocator.poison_byte) * (std.math.maxInt(usize) / 0xff);

    /// THE RULE, as a function a test can pin for every build mode (the
    /// panic itself ends the process): whether a liveness test of a NodeBase
    /// whose owner word is `owner` panics in a build of `mode`. Crane's Debug
    /// modules only - the unit tests and the bug-finding WPT runner - and
    /// never a release build: the liveness tests are on the DOM's hot paths,
    /// and there the comparison is compiled out.
    pub inline fn freedBlockReadPanics(mode: std.builtin.OptimizeMode, owner: usize) bool {
        return mode == .debug and owner == freed_owner_word;
    }

    /// Every liveness test of a NodeBase passes here first
    /// (`registeredInstance`, and through it `instance`, `allocator`,
    /// `keyAsDocument`; `stands`): a freed block is a panic that names the
    /// read, in the builds that can tell.
    inline fn checkBlockNotFreed(self: *const NodeBase) void {
        if (freedBlockReadPanics(builtin.mode, self.owner)) freedBlockRead(self);
    }

    fn freedBlockRead(self: *const NodeBase) noreturn {
        @branchHint(.cold);
        std.debug.panic("NodeBase: a liveness test read a FREED node block at {x} (its owner word is the arena's poison): a raw NodeBase pointer was kept past the node's free. The holder must test the node's slab generation first (dom.slot_helpers.NodeRef.get, dom.refcount.WeakRef.get) or hold a counted reference; in production this read finds 0 or, once the block is reissued, another node's Instance.", .{@intFromPtr(self)});
    }

    /// The Instance this node is, for code that holds a LIVE node: an
    /// argument a caller just read through its Instance, or a node reached
    /// from one by a tree link (a node linked to a live node is not released
    /// before it: a held node keeps its whole tree, and a teardown releases a
    /// tree only once nothing holds any node of it). A released or
    /// unregistered node here is a bug in the caller, and a panic in every
    /// build - one predictable test, where `ownerInstance() orelse return`
    /// was one too, and silently did nothing.
    pub inline fn instance(self: *const NodeBase) *runtime.Instance {
        return self.registeredInstance() orelse deadNode();
    }

    fn deadNode() noreturn {
        @branchHint(.cold);
        @panic("NodeBase.instance: the node is not registered (released by its teardown, or not made yet) - code that holds a live node was handed a dead one");
    }

    /// dom.instance_bridge's register and unregister: the Instance this
    /// node is from now on, or none.
    pub fn setOwnerInstance(self: *NodeBase, registered: ?*runtime.Instance) void {
        std.debug.assert(@intFromPtr(registered) & not_an_instance_bit == 0);
        self.owner = @intFromPtr(registered);
    }

    /// What this node allocates and frees from - its rare data, its observer
    /// records, a mutation's scratch lists: its Browser's allocator
    /// (runtime.allocatorOf, the allocator it was made with). Never called
    /// on a node that is not registered (before its registration, after its
    /// release): a panic.
    pub fn allocator(self: *const NodeBase) Allocator {
        const owner = self.registeredInstance() orelse @panic("a NodeBase with no Instance allocates: not registered yet, or released");
        return runtime.allocatorOf(owner);
    }

    // ========================================================================
    // Rare data (lane perf2 batch 4, R6 part 1; one sparse block since lane nm2)
    // ========================================================================

    /// The allocator the node's rare data comes from and the DOM memory it
    /// is counted in: what dom.node_rare_data's writers take. Never
    /// called on a node that is not registered (`allocator`).
    pub fn rareContext(self: *const NodeBase) rare_data.Context {
        return .{ .allocator = self.allocator(), .memory = self.domMemory() };
    }

    /// The DOM memory of this node's Browser (runtime.BrowserScope.dom_memory),
    /// which counts what the node holds so V8 can schedule collections by it
    /// (runtime.own_state.nodeDomMemory): its rare data and its registered
    /// observer entries are counted here, as they are made and freed. Null
    /// after the node's teardown unregistered it - nothing is counted for it
    /// then (Node's release frees the rare data before it unregisters, so
    /// this is a net, not a path).
    fn domMemory(self: *const NodeBase) ?*runtime.gc.ExternalMemory {
        const owner = self.registeredInstance() orelse return null;
        return &runtime.BrowserScope.ofInstance(owner).dom_memory;
    }

    /// The node's teardown, after its registered observers were released
    /// (dom.observer_registrations.releaseList): frees the rare block and
    /// what its fields still own - the registered observer list's head, an
    /// owned node name, a Text's slottable state (an element's own fields
    /// went with Element's part of the teardown, before this). Nothing may
    /// be registered on the node any more.
    pub fn deinitRareData(self: *NodeBase) void {
        if (self.rare.block == null) return;
        rare_data.destroy(self.rareContext(), &self.rare);
    }

    /// The node name a node type gave its NodeBase, or "" - every node but
    /// the HTML and SVG script, iframe, embed, object and frame elements.
    /// Not DOM's nodeName: a brand the
    /// insertion, removing and post-connection steps dispatch on. Read only
    /// through here, so a tag of its own (Z4/R12) changes only this.
    pub fn nodeName(self: *const NodeBase) []const u8 {
        const record = rare_data.get(self.rare, .node_name) orelse return "";
        return record.name;
    }

    /// Whether the node owns its name (`setOwnedNodeName`).
    pub fn hasOwnedNodeName(self: *const NodeBase) bool {
        const record = rare_data.get(self.rare, .node_name) orelse return false;
        return record.allocated;
    }

    /// Name the node with `name`, which outlives it (a literal).
    pub fn setStaticNodeName(self: *NodeBase, name: []const u8) error{OutOfMemory}!void {
        const record = try rare_data.ensureOwn(self.rareContext(), &self.rare, .node_name);
        if (record.allocated) self.allocator().free(record.name);
        record.* = .{ .name = name, .allocated = false };
    }

    /// Name the node with `name`, allocated from the node's allocator: the
    /// node owns it from here and frees it with its rare data. On failure
    /// the caller still owns it.
    pub fn setOwnedNodeName(self: *NodeBase, name: []const u8) error{OutOfMemory}!void {
        const record = try rare_data.ensureOwn(self.rareContext(), &self.rare, .node_name);
        if (record.allocated) self.allocator().free(record.name);
        record.* = .{ .name = name, .allocated = true };
    }

    // ========================================================================
    // The event listener list (lane nm3: a field of the rare block)
    // ========================================================================

    /// Whether this NodeBase - an Instance's - still stands: Node's teardown
    /// has not released it (Node's own bit of `live`, which the release
    /// clears and keeps readable across the poison it writes). For a holder
    /// of the address that may be asked again after a callback tore the
    /// node down under it (EventTarget's dispatch walk): the State block's
    /// bytes outlive the release, the fields in them do not.
    pub inline fn stands(self: *const NodeBase) bool {
        self.checkBlockNotFreed();
        return self.live & node_level_live_bit != 0;
    }

    /// DOM 2.7: the node's event listener list, BY VALUE - the list is the
    /// address of its one block (dom.event_listener_list.List), kept in a
    /// slot of the node's rare block; empty for a node that never had a
    /// listener, an event handler or a watching owner, which is nearly every
    /// node. The copy is good until the list next grows or is freed: read it
    /// again after anything that can add a listener (a callback, a step that
    /// can run script), and give a list that grew back with
    /// `setEventListeners`. Only EventTarget's impl reads and writes it.
    pub inline fn eventListeners(self: *const NodeBase) event_listener_list.List {
        return .{ .header = rare_data.get(self.rare, .event_listeners) };
    }

    /// Whether the node has an event listener list block - with listeners or
    /// without (a list whose last listener was removed keeps its block).
    pub inline fn hasEventListenerBlock(self: *const NodeBase) bool {
        return rare_data.get(self.rare, .event_listeners) != null;
    }

    /// Give the list its slot in the rare block before the list is made or
    /// grown, so that keeping it after (`setEventListeners`) cannot fail: a
    /// step that must change nothing when it fails reserves first.
    pub fn reserveEventListeners(self: *NodeBase) error{OutOfMemory}!void {
        try rare_data.reserve(self.rareContext(), &self.rare, .event_listeners);
    }

    /// Keep `list` - the node's list after it was made or grew (its block
    /// moved), in the slot `reserveEventListeners` gave it - or forget a
    /// list that was freed (empty: the slot keeps its bit and reads null).
    /// Never allocates.
    pub fn setEventListeners(self: *NodeBase, list: event_listener_list.List) void {
        if (list.header) |header| {
            rare_data.putReserved(&self.rare, .event_listeners, header);
        } else rare_data.clear(&self.rare, .event_listeners);
    }

    /// DOM 4.3: the node's registered observer list, in order - registration
    /// order, transient registered observers appended like any other.
    pub fn registeredObservers(self: *const NodeBase) RegisteredObserverIterator {
        const list = rare_data.get(self.rare, .registered_observers) orelse return .{ .next_link = null };
        return .{ .next_link = list.first };
    }

    /// Whether anything is registered on the node.
    pub fn hasRegisteredObservers(self: *const NodeBase) bool {
        const list = rare_data.get(self.rare, .registered_observers) orelse return false;
        return list.first != null;
    }

    /// Append `registered` to the node's registered observer list (observe()
    /// step 8, "remove" step 15): one record, allocated from the node's
    /// allocator, that stays where it is until it is removed. The list's
    /// head is a block of its own that the rare block points at, made with
    /// the node's first registration and kept until its teardown.
    pub fn appendRegisteredObserver(self: *NodeBase, registered: RegisteredObserverType) error{OutOfMemory}!*RegisteredObserverType {
        const list = try rare_data.ensureOwn(self.rareContext(), &self.rare, .registered_observers);
        const record = try self.allocator().create(ObserverRegistration);
        record.* = .{ .registered = registered };
        list.append(&record.link);
        if (self.domMemory()) |memory| memory.add(@sizeOf(ObserverRegistration));
        return &record.registered;
    }

    /// Remove `registered` - one of this node's - from its registered
    /// observer list and free its record. Constant time.
    pub fn removeRegisteredObserver(self: *NodeBase, registered: *RegisteredObserverType) void {
        const list = rare_data.get(self.rare, .registered_observers).?;
        const record: *ObserverRegistration = @fieldParentPtr("registered", registered);
        list.remove(&record.link);
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
        const first = self.firstChild() orelse return null;
        return first.previous_or_last;
    }

    /// Link `child` - in no tree's links - into this node's children before
    /// `before` (one of them), or after the last with null. The links only:
    /// the parent pointer and its holds are the caller's (`setParent`,
    /// refcount.linkChild). Constant time.
    pub fn linkChildBefore(self: *NodeBase, child: *NodeBase, before: ?*NodeBase) void {
        // In every build: a link written under a leaf would overwrite its
        // data's word. DOM refuses the insert long before (4.2.3 "ensure
        // pre-insert validity" step 1), so this is one predictable test.
        if (self.leaf) @panic("a child linked under a leaf node (a CharacterData node has no children)");
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
                self.child_or_leaf.first_child = child;
            }
            next.previous_or_last = child;
            return;
        }
        if (self.child_or_leaf.first_child) |first| {
            const last = first.previous_or_last.?;
            last.next_sibling = child;
            child.previous_or_last = last;
            first.previous_or_last = child;
        } else {
            // The only child is its own last child.
            self.child_or_leaf.first_child = child;
            child.previous_or_last = child;
        }
    }

    /// Unlink `child` - one of this node's children - from its siblings. The
    /// links only: the parent pointer is the caller's. Constant time.
    pub fn unlinkChild(self: *NodeBase, child: *NodeBase) void {
        // A leaf has no child to unlink (`linkChildBefore` refuses one).
        const first = self.firstChild().?;
        const next = child.next_sibling;
        if (child == first) {
            self.child_or_leaf.first_child = next;
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
        return .{ .next_child = self.firstChild() };
    }

    /// The node's children in reverse tree order; the previous child is read
    /// before the current one is yielded.
    pub fn childrenReversed(self: *const NodeBase) ReverseChildIterator {
        return .{ .previous_child = self.lastChild() };
    }

    /// DOM 4.2.1: how many children the node has - a walk of its links.
    pub fn childCount(self: *const NodeBase) usize {
        var count: usize = 0;
        var child = self.firstChild();
        while (child) |c| : (child = c.next_sibling) count += 1;
        return count;
    }

    /// The node's child at `index` in tree order, or null past the last one:
    /// a walk of its links.
    pub fn childAt(self: *const NodeBase, index_wanted: usize) ?*NodeBase {
        var at: usize = 0;
        var child = self.firstChild();
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

    // u16, as WebIDL's `unsigned short nodeType`: a comparison with the
    // field (a u8) widens it, and each value fits it.
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

/// The NodeBase of the node `instance` is, while it stands: null once Node's
/// teardown released it (Node's own live bit, bit 0 of `NodeBase.live` -
/// Node's level is the root of a node's State chain, checked below). Only
/// for an instance the caller knows is a node in a live slot - its vtable's
/// `counted` is set (runtime.lifetime) and its slab stamp is not the dead
/// one: nothing is checked here. What dom.instance_bridge.getNodeBase
/// answers through Node's hook, for a caller that reads a node's field on a
/// hot path (EventTarget's listener list on every dispatch).
pub inline fn ofLiveNode(instance: *const runtime.Instance) ?*NodeBase {
    const base = ofState(instance.state);
    if (!base.stands()) return null;
    return base;
}

/// Node's own bit of `NodeBase.live`: runtime.OwnState gives a level the bit
/// of its depth from the chain's root, and Node's State is that root.
const node_level_live_bit: u8 = 1;

comptime {
    // Node's State nests no base State (its EventTarget level is absent:
    // lane nm3), which is what makes its level bit 0.
    std.debug.assert(@FieldType(interfaces.Node.State, "base") == void);
}

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

// ============================================================================
// Tests
// ============================================================================
// NodeBase is tested via the concrete node types (Element, CharacterData, etc.)
// See tests/dom/ for comprehensive node hierarchy tests
