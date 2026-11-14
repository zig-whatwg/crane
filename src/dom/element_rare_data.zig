//! An element's rare data: the fields few elements ever set, in ONE sparse
//! block per element (lane rare1 batch 1; node-memory plan v2, B7).
//!
//! Lane perf3 D2 moved these fields out of every element into one fixed
//! struct made on first use (WebKit's ElementRareData shape): 312 bytes, a
//! 320-byte malloc block, made for ANY one field. On the framework pages
//! (tmp/redesign/nodedata/framework-pages.md, table C) 99.8% of the blocks
//! held exactly one field - element.style's object, which React reads for
//! every element with a `style` prop - so most of each block was empty.
//!
//! Blink went the other way on 2026-01-19 (0585db0568ea, 898e83f1fc06,
//! a40f7da2f043, 6005cb94a596, 8e96795b7d9d): its NodeRareData and
//! ElementRareDataVector became one sparse block, read here at chromium
//! 44274363dc1a (core/dom/node_rare_data.h, node_rare_data.cc,
//! rare_data_update.h):
//!
//! - fixed flags and a u64 presence bitmap (`fields_bitfield_`), then one
//!   4-byte slot per present field in AdditionalBytes, sorted by field id and
//!   found by `std::popcount(fields_bitfield_ & LowerFieldIdsMask(id))`
//!   (node_rare_data.h:716-764); capacity is implicit, the popcount rounded
//!   up to a power of two with a minimum of 2, since fields are never deleted
//!   (:719-728; a cleared field keeps its bit, node_rare_data.cc:108-113);
//! - a set at a power of two reallocates the block and moves the slots
//!   (node_rare_data.cc:72-106), so every Set*/Ensure* returns the new block
//!   ([[nodiscard]] RareDataUpdate, node_rare_data.h:127-132), which only
//!   `Node::data_` may keep (5518d421af00 .. a1a3cceafc6d, bug 555647730);
//! - every field is an object of its own, even a scalar (DataFieldWrapper,
//!   node_rare_data.h:652-664), so a grow moves only pointers;
//! - the 2026 bug was a pointer held across a grow: a field's constructor
//!   re-entered the block, the block grew, and the outer call wrote through
//!   the old one (601c5205e1d5, bug 574757964). The fix builds the field
//!   first and inserts it after (SetDisplayLockContext takes a built
//!   context, node_rare_data.cc:427-432).
//!
//! Crane's block is the same design in Zig (the zig review's Z8, MEASURED in
//! tmp/redesign/review/zig/bench/shapes/s04_rare.zig):
//!
//! - an 8-byte `extern struct` header (Z2: a block other code computes into
//!   has an explicit layout) - a u32 presence bitmap and a u32 of flags that
//!   belong to present fields - then one 8-byte `Slot` per present field, in
//!   field order. Capacity is implicit too: 1, 3, 7, 15... slots, so the
//!   block is 16, 32, 64, 128 bytes, each a whole 16-byte malloc quantum.
//!   The first field costs 16 bytes; element.style (its object and the
//!   generation that proves it at the element's teardown) 32.
//! - Field order is use (Z8; framework-pages.md note 3): classList at bit 0
//!   and style at bit 1 need no popcount (LLVM folds bit 0 to nothing and
//!   bit 1 to an AND). classList's [SameObject] cache and the other
//!   family-wide ones left the generated State for this block in N1 (lane
//!   cg1): the generated getters reach them through dom.same_object_cache.
//! - A slot holds a pointer or a scalar, copied when the block grows. Every
//!   multi-word field is a block of its own that the slot points at (the
//!   Attr node list, the slottable state, the registry association, the
//!   element references, the is value's and nonce's bytes), so nothing a
//!   caller holds moves with the block.
//! - Nothing hands out a pointer into the block. Readers take the element's
//!   `Holder` by value and get each field by value (`get`, `keptGet`,
//!   `getBytes`); writers pass the `*Holder` itself - the element's own
//!   word, which `write` refreshes when the block moves (Blink's
//!   RareDataUpdate::RefreshNodeAndUnwrap). A value is built fully before it
//!   is inserted, and an insert reads the holder after the build, so a build
//!   that re-enters and adds fields (601c5205e1d5's shape) is safe. A field
//!   whose object must not be made unless it can be kept reserves its bits
//!   first (`keptReserve`): the write after the build is then in place and
//!   cannot fail.
//! - A cleared field keeps its bit and a zero slot, as Blink's do: setting it
//!   again never moves the block.
//!
//! The block and its own blocks are the element's: allocated from its
//! Browser's allocator (runtime.allocatorOf), counted in its Browser's DOM
//! memory while they live, and freed at both of the element's exits - its
//! deinit and its Browser's teardown sweep (docs/lessons/
//! architecture-an-element-alive-at-teardown-is-swept-not-deinitd.md).
//! Element owns the holder and supplies its address through the hook slot it
//! already installs for its ElementData (dom.element_data's
//! `rare_holder`). What each field means is its owner's: Element's fields
//! are written only by Element; element_internals and its flags only by
//! HTMLElement; an HTML element's style only by the ElementCSSInlineStyle
//! mixin's impl, and every includer's nonce only by the
//! HTMLOrSVGOrMathMLElement mixin's (HTMLElement's teardown releases an HTML
//! element's style and nonce; this module's `destroy` frees any element's
//! nonce bytes).
const std = @import("std");
const NodeBase = @import("node_base.zig").NodeBase;

