//! Attribute names as u32 ids (lane nd2 batch 2, A2; tmp/redesign/
//! node-memory-plan-v2.md I7, I8; nodedata-design.md A2).
//!
//! An attribute's entry in its element's list (dom.element_data) is 8 bytes:
//! a `NameId` and a value id (dom.attribute_values). A name id is either
//!
//! - STATIC: the index of one of the comptime records below - the HTML, SVG,
//!   MathML, ARIA and event handler names in no namespace, and the parser's
//!   "adjust foreign attributes" names in theirs. It decodes with no Browser
//!   (an array index into .rodata) and is never counted. Blink's and WebKit's
//!   static QualifiedNames for these names, made once and shared by every
//!   element (Blink core/html_names.json5 -> html_names.h, WebKit
//!   html/HTMLAttributeNames.in);
//! - DYNAMIC: a COUNTED reference to its Browser's interned record of a name
//!   no static table has (data-*, custom, prefixed or namespaced names) -
//!   one record per distinct name, freed when the last attribute naming it
//!   goes, in a weak table on the Browser's window agent's thread: the rules
//!   of dom.element_name's records (lane nd2 batch 1-fix; lesson
//!   architecture-an-interned-record-of-page-chosen-names-dies-with-its-last-holder),
//!   which are Blink's QualifiedNameCache (qualified_name.cc: the cache is a
//!   HashSet the record leaves in ~QualifiedNameImpl) and Gecko's atoms. An
//!   id is the record's slot in a dense array; a freed slot is reused (a
//!   free list), and a Debug build stamps the slot's generation into the id
//!   so a stale id panics instead of naming the slot's next record.
//!
//! An element's attribute list and the accessors that read it take
//! `*const ElementData`, which has no route to its Browser (review C2,
//! appendix-nd2.md F5): ElementData lives in Element's state, which keeps no
//! pointer back to its instance, and the state arena does not name its
//! Browser from an address. A dynamic id is decoded where the ELEMENT is
//! known: `dom.element_data.of(element)` finds the tables through
//! `runtime.BrowserScope.ofInstance(element)` (the slab header the element's
//! Instance sits in; lesson
//! architecture-find-an-objects-browser-from-its-address-not-its-context)
//! and hands the reader a View that carries them.
//!
//! Static names are found by a comptime PERFECT hash (`PerfectHash`; review
//! zig/report.md Z10): one hash of the name and one compare, hit or miss.
//! std.StaticStringMap, used before, buckets its keys by length and scans a
//! bucket linearly: 18.6 compares per attribute-name hit and 51 for a miss
//! of length 9 (data-* and aria-* names, 9-29% of attributes on 5 of 7 real
//! pages). Blink and WebKit generate the same kind of table for their
//! static names (gperf-made `FindAttribute`/`lookupHTMLTag` tables).
//!
//! Spec: https://dom.spec.whatwg.org/#concept-attribute-qualified-name
//! Spec: https://html.spec.whatwg.org/multipage/indices.html#attributes-3
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html#adjust-foreign-attributes

const std = @import("std");
const builtin = @import("builtin");
const infra = @import("infra");
const runtime = @import("runtime");
const element_name = @import("element_name.zig");

/// Debug-only checks (node-memory-plan-v2.md B8: `std.debug.assert` runs in
/// ReleaseSafe too). Count overflow and a release of nothing are production
/// checks.
const debug_checks = builtin.mode == .debug;

// ============================================================================
// A comptime perfect hash over a fixed list of names
// ============================================================================

/// The 64-bit hash `PerfectHash` places its keys by, the same at compile
/// time and run time: 8-byte words folded by multiply and rotate, then
/// murmur3's finalizer.
pub fn hash64(bytes: []const u8) u64 {
    var h: u64 = 0x9E37_79B9_7F4A_7C15 *% (@as(u64, bytes.len) +% 1);
    var i: usize = 0;
    while (i + 8 <= bytes.len) : (i += 8) h = fold(h, std.mem.readInt(u64, bytes[i..][0..8], .little));
    if (i < bytes.len) {
        var tail: u64 = 0;
        var k: usize = 0;
        while (i + k < bytes.len) : (k += 1) tail |= @as(u64, bytes[i + k]) << @intCast(k * 8);
        h = fold(h, tail);
    }
    return finalize(h);
}

fn fold(h: u64, word: u64) u64 {
    return std.math.rotl(u64, (h ^ word) *% 0x9FB2_1C65_1E98_DF25, 29);
}

fn finalize(x: u64) u64 {
    var z = x;
    z ^= z >> 33;
    z *%= 0xFF51_AFD7_ED55_8CCD;
    z ^= z >> 33;
    z *%= 0xC4CE_B9FE_1A85_EC53;
    z ^= z >> 33;
    return z;
}

