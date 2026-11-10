//! A Document's matched-properties cache: computed styles kept by the
//! declarations that matched their element, so that the next element the
//! same declarations match shares the groups of values its cascade wrote
//! instead of holding copies of its own. Blink's MatchedPropertiesCache
//! (core/css/resolver/matched_properties_cache.{h,cc}; chromium
//! 3a7520d2d79d) and WebKit's Style::MatchedDeclarationsCache
//! (Source/WebCore/style/MatchedDeclarationsCache.{h,cpp}; WebKit
//! b82767f9fd20): "it allows us to reuse subgroups of ComputedStyle so that
//! we use less RAM" (Blink StyleResolver::ApplyBaseStyleNoCache's comment).
//!
//! What a hit does. The cascade still runs for every element; its result
//! then adopts each group whose values are identical to a cached style's
//! (ComputedStyle.adoptIdenticalGroups). Blink and WebKit skip the cascade
//! on a hit instead, under conditions on the parent's inherited values and
//! on what the declarations read (Blink MatchedPropertiesCache::Find and
//! IsStyleCacheable: attr(), zoom, container units, anchor and sibling
//! functions, random(), functional media; WebKit isCacheable and
//! isUsableAfterHighPriorityProperties). Comparing the values the cascade
//! produced needs none of those conditions: a shared group holds the same
//! tags, addresses and bits the element computed, so no computed value can
//! differ from an uncached resolution. Skipping the cascade is a later step
//! (tmp/redesign/style-memory-design.md).
//!
//! The key: each matched block with its cascade Source, and the pseudo-
//! element. A rule's block counts by identity; an element's own style
//! attribute block - one per element - by the property names it declares,
//! so that elements with equal inline styles meet (Blink hashes a property
//! set's contents, CSSPropertyValueSet::GetHash). A key is only where to
//! look: a collision or a reused block address costs a compare, never a
//! value.
//!
//! Holds and the steps that end them (lesson architecture-a-browsers-strong-
//! hold-comes-with-the-step-that-ends-it). Each entry holds a
//! ComputedStyle.clone of the style it was made from - one reference on each
//! of its groups - as Blink's and WebKit's entries hold a clone. Released:
//! 1. every entry when the engine's generation moves (sheets, their
//!    contents, the media environment): Blink's
//!    StyleResolver::InvalidateMatchedPropertiesCache and
//!    ClearViewportDependent, WebKit's invalidate and
//!    clearEntriesAffectedByViewportUnits;
//! 2. the least recently used beyond `limit` entries, down to `prune_target`
//!    (Blink CleanMatchedPropertiesCache: kCacheLimit 500, kPruneCacheTarget
//!    300);
//! 3. a key's least recently used entry when it has `per_key` (WebKit
//!    maxEntriesPerHash = 4);
//! 4. everything, with the Document's style engine (StyleEngine.deinit).
//! The entries hold values, never a node or a realm.
//!
//! One per Document's StyleEngine, used on its Browser's window-agent thread
//! only, as the groups it holds are (css/computed_style.zig, "Storage").

const std = @import("std");
const Allocator = std.mem.Allocator;
const css = @import("css");

