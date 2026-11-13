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
//!   cache). A block of the element's own - its style attribute's, its
//!   presentational hints' (Source.per_element) - is compared by CONTENT
//!   with the entry's snapshot of the one it was made with
//!   (DeclarationBlock.interchangeable; Blink CorrespondsTo compares sets
//!   with CSSPropertyValueSet::Equals): its owner rewrites it in place and
//!   its address passes to the next element (lane style1 b5);
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
//! A miss runs the cascade; `add` then shares every group and custom
//! property record the new style holds alone whose values equal an entry's
//! of the same key (ComputedStyle.adoptEqualGroups and adoptEqualCustom,
//! lanes style1 b1 and b3) and keeps the style while the key has room. So
//! equal elements hold the same objects, as a hit's would.
//!
//! The key (`keyOf`) is only where to look: each matched block - a rule's by
//! address, an element's own by its content hash (DeclarationBlock.
//! contentHash; Blink's key mixes CSSPropertyValueSet::GetHash) - with its
//! Source, the pseudo-element, and the parent's custom property record and
//! inherited groups by address. A collision or a reused address costs a
//! compare, never a value.
//!
//! Holds and the steps that end them (lesson architecture-a-browsers-strong-
//! hold-comes-with-the-step-that-ends-it). Each entry holds a
//! ComputedStyle.clone of its style - one reference on each of its groups and
//! records - and, when it can serve a hit, a clone of its parent's style (so a
//! group address it compares cannot be freed and reused), a copy of its
//! matched list and a snapshot of each own block in it (each declaration's
//! value retained: the owner's later writes change nothing the entry
//! holds). Released, entry and all:
//! 1. every entry when the engine's generation moves: Blink's
//!    StyleResolver::InvalidateMatchedPropertiesCache and
//!    ClearViewportDependent, WebKit's invalidate and
//!    clearEntriesAffectedByViewportUnits;
//! 2. the least recently used beyond `limit` entries, down to `prune_target`
//!    (Blink CleanMatchedPropertiesCache: kCacheLimit 500, kPruneCacheTarget
//!    300);
//! 3. a full key takes no more entries (WebKit maxEntriesPerHash = 4);
//! 4. everything, with the Document's style engine (StyleEngine.deinit).
//! The entries hold values, never a node, a realm or a live declaration block.
//!
//! Admission (lane style1 b5; design 3.6 item 9). A rule's block is one
//! object for every element it matches; an own block's content may be held
//! by one element only (a style attribute that positions one row). Kept, such
//! a style costs an entry and its share of a prune, and serves no hit. Every
//! resolution is kept as it comes - as both browsers keep theirs - until a
//! prune shows that the page's own blocks do not repeat: with at least
//! `own_evidence` own-block entries in the cache, fewer than one in
//! `own_served_share` having answered a lookup (`weigh`). From that prune
//! to the next, a resolution with an own block whose content key has no
//! entry gets one on that key's second sighting (`admits`: the
//! cache-on-second-hit rule of a bounded cache; TinyLFU's doorkeeper). The
//! evidence is what the entries did, not how many there are: a rule tied to
//! the entry count either applied to a page whose cache lives between the
//! prune target and the limit (the AG Grid page: 7,987 of 1,188,349 hits
//! lost) or gave the places each prune freed to the next unique blocks.
//! Neither browser has the rule: Blink declines only an inline set modified
//! after it was hashed (MatchResult::AddMatchedProperties). It decides which
//! entries exist, never what a hit holds.
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
    /// For a resolution that matched a block of the element's own: its key
    /// without that block's content (`shapeOf`), where `add` also adopts
    /// and keeps an adoption-only entry, so elements whose own blocks
    /// differ still share equal groups and records (b3's convergence) and
    /// their children still find one key. Set, it also marks the resolution
    /// as one with an own block for admission (`admits`).
    shape: ?u64 = null,
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
    /// Full correspondences `find` ran (`corresponds`), and values `add`'s
    /// adoption compared (counters for tests and measurements).
    correspondences: u32 = 0,
    adoption_compares: u32 = 0,
    /// Where each group last compared unequal in an adoption scan
    /// (ComputedStyle.DifferenceHints).
    difference_hints: css.computed_style.DifferenceHints = @splat(0),
    /// The last prune found own-block entries serving no hit (`weigh`): an
    /// own block's content is kept from its second sighting (`admits`).
    second_sighting: bool = false,
    /// The content keys of own-block resolutions that were given no entry
    /// (`admits`), one tag per slot; held only while `second_sighting`.
    seen: ?*[seen_slots]u32 = null,

    pub const per_key = 4;
    pub const limit = 500;
    pub const prune_target = 300;
    /// Sightings remembered: about the cache's own size, so a content that
    /// comes again while an entry of it would still be held is recognised.
    pub const seen_slots = 256;
    /// Own-block entries a prune must find before it concludes anything
    /// about them, and the share of them that must have answered a lookup
    /// (one in this many) for first sightings to stay kept.
    pub const own_evidence = limit / 4;
    pub const own_served_share = 8;

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
        /// The matched list, copied; an own block's entry points into `own`.
        matched: []Matched,
        /// A snapshot of each own block of the matched list, in order
        /// (DeclarationBlock.snapshot).
        own: []css.declarations.DeclarationBlock = &.{},
        /// The entry answered a lookup (what a prune weighs, `weigh`).
        served: bool = false,
        pseudo: Pseudo,
        inputs: Inputs,
        /// The cascade took a non-inherited value from the parent.
        parent_non_inherited: bool,
        /// The parent value that rejected the last lookup this entry did not
        /// stand for (null: none yet), compared before every other check:
        /// a lookup whose parent holds another value there is rejected in a
        /// few instructions instead of a full correspondence (lane style1
        /// b4: a lookup that missed a full key ran four, down to the
        /// parent's non-inherited values). The compare is one the
        /// correspondence makes, so it orders the checks and never decides
        /// one: no hit is hidden.
        rejected_at: ?css.computed_style.Place = null,
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
            for (hit.own) |*block| block.deinit();
            self.allocator.free(hit.own);
            self.allocator.free(hit.matched);
            self.allocator.destroy(hit);
        }
    }

    /// Release every entry, and the sightings kept for admission.
    pub fn clear(self: *MatchedPropertiesCache) void {
        for (self.buckets.values()) |*bucket| for (bucket.items[0..bucket.len]) |entry| self.release(entry);
        self.buckets.clearRetainingCapacity();
        self.entries = 0;
        self.keepFirstSightings();
    }

    /// Every resolution is kept as it comes (the state a cache starts in).
    fn keepFirstSightings(self: *MatchedPropertiesCache) void {
        self.second_sighting = false;
        if (self.seen) |seen| self.allocator.destroy(seen);
        self.seen = null;
    }

    /// What a prune found, before it released anything: `own` entries made
    /// for a resolution with an own block, `served` of them having answered
    /// a lookup. Enough of them with almost none serving says the page's
    /// own blocks do not repeat while an entry lasts (2,000 rows each with
    /// a position of its own): until the next prune, such a content is kept
    /// from its second sighting. Anything else - they serve, or they are
    /// too few to tell - keeps every resolution as it comes.
    fn weigh(self: *MatchedPropertiesCache, own: u32, served: u32) void {
        if (own >= own_evidence and served * own_served_share < own) {
            self.second_sighting = true;
        } else {
            self.keepFirstSightings();
        }
    }

    /// Whether a resolution with an own block, whose content key has no
    /// entry, is given one: always, unless the last prune found own-block
    /// entries serving no hit (`weigh`); then at its key's second sighting.
    /// The first leaves the key's tag in `seen` (direct-mapped by the key's
    /// low bits; the tag is its high 32 bits, never 0) and no entry, so a
    /// content one element holds costs a tag, and one that repeats costs
    /// one cascade more. A tag another key overwrote, or one that collides,
    /// delays or admits an entry and nothing else: a hit still compares
    /// content. Out of memory for the table: no entry.
    fn admits(self: *MatchedPropertiesCache, key: u64) bool {
        if (!self.second_sighting) return true;
        const seen = self.seen orelse made: {
            const table = self.allocator.create([seen_slots]u32) catch return false;
            table.* = @splat(0);
            self.seen = table;
            break :made table;
        };
        const slot = &seen[@as(usize, @truncate(key % seen_slots))];
        const tag = @as(u32, @truncate(key >> 32)) | 1;
        if (slot.* == tag) return true;
        slot.* = tag;
        return false;
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
        // No parent (the root): no entry stands for it.
        if (lookup.parent) |parent| if (self.buckets.getPtr(lookup.key)) |bucket| {
            var i = bucket.len;
            while (i > 0) {
                i -= 1;
                const entry = &bucket.items[i];
                const hit = entry.hit orelse continue;
                if (hit.rejected_at) |place| if (!hit.parent.identicalAt(parent, place)) continue;
                self.correspondences +%= 1;
                if (!corresponds(hit, lookup, parent)) continue;
                entry.last_used = self.tick();
                hit.served = true;
                self.hits +%= 1;
                return entry.holder;
            }
        };
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
        // A resolution with an own block: first adopt among the elements
        // whose own blocks have the same shape, whatever their content (the
        // path every such resolution took before lane style1 b5, when it was
        // never looked up), then key it by content below.
        if (lookup.shape) |shape| if (shape != lookup.key) {
            var by_shape = lookup;
            by_shape.key = shape;
            by_shape.shape = null;
            self.add(by_shape, null, style);
        };
        self.enter(lookup.generation);
        const cacheable = if (dependencies) |d| d.cacheable() and lookup.parent != null else false;
        const found = self.buckets.getPtr(lookup.key);
        // Admission: an own block's content that has no entry (so nothing to
        // adopt from under this key either) gets one - on its second
        // sighting when the last prune found such entries serving no hit
        // (`admits`).
        if (found == null and lookup.shape != null and !self.admits(lookup.key)) return;
        // Adoption, the most recent entry first (Blink's Find scans
        // backwards): every group and custom property record the cascade
        // made that holds an entry's values becomes the entry's. The scan
        // is bounded by what is left to share (lane style1 b4): a group
        // adopted from one entry is compared with no other, and one that no
        // entry holds equal is compared first at the value where its group
        // last differed - one value per entry when elements differ where
        // they differed before (a sibling-index() width, an inline margin).
        var scan = style.adoption();
        var custom_alone = style.customHeldAlone();
        if (found) |bucket| {
            var i = bucket.len;
            while (i > 0 and (scan.pending.mask != 0 or custom_alone)) {
                i -= 1;
                const entry = &bucket.items[i];
                var adopted = style.adoptEqualGroupsIn(entry.holder, &scan, &self.difference_hints);
                if (custom_alone) {
                    adopted += style.adoptEqualCustom(entry.holder);
                    custom_alone = style.customHeldAlone();
                }
                if (adopted != 0) entry.last_used = self.tick();
            }
            self.adoption_compares +%= scan.compared;
        }
        // Nothing of its own left to share and no hit to serve: not kept.
        if (!cacheable and scan.pending.mask == 0 and !custom_alone) return;
        const bucket = found orelse made: {
            const gop = self.buckets.getOrPut(self.allocator, lookup.key) catch return;
            gop.value_ptr.* = .{};
            break :made gop.value_ptr;
        };
        // A full key keeps the entries it has (WebKit's
        // MatchedDeclarationsCache::add appends only below
        // maxEntriesPerHash). The key carries the parent's record and
        // inherited groups, so a key fills only with four parents that share
        // those and differ in what explicit inheritance or the adjustments
        // read (no grid page key filled: census b3); replacing the least
        // recently used there cost every such miss a clone and a release
        // (+1,657 instructions per resolution on the all-miss full-key bench)
        // and bought no hit on any measured page.
        if (bucket.len == per_key) return;
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
        var own_count: usize = 0;
        for (lookup.matched) |m| own_count += @intFromBool(m.source.per_element);
        const own = try self.allocator.alloc(css.declarations.DeclarationBlock, own_count);
        errdefer self.allocator.free(own);
        var made: usize = 0;
        errdefer for (own[0..made]) |*block| block.deinit();
        for (matched) |*m| if (m.source.per_element) {
            own[made] = try m.block.snapshot(self.allocator);
            m.block = &own[made];
            made += 1;
        };
        hit.* = .{
            .parent = try lookup.parent.?.clone(self.allocator),
            .own = own,
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
        var own: u32 = 0;
        var served: u32 = 0;
        for (self.buckets.values()) |*bucket| for (bucket.items[0..bucket.len]) |entry| {
            stamps.append(self.allocator, entry.last_used) catch {
                // No room to rank them: release everything instead.
                self.clear();
                return;
            };
            if (entry.hit) |hit| if (hit.own.len != 0) {
                own += 1;
                served += @intFromBool(hit.served);
            };
        };
        self.weigh(own, served);
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

fn corresponds(hit: *MatchedPropertiesCache.Correspondence, lookup: Lookup, parent: *const ComputedStyle) bool {
    if (hit.pseudo != lookup.pseudo or !hit.inputs.eql(lookup.inputs)) return false;
    if (hit.matched.len != lookup.matched.len) return false;
    for (hit.matched, lookup.matched) |a, b| {
        if (!std.meta.eql(a.source, b.source)) return false;
        // An element's own block: by content, against the entry's snapshot.
        if (a.source.per_element) {
            if (!a.block.interchangeable(b.block)) return false;
        } else if (a.block != b.block) return false;
    }
    return parentCorresponds(hit, parent);
}

/// Where justify-items lives in a style.
const justify_items: css.computed_style.Place = blk: {
    const location = css.computed_style.groups.location[@backingInt(Longhand.justify_items)];
    break :blk .{ .group = location.group, .index = location.index };
};

/// Whether a style computed under the entry's parent is the one the cascade
/// computes under `parent`: what the cascade reads of a parent. A parent
/// value that differs is kept as the entry's `rejected_at`.
fn parentCorresponds(hit: *MatchedPropertiesCache.Correspondence, parent: *const ComputedStyle) bool {
    const cached = hit.parent;
    // CSS Variables 1: var() and inherited registered properties read the
    // parent's record (WebKit find: the same inheritedCustomProperties).
    if (cached.custom != parent.custom) return false;
    // adjust() and the base-appearance bit (Blink IsCacheCompatible, WebKit
    // inBaseAppearanceSubtree).
    if (cached.in_base_appearance != parent.in_base_appearance or cached.box_context != parent.box_context) return false;
    if (css.cascade.blockifiesChildren(cached) != css.cascade.blockifiesChildren(parent)) return false;
    // Align 3 7.1: every element's justify-items `legacy` reads its parent's
    // (Blink IsCacheCompatible: the parent's JustifyItems).
    if (!cached.identicalAt(parent, justify_items)) return rejectedAt(hit, justify_items);
    // Blink InheritedEqual, then - under explicit inheritance - the
    // non-inherited values too (HasExplicitInheritance + NonInheritedEqual).
    if (cached.firstUnidentical(parent, .inherited)) |place| return rejectedAt(hit, place);
    if (hit.parent_non_inherited) {
        if (cached.custom_own != parent.custom_own) return false;
        if (cached.firstUnidentical(parent, .non_inherited)) |place| return rejectedAt(hit, place);
    }
    return true;
}

fn rejectedAt(hit: *MatchedPropertiesCache.Correspondence, place: css.computed_style.Place) bool {
    hit.rejected_at = place;
    return false;
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
    // An observation independent of the predicate adoption shares on
    // (computed_style.interchangeable): what getComputedStyle serializes and
    // what the fetch layer requests (lane style1 b4).
    if (try style.firstObservableDifference(fresh, ctx.allocator)) |l| return .{ .longhand = l };
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
        // As getPropertyValue reads it - the text - and the taint a later
        // substitution reads, field by field (not Text.eql, which record
        // adoption compares through).
        const a = style.customValue(name).?;
        const b = fresh.customValue(other).?;
        if (!std.mem.eql(u8, a.bytes, b.bytes) or a.taint.len != b.taint.len) return .{ .custom = name };
        for (a.taint, b.taint) |x, y| if (!std.meta.eql(x, y)) return .{ .custom = name };
    }
    return null;
}

/// The cache key of an element's matched declarations (in cascade order) for
/// `pseudo` under `parent`: each block - a rule's by address, an element's
/// own by its content hash - with its Source, and the parent's
/// custom property record and inherited groups by address (WebKit's
/// MatchedDeclarationsCache::computeHash hashes &inheritedCustomProperties;
/// Blink's key hashes the parent's inherited variables and inherited fields).
/// Equal parents hold the same objects - a hit hands an element the entry's,
/// a miss adopts an entry's equal ones (`add`) - so a key finds the entries
/// made under parents with the same inherited data. A few multiply-rotate
/// steps per block (it runs at every resolution): the key only says where to
/// look, and a collision costs a compare, never a value.
pub fn keyOf(matched: []const Matched, pseudo: ?[]const u8, parent: ?*const ComputedStyle) u64 {
    return keyFor(.content, matched, pseudo, parent);
}

/// keyOf with each element's own block reduced to its shape: a style
/// attribute's by the names it declares, a presentational hint's by address
/// (the key such resolutions had before lane style1 b5). Lookup.shape.
pub fn shapeOf(matched: []const Matched, pseudo: ?[]const u8, parent: ?*const ComputedStyle) u64 {
    return keyFor(.shape, matched, pseudo, parent);
}

fn keyFor(comptime own: enum { content, shape }, matched: []const Matched, pseudo: ?[]const u8, parent: ?*const ComputedStyle) u64 {
    var h: u64 = 0x5354594c4531;
    if (pseudo) |p| h = mix(h, std.hash.Wyhash.hash(0, p));
    for (matched) |*m| {
        const s = &m.source;
        switch (own) {
            .content => h = mix(h, if (s.per_element) m.block.contentHash() else @intFromPtr(m.block)),
            .shape => if (s.element_attached) {
                for (m.block.entries.items) |*entry| h = mix(h, std.hash.Wyhash.hash(1, entry.name()));
            } else {
                h = mix(h, @intFromPtr(m.block));
            },
        }
        h = mix(h, (@as(u64, @backingInt(s.origin)) << 56) | (@as(u64, s.layer) << 40) | (@as(u64, s.tree_depth) << 24) |
            (@as(u64, @intFromBool(s.per_element)) << 2) | (@as(u64, @intFromBool(s.element_attached)) << 1) | @intFromBool(s.tree_count_allowed));
        h = mix(h, (@as(u64, s.order) << 32) ^ (@as(u64, s.specificity.a) << 20) ^ (@as(u64, s.specificity.b) << 10) ^ s.specificity.c);
        h = mix(h, s.tree_scope.serial);
    }
    const p = parent orelse return h;
    h = mix(h, @intFromPtr(p.custom));
    inline for (0..css.computed_style.groups.count) |g| if (comptime css.computed_style.groups.inherited[g]) {
        h = mix(h, @intFromPtr(p.slots[g]));
    };
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

test "a full key takes no style kept only for adoption (WebKit's maxEntriesPerHash)" {
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
        return .{ .key = keyOf(&self.matched, null, parent), .generation = 1, .matched = &self.matched, .parent = parent };
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
    // A cousin: another parent object with the same inherited values. Held
    // in groups of its own it has another key (the key carries the parent's
    // groups by address: equal parents converge on one group by adoption
    // and hits, lane style1 b3) ...
    var cousin = try rootStyle("font-size: 20px; color: blue");
    defer cousin.block.deinit();
    defer cousin.style.destroy();
    try testing.expect(cache.find(scene.lookup(cousin.style)) == null);
    // ... but under the same key it corresponds: the same parent to the cache.
    var same_key = scene.lookup(cousin.style);
    same_key.key = scene.lookup(scene.parent).key;
    try testing.expect(cache.find(same_key) != null);
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

test "a new generation forgets every entry; parents with other inherited groups have keys of their own" {
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
    // Parents with font sizes 1..7px: each a miss, each its own key (the
    // parent's inherited groups are in the key; an entry's parent copy holds
    // its group, so no later parent reuses the address).
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
    try testing.expectEqual(@as(u32, 7), cache.entries);
    try testing.expectEqual(@as(usize, 7), cache.buckets.count());
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

// ---------------------------------------------------------------------------
// Lane style1 b3: the parent in the key, a full key's replacement, and
// adoption of equal records.
// ---------------------------------------------------------------------------

test "the key carries the parent's custom property record and inherited groups by address" {
    var scene: Scene = undefined;
    try scene.init("font-size: 20px; --w: 3px", "margin-left: 1em");
    defer scene.deinit();
    // A clone holds the same objects: the same key.
    const twin = try scene.parent.clone(testing.allocator);
    defer twin.destroy();
    try testing.expectEqual(keyOf(&scene.matched, null, scene.parent), keyOf(&scene.matched, null, twin));
    // Another font group, another record: other keys.
    var other = try rootStyle("font-size: 21px; --w: 3px");
    defer other.block.deinit();
    defer other.style.destroy();
    try testing.expect(keyOf(&scene.matched, null, scene.parent) != keyOf(&scene.matched, null, other.style));
    var record = try rootStyle("font-size: 20px; --w: 4px");
    defer record.block.deinit();
    defer record.style.destroy();
    // The same groups with another record: another key.
    const swapped = try scene.parent.clone(testing.allocator);
    defer swapped.destroy();
    swapped.custom.?.release();
    record.style.custom.?.retain();
    swapped.custom = record.style.custom;
    try testing.expect(keyOf(&scene.matched, null, scene.parent) != keyOf(&scene.matched, null, swapped));
}

test "a full key keeps its entries, for styles that can serve hits too: parents that share the key differ only in what explicit inheritance reads" {
    const cache = try MatchedPropertiesCache.create(testing.allocator);
    defer cache.destroy();
    // Parents that differ only in a non-inherited value, read by explicit
    // inheritance: one key, every lookup a miss on the others' entries.
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "margin-left: inherit");
    defer block.deinit();
    const matched = [_]Matched{.{ .block = &block, .source = .{ .origin = .author, .order = 3 } }};
    var parents: [MatchedPropertiesCache.per_key + 1]@TypeOf(try rootStyle("")) = undefined;
    for (&parents, 0..) |*p, k| {
        var buffer: [32]u8 = undefined;
        p.* = try rootStyle(try std.fmt.bufPrint(&buffer, "margin-left: {d}px", .{k + 1}));
    }
    defer for (&parents) |*p| {
        p.style.destroy();
        p.block.deinit();
    };
    const key = keyOf(&matched, null, parents[0].style);
    for (parents) |p| try testing.expectEqual(key, keyOf(&matched, null, p.style));
    for (parents) |p| {
        const lookup: Lookup = .{ .key = key, .generation = 1, .matched = &matched, .parent = p.style };
        try testing.expect(cache.find(lookup) == null);
        var deps: css.cascade.Dependencies = .{};
        const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = p.style, .dependencies = &deps }, &matched);
        defer style.destroy();
        try testing.expect(deps.parent_non_inherited);
        cache.add(lookup, deps, style);
    }
    // Four entries, the first four parents': the fifth is not kept.
    try testing.expectEqual(@as(u32, MatchedPropertiesCache.per_key), cache.entries);
    const last: Lookup = .{ .key = key, .generation = 1, .matched = &matched, .parent = parents[MatchedPropertiesCache.per_key].style };
    try testing.expect(cache.find(last) == null);
    const first: Lookup = .{ .key = key, .generation = 1, .matched = &matched, .parent = parents[0].style };
    const held = cache.find(first) orelse return error.ExpectedHit;
    try testing.expectEqual(@as(f64, 1), held.get(.margin_left).length.value);
}

test "a miss holds the record an entry made when its values are equal, and the groups whose values are equal" {
    const cache = try MatchedPropertiesCache.create(testing.allocator);
    defer cache.destroy();
    var scene: Scene = undefined;
    try scene.init("--ff: Georgia, serif", "--a: 3px; --b: calc(var(--a) * 2); font-family: var(--ff); margin-left: 2px");
    defer scene.deinit();
    const first = try scene.miss(cache, scene.parent);
    defer first.destroy();
    // An element that is not looked up (a block of its own, say) runs the
    // cascade again: its new record and font group become the entry's.
    const second = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = scene.parent }, &scene.matched);
    defer second.destroy();
    try testing.expect(second.custom != first.custom);
    cache.add(scene.lookup(scene.parent), null, second);
    try testing.expect(second.custom == first.custom);
    const font = css.computed_style.groups.location[@backingInt(Longhand.font_family)].group;
    try testing.expect(second.slots[font] == first.slots[font]);
    try testing.expect(second.firstDifference(first) == null);
}