/// A perfect hash over `keys`, found at compile time: hash-and-displace
/// (Belazzougui, Botelho and Dietzfelbinger's CHD; the scheme of gperf's
/// two-level tables and of PTHash). Each key's bucket has a displacement
/// chosen so every key of the list lands in a slot of its own, so a lookup
/// is one hash, one slot and ONE key compare, for a hit or a miss. `keys`
/// must be distinct: a duplicate cannot be placed and fails the build.
pub fn PerfectHash(comptime keys: []const []const u8) type {
    const key_count = keys.len;
    const slot_count: u32 = std.math.ceilPowerOfTwoAssert(u32, @max(key_count, 2));
    const bucket_count: u32 = @max(1, @as(u32, @intCast((key_count + 1) / 2)));
    const empty_slot = std.math.maxInt(u16);
    if (key_count >= empty_slot) @compileError("PerfectHash: too many keys");

    const Tables = struct {
        displacements: [bucket_count]u16,
        slots: [slot_count]u16,
    };

    const tables: Tables = comptime build: {
        @setEvalBranchQuota(20_000_000);
        var hashes: [key_count]u64 = undefined;
        for (keys, 0..) |key, i| hashes[i] = hash64(key);

        // The keys of each bucket, and the buckets largest first: the
        // crowded ones are placed while most slots are free.
        var bucket_sizes: [bucket_count]u32 = @splat(0);
        for (hashes) |h| bucket_sizes[bucketOf(h, bucket_count)] += 1;
        var order: [bucket_count]u32 = undefined;
        for (&order, 0..) |*o, i| o.* = @intCast(i);
        // Insertion sort, descending by size.
        var a: usize = 1;
        while (a < bucket_count) : (a += 1) {
            const item = order[a];
            var b: usize = a;
            while (b > 0 and bucket_sizes[order[b - 1]] < bucket_sizes[item]) : (b -= 1) order[b] = order[b - 1];
            order[b] = item;
        }

        var out: Tables = .{
            .displacements = @splat(0),
            .slots = @splat(empty_slot),
        };
        for (order) |bucket| {
            if (bucket_sizes[bucket] == 0) continue;
            var members: [key_count]u32 = undefined;
            var member_count: usize = 0;
            for (hashes, 0..) |h, i| if (bucketOf(h, bucket_count) == bucket) {
                members[member_count] = @intCast(i);
                member_count += 1;
            };
            var displacement: u32 = 0;
            const placed = search: while (displacement < std.math.maxInt(u16)) : (displacement += 1) {
                var used: [key_count]u32 = undefined;
                for (members[0..member_count], 0..) |member, m| {
                    const slot = slotOf(hashes[member], displacement, slot_count);
                    if (out.slots[slot] != empty_slot) continue :search;
                    for (used[0..m]) |other| if (other == slot) continue :search;
                    used[m] = slot;
                }
                break :search true;
            } else false;
            if (!placed) @compileError("PerfectHash: no displacement places a bucket (a duplicate key?): " ++ keys[members[0]]);
            out.displacements[bucket] = @intCast(displacement);
            for (members[0..member_count]) |member| out.slots[slotOf(hashes[member], displacement, slot_count)] = @intCast(member);
        }
        break :build out;
    };

    return struct {
        const displacements = tables.displacements;
        const slots = tables.slots;

        /// The index of the only key `key` can be, or null when its slot is
        /// empty. Not yet compared: `get` compares it.
        pub inline fn candidate(key: []const u8) ?u16 {
            const h = hash64(key);
            const index = slots[slotOf(h, displacements[bucketOf(h, bucket_count)], slot_count)];
            return if (index == empty_slot) null else index;
        }

        /// The index of `key` in `keys`, or null: one hash, one compare.
        pub fn get(key: []const u8) ?u16 {
            const index = candidate(key) orelse return null;
            return if (std.mem.eql(u8, keys[index], key)) index else null;
        }

        /// `get`, counting the key compares it makes into `compares`: the
        /// perfect hash's promise, which a test pins.
        pub fn getCounting(key: []const u8, compares: *usize) ?u16 {
            const index = candidate(key) orelse return null;
            compares.* += 1;
            return if (std.mem.eql(u8, keys[index], key)) index else null;
        }
    };
}

inline fn bucketOf(h: u64, bucket_count: u32) u32 {
    return @intCast((@as(u64, @as(u32, @truncate(h >> 32))) * bucket_count) >> 32);
}

inline fn slotOf(h: u64, displacement: u32, slot_count: u32) u32 {
    const step: u32 = @as(u32, @truncate((h >> 32) ^ (h >> 7))) | 1;
    return (@as(u32, @truncate(h)) +% displacement *% step) & (slot_count - 1);
}

// ============================================================================
// Dense ids over counted records, recycled from a free list
// ============================================================================

/// The slots a table's ids index: slot `i` holds the address of the record
/// whose id names `i`, or - free - the next free slot (bit 0 set). A freed
/// slot is reused first, so ids stay dense; a Debug build keeps a
/// generation per slot, bumped on every free, which the table stamps into
/// the ids it hands out (`generation`), so a stale id is caught.
pub fn IdSlots(comptime Record: type) type {
    return struct {
        const Self = @This();

        slots: std.ArrayListUnmanaged(usize) = .empty,
        free_head: u32 = none,
        generations: if (debug_checks) std.ArrayListUnmanaged(u8) else void = if (debug_checks) .empty else {},

        const none = std.math.maxInt(u32);

        comptime {
            if (@alignOf(Record) < 2) @compileError("IdSlots: a record's address must leave bit 0 free");
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            self.slots.deinit(allocator);
            if (debug_checks) self.generations.deinit(allocator);
        }

        /// A slot for `record`: the last one freed, else a new one, below
        /// `limit` slots.
        pub fn take(self: *Self, allocator: std.mem.Allocator, item: *Record, limit: usize) error{OutOfMemory}!u32 {
            if (self.free_head != none) {
                const index = self.free_head;
                self.free_head = @intCast(self.slots.items[index] >> 1);
                self.slots.items[index] = @intFromPtr(item);
                return index;
            }
            if (self.slots.items.len >= limit) return error.OutOfMemory;
            try self.slots.ensureUnusedCapacity(allocator, 1);
            if (debug_checks) try self.generations.append(allocator, 0);
            self.slots.appendAssumeCapacity(@intFromPtr(item));
            return @intCast(self.slots.items.len - 1);
        }

        /// Slot `index` is free again (its record freed).
        pub fn give(self: *Self, index: u32) void {
            self.slots.items[index] = (@as(usize, self.free_head) << 1) | 1;
            self.free_head = index;
            if (debug_checks) self.generations.items[index] +%= 1;
        }

        /// The record in slot `index`; a free slot panics.
        pub inline fn get(self: *const Self, index: u32) *Record {
            const raw = self.slots.items[index];
            if (raw & 1 != 0) @panic("an id names a freed slot");
            return @ptrFromInt(raw);
        }

        /// Slot `index`'s generation (Debug), else 0.
        pub inline fn generation(self: *const Self, index: u32) u8 {
            return if (debug_checks) self.generations.items[index] else 0;
        }

        /// Whether slot `index` holds a record.
        pub fn isLive(self: *const Self, index: u32) bool {
            return index < self.slots.items.len and self.slots.items[index] & 1 == 0;
        }

        /// How many slots there are, free ones included.
        pub fn len(self: *const Self) usize {
            return self.slots.items.len;
        }
    };
}

