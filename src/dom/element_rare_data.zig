//! An element's rare data: the fields few elements ever use, kept out of
//! every element (lane perf3 D2; tmp/plans/perf3b2-element-data-design.md
//! section 3 D2).
//!
//! Over the 3.04 M elements of the perf pages none had a namespace prefix,
//! an Attr node, a shadow root, an is value, a NamedNodeMap, a nonce or an
//! `element.style` object, yet every element carried room for all of them:
//! 104 bytes of Element's InternalState, 40 of its ElementData and 72 of
//! HTMLElement's. The engines keep such fields apart:
//!
//! - WebKit's `ElementRareData : NodeRareData` (Source/WebCore/dom/
//!   ElementRareData.h) is one struct made by `Element::ensureElementRareData()`
//!   on first use: m_attributeMap (the NamedNodeMap), m_nonce,
//!   m_explicitlySetAttrElementsMap (the element references), m_dataset,
//!   m_classList, m_partList, m_customStateSet, the custom element reaction
//!   queue and its default ARIA, the popover data, ...
//! - Blink keeps them in its NodeRareData's sparse fields ("most Elements set
//!   only 0-3 of the 50+ possible fields", core/dom/node_rare_data.h):
//!   kShadowRoot, kAttributeMap, kAttrNodeList, kCssomWrapper,
//!   kElementInternals, kNonce, kIsValue, kExplicitlySetElementsForAttr,
//!   kCustomElementRegistry - a bit set and the present fields after it,
//!   which REALLOCATES when a field is added (its Set*()/Ensure*() are
//!   [[nodiscard]] for that reason; Blink 601c5205e1d5 fixed a corruption
//!   from rare data that moved while a caller held a pointer into it).
//!
//! Crane takes WebKit's shape: ONE fixed struct, made on first use, never
//! moved or reallocated, so a pointer into it stays good for the element's
//! life (perf2's NodeRareData, src/dom/node_base.zig, is made the same way).
//! It is the element's: allocated from its Browser's allocator
//! (runtime.allocatorOf), counted in its Browser's DOM memory while it lives,
//! and freed at both of the element's exits - its deinit, and its Browser's
//! teardown sweep for an element no teardown reached (docs/lessons/
//! architecture-an-element-alive-at-teardown-is-swept-not-deinitd.md).
//!
//! Element owns it and supplies `of` and `ensure` through the hook slot it
//! already installs for its ElementData (dom.element_data's Implementation:
//! one slot per owner, not one per field): HTMLElement reaches its part
//! (`html`) through them, never through Element's impl (AGENTS.md "The impls
//! boundary"). What each field means is its owner's: Element's fields are
//! written only by Element, `html` only by HTMLElement.
const std = @import("std");

const runtime = @import("runtime");
const element_data = @import("element_data.zig");
const same_object = @import("same_object.zig");
const custom_elements = @import("custom_elements.zig");
const element_references = @import("element_references.zig");
const slot_helpers = @import("slot_helpers.zig");

/// HTMLElement's part: every field its InternalState kept (88 bytes on every
/// HTML element before D2). Written only by HTMLElement.
pub const HTMLElementRareData = struct {
    /// HTML 2.5.6 [[CryptographicNonce]], owned independently of the content
    /// attribute. Null means unused/removed; an explicitly empty slot may
    /// still accompany a nonempty attribute that must hide on connection.
    cryptographic_nonce: ?[]u8 = null,
    /// The ElementInternals attachInternals() made, if any.
    element_internals: ?*runtime.Instance = null,
    /// element.style ([SameObject]): the CSSStyleProperties over the
    /// element's inline declaration block, kept for the element's life
    /// (`style_declaration_kept`).
    /// Spec: https://drafts.csswg.org/cssom/#dom-elementcssinlinestyle-style
    style_declaration: ?*runtime.Instance = null,
    style_declaration_kept: same_object.KeptChild = .{},
    /// HTML "click in progress flag" (click() steps 2-5).
    click_in_progress: bool = false,
    /// Whether the element draws an edge to `element_internals`.
    internals_traced: bool = false,
    /// Whether attachInternals() has been called (it can be only once).
    internals_attached: bool = false,

    /// Free what the part owns: the nonce, and element.style's object
    /// (severed from the element; its wrapper, which the element's traced,
    /// goes with the element's). `allocator` is the element's Browser's.
    /// HTMLElement's deinit and teardown sweep run this; the rare data's own
    /// `destroy` runs it again, which then finds nothing.
    pub fn release(self: *HTMLElementRareData, allocator: std.mem.Allocator) void {
        if (self.cryptographic_nonce) |nonce| allocator.free(nonce);
        self.cryptographic_nonce = null;
        if (self.style_declaration) |style| self.style_declaration_kept.releaseOwned(style);
        self.style_declaration = null;
    }
};

