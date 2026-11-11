//! A Document's matched-properties cache: computed styles kept by the
//! declarations that matched their element, so that the next element the
//! same declarations match - under a parent with the same inherited values -
//! takes the kept style instead of running the cascade, and elements the
//! cascade still runs for share the groups of values it wrote. Blink's
//! MatchedPropertiesCache (core/css/resolver/matched_properties_cache.{h,cc};
//! chromium b41b067a9d87) and WebKit's Style::MatchedDeclarationsCache
//! (Source/WebCore/style/MatchedDeclarationsCache.{h,cpp}; WebKit
//! d49abe63b03f): "The MPC thus allows us to skip step 4, but equally
//! important, it allows us to reuse subgroups of ComputedStyle so that we
//! use less RAM" (Blink StyleResolver).
//!
//! A hit (lane style1 b2; design tmp/redesign/style-memory-design.md 3.2) is
//! Blink's full hit: `find` answers an entry whose
//! - matched declarations are the element's, block by block, each with the
//!   same cascade Source (WebKit compares property sets by pointer, as here:
//!   a rule's block is stable for the engine generation the cache was filled
//!   under, and every change to sheets, rules, media, environment variables,
//!   registrations or page color schemes moves the generation and clears the
//!   cache). The engine never looks up a resolution that matched a block of
//!   the element's own - its style attribute, its presentational hints -
//!   whose address another element can reuse;
//! - pseudo-element is the element's;
//! - Context scalars (the root's metrics, the viewport, the color schemes,
//!   the registrations) are the element's;
//! - parent corresponds: the same inherited values (Blink
//!   InheritedEqualIncludingInheritedVariables; the custom property record by
//!   pointer, as WebKit's find), the same parent inputs of the adjustments
//!   (Blink StyleAdjuster::IsCacheCompatible: justify-items, the
//!   blockifying display; box context; base appearance, as WebKit's
//!   inBaseAppearance), and - when the cascade inherited a non-inherited
//!   value explicitly - the same non-inherited values (Blink
//!   HasExplicitInheritance + NonInheritedEqual);
//! - cascade read no input of the element's own (css.cascade.Dependencies:
//!   attr(), tree counts, random(), container, system fonts, font metrics).
//! A hit's style is a clone of the entry's holder: its groups, records and
//! header flags, adjusted already (Blink stores the adjusted style).
//!
//! A miss runs the cascade; `add` then shares every group the new style
//! holds alone whose values are identical to an entry's of the same key
//! (ComputedStyle.adoptIdenticalGroups, lane style1 b1) and keeps the style
//! while the key has room.
//!
//! The key (`keyOf`) is only where to look: each matched block - a rule's by
//! address, a style attribute's by the property names it declares - with its
//! Source, and the pseudo-element. A collision or a reused address costs a
//! compare, never a value.
//!
//! Holds and the steps that end them (lesson architecture-a-browsers-strong-
//! hold-comes-with-the-step-that-ends-it). Each entry holds a
//! ComputedStyle.clone of its style - one reference on each of its groups and
//! records - and, when it can serve a hit, a clone of its parent's style (so a
//! group address it compares cannot be freed and reused) and a copy of its
//! matched list. Released, entry and all:
//! 1. every entry when the engine's generation moves: Blink's
//!    StyleResolver::InvalidateMatchedPropertiesCache and
//!    ClearViewportDependent, WebKit's invalidate and
//!    clearEntriesAffectedByViewportUnits;
//! 2. the least recently used beyond `limit` entries, down to `prune_target`
//!    (Blink CleanMatchedPropertiesCache: kCacheLimit 500, kPruneCacheTarget
//!    300);
//! 3. a full key takes no more entries (WebKit maxEntriesPerHash = 4);
//! 4. everything, with the Document's style engine (StyleEngine.deinit).
//! The entries hold values, never a node, a realm or a declaration block.
//!
//! One per Document's StyleEngine, used on its Browser's window-agent thread
//! only, as the groups it holds are (css/computed_style.zig, "Storage").

const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const css = @import("css");

const ComputedStyle = css.computed_style.ComputedStyle;
const Matched = css.cascade.Matched;
const Longhand = css.properties.Longhand;

/// The pseudo-elements whose styles may serve a hit: none, ::before,
/// ::after, ::marker. Every other one (highlights, arguments) is resolved
/// every time (WebKit isCacheable: highlight pseudo-elements and a
/// pseudo-element name argument).
pub const Pseudo = enum(u8) {
    none,
    before,
    after,
    marker,

    pub fn of(pseudo: ?[]const u8) ?Pseudo {
        const name = pseudo orelse return .none;
        inline for (.{ .before, .after, .marker }) |p| if (std.mem.eql(u8, name, @tagName(p))) return p;
        return null;
    }
};