// ============================================================================
// The name record and its id
// ============================================================================

/// An attribute's qualified name: its namespace, namespace prefix and local
/// name (DOM 4.9.2), which an attribute keeps for its whole life ("replace"
/// gives the list a new attribute). Static for a known name, every element
/// sharing it; else its Browser's counted record.
pub const QualifiedName = struct {
    namespace_uri: ?[]const u8 = null,
    prefix: ?[]const u8 = null,
    local_name: []const u8,
    /// A dynamic record's references: the attributes whose entries name it
    /// (and any holder that took one, `retain`). A static record's stays 0.
    /// Written only by its table, on its Browser's window agent's thread.
    references: u32 = 0,
    /// Its id's raw value (`NameId`).
    id: u32 = 0,
    /// One of the comptime records rather than a Browser's.
    is_static: bool = true,

    /// Whether this name's namespace is `namespace_uri` and its local name
    /// is `local_name` (null matches only null): an attribute's identity in
    /// its element's list.
    pub fn isNamed(self: *const QualifiedName, namespace_uri: ?[]const u8, local_name: []const u8) bool {
        return optionalEql(self.namespace_uri, namespace_uri) and std.mem.eql(u8, local_name, self.local_name);
    }

    /// Whether this name is exactly `namespace_uri`, `prefix` and
    /// `local_name`.
    pub fn eql(self: *const QualifiedName, namespace_uri: ?[]const u8, prefix: ?[]const u8, local_name: []const u8) bool {
        return self.isNamed(namespace_uri, local_name) and optionalEql(self.prefix, prefix);
    }

    /// An attribute's qualified name is its local name if its namespace
    /// prefix is null, and otherwise its prefix, ":", and its local name.
    /// Compared in place.
    ///
    /// Spec: https://dom.spec.whatwg.org/#concept-attribute-qualified-name
    pub fn qualifiedNameIs(self: *const QualifiedName, qualified_name: []const u8) bool {
        return qualifiedNameMatches(self.prefix, self.local_name, qualified_name);
    }
};

/// Whether (`prefix`, `local_name`) is the qualified name `qualified_name`.
pub fn qualifiedNameMatches(prefix_or_null: ?[]const u8, local_name: []const u8, qualified_name: []const u8) bool {
    const prefix = prefix_or_null orelse return std.mem.eql(u8, local_name, qualified_name);
    return qualified_name.len == prefix.len + 1 + local_name.len and
        std.mem.startsWith(u8, qualified_name, prefix) and
        qualified_name[prefix.len] == ':' and
        std.mem.endsWith(u8, qualified_name, local_name);
}

pub fn optionalEql(a: ?[]const u8, b: ?[]const u8) bool {
    const x = a orelse return b == null;
    const y = b orelse return false;
    return std.mem.eql(u8, x, y);
}

/// An attribute name: a static record's index, or a counted reference to a
/// Browser's record (bit 31). In a Debug build bits 24-30 of a dynamic id
/// are its slot's generation.
pub const NameId = enum(u32) {
    _,

    const dynamic_bit: u32 = 1 << 31;
    const generation_shift = 24;
    const index_bits: u32 = if (debug_checks) generation_shift else 31;
    const index_mask: u32 = (@as(u32, 1) << index_bits) - 1;
    /// The dynamic slots a table may hold.
    pub const dynamic_limit: usize = index_mask;

    pub inline fn isStatic(self: NameId) bool {
        return @backingInt(self) & dynamic_bit == 0;
    }

    pub inline fn ofStatic(index: u16) NameId {
        return @fromBackingInt(@intCast(index));
    }

    fn ofDynamic(index: u32, slot_generation: u8) NameId {
        const stamp: u32 = if (debug_checks) @as(u32, slot_generation & 0x7F) << generation_shift else 0;
        return @fromBackingInt(@intCast(dynamic_bit | stamp | index));
    }

    fn slot(self: NameId) u32 {
        return @backingInt(self) & index_mask;
    }

    fn generation(self: NameId) u8 {
        return if (debug_checks) @intCast((@backingInt(self) >> generation_shift) & 0x7F) else 0;
    }
};

// ============================================================================
// The static names
// ============================================================================