const runtime = @import("runtime");
const engine = @import("engine");
const element_data = @import("element_data.zig");
const same_object = @import("same_object.zig");
const custom_elements = @import("custom_elements.zig");
const element_references = @import("element_references.zig");
const slot_helpers = @import("slot_helpers.zig");

/// The fields, one presence bit each, in the order of their use.
pub const Field = enum(u5) {
    /// classList's [SameObject] DOMTokenList (Blink's kClassList): the
    /// generated getter's cache (dom.same_object_cache's element accessors;
    /// lane cg1, N1). The grid reads it 58,137 times in 20 screens: bit 0,
    /// no popcount.
    class_list = 0,
    /// An HTML element's element.style CSSStyleProperties ([SameObject];
    /// Blink's kCssomWrapper), with its generation below: made by the
    /// ElementCSSInlineStyle mixin's impl, released by HTMLElement's teardown.
    style = 1,
    style_generation,
    /// Element: the cached NamedNodeMap of `attributes` (Blink's
    /// kAttributeMap), with the slab generation that proves at the element's
    /// teardown that it is still that map.
    named_node_map,
    named_node_map_generation,
    /// Element: its shadow root (Blink's kShadowRoot), kept by an edge from
    /// its wrapper (`Flag.shadow_root_traced`), with its generation.
    shadow_root,
    shadow_root_generation,
    /// Element: the Attr nodes script was handed, by name record (Blink's
    /// kAttrNodeList). A block of its own.
    attr_nodes,
    /// HTML: its custom element definition, retained.
    custom_element_definition,
    /// DOM: its custom element registry when that is not its node document's
    /// (Element's `registry_place` is `.rare`): traced from the element
    /// (Blink's kCustomElementRegistry). A block of its own.
    custom_element_registry,
    /// HTML: its is value (Blink's kIsValue). Bytes of their own.
    is_value,
    /// The element references of the reflected element attributes (Blink's
    /// kExplicitlySetElementsForAttr). A block of its own.
    references,
    /// DOM 4.2.2.2: the element as a slottable - made only for an element a
    /// slot assigns; readers that find none read dom.slot_helpers.unassigned
    /// (Blink's FlatTreeNodeData). A block of its own.
    slottable,
    /// HTMLOrSVGOrMathMLElement: HTML 2.5.6 [[CryptographicNonce]] of an
    /// HTML, SVG or MathML element (Blink's kNonce). Null is unused/removed;
    /// an explicitly empty value may accompany a nonempty attribute that
    /// must hide on connection. Bytes of their own, freed by `destroy`.
    nonce,
    /// HTMLElement: the ElementInternals attachInternals() made (Blink's
    /// kElementInternals).
    element_internals,

    // The generated [SameObject] getters' caches (lane cg1, N1: they left
    // every element's generated State, 8 bytes each). Each holds the object
    // its impl made, owned by the object's wrapper and traced from the
    // element (dom.same_object_cache): nothing here frees it. After rare1's
    // fields, by measured use (framework-pages.md table E: dataset on
    // load-app, none of the rest on any page).
    /// HTMLOrSVGOrMathMLElement's dataset DOMStringMap (Blink's kDataset).
    dataset,
    /// ParentNode's children HTMLCollection of an element (Blink's
    /// NodeListsNodeData).
    children,
    /// Element's part DOMTokenList (Blink's kPart).
    part,
    /// ElementCSSInlineStyle's attributeStyleMap (Blink's kCssomMapWrapper).
    attribute_style_map,
    /// ElementCSSInlineStyle's style object of an SVG or MathML element:
    /// the generated cache's, owned by its wrapper - never an HTML element's
    /// `style`, which the element keeps and frees whole.
    inline_style,
    /// SVGElement's className SVGAnimatedString.
    svg_class_name,
};