/// The Context scalars a cascade reads that no parent carries.
pub const Inputs = struct {
    root_font_size: f64 = 16,
    root_line_height: ?f64 = null,
    root_vertical: bool = false,
    root_upright: bool = false,
    viewport_width: f64 = 1024,
    viewport_height: f64 = 768,
    page_color_scheme: css.color_scheme.Scheme = .light,
    preferred_color_scheme: css.color_scheme.Scheme = .light,
    registered: ?*const css.registered_properties.Snapshot = null,

    pub fn of(ctx: css.cascade.Context) Inputs {
        return .{
            .root_font_size = ctx.root_font_size,
            .root_line_height = ctx.root_line_height,
            .root_vertical = ctx.root_vertical,
            .root_upright = ctx.root_upright,
            .viewport_width = ctx.viewport_width,
            .viewport_height = ctx.viewport_height,
            .page_color_scheme = ctx.page_color_scheme,
            .preferred_color_scheme = ctx.preferred_color_scheme,
            .registered = ctx.registered,
        };
    }

    fn bits(x: f64) u64 {
        return @bitCast(x);
    }

    fn eql(a: Inputs, b: Inputs) bool {
        if (bits(a.root_font_size) != bits(b.root_font_size) or bits(a.viewport_width) != bits(b.viewport_width) or
            bits(a.viewport_height) != bits(b.viewport_height)) return false;
        if ((a.root_line_height == null) != (b.root_line_height == null)) return false;
        if (a.root_line_height) |x| if (bits(x) != bits(b.root_line_height.?)) return false;
        return a.root_vertical == b.root_vertical and a.root_upright == b.root_upright and
            a.page_color_scheme == b.page_color_scheme and a.preferred_color_scheme == b.preferred_color_scheme and
            a.registered == b.registered;
    }
};

/// One resolution, as the cache sees it.
pub const Lookup = struct {
    key: u64,
    generation: u64,
    matched: []const Matched = &.{},
    pseudo: Pseudo = .none,
    /// The flat-tree parent's style; null for the root, which is never
    /// looked up (WebKit isCacheable: the document element).
    parent: ?*const ComputedStyle = null,
    inputs: Inputs = .{},
};