const ComputedStyle = css.computed_style.ComputedStyle;
const Matched = css.cascade.Matched;

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

    pub const per_key = 4;
    pub const limit = 500;
    pub const prune_target = 300;

    const Entry = struct {
        holder: *ComputedStyle,
        last_used: u32,
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

    /// Release every entry.
    pub fn clear(self: *MatchedPropertiesCache) void {
        for (self.buckets.values()) |*bucket| for (bucket.items[0..bucket.len]) |entry| entry.holder.destroy();
        self.buckets.clearRetainingCapacity();
        self.entries = 0;
    }

    fn tick(self: *MatchedPropertiesCache) u32 {
        self.clock +%= 1;
        return self.clock;
    }

    /// `style` was just computed for an element whose matched declarations
    /// hash to `key`, under engine generation `generation`: share each of its
    /// groups a cached style of the same key holds with identical values, and
    /// keep it for the next element when a group of its own is left. Never
    /// fails: running out of memory only leaves `style` holding its own
    /// groups, as before.
    pub fn share(self: *MatchedPropertiesCache, key: u64, generation: u64, style: *ComputedStyle) void {
        if (generation != self.generation) {
            self.clear();
            self.generation = generation;
        }
        if (style.groupsHeldAlone() == 0) return;
        const gop = self.buckets.getOrPut(self.allocator, key) catch return;
        if (!gop.found_existing) gop.value_ptr.* = .{};
        const bucket = gop.value_ptr;
        // The most recent first (Blink's Find scans backwards).
        var i = bucket.len;
        while (i > 0) {
            i -= 1;
            const entry = &bucket.items[i];
            if (style.adoptIdenticalGroups(entry.holder) != 0) entry.last_used = self.tick();
            if (style.groupsHeldAlone() == 0) return;
        }
        // A group no entry holds: keep this style for the next element.
        const holder = style.clone(self.allocator) catch {
            if (bucket.len == 0) _ = self.buckets.swapRemove(key);
            return;
        };
        const made: Entry = .{ .holder = holder, .last_used = self.tick() };
        if (bucket.len < per_key) {
            bucket.items[bucket.len] = made;
            bucket.len += 1;
            self.entries += 1;
        } else {
            var oldest: usize = 0;
            for (bucket.items[1..], 1..) |entry, k| {
                if (entry.last_used < bucket.items[oldest].last_used) oldest = k;
            }
            bucket.items[oldest].holder.destroy();
            bucket.items[oldest] = made;
        }
        if (self.entries > limit) self.prune();
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
                    entry.holder.destroy();
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

/// The cache key of an element's matched declarations (in cascade order) for
/// `pseudo`: each block - a rule's by address, a style attribute's by the
/// names it declares - with its Source.
pub fn keyOf(matched: []const Matched, pseudo: ?[]const u8) u64 {
    var h = std.hash.Wyhash.init(0x5354594c4531);
    if (pseudo) |p| h.update(p);
    h.update(&.{0});
    for (matched) |*m| {
        if (m.source.element_attached) {
            for (m.block.entries.items) |*entry| {
                h.update(entry.name());
                h.update(&.{0});
            }
        } else {
            const address = @intFromPtr(m.block);
            h.update(std.mem.asBytes(&address));
        }
        std.hash.autoHashStrat(&h, m.source, .Shallow);
    }
    return h.final();
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
    cache.share(7, 1, a);
    try testing.expectEqual(@as(u32, 1), cache.entries);
    const b = try styleOf(allocator, root, text);
    defer b.destroy();
    cache.share(7, 1, b);
    try testing.expectEqual(@as(usize, 0), b.groupsHeldAlone());
    try testing.expectEqual(@as(u32, 1), cache.entries);
    const g = css.computed_style.groups.location[@backingInt(css.properties.Longhand.margin_left)].group;
    try testing.expect(b.slots[g] == a.slots[g]);
    // Another generation: the entry made under the first is released before
    // anything is looked up, so c keeps its own groups and becomes the new
    // entry (its holder the only other reference on them).
    const c = try styleOf(allocator, root, text);
    defer c.destroy();
    cache.share(7, 2, c);
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
        cache.share(1, 1, s);
    }
    try testing.expectEqual(@as(u32, MatchedPropertiesCache.per_key), cache.entries);
    for (0..MatchedPropertiesCache.limit + 1) |k| {
        const s = try styleOf(allocator, root, try std.fmt.bufPrint(&buffer, "margin-top: {d}px", .{k + 1}));
        defer s.destroy();
        cache.share(100 + k, 1, s);
    }
    try testing.expect(cache.entries <= MatchedPropertiesCache.limit);
    try testing.expect(cache.entries >= MatchedPropertiesCache.prune_target);
}

const per_key_test_styles = MatchedPropertiesCache.per_key + 3;

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
    cache.share(3, 1, a);
    try testing.expectEqual(alone, a.groupsHeldAlone());
    try testing.expectEqual(@as(u32, 0), cache.entries);
}