/// The known attribute local names in no namespace. Distinct (the perfect
/// hash cannot be built otherwise). Lane perf3 D1's table (moved here from
/// html/parser/attribute_name_intern.zig, which forwards to it):
/// - HTML's attribute index (HTML "Index" > "Attributes", both lists) and
///   the event handler content attributes of GlobalEventHandlers,
///   WindowEventHandlers and DocumentAndElementEventHandlers (specs/idl);
/// - the obsolete and presentational attributes HTML 15 "Rendering" and 16
///   "Obsolete features" still read (align, bgcolor, border, ...);
/// - ARIA's role and aria-* states and properties (WAI-ARIA 1.3);
/// - the SVG and MathML names the parser makes ("adjust SVG attributes",
///   "adjust MathML attributes") and common SVG presentation attributes.
/// An exact, case-sensitive match: an attribute's local name keeps its case
/// (setAttributeNS(null, "FOO") is not "foo").
pub const names = [_][]const u8{
    // HTML's attribute index.
    "abbr",                        "accept",                          "accept-charset",           "accesskey",                 "action",
    "allow",                       "allowfullscreen",                 "alpha",                    "alt",                       "as",
    "async",                       "autocapitalize",                  "autocomplete",             "autocorrect",               "autofocus",
    "autoplay",                    "blocking",                        "charset",                  "checked",                   "cite",
    "class",                       "closedby",                        "color",                    "colorspace",                "cols",
    "colspan",                     "command",                         "commandfor",               "content",                   "contenteditable",
    "controls",                    "coords",                          "crossorigin",              "data",                      "datetime",
    "decoding",                    "default",                         "defer",                    "dir",                       "dirname",
    "disabled",                    "download",                        "draggable",                "enctype",                   "enterkeyhint",
    "fetchpriority",               "for",                             "form",                     "formaction",                "formenctype",
    "formmethod",                  "formnovalidate",                  "formtarget",               "headers",                   "headingoffset",
    "headingreset",                "height",                          "hidden",                   "high",                      "href",
    "hreflang",                    "http-equiv",                      "id",                       "imagesizes",                "imagesrcset",
    "inert",                       "inputmode",                       "integrity",                "is",                        "ismap",
    "itemid",                      "itemprop",                        "itemref",                  "itemscope",                 "itemtype",
    "kind",                        "label",                           "lang",                     "list",                      "loading",
    "loop",                        "low",                             "max",                      "maxlength",                 "media",
    "method",                      "min",                             "minlength",                "multiple",                  "muted",
    "name",                        "nomodule",                        "nonce",                    "novalidate",                "open",
    "optimum",                     "pattern",                         "ping",                     "placeholder",               "playsinline",
    "popover",                     "popovertarget",                   "popovertargetaction",      "poster",                    "preload",
    "readonly",                    "referrerpolicy",                  "rel",                      "required",                  "reversed",
    "rows",                        "rowspan",                         "sandbox",                  "scope",                     "selected",
    "shadowrootclonable",          "shadowrootcustomelementregistry", "shadowrootdelegatesfocus", "shadowrootmode",            "shadowrootserializable",
    "shadowrootslotassignment",    "shape",                           "size",                     "sizes",                     "slot",
    "span",                        "spellcheck",                      "src",                      "srcdoc",                    "srclang",
    "srcset",                      "start",                           "step",                     "style",                     "tabindex",
    "target",                      "title",                           "translate",                "type",                      "usemap",
    "value",                       "width",                           "wrap",                     "writingsuggestions",

    // Event handler content attributes.
           "onabort",
    "onafterprint",                "onanimationcancel",               "onanimationend",           "onanimationiteration",      "onanimationstart",
    "onauxclick",                  "onbeforeinput",                   "onbeforematch",            "onbeforeprint",             "onbeforetoggle",
    "onbeforeunload",              "onblur",                          "oncancel",                 "oncanplay",                 "oncanplaythrough",
    "onchange",                    "onclick",                         "onclose",                  "oncommand",                 "oncontextlost",
    "oncontextmenu",               "oncontextrestored",               "oncopy",                   "oncuechange",               "oncut",
    "ondblclick",                  "ondrag",                          "ondragend",                "ondragenter",               "ondragleave",
    "ondragover",                  "ondragstart",                     "ondrop",                   "ondurationchange",          "onemptied",
    "onended",                     "onerror",                         "onfocus",                  "onformdata",                "ongotpointercapture",
    "onhashchange",                "oninput",                         "oninvalid",                "onkeydown",                 "onkeypress",
    "onkeyup",                     "onlanguagechange",                "onload",                   "onloadeddata",              "onloadedmetadata",
    "onloadstart",                 "onlostpointercapture",            "onmessage",                "onmessageerror",            "onmousedown",
    "onmouseenter",                "onmouseleave",                    "onmousemove",              "onmouseout",                "onmouseover",
    "onmouseup",                   "onoffline",                       "ononline",                 "onpagehide",                "onpagereveal",
    "onpageshow",                  "onpageswap",                      "onpaste",                  "onpause",                   "onplay",
    "onplaying",                   "onpointercancel",                 "onpointerdown",            "onpointerenter",            "onpointerleave",
    "onpointermove",               "onpointerout",                    "onpointerover",            "onpointerrawupdate",        "onpointerup",
    "onpopstate",                  "onprogress",                      "onratechange",             "onrejectionhandled",        "onreset",
    "onresize",                    "onscroll",                        "onscrollend",              "onsecuritypolicyviolation", "onseeked",
    "onseeking",                   "onselect",                        "onselectionchange",        "onselectstart",             "onslotchange",
    "onstalled",                   "onstorage",                       "onsubmit",                 "onsuspend",                 "ontimeupdate",
    "ontoggle",                    "ontouchcancel",                   "ontouchend",               "ontouchmove",               "ontouchstart",
    "ontransitioncancel",          "ontransitionend",                 "ontransitionrun",          "ontransitionstart",         "onunhandledrejection",
    "onunload",                    "onvolumechange",                  "onwaiting",                "onwebkitanimationend",      "onwebkitanimationiteration",
    "onwebkitanimationstart",      "onwebkittransitionend",           "onwheel",

    // Obsolete and presentational attributes HTML 15 and 16 still read.
                     "align",                     "alink",
    "archive",                     "axis",                            "background",               "bgcolor",                   "border",
    "bordercolor",                 "bottommargin",                    "cellpadding",              "cellspacing",               "char",
    "charoff",                     "classid",                         "clear",                    "code",                      "codebase",
    "codetype",                    "compact",                         "declare",                  "direction",                 "event",
    "face",                        "frame",                           "frameborder",              "hspace",                    "language",
    "leftmargin",                  "link",                            "longdesc",                 "lowsrc",                    "manifest",
    "marginheight",                "marginwidth",                     "nohref",                   "noshade",                   "nowrap",
    "profile",                     "rev",                             "rightmargin",              "rules",                     "scheme",
    "scrollamount",                "scrolldelay",                     "scrolling",                "standby",                   "summary",
    "text",                        "topmargin",                       "truespeed",                "valign",                    "valuetype",
    "version",                     "vlink",                           "vspace",                   "behavior",                  "allowtransparency",

    // ARIA.
    "role",                        "aria-activedescendant",           "aria-atomic",              "aria-autocomplete",         "aria-braillelabel",
    "aria-brailleroledescription", "aria-busy",                       "aria-checked",             "aria-colcount",             "aria-colindex",
    "aria-colindextext",           "aria-colspan",                    "aria-controls",            "aria-current",              "aria-describedby",
    "aria-description",            "aria-details",                    "aria-disabled",            "aria-dropeffect",           "aria-errormessage",
    "aria-expanded",               "aria-flowto",                     "aria-grabbed",             "aria-haspopup",             "aria-hidden",
    "aria-invalid",                "aria-keyshortcuts",               "aria-label",               "aria-labelledby",           "aria-level",
    "aria-live",                   "aria-modal",                      "aria-multiline",           "aria-multiselectable",      "aria-orientation",
    "aria-owns",                   "aria-placeholder",                "aria-posinset",            "aria-pressed",              "aria-readonly",
    "aria-relevant",               "aria-required",                   "aria-roledescription",     "aria-rowcount",             "aria-rowindex",
    "aria-rowindextext",           "aria-rowspan",                    "aria-selected",            "aria-setsize",              "aria-sort",
    "aria-valuemax",               "aria-valuemin",                   "aria-valuenow",            "aria-valuetext",

    // RDFa and Open Graph names real pages carry on meta and other elements.
               "property",
    "about",                       "typeof",                          "vocab",                    "resource",                  "prefix",

    // SVG: the names "adjust SVG attributes" makes, then common lowercase ones.
    "attributeName",               "attributeType",                   "baseFrequency",            "baseProfile",               "calcMode",
    "clipPathUnits",               "diffuseConstant",                 "edgeMode",                 "filterUnits",               "glyphRef",
    "gradientTransform",           "gradientUnits",                   "kernelMatrix",             "kernelUnitLength",          "keyPoints",
    "keySplines",                  "keyTimes",                        "lengthAdjust",             "limitingConeAngle",         "markerHeight",
    "markerUnits",                 "markerWidth",                     "maskContentUnits",         "maskUnits",                 "numOctaves",
    "pathLength",                  "patternContentUnits",             "patternTransform",         "patternUnits",              "pointsAtX",
    "pointsAtY",                   "pointsAtZ",                       "preserveAlpha",            "preserveAspectRatio",       "primitiveUnits",
    "refX",                        "refY",                            "repeatCount",              "repeatDur",                 "requiredExtensions",
    "requiredFeatures",            "specularConstant",                "specularExponent",         "spreadMethod",              "startOffset",
    "stdDeviation",                "stitchTiles",                     "surfaceScale",             "systemLanguage",            "tableValues",
    "targetX",                     "targetY",                         "textLength",               "viewBox",                   "viewTarget",
    "xChannelSelector",            "yChannelSelector",                "zoomAndPan",               "d",                         "fill",
    "stroke",                      "x",                               "y",                        "x1",                        "y1",
    "x2",                          "y2",                              "cx",                       "cy",                        "r",
    "rx",                          "ry",                              "dx",                       "dy",                        "fr",
    "fx",                          "fy",                              "points",                   "transform",                 "opacity",
    "fill-opacity",                "fill-rule",                       "stroke-width",             "stroke-opacity",            "stroke-linecap",
    "stroke-linejoin",             "stroke-dasharray",                "stroke-dashoffset",        "stroke-miterlimit",         "clip-path",
    "clip-rule",                   "mask",                            "filter",                   "offset",                    "stop-color",
    "stop-opacity",                "font-family",                     "font-size",                "font-weight",               "font-style",
    "font-variant",                "font-stretch",                    "text-anchor",              "text-decoration",           "dominant-baseline",
    "alignment-baseline",          "baseline-shift",                  "letter-spacing",           "word-spacing",              "writing-mode",
    "visibility",                  "display",                         "overflow",                 "color-interpolation",       "color-interpolation-filters",
    "flood-color",                 "flood-opacity",                   "lighting-color",           "marker-start",              "marker-mid",
    "marker-end",                  "vector-effect",                   "paint-order",              "pointer-events",            "shape-rendering",
    "text-rendering",              "image-rendering",                 "cursor",                   "focusable",                 "in",
    "in2",                         "result",                          "mode",                     "operator",                  "k1",
    "k2",                          "k3",                              "k4",                       "values",                    "begin",
    "dur",                         "end",                             "from",                     "to",                        "by",
    "rotate",                      "scale",                           "order",                    "radius",                    "azimuth",
    "elevation",                   "amplitude",                       "exponent",                 "intercept",                 "slope",
    "seed",                        "path",

    // MathML: "adjust MathML attributes" and the presentation attributes.
                               "definitionURL",            "mathvariant",               "displaystyle",
    "scriptlevel",                 "mathcolor",                       "mathbackground",           "mathsize",                  "linethickness",
    "stretchy",                    "symmetric",                       "largeop",                  "movablelimits",             "accent",
    "accentunder",                 "lspace",                          "rspace",                   "fence",                     "separator",
    "minsize",                     "maxsize",                         "columnspan",               "rowspacing",                "columnspacing",
    "notation",                    "encoding",
};