pub const MatchedPropertiesCache = struct {
    allocator: Allocator,
    /// An array hash map: buckets come and go with the cache's keys, and an
    /// array map removes without tombstones (tools/lint_tombstones.zig).
    buckets: std.AutoArrayHashMapUnmanaged(u64, Bucket) = .empty,
    /// Entries across every bucket.
    entries: u32 = 0,
    /// A virtual clock for least-recently-used order (Blink's `clock_`): it
    /// may wrap, which only evicts the wrong entry, never shares a wrong
    /// value.
    clock: u32 = 0,
    /// The engine generation the entries were made under.
    generation: u64 = 0,
    /// Lookups answered and not (counters for tests and measurements).
    hits: u32 = 0,
    misses: u32 = 0,

    pub const per_key = 4;
    pub const limit = 500;
    pub const prune_target = 300;

    const Entry = struct {
        holder: *ComputedStyle,
        last_used: u32,
        /// What a hit must correspond to; null for a style that serves none
        /// (its cascade read an input of its element's own, or its
        /// resolution was never cacheable): it is kept for adoption only.
        hit: ?*Correspondence = null,
    };

    const Correspondence = struct {
        /// The parent's style when the entry was made, held (a clone).
        parent: *ComputedStyle,
        /// The matched list, copied.
        matched: []Matched,
        pseudo: Pseudo,
        inputs: Inputs,
        /// The cascade took a non-inherited value from the parent.
        parent_non_inherited: bool,
    };

    const Bucket = struct {
        len: u8 = 0,
        items: [per_key]Entry = undefined,
    };

    pub fn create(allocator: Allocator) Allocator.Error!*MatchedPropertiesCache {
        const self = try allocator.create(MatchedPropertiesCache);
        self.* = .{ .allocator = allocator };
        return self;
    }

    pub fn destroy(self: *MatchedPropertiesCache) void {
        self.clear();
        self.buckets.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    fn release(self: *MatchedPropertiesCache, entry: Entry) void {
        entry.holder.destroy();
        if (entry.hit) |hit| {
            hit.parent.destroy();
            self.allocator.free(hit.matched);
            self.allocator.destroy(hit);
        }
    }

    /// Release every entry.
    pub fn clear(self: *MatchedPropertiesCache) void {
        for (self.buckets.values()) |*bucket| for (bucket.items[0..bucket.len]) |entry| self.release(entry);
        self.buckets.clearRetainingCapacity();
        self.entries = 0;
    }

    fn tick(self: *MatchedPropertiesCache) u32 {
        self.clock +%= 1;
        return self.clock;
    }

    fn enter(self: *MatchedPropertiesCache, generation: u64) void {
        if (generation != self.generation) {
            self.clear();
            self.generation = generation;
        }
    }

    /// The kept style that stands for the cascade of `lookup` (borrowed: the
    /// caller clones it), or null. Blink MatchedPropertiesCache::Find, most
    /// recent entry first.
    pub fn find(self: *MatchedPropertiesCache, lookup: Lookup) ?*const ComputedStyle {
        self.enter(lookup.generation);
        if (self.buckets.getPtr(lookup.key)) |bucket| {
            var i = bucket.len;
            while (i > 0) {
                i -= 1;
                const entry = &bucket.items[i];
                const hit = entry.hit orelse continue;
                if (!corresponds(hit, lookup)) continue;
                entry.last_used = self.tick();
                self.hits +%= 1;
                return entry.holder;
            }
        }
        self.misses +%= 1;
        return null;
    }

    /// `style` was just computed by the cascade for `lookup`, which recorded
    /// `dependencies` (null: the resolution is not cacheable at all): share
    /// each of its groups an entry of the same key holds with identical
    /// values, and keep it - for hits when its cascade read nothing of its
    /// element's own, else for adoption while it holds a group of its own -
    /// while the key has room. Never fails: running out of memory only
    /// leaves `style` holding its own groups and the cache without it.
    pub fn add(self: *MatchedPropertiesCache, lookup: Lookup, dependencies: ?css.cascade.Dependencies, style: *ComputedStyle) void {
        self.enter(lookup.generation);
        const cacheable = if (dependencies) |d| d.cacheable() and lookup.parent != null else false;
        if (!cacheable and style.groupsHeldAlone() == 0) return;
        const gop = self.buckets.getOrPut(self.allocator, lookup.key) catch return;
        if (!gop.found_existing) gop.value_ptr.* = .{};
        const bucket = gop.value_ptr;
        // The most recent first (Blink's Find scans backwards).
        var i = bucket.len;
        while (i > 0 and style.groupsHeldAlone() != 0) {
            i -= 1;
            const entry = &bucket.items[i];
            if (style.adoptIdenticalGroups(entry.holder) != 0) entry.last_used = self.tick();
        }
        // A full key keeps the entries it has (WebKit's
        // MatchedDeclarationsCache::add appends only below
        // maxEntriesPerHash): a style whose own group no entry matches - a
        // per-element value - would otherwise replace an entry on every
        // resolution, a clone made and a holder destroyed each time.
        if (bucket.len == per_key or (!cacheable and style.groupsHeldAlone() == 0)) {
            if (bucket.len == 0) _ = self.buckets.swapRemove(lookup.key);
            return;
        }
        const entry = self.makeEntry(lookup, if (cacheable) dependencies.?.parent_non_inherited else null, style) catch {
            if (bucket.len == 0) _ = self.buckets.swapRemove(lookup.key);
            return;
        };
        bucket.items[bucket.len] = entry;
        bucket.len += 1;
        self.entries += 1;
        if (self.entries > limit) self.prune();
    }

    fn makeEntry(self: *MatchedPropertiesCache, lookup: Lookup, parent_non_inherited: ?bool, style: *const ComputedStyle) Allocator.Error!Entry {
        const holder = try style.clone(self.allocator);
        errdefer holder.destroy();
        const non_inherited = parent_non_inherited orelse return .{ .holder = holder, .last_used = self.tick() };
        const hit = try self.allocator.create(Correspondence);
        errdefer self.allocator.destroy(hit);
        const matched = try self.allocator.dupe(Matched, lookup.matched);
        errdefer self.allocator.free(matched);
        hit.* = .{
            .parent = try lookup.parent.?.clone(self.allocator),
            .matched = matched,
            .pseudo = lookup.pseudo,
            .inputs = lookup.inputs,
            .parent_non_inherited = non_inherited,
        };
        return .{ .holder = holder, .last_used = self.tick(), .hit = hit };
    }

    /// Keep the `prune_target` most recently used entries (Blink's
    /// CleanMatchedPropertiesCache once over kCacheLimit).
    fn prune(self: *MatchedPropertiesCache) void {
        var stamps: std.ArrayList(u32) = .empty;
        defer stamps.deinit(self.allocator);
        for (self.buckets.values()) |*bucket| for (bucket.items[0..bucket.len]) |entry| {
            stamps.append(self.allocator, entry.last_used) catch {
                // No room to rank them: release everything instead.
                self.clear();
                return;
            };
        };
        if (stamps.items.len <= prune_target) return;
        std.mem.sortUnstable(u32, stamps.items, {}, std.sort.asc(u32));
        const cutoff = stamps.items[stamps.items.len - prune_target - 1];
        var keys: std.ArrayList(u64) = .empty;
        defer keys.deinit(self.allocator);
        for (self.buckets.keys(), self.buckets.values()) |key, *bucket| {
            var kept: u8 = 0;
            for (bucket.items[0..bucket.len]) |entry| {
                if (entry.last_used <= cutoff) {
                    self.release(entry);
                    self.entries -= 1;
                } else {
                    bucket.items[kept] = entry;
                    kept += 1;
                }
            }
            bucket.len = kept;
            if (kept == 0) keys.append(self.allocator, key) catch {};
        }
        // An empty bucket that could not be listed stays, empty: harmless.
        for (keys.items) |k| _ = self.buckets.swapRemove(k);
    }
};

fn corresponds(hit: *const MatchedPropertiesCache.Correspondence, lookup: Lookup) bool {
    if (hit.pseudo != lookup.pseudo or !hit.inputs.eql(lookup.inputs)) return false;
    if (hit.matched.len != lookup.matched.len) return false;
    for (hit.matched, lookup.matched) |a, b| {
        if (a.block != b.block or !std.meta.eql(a.source, b.source)) return false;
    }
    const parent = lookup.parent orelse return false;
    return parentCorresponds(hit.parent, parent, hit.parent_non_inherited);
}

/// Whether a style computed under `cached` (the entry's parent) is the one
/// the cascade computes under `parent`: what the cascade reads of a parent.
fn parentCorresponds(cached: *const ComputedStyle, parent: *const ComputedStyle, non_inherited: bool) bool {
    // CSS Variables 1: var() and inherited registered properties read the
    // parent's record (WebKit find: the same inheritedCustomProperties).
    if (cached.custom != parent.custom) return false;
    // adjust() and the base-appearance bit (Blink IsCacheCompatible, WebKit
    // inBaseAppearanceSubtree).
    if (cached.in_base_appearance != parent.in_base_appearance or cached.box_context != parent.box_context) return false;
    if (css.cascade.blockifiesChildren(cached) != css.cascade.blockifiesChildren(parent)) return false;
    // Align 3 7.1: every element's justify-items `legacy` reads its parent's
    // (Blink IsCacheCompatible: the parent's JustifyItems).
    if (!css.computed_style.identical(cached.get(.justify_items), parent.get(.justify_items))) return false;
    if (!cached.inheritedEqual(parent)) return false;
    if (non_inherited) {
        if (cached.custom_own != parent.custom_own or !cached.nonInheritedEqual(parent)) return false;
    }
    return true;
}

/// What tells a hit's style from the cascade it stood for.
pub const Difference = union(enum) {
    /// The cascade read an input of the element's own.
    uncacheable: css.cascade.Dependencies,
    longhand: Longhand,
    custom: []const u8,
    flags,
};

/// The cascade of `ctx` over `matched`, compared with `style` - a hit's
/// style - as a reader would: every longhand's value, every custom property,
/// the header's flags. Null when they agree. The engine's Debug self-check
/// (the bug-finding runner and the unit tests) runs it on every hit.
pub fn differenceFromCascade(ctx: css.cascade.Context, matched: []const Matched, style: *const ComputedStyle) Allocator.Error!?Difference {
    var dependencies: css.cascade.Dependencies = .{};
    var recording = ctx;
    recording.dependencies = &dependencies;
    const fresh = try css.cascade.cascade(recording, matched);
    defer fresh.destroy();
    if (!dependencies.cacheable()) return .{ .uncacheable = dependencies };
    if (style.firstDifference(fresh)) |l| return .{ .longhand = l };
    if (style.used_color_scheme != fresh.used_color_scheme or style.box_context != fresh.box_context or
        style.subgrid_ineligible != fresh.subgrid_ineligible or style.in_base_appearance != fresh.in_base_appearance or
        style.registered != fresh.registered) return .flags;
    const names = try style.customNames(ctx.allocator);
    defer ctx.allocator.free(names);
    const fresh_names = try fresh.customNames(ctx.allocator);
    defer ctx.allocator.free(fresh_names);
    if (names.len != fresh_names.len) return .{ .custom = if (names.len > fresh_names.len) names[fresh_names.len] else fresh_names[names.len] };
    for (names, fresh_names) |name, other| {
        if (!std.mem.eql(u8, name, other)) return .{ .custom = name };
        const a = style.customValue(name).?;
        const b = fresh.customValue(other).?;
        if (!a.eql(b)) return .{ .custom = name };
    }
    return null;
}

/// The cache key of an element's matched declarations (in cascade order) for
/// `pseudo`: each block - a rule's by address, a style attribute's by the
/// names it declares - with its Source. A few multiply-rotate steps per block
/// (it runs at every resolution): the key only says where to look, and a
/// collision costs a compare, never a value.
pub fn keyOf(matched: []const Matched, pseudo: ?[]const u8) u64 {
    var h: u64 = 0x5354594c4531;
    if (pseudo) |p| h = mix(h, std.hash.Wyhash.hash(0, p));
    for (matched) |*m| {
        const s = &m.source;
        if (s.element_attached) {
            for (m.block.entries.items) |*entry| h = mix(h, std.hash.Wyhash.hash(1, entry.name()));
        } else h = mix(h, @intFromPtr(m.block));
        h = mix(h, (@as(u64, @backingInt(s.origin)) << 56) | (@as(u64, s.layer) << 40) | (@as(u64, s.tree_depth) << 24) |
            (@as(u64, @intFromBool(s.element_attached)) << 1) | @intFromBool(s.tree_count_allowed));
        h = mix(h, (@as(u64, s.order) << 32) ^ (@as(u64, s.specificity.a) << 20) ^ (@as(u64, s.specificity.b) << 10) ^ s.specificity.c);
        h = mix(h, s.tree_scope.serial);
    }
    return h;
}

fn mix(h: u64, x: u64) u64 {
    return std.math.rotl(u64, (h ^ x) *% 0x9E3779B97F4A7C15, 29);
}

const testing = std.testing;

fn styleOf(allocator: Allocator, parent: ?*const ComputedStyle, text: []const u8) !*ComputedStyle {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, text);
    defer block.deinit();
    return css.cascade.cascade(.{ .allocator = allocator, .parent = parent, .is_root = parent == null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
}

test "the second style of a key shares the first's groups; a new generation forgets them" {
    const allocator = testing.allocator;
    const cache = try MatchedPropertiesCache.create(allocator);
    defer cache.destroy();
    const root = try styleOf(allocator, null, "");
    defer root.destroy();
    const text = "display: flex; margin-left: 3px; background-color: #fafafa";
    const a = try styleOf(allocator, root, text);
    defer a.destroy();
    cache.add(.{ .key = 7, .generation = 1 }, null, a);
    try testing.expectEqual(@as(u32, 1), cache.entries);
    const b = try styleOf(allocator, root, text);
    defer b.destroy();
    cache.add(.{ .key = 7, .generation = 1 }, null, b);
    try testing.expectEqual(@as(usize, 0), b.groupsHeldAlone());
    try testing.expectEqual(@as(u32, 1), cache.entries);
    const g = css.computed_style.groups.location[@backingInt(css.properties.Longhand.margin_left)].group;
    try testing.expect(b.slots[g] == a.slots[g]);
    // Another generation: the entry made under the first is released before
    // anything is looked up, so c keeps its own groups and becomes the new
    // entry (its holder the only other reference on them).
    const c = try styleOf(allocator, root, text);
    defer c.destroy();
    cache.add(.{ .key = 7, .generation = 2 }, null, c);
    try testing.expect(c.slots[g] != a.slots[g]);
    try testing.expectEqual(@as(u32, 2), css.computed_style.Group.of(c.slots[g]).refs);
    try testing.expectEqual(@as(u32, 2), css.computed_style.Group.of(a.slots[g]).refs);
    try testing.expectEqual(@as(u32, 1), cache.entries);
}

test "a key keeps at most per_key entries and the cache at most limit" {
    const allocator = testing.allocator;
    const cache = try MatchedPropertiesCache.create(allocator);
    defer cache.destroy();
    const root = try styleOf(allocator, null, "");
    defer root.destroy();
    var buffer: [64]u8 = undefined;
    for (0..per_key_test_styles) |k| {
        const s = try styleOf(allocator, root, try std.fmt.bufPrint(&buffer, "margin-left: {d}px", .{k + 1}));
        defer s.destroy();
        cache.add(.{ .key = 1, .generation = 1 }, null, s);
    }
    try testing.expectEqual(@as(u32, MatchedPropertiesCache.per_key), cache.entries);
    for (0..MatchedPropertiesCache.limit + 1) |k| {
        const s = try styleOf(allocator, root, try std.fmt.bufPrint(&buffer, "margin-top: {d}px", .{k + 1}));
        defer s.destroy();
        cache.add(.{ .key = 100 + k, .generation = 1 }, null, s);
    }
    try testing.expect(cache.entries <= MatchedPropertiesCache.limit);
    try testing.expect(cache.entries >= MatchedPropertiesCache.prune_target);
}

const per_key_test_styles = MatchedPropertiesCache.per_key + 3;

test "a full key keeps the entries it has: a later style of that key is not kept (WebKit's maxEntriesPerHash)" {
    const allocator = testing.allocator;
    const cache = try MatchedPropertiesCache.create(allocator);
    defer cache.destroy();
    const root = try styleOf(allocator, null, "");
    defer root.destroy();
    var buffer: [64]u8 = undefined;
    // The first per_key styles fill the key; the next ones (each with a value
    // of its own) find no entry to share with and are not kept.
    for (0..per_key_test_styles) |k| {
        const s = try styleOf(allocator, root, try std.fmt.bufPrint(&buffer, "margin-left: {d}px", .{k + 1}));
        defer s.destroy();
        cache.add(.{ .key = 1, .generation = 1 }, null, s);
    }
    try testing.expectEqual(@as(u32, MatchedPropertiesCache.per_key), cache.entries);
    // The entries are the first per_key styles' (1px to 4px), in order.
    const bucket = cache.buckets.getPtr(1).?;
    for (bucket.items[0..bucket.len], 1..) |entry, px| {
        try testing.expectEqual(@as(f64, @floatFromInt(px)), entry.holder.get(.margin_left).length.value);
    }
    // So the first style's values are still there to share, and sharing them
    // replaces no entry.
    const again = try styleOf(allocator, root, "margin-left: 1px");
    defer again.destroy();
    const first = bucket.items[0].holder;
    cache.add(.{ .key = 1, .generation = 1 }, null, again);
    try testing.expect(cache.buckets.getPtr(1).?.items[0].holder == first);
    const g = css.computed_style.groups.location[@backingInt(css.properties.Longhand.margin_left)].group;
    try testing.expect(again.slots[g] == first.slots[g]);
}

test "sharing under allocation failure leaves the style's own groups" {
    const allocator = testing.allocator;
    // The cache itself is the first allocation; its bucket the second.
    var failing = testing.FailingAllocator.init(allocator, .{ .fail_index = 1 });
    const cache = try MatchedPropertiesCache.create(failing.allocator());
    defer cache.destroy();
    const root = try styleOf(allocator, null, "");
    defer root.destroy();
    const a = try styleOf(allocator, root, "margin-left: 3px");
    defer a.destroy();
    const alone = a.groupsHeldAlone();
    cache.add(.{ .key = 3, .generation = 1 }, null, a);
    try testing.expectEqual(alone, a.groupsHeldAlone());
    try testing.expectEqual(@as(u32, 0), cache.entries);
}

// ---------------------------------------------------------------------------
// Lane style1 b2 (S2): hits. Each test removes one correspondence rule's
// reason and expects a miss; the batch's mutation run removes each rule's
// check and shows its test fail.
// ---------------------------------------------------------------------------

/// A parent style and a block its child cascades, kept for a test.
const Scene = struct {
    parent: *ComputedStyle,
    parent_block: css.declarations.DeclarationBlock,
    block: css.declarations.DeclarationBlock,
    matched: [1]Matched = undefined,

    fn init(self: *Scene, parent_text: []const u8, text: []const u8) !void {
        self.parent_block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, parent_text);
        errdefer self.parent_block.deinit();
        self.parent = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null, .is_root = true }, &.{.{ .block = &self.parent_block, .source = .{ .origin = .author } }});
        errdefer self.parent.destroy();
        self.block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, text);
        self.matched = .{.{ .block = &self.block, .source = .{ .origin = .author, .order = 3 } }};
    }

    fn deinit(self: *Scene) void {
        self.block.deinit();
        self.parent.destroy();
        self.parent_block.deinit();
    }

    fn lookup(self: *const Scene, parent: *const ComputedStyle) Lookup {
        return .{ .key = keyOf(&self.matched, null), .generation = 1, .matched = &self.matched, .parent = parent };
    }

    /// The child's cascade under `parent`, recorded, then kept by `cache`.
    fn miss(self: *const Scene, cache: *MatchedPropertiesCache, parent: *const ComputedStyle) !*ComputedStyle {
        var deps: css.cascade.Dependencies = .{};
        const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = parent, .dependencies = &deps }, &self.matched);
        cache.add(self.lookup(parent), deps, style);
        return style;
    }
};