// ---------------------------------------------------------------------------
// Lane style1 b4: the miss path's two costs that bought nothing. A lookup
// that missed a full key ran every entry's full correspondence, down to the
// parent's non-inherited values, every time; an adoption scan compared a
// group no entry holds equal with every entry's from its first value.
// ---------------------------------------------------------------------------

test "a lookup that misses a full key runs each entry's full correspondence once, then compares the parent value that rejected it first" {
    const cache = try MatchedPropertiesCache.create(testing.allocator);
    defer cache.destroy();
    // Parents that differ only in margin-left (non-inherited) and a child
    // that inherits it explicitly: one key for every parent.
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "margin-left: inherit");
    defer block.deinit();
    const matched = [_]Matched{.{ .block = &block, .source = .{ .origin = .author, .order = 3 } }};
    var parents: [24]@TypeOf(try rootStyle("")) = undefined;
    for (&parents, 0..) |*p, k| {
        var buffer: [32]u8 = undefined;
        p.* = try rootStyle(try std.fmt.bufPrint(&buffer, "margin-left: {d}px", .{k + 1}));
    }
    defer for (&parents) |*p| {
        p.style.destroy();
        p.block.deinit();
    };
    const key = keyOf(&matched, null, parents[0].style);
    // The first per_key parents' children become the key's entries; every
    // parent after them only looks it up, and misses.
    for (parents, 0..) |p, k| {
        try testing.expectEqual(key, keyOf(&matched, null, p.style));
        const lookup: Lookup = .{ .key = key, .generation = 1, .matched = &matched, .parent = p.style };
        try testing.expect(cache.find(lookup) == null);
        if (k >= MatchedPropertiesCache.per_key) continue;
        var deps: css.cascade.Dependencies = .{};
        const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = p.style, .dependencies = &deps }, &matched);
        defer style.destroy();
        cache.add(lookup, deps, style);
    }
    try testing.expectEqual(@as(u32, MatchedPropertiesCache.per_key), cache.entries);
    // Each entry ran its full correspondence for the first parent it did not
    // stand for, which named the value that told them apart; every later
    // parent with another value there is rejected on that value alone.
    try testing.expectEqual(@as(u32, MatchedPropertiesCache.per_key), cache.correspondences);
    // A parent with an entry's value there still hits, after one full
    // correspondence: comparing that value first hides no hit.
    var twin = try rootStyle("margin-left: 2px");
    defer twin.block.deinit();
    defer twin.style.destroy();
    const counted = cache.correspondences;
    const held = cache.find(.{ .key = key, .generation = 1, .matched = &matched, .parent = twin.style }) orelse return error.ExpectedHit;
    try testing.expectEqual(@as(f64, 2), held.get(.margin_left).length.value);
    try testing.expectEqual(counted + 1, cache.correspondences);
}

