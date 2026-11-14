//! SVG 2 §6.6 "Presentation attributes": an SVG element's presentation
//! attributes as the cascade's presentational hints. "Presentation
//! attributes contribute to the author level of the cascade, followed by
//! all other author-level style sheets, and have specificity 0" - CSS
//! Cascade 5 §6.2's author presentational hint origin, as HTML's hints
//! (html-hints.css, font_hints.zig, the background hint). Which attribute
//! maps to which property, and how its value parses, is
//! css.svg_presentation's (an invalid value contributes no hint: all three
//! browsers agree, its file says).
//!
//! The hint is SHARED: elements with equal presentation attributes hold one
//! immutable declaration block, kept in a per-document cache (`Cache`,
//! StyleEngine.Rare), as Blink keeps presentation attribute style in its
//! PresentationAttributeCache (blink/renderer/core/dom/
//! presentation_attribute_style.cc: keyed by the tag name and the attributes'
//! names and values, sorted; at most kPresentationAttributeCacheMaximumSize
//! = 4096 entries, the whole cache dropped when a new entry passes it - its
//! elements keep their style - and an entry whose hash collides with another
//! key's is not cached). Blink still skips SVG there ("FIXME: Enable for
//! SVG"); Gecko shares SVG mapped attributes the same way. One hint per
//! element was +583 bytes per SVG element with a presentation attribute
//! (lane quick1 b4's smoke, a rect with fill: 1,650 against 1,067). An
//! element's style state points at its entry (its hint slot,
//! element_style.Hint), a counted reference; the entry leaves the cache and
//! is freed when its last element lets go - a changed attribute, a freed
//! element, a style state dropped - and an entry the cache let go of
//! (Blink's clearing, or the document's teardown) lives on uncached with its
//! elements.
//!
//! The key: the element's local name, each presentation attribute's name
//! and value in name order, and - only when a value has a url(), which
//! resolves against the node document's base URL as the style attribute's
//! does (resource_loading.inlineParseContext) - that base URL. An element
//! whose hint came from another document's cache (it was adopted) makes a
//! new one in its own document.
//!
//! Spec: https://svgwg.org/svg2-draft/styling.html#PresentationAttributes

const std = @import("std");
const runtime = @import("runtime");
const css = @import("css");
const interfaces = @import("interfaces");
const element_style = @import("element_style.zig");
const resource_loading = @import("resource_loading.zig");
const element_data = @import("../element_data.zig");

const Allocator = std.mem.Allocator;
const DeclarationBlock = css.declarations.DeclarationBlock;
const ElementStyle = element_style.ElementStyle;
const Hint = element_style.Hint;

pub const svg_namespace = css.svg_presentation.svg_namespace;

/// Blink's kPresentationAttributeCacheMaximumSize.
pub const max_entries = 4096;

/// One input: a presentation attribute's name and value, owned.
const Input = struct {
    name: []u8,
    value: []u8,
};

/// A key being looked up: borrowed.
const Key = struct {
    local: []const u8,
    /// Each presentation attribute, in name order.
    inputs: []const BorrowedInput,
    /// The base URL, only when a value has a url().
    base: ?[]const u8,

    const BorrowedInput = struct { name: []const u8, value: []const u8 };

    fn hash(self: Key) u64 {
        var h = std.hash.Wyhash.init(0x5356_4748);
        h.update(self.local);
        h.update(&.{0});
        for (self.inputs) |input| {
            h.update(input.name);
            h.update(&.{0});
            h.update(input.value);
            h.update(&.{0});
        }
        if (self.base) |b| {
            h.update(&.{1});
            h.update(b);
        }
        return h.final();
    }
};