fn rootStyle(text: []const u8) !struct { style: *ComputedStyle, block: css.declarations.DeclarationBlock } {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, text);
    errdefer block.deinit();
    const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null, .is_root = true }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    return .{ .style = style, .block = block };
}

test "a kept style stands for the next cascade of the same declarations under an equal parent" {
    const cache = try MatchedPropertiesCache.create(testing.allocator);
    defer cache.destroy();
    var scene: Scene = undefined;
    try scene.init("font-size: 20px; color: blue", "margin-left: 2em; display: flex; color: currentcolor");
    defer scene.deinit();
    const first = try scene.miss(cache, scene.parent);
    defer first.destroy();
    const held = cache.find(scene.lookup(scene.parent)) orelse return error.ExpectedHit;
    try testing.expectEqual(@as(u32, 1), cache.hits);
    try testing.expect(held.firstDifference(first) == null);
    // A cousin: another parent object with the same inherited values (its
    // own groups, not shared) is the same parent to the cache.
    var cousin = try rootStyle("font-size: 20px; color: blue");
    defer cousin.block.deinit();
    defer cousin.style.destroy();
    try testing.expect(cache.find(scene.lookup(cousin.style)) != null);
    // The self-check agrees with the hit.
    try testing.expect(try differenceFromCascade(.{ .allocator = testing.allocator, .parent = cousin.style }, &scene.matched, held) == null);
}