/// HTML "adjust foreign attributes": the names the parser puts in a
/// namespace, each with its prefix - the only static names with a namespace
/// or a prefix.
pub const foreign = [_]QualifiedName{
    .{ .namespace_uri = infra.namespaces.XLINK_NAMESPACE, .prefix = "xlink", .local_name = "actuate" },
    .{ .namespace_uri = infra.namespaces.XLINK_NAMESPACE, .prefix = "xlink", .local_name = "arcrole" },
    .{ .namespace_uri = infra.namespaces.XLINK_NAMESPACE, .prefix = "xlink", .local_name = "href" },
    .{ .namespace_uri = infra.namespaces.XLINK_NAMESPACE, .prefix = "xlink", .local_name = "role" },
    .{ .namespace_uri = infra.namespaces.XLINK_NAMESPACE, .prefix = "xlink", .local_name = "show" },
    .{ .namespace_uri = infra.namespaces.XLINK_NAMESPACE, .prefix = "xlink", .local_name = "title" },
    .{ .namespace_uri = infra.namespaces.XLINK_NAMESPACE, .prefix = "xlink", .local_name = "type" },
    .{ .namespace_uri = infra.namespaces.XML_NAMESPACE, .prefix = "xml", .local_name = "lang" },
    .{ .namespace_uri = infra.namespaces.XML_NAMESPACE, .prefix = "xml", .local_name = "space" },
    .{ .namespace_uri = infra.namespaces.XMLNS_NAMESPACE, .prefix = null, .local_name = "xmlns" },
    .{ .namespace_uri = infra.namespaces.XMLNS_NAMESPACE, .prefix = "xmlns", .local_name = "xlink" },
};