test "adoption compares a group no entry holds equal once per entry, at the value where it differed before" {
    const allocator = testing.allocator;
    const cache = try MatchedPropertiesCache.create(allocator);
    defer cache.destroy();
    const root = try styleOf(allocator, null, "");
    defer root.destroy();
    // Styles of one key that differ only in padding-left, the eighth value
    // of its group: the first per_key become the key's entries, each holding
    // a group of its own there and one box group between them.
    var styles: [MatchedPropertiesCache.per_key + 1]*ComputedStyle = undefined;
    for (&styles, 0..) |*s, k| {
        var buffer: [64]u8 = undefined;
        s.* = try styleOf(allocator, root, try std.fmt.bufPrint(&buffer, "display: flex; padding-left: {d}px", .{k + 1}));
    }
    defer for (styles) |s| s.destroy();
    for (styles[0..MatchedPropertiesCache.per_key]) |s| cache.add(.{ .key = 1, .generation = 1 }, null, s);
    try testing.expectEqual(@as(u32, MatchedPropertiesCache.per_key), cache.entries);
    const box = css.computed_style.groups.location[@backingInt(Longhand.display)].group;
    const surround = css.computed_style.groups.location[@backingInt(Longhand.padding_left)].group;
    try testing.expect(styles[1].slots[box] == styles[0].slots[box]);
    // The next style takes the box group from the most recent entry - every
    // value compared - and compares its own surround group with each entry's
    // once, at padding-left alone.
    const before = cache.adoption_compares;
    cache.add(.{ .key = 1, .generation = 1 }, null, styles[MatchedPropertiesCache.per_key]);
    try testing.expect(styles[MatchedPropertiesCache.per_key].slots[box] == styles[0].slots[box]);
    try testing.expectEqual(@as(u32, css.computed_style.groups.lengths[box] + MatchedPropertiesCache.per_key), cache.adoption_compares - before);
    // A style equal to an entry still shares that entry's group: the value
    // compared first orders the compares, it decides none.
    const again = try styleOf(allocator, root, "display: flex; padding-left: 2px");
    defer again.destroy();
    cache.add(.{ .key = 1, .generation = 1 }, null, again);
    try testing.expect(again.slots[surround] == styles[1].slots[surround]);
    try testing.expectEqual(@as(usize, 0), again.groupsHeldAlone());
}