test "an input the cascade read of the element's own makes the style serve no hit" {
    inline for (.{ "attr", "tree_counts", "random", "container", "system_font", "font_metrics" }) |field| {
        const cache = try MatchedPropertiesCache.create(testing.allocator);
        defer cache.destroy();
        var scene: Scene = undefined;
        try scene.init("font-size: 20px", "margin-left: 3px");
        defer scene.deinit();
        const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = scene.parent }, &scene.matched);
        defer style.destroy();
        var deps: css.cascade.Dependencies = .{};
        @field(deps, field) = true;
        cache.add(scene.lookup(scene.parent), deps, style);
        try testing.expect(cache.find(scene.lookup(scene.parent)) == null);
        // Kept for adoption all the same.
        try testing.expectEqual(@as(u32, 1), cache.entries);
    }
}

test "a parent whose inherited values differ is another parent (Blink InheritedEqual)" {
    const cache = try MatchedPropertiesCache.create(testing.allocator);
    defer cache.destroy();
    var scene: Scene = undefined;
    try scene.init("font-size: 20px", "margin-left: 2em");
    defer scene.deinit();
    const first = try scene.miss(cache, scene.parent);
    defer first.destroy();
    var other = try rootStyle("font-size: 30px");
    defer other.block.deinit();
    defer other.style.destroy();
    try testing.expect(cache.find(scene.lookup(other.style)) == null);
    // The self-check names what a wrong hit would get wrong: 2em under 30px.
    const wrong = try differenceFromCascade(.{ .allocator = testing.allocator, .parent = other.style }, &scene.matched, first) orelse return error.SelfCheckMissedAWrongHit;
    try testing.expect(wrong == .longhand);
}