/// What each field's slot holds.
pub fn Value(comptime field: Field) type {
    return switch (field) {
        .class_list, .style, .named_node_map, .shadow_root, .element_internals => *runtime.Instance,
        .dataset, .children, .part, .attribute_style_map, .inline_style, .svg_class_name => *runtime.Instance,
        .style_generation, .named_node_map_generation, .shadow_root_generation => u64,
        .attr_nodes => *element_data.AttrNodeList,
        .custom_element_definition => *custom_elements.Definition,
        .custom_element_registry => *custom_elements.RegistryAssociation,
        .is_value, .nonce => *Bytes,
        .references => *element_references.State,
        .slottable => *slot_helpers.SlottableState,
    };
}

/// One field's storage: a pointer or a scalar, copied when the block grows.
pub const Slot = u64;

/// Flags of present fields (they never make a block of their own).
pub const Flags = packed struct(u32) {
    /// The element's wrapper draws an edge to its style object.
    style_traced: bool = false,
    /// The element's wrapper draws an edge to its shadow root.
    shadow_root_traced: bool = false,
    /// The element draws an edge to its ElementInternals.
    internals_traced: bool = false,
    /// attachInternals() was called (it can be only once).
    internals_attached: bool = false,
    _unused: u28 = 0,
};
pub const Flag = enum { style_traced, shadow_root_traced, internals_traced, internals_attached };

/// The block's header; the slots follow it.
pub const Block = extern struct {
    /// One bit per present `Field`. 8-aligned: the slots follow directly.
    present: u32 align(8) = 0,
    flags: Flags = .{},

    fn slots(self: *Block) [*]Slot {
        return @ptrCast(@alignCast(@as([*]u8, @ptrCast(self)) + @sizeOf(Block)));
    }

    fn count(self: *const Block) u32 {
        return @popCount(self.present);
    }
};

comptime {
    // A u5 field id: every field has a bit of `present`. The slots follow
    // the 8-byte header directly, aligned.
    std.debug.assert(@sizeOf(Block) == 8 and @alignOf(Block) >= @alignOf(Slot));
}

/// The block's capacity for `n` present fields: the slots that fill it to a
/// power of two with the header (1, 3, 7, 15, 31), 0 for none.
pub fn capacityFor(n: u32) u32 {
    if (n == 0) return 0;
    return (@as(u32, 2) << @intCast(31 - @clz(n))) - 1;
}

/// The bytes of a block holding `n` fields, as asked of its allocator: 16,
/// 32, 64, 128 ...; 0 for none.
pub fn blockBytesFor(n: u32) usize {
    const capacity = capacityFor(n);
    if (capacity == 0) return 0;
    return @sizeOf(Block) + capacity * @sizeOf(Slot);
}

/// What the element keeps: its block's address, null while no field was
/// ever set. Readers take it by value; writers pass its address, and a
/// write that moves the block updates it.
pub const Holder = extern struct {
    block: ?*Block = null,

    /// The block's bytes as its allocator was asked for them; 0 for none.
    pub fn blockBytes(self: Holder) usize {
        const b = self.block orelse return 0;
        return blockBytesFor(b.count());
    }

    /// How many fields have a bit (cleared ones included).
    pub fn fieldCount(self: Holder) u32 {
        const b = self.block orelse return 0;
        return b.count();
    }
};

/// The allocator the element's rare data comes from, and the DOM memory it
/// is counted in (null: not counted - a Browser-less fixture).
pub const Context = struct {
    allocator: std.mem.Allocator,
    memory: ?*runtime.gc.ExternalMemory = null,
};

/// `element`'s Browser's allocator and DOM memory.
pub fn contextOf(element: *runtime.Instance) Context {
    return .{ .allocator = runtime.allocatorOf(element), .memory = &runtime.BrowserScope.ofInstance(element).dom_memory };
}