// ---------------------------------------------------------------------------
// Lane style1 b5: an element's own blocks, keyed and compared by content.
// ---------------------------------------------------------------------------

const own_source: css.cascade.Source = .{ .origin = .author, .element_attached = true, .per_element = true };

/// A lookup of one own block under `parent`, with `key` (null: its keyOf).
fn ownLookup(matched: *const [1]Matched, parent: *const ComputedStyle, key: ?u64) Lookup {
    return .{ .key = key orelse keyOf(matched, null, parent), .generation = 1, .matched = matched, .parent = parent };
}

fn ownMiss(cache: *MatchedPropertiesCache, matched: *const [1]Matched, parent: *const ComputedStyle, key: ?u64) !*ComputedStyle {
    var deps: css.cascade.Dependencies = .{};
    const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = parent, .dependencies = &deps }, matched);
    cache.add(ownLookup(matched, parent, key), deps, style);
    return style;
}

test "an own block corresponds by content: an equal block another element holds hits, and the owner's rewrite in place changes nothing the entry holds" {
    const cache = try MatchedPropertiesCache.create(testing.allocator);
    defer cache.destroy();
    var root = try rootStyle("font-size: 20px");
    defer root.block.deinit();
    defer root.style.destroy();
    var a = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "margin-left: 3px");
    defer a.deinit();
    var b = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "margin-left:3px");
    defer b.deinit();
    const ma = [1]Matched{.{ .block = &a, .source = own_source }};
    const mb = [1]Matched{.{ .block = &b, .source = own_source }};
    const first = try ownMiss(cache, &ma, root.style, null);
    defer first.destroy();
    try testing.expectEqual(keyOf(&ma, null, root.style), keyOf(&mb, null, root.style));
    const held = cache.find(ownLookup(&mb, root.style, null)) orelse return error.ExpectedHit;
    try testing.expect(held.firstDifference(first) == null);
    // a's block rewritten in place (CSSOM setProperty): same address, new
    // content, the hash reset.
    const old_key = keyOf(&ma, null, root.style);
    try testing.expect(try a.setProperty(.{ .allocator = testing.allocator }, "margin-left", "9px", ""));
    try testing.expect(keyOf(&ma, null, root.style) != old_key);
    // b still finds the entry a made, with a's old content ...
    try testing.expect(cache.find(ownLookup(&mb, root.style, null)) != null);
    // ... and a, looked up where its old content was, corresponds no more.
    try testing.expect(cache.find(ownLookup(&ma, root.style, old_key)) == null);
    try testing.expectEqual(@as(u32, 2), cache.hits);
}