test "a parent with another custom property record is another parent (WebKit: the same inheritedCustomProperties)" {
    const cache = try MatchedPropertiesCache.create(testing.allocator);
    defer cache.destroy();
    var scene: Scene = undefined;
    try scene.init("--w: 3px", "margin-left: var(--w)");
    defer scene.deinit();
    const first = try scene.miss(cache, scene.parent);
    defer first.destroy();
    var other = try rootStyle("--w: 4px");
    defer other.block.deinit();
    defer other.style.destroy();
    try testing.expect(cache.find(scene.lookup(other.style)) == null);
    try testing.expect(cache.find(scene.lookup(scene.parent)) != null);
}

test "explicit inheritance of a non-inherited value needs the parent's non-inherited values (Blink HasExplicitInheritance)" {
    const cache = try MatchedPropertiesCache.create(testing.allocator);
    defer cache.destroy();
    var scene: Scene = undefined;
    try scene.init("margin-left: 5px", "margin-left: inherit");
    defer scene.deinit();
    const first = try scene.miss(cache, scene.parent);
    defer first.destroy();
    var other = try rootStyle("margin-left: 6px");
    defer other.block.deinit();
    defer other.style.destroy();
    try testing.expect(cache.find(scene.lookup(other.style)) == null);
    // Without explicit inheritance the parent's non-inherited values do not matter.
    var plain: Scene = undefined;
    try plain.init("margin-left: 5px", "margin-left: 1px");
    defer plain.deinit();
    const kept = try plain.miss(cache, plain.parent);
    defer kept.destroy();
    try testing.expect(cache.find(plain.lookup(other.style)) != null);
}