/// An owned byte string in one allocation: its length, then its bytes.
pub const Bytes = extern struct {
    len: usize,

    /// The explicitly empty value, shared and never freed: setting one
    /// allocates nothing, as copying an empty slice never did (HTML 2.5.6's
    /// hidden nonce sets "" where an allocation may fail:
    /// tests/html/cn_nonce_slot_test.zig).
    const empty: Bytes = .{ .len = 0 };

    pub fn create(allocator: std.mem.Allocator, value: []const u8) error{OutOfMemory}!*Bytes {
        if (value.len == 0) return @constCast(&empty);
        const memory = try allocator.alignedAlloc(u8, .of(Bytes), @sizeOf(Bytes) + value.len);
        const self: *Bytes = @ptrCast(memory.ptr);
        self.len = value.len;
        @memcpy(memory[@sizeOf(Bytes)..], value);
        return self;
    }

    pub fn slice(self: *const Bytes) []const u8 {
        const base: [*]const u8 = @ptrCast(self);
        return base[@sizeOf(Bytes)..][0..self.len];
    }

    pub fn destroy(self: *Bytes, allocator: std.mem.Allocator) void {
        if (self == &empty) return;
        const base: [*]align(@alignOf(Bytes)) u8 = @ptrCast(self);
        allocator.free(base[0 .. @sizeOf(Bytes) + self.len]);
    }
};

fn bit(comptime field: Field) u32 {
    return @as(u32, 1) << @backingInt(field);
}

fn toSlot(comptime field: Field, value: ?Value(field)) Slot {
    if (comptime @typeInfo(Value(field)) == .pointer) return if (value) |v| @intFromPtr(v) else 0;
    return value orelse 0;
}

fn fromSlot(comptime field: Field, slot: Slot) ?Value(field) {
    if (comptime @typeInfo(Value(field)) == .pointer) return @ptrFromInt(@as(usize, @intCast(slot)));
    return slot;
}

/// The index of `field`'s slot in a block whose bits are `present`.
fn indexOf(present: u32, comptime field: Field) u32 {
    return @popCount(present & (bit(field) - 1));
}

// ============================================================================
// Reading: by value, never a pointer into the block
// ============================================================================

/// `field`'s value, or null when it has no bit or was cleared.
pub fn get(holder: Holder, comptime field: Field) ?Value(field) {
    const b = holder.block orelse return null;
    if (b.present & bit(field) == 0) return null;
    return fromSlot(field, b.slots()[indexOf(b.present, field)]);
}

/// A flag of a present field.
pub fn flag(holder: Holder, comptime which: Flag) bool {
    const b = holder.block orelse return false;
    return @field(b.flags, @tagName(which));
}

/// A bytes field's value, borrowed until it is set or cleared.
pub fn getBytes(holder: Holder, comptime field: Field) ?[]const u8 {
    comptime std.debug.assert(Value(field) == *Bytes);
    const bytes = get(holder, field) orelse return null;
    return bytes.slice();
}

// ============================================================================
// Writing: through the element's holder
// ============================================================================

/// Write `values` to `fields`' slots, adding the bits of those that have
/// none. The one place a block is made or moves: when the new count passes
/// the capacity, a new block takes every slot, the holder is updated and the
/// old block freed. The holder is read here, after the caller built every
/// value. Nothing allocates when every field already has its bit.
fn write(ctx: Context, holder: *Holder, comptime fields: []const Field, values: [fields.len]Slot) error{OutOfMemory}!void {
    comptime var adding: u32 = 0;
    inline for (fields) |field| adding |= comptime bit(field);
    const old = holder.block;
    const old_present: u32 = if (old) |b| b.present else 0;
    const present = old_present | adding;
    if (old) |b| if (present == old_present or capacityFor(@popCount(present)) == capacityFor(@popCount(old_present))) {
        // In place: the slots above each new bit move up, from the top down.
        if (present != old_present) {
            const slots = b.slots();
            var from: u32 = @popCount(old_present);
            var bits = old_present;
            while (bits != 0) {
                const top: u32 = @as(u32, 1) << @intCast(31 - @clz(bits));
                bits &= ~top;
                from -= 1;
                slots[@popCount(present & (top - 1))] = slots[from];
            }
            b.present = present;
        }
        inline for (fields, 0..) |field, i| b.slots()[indexOf(present, field)] = values[i];
        return;
    };
    // A new block: every old slot to its new index, then the new values.
    const bytes = blockBytesFor(@popCount(present));
    const memory = try ctx.allocator.alignedAlloc(u8, .of(Block), bytes);
    const b: *Block = @ptrCast(memory.ptr);
    b.* = .{ .present = present, .flags = if (old) |o| o.flags else .{} };
    const slots = b.slots();
    @memset(slots[0..capacityFor(@popCount(present))], 0);
    if (old) |o| {
        var from: u32 = 0;
        var bits = old_present;
        while (bits != 0) : (from += 1) {
            const low = bits & (0 -% bits);
            bits &= bits - 1;
            slots[@popCount(present & (low - 1))] = o.slots()[from];
        }
    }
    inline for (fields, 0..) |field, i| slots[indexOf(present, field)] = values[i];
    if (ctx.memory) |m| m.add(bytes);
    holder.block = b;
    if (old) |o| freeBlock(ctx, o);
}