test "under one key, own blocks that differ in importance, value, a url()'s base or a pending value's base do not correspond" {
    const Resolver = struct {
        prefix: []const u8,
        fn resolve(context: *const anyopaque, allocator: Allocator, raw: []const u8) ?[]u8 {
            const self: *const @This() = @ptrCast(@alignCast(context));
            return std.mem.concat(allocator, u8, &.{ self.prefix, raw }) catch null;
        }
    };
    const Case = struct { a: []const u8, b: []const u8, base_b: []const u8 = "https://one.test/" };
    const cases = [_]Case{
        .{ .a = "margin-left: 3px", .b = "margin-left: 3px !important" },
        .{ .a = "margin-left: 3px", .b = "margin-left: 4px" },
        .{ .a = "--a: 1px", .b = "--a: 2px" },
        .{ .a = "background-image: url(./a.png)", .b = "background-image: url(./a.png)", .base_b = "https://two.test/" },
        .{ .a = "--u: url(./a.png); background-image: var(--u)", .b = "--u: url(./a.png); background-image: var(--u)", .base_b = "https://two.test/" },
    };
    var root = try rootStyle("font-size: 20px");
    defer root.block.deinit();
    defer root.style.destroy();
    for (cases) |case| {
        const cache = try MatchedPropertiesCache.create(testing.allocator);
        defer cache.destroy();
        var blocks: [2]css.declarations.DeclarationBlock = undefined;
        for (&blocks, [_][]const u8{ case.a, case.b }, [_][]const u8{ "https://one.test/", case.base_b }) |*block, text, base| {
            const resolver: Resolver = .{ .prefix = base };
            const source = try css.style_values.ResourceSource.create(testing.allocator, .{ .base_url = base });
            defer source.unref();
            block.* = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator, .resource_source = source, .url_resolver = .{ .context = &resolver, .resolve = Resolver.resolve } }, text);
        }
        defer for (&blocks) |*block| block.deinit();
        const ma = [1]Matched{.{ .block = &blocks[0], .source = own_source }};
        const mb = [1]Matched{.{ .block = &blocks[1], .source = own_source }};
        const first = try ownMiss(cache, &ma, root.style, 7);
        defer first.destroy();
        // The same block content, the same key: a hit (the entry is there).
        try testing.expect(cache.find(ownLookup(&ma, root.style, 7)) != null);
        if (cache.find(ownLookup(&mb, root.style, 7)) != null) {
            std.debug.print("\n'{s}' under {s} corresponded to '{s}'\n", .{ case.b, case.base_b, case.a });
            return error.TestUnexpectedResult;
        }
    }
}