/// One hint, shared by every element with its key; immutable once made. A
/// counted object: each element's style state holds one reference.
pub const SvgHint = struct {
    header: Hint = .{ .kind = .svg },
    allocator: Allocator,
    refs: u32 = 1,
    local: []u8,
    inputs: []Input,
    base: ?[]u8,
    key_hash: u64,
    block: DeclarationBlock,
    /// The cache it is in; null once the cache let go of it (a weak back
    /// link: the cache clears it before it drops the entry).
    cache: ?*Cache = null,
    /// The document whose cache made it, and that document's generation:
    /// an element adopted into another document makes a new hint there.
    document: usize = 0,
    document_generation: u64 = 0,

    pub fn retain(self: *SvgHint) void {
        self.refs += 1;
    }

    /// Drop one reference; the last frees it, out of its cache first.
    pub fn release(self: *SvgHint) void {
        std.debug.assert(self.refs > 0);
        self.refs -= 1;
        if (self.refs != 0) return;
        if (self.cache) |cache| cache.forget(self);
        self.block.deinit();
        freeInputs(self.allocator, self.inputs);
        self.allocator.free(self.local);
        if (self.base) |b| self.allocator.free(b);
        self.allocator.destroy(self);
    }

    /// element_style's name for dropping a slot's hint.
    pub fn destroy(self: *SvgHint) void {
        self.release();
    }

    fn matches(self: *const SvgHint, key: Key) bool {
        if (!std.mem.eql(u8, self.local, key.local)) return false;
        if (self.inputs.len != key.inputs.len) return false;
        for (self.inputs, key.inputs) |a, b| {
            if (!std.mem.eql(u8, a.name, b.name) or !std.mem.eql(u8, a.value, b.value)) return false;
        }
        if ((self.base == null) != (key.base == null)) return false;
        if (self.base) |b| return std.mem.eql(u8, b, key.base.?);
        return true;
    }
};

fn freeInputs(allocator: Allocator, inputs: []Input) void {
    for (inputs) |input| {
        allocator.free(input.name);
        allocator.free(input.value);
    }
    allocator.free(inputs);
}