/// The rare fields of one element.
pub const ElementRareData = struct {
    /// DOM 4.9: the element's namespace prefix, fixed by "create an element"
    /// (createElementNS, or a custom element's upgrade); null for none -
    /// every element the HTML parser makes. ElementData's before D2.
    prefix: ?runtime.DOMString = null,
    /// The Attr nodes script was handed, each by its attribute's name record
    /// (Blink's kAttrNodeList). ElementData's before D2.
    attr_nodes: element_data.AttrNodeList = .{},
    /// The cached NamedNodeMap of `attributes` ([SameObject]; WebKit's
    /// m_attributeMap, Blink's kAttributeMap), with the slab generation that
    /// proves at the element's teardown that it is still that map.
    named_node_map: ?*runtime.Instance = null,
    named_node_map_generation: u64 = 0,
    /// The element's shadow root (Blink's kShadowRoot), kept for as long as
    /// the element's wrapper lives by an edge from it (`shadow_root_kept`).
    shadow_root: ?*runtime.Instance = null,
    shadow_root_kept: same_object.KeptChild = .{},
    /// HTML: the element's custom element definition, retained.
    custom_element_definition: ?*custom_elements.Definition = null,
    /// DOM: the element's custom element registry when it is not its node
    /// document's (Element's `registry_place` is `.rare`): a scoped
    /// registry, or a global one another document keeps - traced from the
    /// element, which is all that keeps a scoped one (lane perf3 E1;
    /// Blink's kCustomElementRegistry). Let go (`release`) by Element at its
    /// deinit, while its wrapper's edge can still be forgotten; it owns no
    /// memory, so `destroy` has nothing to free for it.
    custom_element_registry: custom_elements.RegistryAssociation = .{},
    /// HTML: the element's is value, for a customized built-in element
    /// (Blink's kIsValue).
    is_value: ?runtime.DOMString = null,
    /// The element references of the reflected element attributes (WebKit's
    /// m_explicitlySetAttrElementsMap, Blink's kExplicitlySetElementsForAttr).
    references: ?*element_references.State = null,
    /// DOM 4.2.2.2: the element as a slottable - its assigned slot and its
    /// manual slot assignment, weak references (NodeRefs) the slot
    /// algorithms keep (dom.slot_helpers, dom.shadow_dom_algorithms). Made
    /// only for an element a slot assigns: readers that find no rare data
    /// read dom.slot_helpers.unassigned (lane perf3 E1; Blink's
    /// FlatTreeNodeData in NodeRareData). Owns nothing.
    slottable: slot_helpers.SlottableState = .{},
    /// HTMLElement's part.
    html: HTMLElementRareData = .{},

    /// A new, empty block for an element of the Browser whose allocator and
    /// DOM memory these are (null: not counted - a Browser-less fixture).
    pub fn create(allocator: std.mem.Allocator, memory: ?*runtime.gc.ExternalMemory) error{OutOfMemory}!*ElementRareData {
        const rare = try allocator.create(ElementRareData);
        rare.* = .{};
        if (memory) |m| m.add(@sizeOf(ElementRareData));
        return rare;
    }

    /// Free the block and what it still owns - the prefix, the is value, the
    /// Attr node list's storage, HTMLElement's part - once Element let go of
    /// what its fields refer to (the Attr nodes, the NamedNodeMap, the
    /// shadow root, the definition, the references).
    pub fn destroy(self: *ElementRareData, allocator: std.mem.Allocator, memory: ?*runtime.gc.ExternalMemory) void {
        if (self.prefix) |*p| p.deinit(allocator);
        if (self.is_value) |*v| v.deinit(allocator);
        self.attr_nodes.deinit(allocator);
        self.html.release(allocator);
        allocator.destroy(self);
        if (memory) |m| m.sub(@sizeOf(ElementRareData));
    }
};

pub const Error = error{ OutOfMemory, InvalidStateError };

/// `element`'s rare data, or null when it has none: a reader's path, which
/// never allocates.
pub fn of(element: *runtime.Instance) ?*ElementRareData {
    return element_data.rareDataOf(element);
}

/// `element`'s rare data, made on first use: a writer's path. The block
/// never moves once made.
pub fn ensure(element: *runtime.Instance) Error!*ElementRareData {
    return element_data.ensureRareData(element);
}

// ============================================================================
// Tests
// ============================================================================

test "a new block is empty, counted while it lives, and frees what it owns" {
    const allocator = std.testing.allocator;
    var memory: runtime.gc.ExternalMemory = .{};
    const rare = try ElementRareData.create(allocator, &memory);
    try std.testing.expectEqual(@as(usize, @sizeOf(ElementRareData)), memory.live);
    try std.testing.expect(rare.prefix == null and rare.shadow_root == null and rare.html.cryptographic_nonce == null);

    rare.prefix = try runtime.DOMString.initDupe(allocator, "svg");
    rare.is_value = try runtime.DOMString.initDupe(allocator, "x-y");
    rare.html.cryptographic_nonce = try allocator.dupe(u8, "abc");
    const name: element_data.QualifiedName = .{ .local_name = "title" };
    var fake: runtime.Instance = undefined;
    _ = try rare.attr_nodes.put(allocator, &name, .{ .instance = &fake, .generation = 3 });
    rare.destroy(allocator, &memory);
    try std.testing.expectEqual(@as(usize, 0), memory.live);
}