/// ownLookup as the engine makes it for a resolution with an own block: the
/// content key and the shape key (Lookup.shape).
fn ownShaped(matched: *const [1]Matched, parent: *const ComputedStyle) Lookup {
    var lookup = ownLookup(matched, parent, null);
    lookup.shape = shapeOf(matched, null, parent);
    return lookup;
}

fn ownShapedMiss(cache: *MatchedPropertiesCache, matched: *const [1]Matched, parent: *const ComputedStyle) !*ComputedStyle {
    var deps: css.cascade.Dependencies = .{};
    const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = parent, .dependencies = &deps }, matched);
    cache.add(ownShaped(matched, parent), deps, style);
    return style;
}

/// Own blocks no other element holds (`margin-left: <from>px` and up), each
/// resolved and added, until the cache prunes; returns how many it took.
fn uniqueUntilPrune(cache: *MatchedPropertiesCache, parent: *const ComputedStyle, from: usize) !usize {
    var buffer: [64]u8 = undefined;
    var n: usize = 0;
    var last = cache.entries;
    while (n <= 2 * MatchedPropertiesCache.limit) : (n += 1) {
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, try std.fmt.bufPrint(&buffer, "margin-left: {d}px", .{from + n}));
        defer block.deinit();
        const matched = [1]Matched{.{ .block = &block, .source = own_source }};
        (try ownShapedMiss(cache, &matched, parent)).destroy();
        if (cache.entries < last) return n + 1;
        last = cache.entries;
    }
    return error.NoPrune;
}