test "the parent inputs of the adjustments must match (Blink StyleAdjuster::IsCacheCompatible)" {
    inline for (.{
        .{ "display: block", "display: flex" }, // blockification
        .{ "justify-items: legacy center", "justify-items: legacy left" }, // justify-items legacy
        .{ "display: block", "display: none" }, // box context
    }) |pair| {
        const cache = try MatchedPropertiesCache.create(testing.allocator);
        defer cache.destroy();
        var scene: Scene = undefined;
        try scene.init(pair[0], "display: inline; margin-left: 1px");
        defer scene.deinit();
        const first = try scene.miss(cache, scene.parent);
        defer first.destroy();
        var other = try rootStyle(pair[1]);
        defer other.block.deinit();
        defer other.style.destroy();
        try testing.expect(cache.find(scene.lookup(other.style)) == null);
    }
}

test "the matched declarations, their sources, the pseudo-element and the context scalars must be the element's" {
    const cache = try MatchedPropertiesCache.create(testing.allocator);
    defer cache.destroy();
    var scene: Scene = undefined;
    try scene.init("font-size: 20px", "margin-left: 1rem");
    defer scene.deinit();
    const first = try scene.miss(cache, scene.parent);
    defer first.destroy();
    // Another block with the same text: a different block.
    var twin = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "margin-left: 1rem");
    defer twin.deinit();
    const twin_matched = [_]Matched{.{ .block = &twin, .source = scene.matched[0].source }};
    var lookup = scene.lookup(scene.parent);
    lookup.matched = &twin_matched;
    try testing.expect(cache.find(lookup) == null);
    // The same block from another layer.
    var layered = scene.matched;
    layered[0].source.layer = 2;
    lookup = scene.lookup(scene.parent);
    lookup.matched = &layered;
    try testing.expect(cache.find(lookup) == null);
    // Another pseudo-element.
    lookup = scene.lookup(scene.parent);
    lookup.pseudo = .before;
    try testing.expect(cache.find(lookup) == null);
    // Another root font size (rem).
    lookup = scene.lookup(scene.parent);
    lookup.inputs.root_font_size = 20;
    try testing.expect(cache.find(lookup) == null);
    // Another viewport, another preferred color scheme.
    lookup = scene.lookup(scene.parent);
    lookup.inputs.viewport_width = 800;
    try testing.expect(cache.find(lookup) == null);
    lookup = scene.lookup(scene.parent);
    lookup.inputs.preferred_color_scheme = .dark;
    try testing.expect(cache.find(lookup) == null);
    // And the same lookup hits.
    try testing.expect(cache.find(scene.lookup(scene.parent)) != null);
}