fn freeBlock(ctx: Context, b: *Block) void {
    const bytes = blockBytesFor(b.count());
    const memory: [*]align(@alignOf(Block)) u8 = @ptrCast(b);
    ctx.allocator.free(memory[0..bytes]);
    if (ctx.memory) |m| m.sub(bytes);
}

/// Set `field` (a pointer field). Null clears it (its bit stays), which never
/// allocates; a value for a field without a bit may grow the block.
pub fn put(ctx: Context, holder: *Holder, comptime field: Field, value: ?Value(field)) error{OutOfMemory}!void {
    if (value == null) return clear(holder, field);
    try write(ctx, holder, &.{field}, .{toSlot(field, value)});
}

/// Give `field` its bit (a cleared field) before its value is made, so that
/// keeping the value after (`putReserved`) cannot fail.
pub fn reserve(ctx: Context, holder: *Holder, comptime field: Field) error{OutOfMemory}!void {
    if (holder.block) |b| if (b.present & bit(field) != 0) return;
    try write(ctx, holder, &.{field}, .{0});
}

/// Set a field `reserve` gave its bit, in place: never allocates.
pub fn putReserved(holder: *Holder, comptime field: Field, value: ?Value(field)) void {
    const b = holder.block.?;
    std.debug.assert(b.present & bit(field) != 0);
    b.slots()[indexOf(b.present, field)] = toSlot(field, value);
}

/// Clear `field`, keeping its bit (Blink's SetFieldToNullIfExists): what its
/// value owned is the caller's.
pub fn clear(holder: *Holder, comptime field: Field) void {
    const b = holder.block orelse return;
    if (b.present & bit(field) == 0) return;
    b.slots()[indexOf(b.present, field)] = 0;
}

/// Set a flag of a present field: a flag never makes a block.
pub fn setFlag(holder: *Holder, comptime which: Flag, value: bool) void {
    const b = holder.block orelse {
        std.debug.assert(!value);
        return;
    };
    @field(b.flags, @tagName(which)) = value;
}

/// `field`'s value, made now when it has none: `make(context)` builds it
/// fully, then it is inserted - the holder is read after `make`, so a `make`
/// that adds fields to the same element moves nothing under it (Blink
/// 601c5205e1d5). If the insert fails, `discard` gets the value back.
pub fn ensureWith(
    ctx: Context,
    holder: *Holder,
    comptime field: Field,
    context: anytype,
    comptime make: fn (@TypeOf(context)) error{OutOfMemory}!Value(field),
    comptime discard: ?fn (@TypeOf(context), Value(field)) void,
) error{OutOfMemory}!Value(field) {
    if (get(holder.*, field)) |existing| return existing;
    const value = try make(context);
    write(ctx, holder, &.{field}, .{toSlot(field, value)}) catch |err| {
        if (discard) |f| f(context, value);
        return err;
    };
    return value;
}

/// The fields that are blocks of their own: made empty by `ensureOwn`,
/// freed by `destroy`.
fn isOwnBlock(comptime field: Field) bool {
    return switch (field) {
        .attr_nodes, .custom_element_registry, .references, .slottable => true,
        else => false,
    };
}