/// Rules' styles (adoption-only, keys of their own from `from` up) until the
/// cache prunes.
fn rulesUntilPrune(cache: *MatchedPropertiesCache, parent: *const ComputedStyle, from: usize) !void {
    var buffer: [64]u8 = undefined;
    var k: usize = 0;
    var last = cache.entries;
    while (k <= 2 * MatchedPropertiesCache.limit) : (k += 1) {
        const s = try styleOf(testing.allocator, parent, try std.fmt.bufPrint(&buffer, "margin-top: {d}px", .{k + 1}));
        defer s.destroy();
        cache.add(.{ .key = from + k, .generation = 1 }, null, s);
        if (cache.entries < last) return;
        last = cache.entries;
    }
    return error.NoPrune;
}

/// Whether an own block's content, first seen now, is kept: a second block
/// with the same content finds it.
fn firstSightingKept(cache: *MatchedPropertiesCache, parent: *const ComputedStyle, text: []const u8) !bool {
    const parse = css.declarations.DeclarationBlock.parse;
    var a = try parse(.{ .allocator = testing.allocator }, text);
    defer a.deinit();
    var b = try parse(.{ .allocator = testing.allocator }, text);
    defer b.deinit();
    const ma = [1]Matched{.{ .block = &a, .source = own_source }};
    const mb = [1]Matched{.{ .block = &b, .source = own_source }};
    (try ownShapedMiss(cache, &ma, parent)).destroy();
    return cache.find(ownShaped(&mb, parent)) != null;
}