test "a new generation forgets every entry; a key keeps at most per_key styles that serve hits" {
    const cache = try MatchedPropertiesCache.create(testing.allocator);
    defer cache.destroy();
    var scene: Scene = undefined;
    try scene.init("font-size: 20px", "margin-left: 1em");
    defer scene.deinit();
    const first = try scene.miss(cache, scene.parent);
    defer first.destroy();
    var lookup = scene.lookup(scene.parent);
    lookup.generation = 2;
    try testing.expect(cache.find(lookup) == null);
    try testing.expectEqual(@as(u32, 0), cache.entries);
    // Parents with font sizes 1..7px: each a miss, the key full at four.
    for (1..8) |px| {
        var buffer: [32]u8 = undefined;
        var parent = try rootStyle(try std.fmt.bufPrint(&buffer, "font-size: {d}px", .{px}));
        defer parent.block.deinit();
        defer parent.style.destroy();
        lookup = scene.lookup(parent.style);
        lookup.generation = 2;
        try testing.expect(cache.find(lookup) == null);
        var deps: css.cascade.Dependencies = .{};
        const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = parent.style, .dependencies = &deps }, &scene.matched);
        defer style.destroy();
        cache.add(lookup, deps, style);
    }
    try testing.expectEqual(@as(u32, MatchedPropertiesCache.per_key), cache.entries);
}

test "an entry that serves hits is kept whole under allocation failure, or not at all" {
    // Each allocation of add in turn fails: the cache keeps a whole entry or
    // none, and the testing allocator sees every block released.
    var index: usize = 0;
    while (index < 8) : (index += 1) {
        var failing = testing.FailingAllocator.init(testing.allocator, .{ .fail_index = index });
        const cache = MatchedPropertiesCache.create(failing.allocator()) catch continue;
        defer cache.destroy();
        var scene: Scene = undefined;
        try scene.init("font-size: 20px", "margin-left: 1em");
        defer scene.deinit();
        const style = try scene.miss(cache, scene.parent);
        defer style.destroy();
        const hit = cache.find(scene.lookup(scene.parent));
        try testing.expect((hit != null) == (cache.entries == 1));
    }
}