/// A block-of-its-own field, made empty (`.{}`) when it has none. Its
/// address stays good while the element lives, whatever the rare block does.
pub fn ensureOwn(ctx: Context, holder: *Holder, comptime field: Field) error{OutOfMemory}!Value(field) {
    comptime std.debug.assert(isOwnBlock(field));
    if (get(holder.*, field)) |existing| return existing;
    const T = @typeInfo(Value(field)).pointer.child;
    const own = try ctx.allocator.create(T);
    errdefer ctx.allocator.destroy(own);
    own.* = .{};
    try write(ctx, holder, &.{field}, .{@intFromPtr(own)});
    if (ctx.memory) |m| m.add(@sizeOf(T));
    return own;
}

fn destroyOwn(ctx: Context, comptime field: Field, own: Value(field)) void {
    const T = @typeInfo(Value(field)).pointer.child;
    ctx.allocator.destroy(own);
    if (ctx.memory) |m| m.sub(@sizeOf(T));
}

/// Set a bytes field to a copy of `value` (an explicitly empty one too).
/// The copy is made first; the old bytes are freed after.
pub fn putBytes(ctx: Context, holder: *Holder, comptime field: Field, value: []const u8) error{OutOfMemory}!void {
    comptime std.debug.assert(Value(field) == *Bytes);
    const copy = try Bytes.create(ctx.allocator, value);
    errdefer copy.destroy(ctx.allocator);
    const old = get(holder.*, field);
    try write(ctx, holder, &.{field}, .{@intFromPtr(copy)});
    if (old) |bytes| bytes.destroy(ctx.allocator);
}

/// Clear a bytes field and free its bytes.
pub fn clearBytes(ctx: Context, holder: *Holder, comptime field: Field) void {
    const old = get(holder.*, field) orelse return;
    clear(holder, field);
    old.destroy(ctx.allocator);
}

/// Take a bytes field's value out, leaving it cleared (its bit stays): the
/// caller owns the bytes until `restoreBytes` gives them back.
pub fn takeBytes(holder: *Holder, comptime field: Field) ?*Bytes {
    const old = get(holder.*, field) orelse return null;
    clear(holder, field);
    return old;
}

/// Give back what `takeBytes` took, freeing whatever was set since. The bit
/// is still there, so this never allocates.
pub fn restoreBytes(ctx: Context, holder: *Holder, comptime field: Field, saved: *Bytes) void {
    if (get(holder.*, field)) |since| since.destroy(ctx.allocator);
    const b = holder.block.?;
    std.debug.assert(b.present & bit(field) != 0);
    b.slots()[indexOf(b.present, field)] = @intFromPtr(saved);
}

// ============================================================================
// Kept children: an object made once and handed out as the same object
// ============================================================================

/// The children an element keeps with their generations: dom.same_object's
/// KeptChild, as slots (a pointer and a generation) and a flag.
pub const Kept = enum { style, named_node_map, shadow_root };

fn keptPointer(comptime kept: Kept) Field {
    return switch (kept) {
        .style => .style,
        .named_node_map => .named_node_map,
        .shadow_root => .shadow_root,
    };
}

fn keptGeneration(comptime kept: Kept) Field {
    return switch (kept) {
        .style => .style_generation,
        .named_node_map => .named_node_map_generation,
        .shadow_root => .shadow_root_generation,
    };
}

fn keptTraced(comptime kept: Kept) ?Flag {
    return switch (kept) {
        .style => .style_traced,
        .named_node_map => null,
        .shadow_root => .shadow_root_traced,
    };
}

/// The child the element made, or null before it made one (and after its
/// release) - KeptChild.get: no liveness check.
pub fn keptGet(holder: Holder, comptime kept: Kept) ?*runtime.Instance {
    return get(holder, keptPointer(kept));
}

/// The child with the generation it had when it was made.
pub fn keptLink(holder: Holder, comptime kept: Kept) ?same_object.Link {
    const child = get(holder, keptPointer(kept)) orelse return null;
    return .{ .instance = child, .generation = get(holder, keptGeneration(kept)) orelse 0 };
}

/// Give the child's slots their bits before it is made, so that keeping it
/// after (`keptSet`) cannot fail: a child must not exist unless it can be
/// kept.
pub fn keptReserve(ctx: Context, holder: *Holder, comptime kept: Kept) error{OutOfMemory}!void {
    const b = holder.block;
    if (b) |block| if (block.present & bit(keptPointer(kept)) != 0) return;
    try write(ctx, holder, &.{ keptPointer(kept), keptGeneration(kept) }, .{ 0, 0 });
}