/// A document's cache of SVG hints, by key hash; it holds no reference to
/// them (an entry leaves when its last element lets go).
pub const Cache = struct {
    allocator: Allocator,
    map: std.AutoHashMapUnmanaged(u64, *SvgHint) = .empty,
    /// Entries come and go: the map's tombstones are cleared before they
    /// fill it (tools/lint_tombstones.zig).
    guard: @import("infra").tombstones.TombstoneGuard = .{},

    pub fn create(allocator: Allocator) Allocator.Error!*Cache {
        const self = try allocator.create(Cache);
        self.* = .{ .allocator = allocator };
        return self;
    }

    /// The document's teardown: every entry its elements still hold lives
    /// on uncached.
    pub fn destroy(self: *Cache) void {
        self.letGoOfAll();
        self.map.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn count(self: *const Cache) usize {
        return self.map.count();
    }

    /// Blink's clearing past the bound: the cache lets go of every entry.
    fn letGoOfAll(self: *Cache) void {
        var it = self.map.valueIterator();
        while (it.next()) |hint| hint.*.cache = null;
        self.map.clearRetainingCapacity();
        self.guard.reset();
    }

    /// The entry for `key`, retained; null when there is none (or another
    /// key holds its hash).
    fn find(self: *Cache, key: Key, key_hash: u64) ?*SvgHint {
        const hint = self.map.get(key_hash) orelse return null;
        if (!hint.matches(key)) return null;
        hint.retain();
        return hint;
    }

    /// Keep `hint` for its key, unless another key holds its hash. Out of
    /// memory, the hint simply stays uncached.
    fn insert(self: *Cache, hint: *SvgHint) void {
        if (self.map.contains(hint.key_hash)) return;
        if (self.map.count() >= max_entries) self.letGoOfAll();
        self.guard.beforeInsert(&self.map);
        self.map.put(self.allocator, hint.key_hash, hint) catch return;
        hint.cache = self;
    }

    fn forget(self: *Cache, hint: *SvgHint) void {
        if (self.map.get(hint.key_hash)) |held| {
            if (held == hint) {
                _ = self.map.remove(hint.key_hash);
                self.guard.noteRemoval(&self.map);
            }
        }
        hint.cache = null;
    }
};

/// The presentational hint block of the SVG element `element` (local name
/// `local`, node document `document`): its shared hint, from `cache` (null:
/// no cache - every hint its element's own), held in `state`'s hint slot;
/// null when no presentation attribute gives a declaration.
pub fn svgHint(element: *runtime.Instance, state: *ElementStyle, data: element_data.View, local: []const u8, cache: ?*Cache, document: *runtime.Instance) Allocator.Error!?*const DeclarationBlock {
    // The element's presentation attributes, in name order: on the stack
    // for the usual few, in a list past them.
    var stack_inputs: [16]Key.BorrowedInput = undefined;
    var n: usize = 0;
    var more: std.ArrayList(Key.BorrowedInput) = .empty;
    defer more.deinit(state.allocator);
    var any_url = false;
    var it = data.attributeIterator();
    while (it.next()) |entry| {
        if (entry.namespace_uri != null) continue;
        if (css.svg_presentation.lookup(svg_namespace, local, entry.local_name) == null) continue;
        const input: Key.BorrowedInput = .{ .name = entry.local_name, .value = entry.value };
        if (more.items.len == 0 and n < stack_inputs.len) {
            stack_inputs[n] = input;
        } else {
            if (more.items.len == 0) try more.appendSlice(state.allocator, stack_inputs[0..n]);
            try more.append(state.allocator, input);
        }
        n += 1;
        if (resource_loading.mayHaveResources(entry.value)) any_url = true;
    }
    if (n == 0) {
        state.dropSvgHint();
        return null;
    }
    const inputs: []Key.BorrowedInput = if (more.items.len != 0) more.items else stack_inputs[0..n];
    std.mem.sort(Key.BorrowedInput, inputs, {}, struct {
        fn less(_: void, a: Key.BorrowedInput, b: Key.BorrowedInput) bool {
            return std.mem.lessThan(u8, a.name, b.name);
        }
    }.less);
    var base_storage: []const u8 = "";
    defer if (base_storage.len != 0) element.ctx.allocator.free(base_storage);
    if (any_url) {
        base_storage = interfaces.Node.get_baseURI(element) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => "",
        };
    }
    const key: Key = .{ .local = local, .inputs = inputs, .base = if (any_url) base_storage else null };
    const key_hash = key.hash();
    const generation = runtime.SlabAllocator.generationOf(document);
    // The element's own hint still stands for its attributes and document.
    if (state.svgHint()) |old| {
        if (old.key_hash == key_hash and old.matches(key) and old.document == @intFromPtr(document) and old.document_generation == generation) return &old.block;
    }
    // Another element's, from the document's cache.
    if (cache) |c| if (c.find(key, key_hash)) |shared| {
        if (state.svgHint() == shared) {
            shared.release();
            return &shared.block;
        }
        state.setHint(&shared.header);
        return &shared.block;
    };
    const made = try build(state.allocator, element, local, key, key_hash) orelse {
        state.dropSvgHint();
        return null;
    };
    made.document = @intFromPtr(document);
    made.document_generation = generation;
    if (cache) |c| c.insert(made);
    state.setHint(&made.header);
    return &made.block;
}