test "a prune that finds the own-block entries served no hit: from then an own block's content is kept from its second sighting" {
    const allocator = testing.allocator;
    const cache = try MatchedPropertiesCache.create(allocator);
    defer cache.destroy();
    var scene: Scene = undefined;
    try scene.init("font-size: 20px", "display: flex; color: currentcolor");
    defer scene.deinit();
    const root = scene.parent;
    var buffer: [64]u8 = undefined;
    const parse = css.declarations.DeclarationBlock.parse;

    // Before any prune an own block's content is kept at its first sighting.
    try testing.expect(try firstSightingKept(cache, root, "padding-left: 1px"));
    // Own blocks no other element holds, until the cache prunes for one:
    // the prune finds hundreds of own-block entries and one that served.
    _ = try uniqueUntilPrune(cache, root, 1);
    const after_prune = cache.entries;
    // From here such a block gets no entry (its shape key keeps its
    // adoption-only entries, as before lane style1 b5): no further prune.
    for (0..1000) |i| {
        var block = try parse(.{ .allocator = allocator }, try std.fmt.bufPrint(&buffer, "margin-left: {d}px", .{100000 + i}));
        defer block.deinit();
        const matched = [1]Matched{.{ .block = &block, .source = own_source }};
        (try ownShapedMiss(cache, &matched, root)).destroy();
    }
    try testing.expect(cache.entries <= after_prune + MatchedPropertiesCache.per_key);

    // A content that repeats: its first sighting leaves no entry, its
    // second makes one, its third is a hit.
    var blocks: [3]css.declarations.DeclarationBlock = undefined;
    for (&blocks) |*b| b.* = try parse(.{ .allocator = allocator }, "margin-left: 7777777px");
    defer for (&blocks) |*b| b.deinit();
    const m0 = [1]Matched{.{ .block = &blocks[0], .source = own_source }};
    const m1 = [1]Matched{.{ .block = &blocks[1], .source = own_source }};
    const m2 = [1]Matched{.{ .block = &blocks[2], .source = own_source }};
    const before = cache.entries;
    (try ownShapedMiss(cache, &m0, root)).destroy();
    try testing.expectEqual(before, cache.entries);
    try testing.expect(cache.find(ownShaped(&m1, root)) == null);
    (try ownShapedMiss(cache, &m1, root)).destroy();
    try testing.expectEqual(before + 1, cache.entries);
    try testing.expect(cache.find(ownShaped(&m2, root)) != null);

    // A rule's style is kept at its first sighting, as before: a rule's
    // block is one object for every element it matches.
    (try scene.miss(cache, root)).destroy();
    try testing.expect(cache.find(scene.lookup(root)) != null);
}

test "a prune that finds own-block entries serving hits, or too few of them to tell, leaves an own block's content kept at its first sighting" {
    const allocator = testing.allocator;
    var buffer: [64]u8 = undefined;
    {
        // Half the cache's limit in own-block contents, each held by two
        // elements: every entry serves a hit.
        const cache = try MatchedPropertiesCache.create(allocator);
        defer cache.destroy();
        var root = try rootStyle("font-size: 20px");
        defer root.block.deinit();
        defer root.style.destroy();
        for (0..MatchedPropertiesCache.limit / 2) |i| {
            try testing.expect(try firstSightingKept(cache, root.style, try std.fmt.bufPrint(&buffer, "margin-left: {d}px", .{i + 1})));
        }
        try rulesUntilPrune(cache, root.style, 1000);
        try testing.expect(try firstSightingKept(cache, root.style, "padding-left: 9px"));
    }
    {
        // A dozen own-block entries that served no hit among rules' styles:
        // too few to say what the page's own blocks do.
        const cache = try MatchedPropertiesCache.create(allocator);
        defer cache.destroy();
        var root = try rootStyle("font-size: 20px");
        defer root.block.deinit();
        defer root.style.destroy();
        for (0..12) |i| {
            var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, try std.fmt.bufPrint(&buffer, "margin-left: {d}px", .{i + 1}));
            defer block.deinit();
            const matched = [1]Matched{.{ .block = &block, .source = own_source }};
            (try ownShapedMiss(cache, &matched, root.style)).destroy();
        }
        try rulesUntilPrune(cache, root.style, 1000);
        try testing.expect(try firstSightingKept(cache, root.style, "padding-left: 9px"));
    }
}