/// `child` was just made and its slots reserved: the element keeps it here,
/// and only here. Never allocates.
pub fn keptSet(holder: *Holder, comptime kept: Kept, child: *runtime.Instance) void {
    const b = holder.block.?;
    std.debug.assert(b.present & bit(keptPointer(kept)) != 0);
    b.slots()[indexOf(b.present, keptPointer(kept))] = @intFromPtr(child);
    b.slots()[indexOf(b.present, keptGeneration(kept))] = runtime.SlabAllocator.generationOf(child);
    if (comptime keptTraced(kept)) |traced| setFlag(holder, traced, false);
}

/// `child` was just made: keep it, reserving its slots now if need be.
pub fn keptMade(ctx: Context, holder: *Holder, comptime kept: Kept, child: *runtime.Instance) error{OutOfMemory}!void {
    try keptReserve(ctx, holder, kept);
    keptSet(holder, kept, child);
}

/// `child` is going to script: the element keeps it, in its member `slot`,
/// for as long as the element's wrapper lives. Once per child made
/// (KeptChild.handOut).
pub fn keptHandOut(holder: *Holder, comptime kept: Kept, owner: *runtime.Instance, child: *runtime.Instance, slot: engine.TracedSlot) void {
    // A child handed out with an edge has a traced flag (named_node_map has none).
    const traced: Flag = comptime keptTraced(kept).?;
    if (flag(holder.*, traced)) return;
    engine.traceChild(owner, child, slot);
    // Read again: the trace may have run anything.
    setFlag(holder, traced, true);
}

/// The element is going: its child, if it is still the object it made, is
/// severed from it (KeptChild.release); the slots are cleared.
pub fn keptRelease(holder: *Holder, comptime kept: Kept, sever: *const fn (*runtime.Instance) void) void {
    const link = keptLink(holder.*, kept) orelse return;
    keptClear(holder, kept);
    if (link.isLive()) sever(link.instance);
}

/// The element is going, and its child - if it is still the object it
/// made - goes WHOLE with it (KeptChild.releaseOwned, runtime.gc.releaseOwned).
pub fn keptReleaseOwned(holder: *Holder, comptime kept: Kept) void {
    const link = keptLink(holder.*, kept) orelse return;
    keptClear(holder, kept);
    if (link.isLive()) runtime.gc.releaseOwned(link.instance);
}

fn keptClear(holder: *Holder, comptime kept: Kept) void {
    clear(holder, keptPointer(kept));
    clear(holder, keptGeneration(kept));
    if (comptime keptTraced(kept)) |traced| if (holder.block != null) setFlag(holder, traced, false);
}

// ============================================================================
// Teardown
// ============================================================================

/// Free the block and what it still owns - its own blocks (the Attr node
/// list's storage, the slottable state, the registry association, the
/// element references) and the is value's and nonce's bytes - once each
/// owner let go of what its fields refer to (the Attr nodes, the
/// NamedNodeMap, the shadow root, the style object, the internals, the
/// definition, the registry's edge).
pub fn destroy(ctx: Context, holder: *Holder) void {
    const b = holder.block orelse return;
    if (get(holder.*, .attr_nodes)) |list| {
        list.deinit(ctx.allocator);
        destroyOwn(ctx, .attr_nodes, list);
    }
    if (get(holder.*, .references)) |refs| {
        refs.deinit(ctx.allocator);
        destroyOwn(ctx, .references, refs);
    }
    if (get(holder.*, .slottable)) |state| destroyOwn(ctx, .slottable, state);
    if (get(holder.*, .custom_element_registry)) |association| destroyOwn(ctx, .custom_element_registry, association);
    if (get(holder.*, .is_value)) |bytes| bytes.destroy(ctx.allocator);
    if (get(holder.*, .nonce)) |bytes| bytes.destroy(ctx.allocator);
    holder.block = null;
    freeBlock(ctx, b);
}

// ============================================================================
// Through the element (Element's hook)
// ============================================================================