/// A new hint for `key` (one reference), or null when no attribute gives a
/// declaration.
fn build(allocator: Allocator, element: *runtime.Instance, local: []const u8, key: Key, key_hash: u64) Allocator.Error!?*SvgHint {
    var block = DeclarationBlock.init(allocator);
    errdefer block.deinit();
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer assignments.deinit(allocator);
    for (key.inputs) |input| {
        const property = css.svg_presentation.lookup(svg_namespace, local, input.name) orelse continue;
        var context = try resource_loading.inlineParseContext(element, allocator, false, input.value);
        defer context.deinit();
        assignments.clearRetainingCapacity();
        const parsed = try css.svg_presentation.parse(context.options(), svg_namespace, local, input.name, input.value, &assignments);
        // The parsed values are ours; the block retains what it keeps.
        defer for (assignments.items) |a| a.value.release();
        if (!parsed) continue;
        _ = block.setValidatedProperty(property, assignments.items) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            // A value the block refuses sets nothing, as an invalid one.
            error.Invalid => {},
        };
    }
    if (block.length() == 0) {
        block.deinit();
        return null;
    }
    const inputs = try allocator.alloc(Input, key.inputs.len);
    var made_inputs: usize = 0;
    errdefer {
        for (inputs[0..made_inputs]) |input| {
            allocator.free(input.name);
            allocator.free(input.value);
        }
        allocator.free(inputs);
    }
    for (key.inputs, 0..) |input, i| {
        const name = try allocator.dupe(u8, input.name);
        errdefer allocator.free(name);
        inputs[i] = .{ .name = name, .value = try allocator.dupe(u8, input.value) };
        made_inputs += 1;
    }
    const owned_local = try allocator.dupe(u8, local);
    errdefer allocator.free(owned_local);
    const base: ?[]u8 = if (key.base) |b| try allocator.dupe(u8, b) else null;
    errdefer if (base) |b| allocator.free(b);
    const hint = try allocator.create(SvgHint);
    hint.* = .{ .allocator = allocator, .local = owned_local, .inputs = inputs, .base = base, .key_hash = key_hash, .block = block };
    return hint;
}

/// A hint for a test: `local` with no inputs and an empty block, cached in
/// `cache` under `key_hash` when given.
pub fn createForTest(allocator: Allocator, local: []const u8, key_hash: u64, cache: ?*Cache) Allocator.Error!*SvgHint {
    const hint = try allocator.create(SvgHint);
    errdefer allocator.destroy(hint);
    const owned_local = try allocator.dupe(u8, local);
    errdefer allocator.free(owned_local);
    const inputs = try allocator.alloc(Input, 0);
    hint.* = .{ .allocator = allocator, .local = owned_local, .inputs = inputs, .base = null, .key_hash = key_hash, .block = DeclarationBlock.init(allocator) };
    if (cache) |c| c.insert(hint);
    return hint;
}

/// The cached entry for `key_hash`, retained, for a test.
pub fn findForTest(cache: *Cache, local: []const u8, key_hash: u64) ?*SvgHint {
    return cache.find(.{ .local = local, .inputs = &.{}, .base = null }, key_hash);
}

test "the cache keeps an entry while an element holds it, and is empty when the last lets go" {
    const allocator = std.testing.allocator;
    const cache = try Cache.create(allocator);
    defer cache.destroy();
    const a = try createForTest(allocator, "rect", 1, cache);
    const b = try createForTest(allocator, "circle", 2, cache);
    try std.testing.expectEqual(@as(usize, 2), cache.count());
    // A second element with a's key shares it.
    const shared = findForTest(cache, "rect", 1) orelse return error.TestExpectedEntry;
    try std.testing.expect(shared == a);
    a.release();
    try std.testing.expectEqual(@as(usize, 2), cache.count());
    shared.release();
    try std.testing.expectEqual(@as(usize, 1), cache.count());
    b.release();
    try std.testing.expectEqual(@as(usize, 0), cache.count());
}

test "an entry the cache let go of lives on with its element, uncached" {
    const allocator = std.testing.allocator;
    const cache = try Cache.create(allocator);
    const a = try createForTest(allocator, "rect", 7, cache);
    cache.destroy();
    try std.testing.expect(a.cache == null);
    a.release();
}

test "past the bound, the cache lets go of every entry, as Blink's clears" {
    const allocator = std.testing.allocator;
    const cache = try Cache.create(allocator);
    defer cache.destroy();
    var hints: [max_entries + 1]*SvgHint = undefined;
    for (&hints, 0..) |*h, i| h.* = try createForTest(allocator, "rect", i + 1, cache);
    try std.testing.expectEqual(@as(usize, 1), cache.count());
    try std.testing.expect(hints[0].cache == null);
    try std.testing.expect(hints[max_entries].cache == cache);
    for (hints) |h| h.release();
    try std.testing.expectEqual(@as(usize, 0), cache.count());
}