/// The static records: `names` (no namespace) in order, then `foreign`. A
/// static NameId is an index here.
pub const static_records: [names.len + foreign.len]QualifiedName = blk: {
    var out: [names.len + foreign.len]QualifiedName = undefined;
    for (names, 0..) |name, i| out[i] = .{ .local_name = name, .id = i };
    for (foreign, names.len..) |known, i| {
        out[i] = known;
        out[i].id = i;
    }
    break :blk out;
};

/// The perfect hash over `names`.
pub const static_index = PerfectHash(&names);

/// The static id of a name in no namespace with no prefix, or null.
pub inline fn staticLocalId(local_name: []const u8) ?NameId {
    return NameId.ofStatic(static_index.get(local_name) orelse return null);
}

/// The static id of a name known at compile time (a reader's fixed name:
/// `id`, `class`, `slot`): checked to exist when the build runs.
pub inline fn comptimeLocalId(comptime local_name: []const u8) NameId {
    const index = comptime blk: {
        @setEvalBranchQuota(1_000_000);
        break :blk static_index.get(local_name) orelse @compileError("not a static attribute name: " ++ local_name);
    };
    return NameId.ofStatic(index);
}

/// The static id of exactly this name, or null when no table has it.
pub fn staticId(namespace: ?[]const u8, prefix: ?[]const u8, local_name: []const u8) ?NameId {
    if (namespace == null) {
        if (prefix != null) return null;
        return staticLocalId(local_name);
    }
    for (&foreign, names.len..) |*known, i| {
        if (known.eql(namespace, prefix, local_name)) return NameId.ofStatic(@intCast(i));
    }
    return null;
}

/// The record a static id names.
pub inline fn staticRecord(id: NameId) *const QualifiedName {
    return &static_records[@backingInt(id)];
}

/// The record `id` names: a static one, or one of `table`'s (which a dynamic
/// id needs: its element's Browser's, `tableOf`).
pub inline fn record(table: ?*const Table, id: NameId) *const QualifiedName {
    if (id.isStatic()) return staticRecord(id);
    return table.?.get(id);
}

// ============================================================================
// A Browser's interned names
// ============================================================================

/// What a table lookup is keyed by: a name's three parts.
const Key = struct {
    namespace_uri: ?[]const u8,
    prefix: ?[]const u8,
    local_name: []const u8,

    fn hash(self: Key) u64 {
        var hasher = std.hash.Wyhash.init(0);
        hashPart(&hasher, self.namespace_uri);
        hashPart(&hasher, self.prefix);
        hasher.update(self.local_name);
        return hasher.final();
    }

    /// Null and "" hash apart: the part's presence, its length, its bytes.
    fn hashPart(hasher: *std.hash.Wyhash, part: ?[]const u8) void {
        const bytes = part orelse {
            hasher.update(&[_]u8{0});
            return;
        };
        const len: u64 = bytes.len;
        hasher.update(&[_]u8{1});
        hasher.update(std.mem.asBytes(&len));
        hasher.update(bytes);
    }

    fn of(name: *const QualifiedName) Key {
        return .{ .namespace_uri = name.namespace_uri, .prefix = name.prefix, .local_name = name.local_name };
    }
};

/// The map's own context: records hash by their names and are equal only
/// to themselves (the table holds one record per name).
const RecordContext = struct {
    pub fn hash(_: RecordContext, name: *const QualifiedName) u64 {
        return Key.of(name).hash();
    }
    pub fn eql(_: RecordContext, a: *const QualifiedName, b: *const QualifiedName) bool {
        return a == b;
    }
};

/// A lookup by name.
const KeyAdapter = struct {
    pub fn hash(_: KeyAdapter, key: Key) u64 {
        return key.hash();
    }
    pub fn eql(_: KeyAdapter, key: Key, name: *const QualifiedName) bool {
        return name.eql(key.namespace_uri, key.prefix, key.local_name);
    }
};