/// What Element hands this module for one element: the address of its rare
/// data's holder, in Element's InternalState, and of click()'s in-progress
/// flag (HTMLElement's: HTML click() steps 2-5), a bit of the element's byte
/// in its NodeBase (dom.NodeBase.ElementBits; lane nm1) - both good for the
/// element's life. The flag is the one bool that would make a block on its
/// own; Blink and WebKit keep it out of the element too (the elements
/// dispatching a simulated click: Blink EventDispatcher::
/// DispatchSimulatedClick, WebKit simulateClick).
pub const Access = struct {
    holder: *Holder,
    click_in_progress: NodeBase.ClickInProgress,
};

pub const Error = error{ OutOfMemory, InvalidStateError };

/// `element`'s access, or null for an instance that is no element.
pub fn access(element: *runtime.Instance) ?Access {
    return element_data.rareHolderOf(element);
}

/// `element`'s holder by value (empty for none, or for no element): a
/// reader's path, which never allocates.
pub fn of(element: *runtime.Instance) Holder {
    const a = access(element) orelse return .{};
    return a.holder.*;
}

// ============================================================================
// Tests
// ============================================================================

test "capacity fills the block to a power of two with the header" {
    try std.testing.expectEqual(@as(u32, 0), capacityFor(0));
    try std.testing.expectEqual(@as(u32, 1), capacityFor(1));
    try std.testing.expectEqual(@as(u32, 3), capacityFor(2));
    try std.testing.expectEqual(@as(u32, 3), capacityFor(3));
    try std.testing.expectEqual(@as(u32, 7), capacityFor(4));
    try std.testing.expectEqual(@as(u32, 15), capacityFor(15));
    try std.testing.expectEqual(@as(u32, 31), capacityFor(16));
    try std.testing.expectEqual(@as(usize, 16), blockBytesFor(1));
    try std.testing.expectEqual(@as(usize, 32), blockBytesFor(3));
}

test "fields inserted out of order land at their popcount index and survive every grow and shift" {
    const allocator = std.testing.allocator;
    var memory: runtime.gc.ExternalMemory = .{};
    const ctx: Context = .{ .allocator = allocator, .memory = &memory };
    var holder: Holder = .{};
    defer destroy(ctx, &holder);
    var words: [3]u64 align(16) = @splat(0);
    const a: *runtime.Instance = @ptrCast(&words[0]);
    const b: *runtime.Instance = @ptrCast(&words[1]);
    const c: *runtime.Instance = @ptrCast(&words[2]);

    // The highest first, then lower ones: each insert shifts what is above.
    try put(ctx, &holder, .element_internals, a);
    try std.testing.expectEqual(@as(usize, 16), holder.blockBytes());
    try putBytes(ctx, &holder, .nonce, "n");
    try put(ctx, &holder, .style, b);
    try put(ctx, &holder, .shadow_root, c);
    try std.testing.expectEqual(@as(usize, 64), holder.blockBytes());
    try std.testing.expectEqual(holder.blockBytes(), memory.live);
    try std.testing.expect(get(holder, .element_internals).? == a);
    try std.testing.expect(get(holder, .style).? == b);
    try std.testing.expect(get(holder, .shadow_root).? == c);
    try std.testing.expectEqualStrings("n", getBytes(holder, .nonce).?);
    try std.testing.expect(get(holder, .named_node_map) == null);

    // A cleared field keeps its bit and reads null; setting it again moves nothing.
    const block = holder.block;
    try put(ctx, &holder, .style, null);
    try std.testing.expect(get(holder, .style) == null);
    try put(ctx, &holder, .style, c);
    try std.testing.expect(holder.block == block and get(holder, .style).? == c);

    // The flags are the block's and travel with it.
    setFlag(&holder, .internals_attached, true);
    try put(ctx, &holder, .element_internals, b);
    try std.testing.expect(flag(holder, .internals_attached));
}

test "an explicitly empty bytes value allocates nothing once its field has a bit" {
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    const ctx: Context = .{ .allocator = failing.allocator() };
    var holder: Holder = .{};
    defer destroy(ctx, &holder);
    try putBytes(ctx, &holder, .nonce, "n");
    failing.fail_index = failing.alloc_index;
    try putBytes(ctx, &holder, .nonce, "");
    try std.testing.expectEqualStrings("", getBytes(holder, .nonce).?);
    try std.testing.expectError(error.OutOfMemory, putBytes(ctx, &holder, .nonce, "x"));
    try std.testing.expectEqualStrings("", getBytes(holder, .nonce).?);
}