/// A Browser's interned attribute names (its BrowserScope's
/// `.attribute_names` table, made on first use): one COUNTED record per
/// distinct name no static table has that an attribute of the Browser names
/// now (13-360 per real page against 545-19,124 attributes: nodedata-design
/// A2), each with a dense id. WEAK: it holds no reference; a record's last
/// release removes it, frees it and frees its slot for the next name. Its
/// window agent's thread only, so no lock.
pub const Table = struct {
    allocator: std.mem.Allocator,
    records: Map = .empty,
    ids: IdSlots(QualifiedName) = .{},
    /// When to drop the tombstones removals leave (infra.tombstones).
    tombstones: infra.tombstones.TombstoneGuard = .{},

    const Map = std.HashMapUnmanaged(*const QualifiedName, void, RecordContext, 80);

    /// Below this many slots an emptied map keeps its storage.
    const kept_capacity = 64;

    pub fn init(allocator: std.mem.Allocator) Table {
        return .{ .allocator = allocator };
    }

    /// The table's end, with its Browser's scope: every record still in it
    /// (an engine-less test's element no teardown reached), the map, the
    /// slots.
    pub fn deinit(self: *Table) void {
        var keys = self.records.keyIterator();
        while (keys.next()) |name| destroy(self.allocator, name.*);
        self.records.deinit(self.allocator);
        self.ids.deinit(self.allocator);
    }

    /// How many names the table holds.
    pub fn count(self: *const Table) usize {
        return self.records.count();
    }

    /// The record dynamic `id` names, checked: a freed slot, or (Debug) a
    /// slot freed and reused since the id was handed out, panics.
    pub fn get(self: *const Table, id: NameId) *const QualifiedName {
        std.debug.assert(!id.isStatic());
        const slot = id.slot();
        if (debug_checks and self.ids.generation(slot) & 0x7F != id.generation()) @panic("a stale attribute name id");
        return self.ids.get(slot);
    }

    /// A counted reference to the record of exactly (`namespace_uri`,
    /// `prefix`, `local_name`), made the first time the name is asked for.
    /// The caller keeps it until its `release`. A name a static table has
    /// is never asked for here (`intern` tries those first).
    pub fn intern(self: *Table, namespace_uri: ?[]const u8, prefix: ?[]const u8, local_name: []const u8) error{OutOfMemory}!NameId {
        const key: Key = .{ .namespace_uri = namespace_uri, .prefix = prefix, .local_name = local_name };
        if (self.records.getKeyAdapted(key, KeyAdapter{})) |found| {
            const id: NameId = @fromBackingInt(@intCast(found.id));
            self.retain(id);
            return id;
        }
        self.tombstones.beforeInsert(&self.records);
        try self.records.ensureUnusedCapacity(self.allocator, 1);
        const name = try create(self.allocator, namespace_uri, prefix, local_name);
        errdefer destroy(self.allocator, name);
        const slot = try self.ids.take(self.allocator, name, NameId.dynamic_limit);
        const id = NameId.ofDynamic(slot, self.ids.generation(slot));
        name.id = @backingInt(id);
        self.records.putAssumeCapacityNoClobber(name, {});
        return id;
    }

    /// One more reference to dynamic `id`'s record: its count, checked for
    /// overflow in every build (string_cache's count overflow became a
    /// use-after-free: review oss/report.md R8).
    pub fn retain(self: *Table, id: NameId) void {
        const name: *QualifiedName = @constCast(self.get(id));
        if (name.references == std.math.maxInt(u32)) @panic("an attribute name record's count overflowed");
        name.references += 1;
    }

    /// Drop one reference to dynamic `id`'s record; the last removes it from
    /// the table, frees it and frees its slot, now.
    pub fn release(self: *Table, id: NameId) void {
        const name: *QualifiedName = @constCast(self.get(id));
        if (name.references == 0) @panic("an attribute name record released more often than it was kept");
        name.references -= 1;
        if (name.references != 0) return;
        const removed = self.records.remove(name);
        if (debug_checks and !removed) @panic("a released attribute name record was not in its Browser's table");
        self.ids.give(id.slot());
        destroy(self.allocator, name);
        self.afterRemove();
    }

    /// The map after a removal (dom.element_name.Table's rule: WTF's
    /// HashTable shrinks below a sixth full).
    fn afterRemove(self: *Table) void {
        const capacity = self.records.capacity();
        const live = self.records.count();
        if (live == 0) {
            if (capacity > kept_capacity) self.records.clearAndFree(self.allocator) else self.records.clearRetainingCapacity();
            self.tombstones.reset();
        } else if (capacity > kept_capacity and live * 6 < capacity) {
            self.shrink();
        } else {
            self.tombstones.noteRemoval(&self.records);
        }
    }

    fn shrink(self: *Table) void {
        var smaller: Map = .empty;
        smaller.ensureTotalCapacity(self.allocator, self.records.count()) catch {
            self.tombstones.noteRemoval(&self.records);
            return;
        };
        var keys = self.records.keyIterator();
        while (keys.next()) |name| smaller.putAssumeCapacityNoClobber(name.*, {});
        self.records.deinit(self.allocator);
        self.records = smaller;
        self.tombstones.reset();
    }
};

/// One record and its strings in ONE block of `allocator`: the local name,
/// the prefix, and the namespace unless it is one of the six named ones
/// (Infra's string). Written in full at once, so it takes the allocator's
/// raw entry point (review zig/report.md Z5: `std.mem.Allocator.alloc`
/// fills a new block with 0xaa in ReleaseSafe). Its one reference is the
/// caller's.
fn create(allocator: std.mem.Allocator, namespace_uri: ?[]const u8, prefix: ?[]const u8, local_name: []const u8) error{OutOfMemory}!*QualifiedName {
    const static_namespace: ?[]const u8 = if (namespace_uri) |ns| element_name.internNamespace(ns) else null;
    const namespace_bytes: usize = if (namespace_uri) |ns| (if (static_namespace == null) ns.len else 0) else 0;
    const prefix_bytes: usize = if (prefix) |p| p.len else 0;
    const total = @sizeOf(QualifiedName) + local_name.len + prefix_bytes + namespace_bytes;
    const memory = allocator.rawAlloc(total, .of(QualifiedName), @returnAddress()) orelse return error.OutOfMemory;
    var tail: []u8 = memory[@sizeOf(QualifiedName)..total];
    const local = copyInto(&tail, local_name);
    const own_prefix: ?[]const u8 = if (prefix) |p| copyInto(&tail, p) else null;
    const own_namespace: ?[]const u8 = if (namespace_uri) |ns| (static_namespace orelse copyInto(&tail, ns)) else null;
    if (debug_checks and tail.len != 0) @panic("an attribute name record's strings did not fill its block");
    const name: *QualifiedName = @ptrCast(@alignCast(memory));
    name.* = .{
        .namespace_uri = own_namespace,
        .prefix = own_prefix,
        .local_name = local,
        .references = 1,
        .is_static = false,
    };
    return name;
}

/// The size of a dynamic record's block, from its names.
fn blockSize(name: *const QualifiedName) usize {
    var total = @sizeOf(QualifiedName) + name.local_name.len;
    if (name.prefix) |p| total += p.len;
    if (name.namespace_uri) |ns| if (element_name.internNamespace(ns) == null) {
        total += ns.len;
    };
    return total;
}

/// Free a dynamic record's block; Debug poisons it first (the raw entry
/// point does not).
fn destroy(allocator: std.mem.Allocator, name: *const QualifiedName) void {
    const block: [*]u8 = @ptrCast(@constCast(name));
    const bytes = block[0..blockSize(name)];
    if (debug_checks) @memset(bytes, 0xAA);
    allocator.rawFree(bytes, .of(QualifiedName), @returnAddress());
}

fn copyInto(tail: *[]u8, bytes: []const u8) []const u8 {
    const out = tail.*[0..bytes.len];
    @memcpy(out, bytes);
    tail.* = tail.*[bytes.len..];
    return out;
}

// ============================================================================
// A Browser's names, through its scope
// ============================================================================

/// The id of (`namespace_uri`, `prefix`, `local_name`): the static one if a
/// static table has the name, else a COUNTED reference to `scope`'s
/// interned record, which the caller keeps until its `release`.
pub fn intern(scope: *runtime.BrowserScope, namespace_uri: ?[]const u8, prefix: ?[]const u8, local_name: []const u8) error{OutOfMemory}!NameId {
    if (staticId(namespace_uri, prefix, local_name)) |id| return id;
    element_name.checkOwnerThread(scope);
    const table = try scope.table(.attribute_names, Table);
    return table.intern(namespace_uri, prefix, local_name);
}

/// One more reference to `id` (nothing for a static id): a holder that
/// keeps a name across a point where script can run.
pub fn retain(scope: *runtime.BrowserScope, id: NameId) void {
    if (id.isStatic()) return;
    element_name.checkOwnerThread(scope);
    scope.existingTable(.attribute_names, Table).?.retain(id);
}

/// Drop a reference `intern` or `retain` gave - nothing for a static id. A
/// release after the scope's tables ended (its end freed every record)
/// touches nothing.
pub fn release(scope: *runtime.BrowserScope, id: NameId) void {
    if (id.isStatic()) return;
    const table = scope.existingTable(.attribute_names, Table) orelse return;
    element_name.checkOwnerThread(scope);
    table.release(id);
}

/// `scope`'s table, if it has made one: what a reader decodes dynamic ids
/// with.
pub fn tableOf(scope: *runtime.BrowserScope) ?*const Table {
    return scope.existingTable(.attribute_names, Table);
}

// ============================================================================
// Tests
// ============================================================================

test "the perfect hash finds every static name with ONE compare, and a miss with at most one" {
    var compares: usize = 0;
    for (names, 0..) |name, i| {
        compares = 0;
        try std.testing.expectEqual(@as(?u16, @intCast(i)), static_index.getCounting(name, &compares));
        // Z10: std.StaticStringMap made 18.6 compares per hit on this table.
        try std.testing.expectEqual(@as(usize, 1), compares);
        try std.testing.expect(staticRecord(staticLocalId(name).?) == &static_records[i]);
    }
    // Misses: 51 compares for a length-9 miss before; at most one now.
    const misses = [_][]const u8{ "data-item", "aria-xyzw", "CLASS", "viewbox", "data-id", "x-foo-bar", "", "onclickx", "a" };
    for (misses) |miss| {
        compares = 0;
        try std.testing.expect(static_index.getCounting(miss, &compares) == null);
        try std.testing.expect(compares <= 1);
    }
}

test "a static id is exact: case, prefix and namespace all count" {
    try std.testing.expect(staticId(null, null, "class") != null);
    try std.testing.expect(staticId(null, null, "CLASS") == null);
    try std.testing.expect(staticId(null, null, "viewBox") != null);
    try std.testing.expect(staticId(null, null, "viewbox") == null);
    try std.testing.expect(staticId(null, null, "data-x") == null);
    try std.testing.expect(staticId(null, "p", "class") == null);
    const href = staticId(infra.namespaces.XLINK_NAMESPACE, "xlink", "href").?;
    try std.testing.expect(href.isStatic());
    try std.testing.expectEqualStrings("xlink", staticRecord(href).prefix.?);
    try std.testing.expect(staticRecord(href).namespace_uri.?.ptr == infra.namespaces.XLINK_NAMESPACE.ptr);
    try std.testing.expect(staticId(infra.namespaces.XLINK_NAMESPACE, "other", "href") == null);
    try std.testing.expect(staticId(infra.namespaces.XLINK_NAMESPACE, null, "href") == null);
    try std.testing.expect(staticId("urn:x", null, "class") == null);
    try std.testing.expect(staticId(infra.namespaces.XMLNS_NAMESPACE, null, "xmlns") != null);
    try std.testing.expect(comptimeLocalId("id") == staticLocalId("id").?);
    try std.testing.expectEqual(@as(u32, @backingInt(comptimeLocalId("class"))), staticRecord(comptimeLocalId("class")).id);
}

test "a dynamic name is one counted record with a dense id, freed and its slot reused at zero" {
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    defer scope.deinit();

    const a = try intern(&scope, null, null, "data-a");
    try std.testing.expect(!a.isStatic());
    try std.testing.expect(try intern(&scope, null, null, "data-a") == a);
    const table = scope.existingTable(.attribute_names, Table).?;
    try std.testing.expectEqual(@as(u32, 2), table.get(a).references);
    // Namespace and prefix make other names; the namespace string of a
    // named namespace stays Infra's.
    const ns = try intern(&scope, infra.namespaces.SVG_NAMESPACE, "p", "data-a");
    try std.testing.expect(ns != a);
    try std.testing.expect(table.get(ns).namespace_uri.?.ptr == infra.namespaces.SVG_NAMESPACE.ptr);
    try std.testing.expectEqual(@sizeOf(QualifiedName) + "data-a".len + "p".len, blockSize(table.get(ns)));
    // A static name never reaches the table.
    try std.testing.expect((try intern(&scope, null, null, "class")).isStatic());
    try std.testing.expectEqual(@as(usize, 2), table.count());

    release(&scope, a);
    release(&scope, a);
    try std.testing.expectEqual(@as(usize, 1), table.count());
    // The freed slot is the next name's.
    const b = try intern(&scope, null, null, "data-b");
    try std.testing.expectEqual(a.slot(), b.slot());
    if (debug_checks) try std.testing.expect(a != b);
    try std.testing.expectEqualStrings("data-b", record(table, b).local_name);
    release(&scope, b);
    release(&scope, ns);
    try std.testing.expectEqual(@as(usize, 0), table.count());
}

test "names that come and go keep the table small" {
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    defer scope.deinit();
    var live: [100]NameId = undefined;
    var buffer: [24]u8 = undefined;
    for (&live, 0..) |*slot, i| slot.* = try intern(&scope, null, null, try std.fmt.bufPrint(&buffer, "data-{d}", .{i}));
    const table = scope.existingTable(.attribute_names, Table).?;
    for (100..20_100) |i| {
        const at = i % live.len;
        release(&scope, live[at]);
        live[at] = try intern(&scope, null, null, try std.fmt.bufPrint(&buffer, "data-{d}", .{i}));
    }
    // Ids stay dense: the slots never outgrow the names alive at once.
    try std.testing.expectEqual(@as(usize, 100), table.ids.len());
    try std.testing.expect(table.records.capacity() <= 256);
    for (live) |id| release(&scope, id);
    try std.testing.expectEqual(@as(usize, 0), table.count());
}
