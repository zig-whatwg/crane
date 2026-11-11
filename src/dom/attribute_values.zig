//! Attribute values as counted, interned per-Browser records (lane nd2
//! batch 2, A1; the integrator's decision of 2026-11-10 19:41 UTC, after
//! A1's first shape - value bytes packed in the element's attribute block -
//! was shown to dangle every value view when the block grew).
//!
//! An attribute's entry (dom.element_data) is {name id, value id}, 8 bytes,
//! and its value is ONE record its Browser shares among every attribute
//! that has that value now: the browsers' shape.
//!
//! - Blink: `Attribute` is a `QualifiedName name_` and an `AtomicString
//!   value_` (core/dom/attribute.h), and the parser makes every value an
//!   AtomicString whatever its length (html_token.h `GetValue()` ->
//!   literal_buffer.h `AsAtomicString()`), interned in the AtomicStringTable
//!   (platform/wtf/text/atomic_string_table.h: a HashSet of StringImpl* the
//!   string leaves when its last reference goes).
//! - WebKit: `Attribute` is a QualifiedName and an `AtomString m_value`
//!   (Source/WebCore/dom/Attribute.h:38-67), atomized at any length.
//! - Gecko: nsAttrValue atomizes ids, class lists, `lang`, `for`, `form`
//!   (Element::ParseAttribute, dom/base/Element.cpp) and, through
//!   ParseStringOrAtom, values of 1 to 12 characters
//!   (NS_ATTRVALUE_MAX_STRINGLENGTH_ATOM, nsAttrValue.h:99,
//!   nsAttrValue.cpp:1456-1466); any other value is a refcounted
//!   StringBuffer (nsAttrValue::SetTo, nsAttrValue.cpp:408), which a clone
//!   shares and which script's string can hand over without a copy.
//!
//! Every value is interned here, whatever its length: two of the three
//! browsers do (golden rule 2: the browsers differ and no newer spec is
//! involved, so the majority), and Gecko's limit does not carry over.
//! Gecko keeps a long value as a buffer it SHARES with the string it came
//! from - JS strings and the parser's are nsStringBuffers already - so an
//! atom would add a hash and a table entry to a copy it otherwise skips.
//! Crane copies every value it stores (V8's strings are not Crane's), so a
//! long value pays the copy anyway, and interning adds only the hash (one
//! pass over bytes just copied), an 8-byte record header, an 8-byte id slot
//! and one map slot (5 bytes: a u32 key and its metadata byte) - while long
//! values repeat on the pages that matter: the class strings of
//! framework-built pages ("btn btn-primary ...": 17-28 distinct `class`
//! values in 2,011-3,010 on the React, Vue, Preact and jQuery pages,
//! tmp/redesign/nodedata/framework-pages.md table F and note 2) are mostly
//! longer than 12 bytes, and Gecko itself atomizes them as class lists.
//!
//! The rules are dom.element_name's (lane nd2 batch 1-fix): a record is
//! COUNTED - each attribute whose entry names it holds one reference, and a
//! holder that keeps a value across a point where script can run takes one
//! more for that span (`Hold`); the table is WEAK and the last release frees
//! the record at once, on the Browser's window agent's thread; the count is
//! checked for overflow and underflow in every build; records come from the
//! Browser's general allocator through its raw entry point (written in full
//! at once: review zig/report.md Z5), never the state arena. The empty value
//! is id 0 and has no record (Gecko stores "" without an allocation too).
//!
//! A value VIEW - the bytes a reader is handed - is the record's bytes:
//! stable while the record is counted, so a growth of the element's
//! attribute block (which moves ids, never bytes) cannot dangle it. A view
//! is valid until its attribute's value next changes or the attribute goes,
//! as it was when each value was its own allocation; a reader that only
//! reads within its own step borrows it, and a holder across a point where
//! script can run holds it (`Hold`).
//!
//! An id is the record's slot in a dense array (attribute_names.IdSlots),
//! reused from a free list; a Debug build stamps the slot's generation into
//! the id, so a stale id panics.
//!
//! Spec: https://dom.spec.whatwg.org/#concept-attribute-value

const std = @import("std");
const builtin = @import("builtin");
const infra = @import("infra");
const runtime = @import("runtime");
const attribute_names = @import("attribute_names.zig");
const element_name = @import("element_name.zig");

const debug_checks = builtin.mode == .debug;

/// An attribute value: 0 for the empty string, else a counted reference to
/// a record of its Browser's table.
///
/// Bits 30 and 31 are two facts of the value's bytes, so one record always
/// has one id and a class check reads them with no table load (lane nd2
/// batch 3): bit 31, the value is ONE token - not empty, no ASCII whitespace
/// - so its classes are itself (Blink's SpaceSplitString::Data::CreateVector
/// pushes the source atom itself when one token spans the string; WebKit's
/// TokenAtomStringInitializer reuses the key string the same way); bit 30,
/// it has no ASCII upper-case letter, so it is its own ASCII lowercase
/// (Blink's ContainsNoAsciiUpper, which SetClassFoldingCase checks before
/// folding). In a Debug build bits 22-29 are its slot's generation.
pub const ValueId = enum(u32) {
    empty = 0,
    _,

    const one_token_bit: u32 = 1 << 31;
    const lowercase_bit: u32 = 1 << 30;
    const flag_bits: u32 = one_token_bit | lowercase_bit;
    const generation_shift = 22;
    const index_bits: u32 = if (debug_checks) generation_shift else 30;
    const index_mask: u32 = (@as(u32, 1) << index_bits) - 1;
    /// The slots a table may hold (slot + 1 must fit the index bits).
    pub const limit: usize = index_mask - 1;

    fn of(slot_index: u32, slot_generation: u8, flags: u32) ValueId {
        const stamp: u32 = if (debug_checks) @as(u32, slot_generation) << generation_shift else 0;
        return @fromBackingInt(@intCast(flags | stamp | (slot_index + 1)));
    }

    /// Its slot: the low bits less one. Subtracting before masking never
    /// borrows from the flags or the generation (slot + 1 is at least 1 and
    /// fits the index bits), and a caller that has ruled out .empty needs no
    /// underflow check.
    fn slot(self: ValueId) u32 {
        return (@backingInt(self) - 1) & index_mask;
    }

    fn generation(self: ValueId) u8 {
        return if (debug_checks) @truncate(@backingInt(self) >> generation_shift) else 0;
    }

    /// The value is one token: its classes are itself.
    pub inline fn isOneToken(self: ValueId) bool {
        return @backingInt(self) & one_token_bit != 0;
    }

    /// The value has no ASCII upper-case letter (the empty value included).
    pub inline fn isLowercase(self: ValueId) bool {
        return self == .empty or @backingInt(self) & lowercase_bit != 0;
    }

    /// The two flags of `bytes`, at a record's creation: 16 bytes a step,
    /// as masks OR-ed together and reduced once (a byte-by-byte loop cost a
    /// new 300-B value ~4,300 instructions - the cost pair's matches-churn
    /// row, 2026-11-11; this is under one instruction a byte). A value
    /// under 16 bytes is read through a zero-padded copy (a zero byte is
    /// neither whitespace nor upper case), the last partial step through an
    /// overlapping load (OR-ing a byte twice changes nothing).
    ///
    /// Every load is inside `bytes`: under 16 bytes, only `bytes.len` bytes
    /// are copied (into `padded`, whose other bytes stay zero) and the copy is
    /// what is read; from 16 bytes on, each step reads `bytes[at..at + 16]`
    /// with `at + 16 <= bytes.len`, and the tail step `bytes[len - 16..len]`
    /// starts at `len - 16 >= 0` - both slices bounds-checked in safe builds
    /// (the bug-finding runner's, the tests'). The vectors are portable
    /// (@Vector: NEON on aarch64, SSE2 on x86-64); the unit test compares
    /// both against a byte-by-byte reading on each pool host.
    fn flagsOf(bytes: []const u8) u32 {
        const V = @Vector(16, u8);
        var whitespace: V = @splat(0);
        var upper: V = @splat(0);
        if (bytes.len < 16) {
            var padded: [16]u8 = @splat(0);
            @memcpy(padded[0..bytes.len], bytes);
            scan(padded, &whitespace, &upper);
        } else {
            var at: usize = 0;
            while (at + 16 <= bytes.len) : (at += 16) scan(bytes[at..][0..16].*, &whitespace, &upper);
            if (at != bytes.len) scan(bytes[bytes.len - 16 ..][0..16].*, &whitespace, &upper);
        }
        const one_token = bytes.len != 0 and @reduce(.Or, whitespace) == 0;
        const lowercase = @reduce(.Or, upper) == 0;
        return (if (one_token) one_token_bit else 0) | (if (lowercase) lowercase_bit else 0);
    }

    /// OR into the masks 0xFF for each of `chunk`'s bytes that is Infra's
    /// ASCII whitespace (SPACE, or 0x09-0x0D but VT 0x0B) or an ASCII upper
    /// case letter.
    inline fn scan(chunk: [16]u8, whitespace: *@Vector(16, u8), upper: *@Vector(16, u8)) void {
        const V = @Vector(16, u8);
        const v: V = chunk;
        const ones: V = @splat(0xFF);
        const zeros: V = @splat(0);
        const space = @select(u8, v == @as(V, @splat(' ')), ones, zeros);
        const controls = @select(u8, (v -% @as(V, @splat(0x09))) < @as(V, @splat(5)), ones, zeros);
        const vt = @select(u8, v == @as(V, @splat(0x0B)), ones, zeros);
        whitespace.* |= space | (controls & ~vt);
        upper.* |= @select(u8, (v -% @as(V, @splat('A'))) < @as(V, @splat(26)), ones, zeros);
    }
};

/// Infra's ASCII whitespace: TAB, LF, FF, CR, SPACE - not VT (lesson
/// spec-compliance-infra-ascii-whitespace-is-not-std-ascii-iswhitespace).
fn isAsciiWhitespace(c: u8) bool {
    return c == ' ' or c == '\t' or c == '\n' or c == '\r' or c == 0x0C;
}

/// The longest value a record holds: its length shares 32 bits with its
/// id's two flags. A longer one is error.OutOfMemory, as one past 4 GiB
/// was before.
pub const max_value_bytes: usize = (1 << 30) - 1;

/// One value: this 8-byte header, then its bytes, in one block. Its id and
/// hash are not kept: the map is keyed by slot and hashes a record's bytes
/// when it grows or removes one (a long value's hash is one pass over bytes
/// that were just copied); 8 bytes a record less matter more - most values
/// are short (crane-layout.md: 20-54% of them 1-8 bytes), and a record of up
/// to 8 bytes fits malloc's 16-byte class.
pub const Value = extern struct {
    /// The attributes whose entries name it, and the holders that took one
    /// (`Hold`). Written only by its table, on its Browser's window agent's
    /// thread.
    references: u32,
    /// Its length in bytes (bits 0-29) and its id's two flags (bits 30-31,
    /// `ValueId`'s).
    len_and_flags: u32,

    comptime {
        std.debug.assert(@sizeOf(Value) == 8);
    }

    /// Its length in bytes.
    pub inline fn len(self: *const Value) u32 {
        return self.len_and_flags & ~ValueId.flag_bits;
    }

    fn flags(self: *const Value) u32 {
        return self.len_and_flags & ValueId.flag_bits;
    }

    /// Whether a class read can give it a ClassNames: not when it is ONE
    /// token with no upper-case letter - its classes are itself and its
    /// fold is itself, so a list would hold nothing (`makeClassNames` is
    /// never asked for one). A plain attribute write (`el.id = 'x'`,
    /// `data-k`) then parks, revives and frees its record with no lookup of
    /// the lists (the cost pair's setter and set/get rows, 2026-11-11).
    inline fn mayHaveClassNames(self: *const Value) bool {
        return self.flags() != ValueId.flag_bits;
    }

    /// Its bytes, borrowed while it is counted.
    pub inline fn bytes(self: *const Value) []const u8 {
        const base: [*]const u8 = @ptrCast(self);
        return base[@sizeOf(Value)..][0..self.len()];
    }

    fn blockSize(self: *const Value) usize {
        return @sizeOf(Value) + self.len();
    }
};

/// What class reads make of a value, once: Blink's SpaceSplitString::Data
/// (core/dom/space_split_string.{h,cc}, one per AtomicString in a shared
/// map) and WebKit's SpaceSplitStringData (Source/WebCore/dom/
/// SpaceSplitString.{h,cpp}, one per AtomString in spaceSplitStringTable).
/// Here it is the value record's own: its table keeps it by the record's
/// slot (`Table.class_names`), makes it on the record's first class read -
/// the class selector, classList, getElementsByClassName - and frees it with
/// the record; a parked record keeps it, so a value the ring revives comes
/// back with its tokens.
///
/// Its tokens are DOM's ordered set parser over the value (split on ASCII
/// whitespace, each token once, in first-seen order: Blink's CreateVector
/// with its HashSet past the second token), each a COUNTED reference to that
/// token's own record - the same table, as Blink's tokens are AtomicStrings
/// of the AtomicStringTable its values are. A one-token value has none
/// (`ValueId.isOneToken`: its token is itself). After a quirks-mode read it
/// also counts the record of the value ASCII-lowercased (Blink's
/// ElementData::SetClassFoldingCase, WebKit's ShouldFoldCase::Yes), whose
/// own tokens are the folded ones.
pub const ClassNames = extern struct {
    /// How many tokens follow.
    len: u32,
    /// The ASCII-lowercase value's record, counted; .empty until a
    /// quirks-mode read needs it (a value with no upper-case letter is its
    /// own).
    folded: ValueId,

    comptime {
        std.debug.assert(@sizeOf(ClassNames) == 8);
    }

    /// The tokens, each a counted one-token record.
    pub fn tokens(self: *const ClassNames) []const ValueId {
        const base: [*]const u8 = @ptrCast(self);
        const first: [*]const ValueId = @ptrCast(@alignCast(base + @sizeOf(ClassNames)));
        return first[0..self.len];
    }

    fn blockSize(len: usize) usize {
        return @sizeOf(ClassNames) + len * @sizeOf(ValueId);
    }
};

fn hashOf(bytes: []const u8) u64 {
    return std.hash.Wyhash.hash(0, bytes);
}

/// The map's keys are slots (u32, 4 bytes a key); a slot's hash is its
/// record's bytes'.
const SlotContext = struct {
    ids: *const attribute_names.IdSlots(Value),
    pub fn hash(ctx: SlotContext, slot: u32) u64 {
        return hashOf(ctx.ids.get(slot).bytes());
    }
    pub fn eql(_: SlotContext, a: u32, b: u32) bool {
        return a == b;
    }
};

/// A lookup by bytes, with the hash computed once.
const BytesKey = struct {
    bytes: []const u8,
    hash: u64,
};

const KeyAdapter = struct {
    table: *const Table,
    /// Where `eql` leaves the record it found equal: the found path takes
    /// its count and its id's flags from there, with no second read of the
    /// slot (after eqlBytes the compiler must reload the slot array and
    /// check it again: ~10 instructions an attribute write, the cost pair
    /// 2026-11-11).
    found: *?*Value,
    pub fn hash(_: KeyAdapter, key: BytesKey) u64 {
        return key.hash;
    }
    /// Inline: run on every probed slot of every attribute write; out of
    /// line it cost a call, a frame and two reloads a probe (the cost pair,
    /// 2026-11-11). Its read of the record is counted (`Table.recordAt`).
    pub inline fn eql(adapter: KeyAdapter, key: BytesKey, slot: u32) bool {
        const value = adapter.table.recordAt(slot);
        if (value.len() != key.bytes.len or !std.mem.eql(u8, value.bytes(), key.bytes)) return false;
        adapter.found.* = value;
        return true;
    }
};

/// A Browser's attribute values (its BrowserScope's `.attribute_values`
/// table, made on first use): one COUNTED record per distinct non-empty
/// value an attribute of the Browser has now. WEAK: a record's last release
/// removes it, frees it and frees its slot. Its window agent's thread only,
/// so no lock.
pub const Table = struct {
    allocator: std.mem.Allocator,
    records: Map = .empty,
    ids: attribute_names.IdSlots(Value) = .{},
    /// When to drop the tombstones removals leave (infra.tombstones' rule).
    tombstones: Tombstones = .{},
    /// The bytes of the records alive (headers included): a measurement.
    bytes_held: usize = 0,
    /// The PARKED records: their last reference went, and they wait here,
    /// still in the map, for a value that comes back (oldest first). See
    /// `Parking`.
    parked: Parking = .{},
    /// Each record's ClassNames by its slot, made on its first class read
    /// (null: none yet). Grown on demand to the highest slot read; a freed
    /// record's goes with it.
    class_names: std.ArrayListUnmanaged(?*ClassNames) = .empty,
    /// The slots whose record a class selector's operand names (a compiled
    /// selector keeps the id with no count: `operandOf`). A set bit is
    /// cleared, and `operand_frees` moves, when that record is freed.
    operand_slots: std.DynamicBitSetUnmanaged = .{},
    /// How many records a class selector's operand named were freed: a
    /// selector's cached id is valid while this has not moved since it was
    /// read. 64 bits, never reset and never narrowed - a wrap would make a
    /// stale id look valid. Only those records move it, so the values a
    /// page churns (style, data-*, aria writes, freed at once past the
    /// ring's per-record cap) leave every selector's ids valid.
    operand_frees: u64 = 0,
    /// Measurements: the passes class reads made over class values' bytes
    /// (a split, or a byte compare), and the ClassNames alive and their
    /// bytes.
    class_scans: usize = 0,
    class_lists: usize = 0,
    class_bytes: usize = 0,
    /// Debug: the records read by their slot (`recordAt`), for the tests
    /// that pin how many reads a step takes.
    slot_reads: if (debug_checks) usize else void = if (debug_checks) 0 else {},
    /// Debug: the lookups of a slot's ClassNames (`classNamesAt`), for the
    /// tests that pin which steps look.
    class_names_reads: if (debug_checks) usize else void = if (debug_checks) 0 else {},

    const Map = std.HashMapUnmanaged(u32, void, SlotContext, 80);

    /// infra.tombstones.TombstoneGuard's rule - removals counted since the
    /// map last had no tombstones; past half its unused slots, the next
    /// insert rehashes it in place - for a map whose context has state,
    /// which that guard cannot rehash (it makes a stateless context).
    const Tombstones = struct {
        removals: usize = 0,
        /// The capacity the count belongs to: a map that grew since has no
        /// tombstones.
        capacity: usize = 0,

        fn noteRemoval(self: *Tombstones, map: *Map) void {
            self.sync(map);
            self.removals += 1;
        }

        fn beforeInsert(self: *Tombstones, map: *Map, ctx: SlotContext) void {
            self.sync(map);
            if (self.removals == 0) return;
            if (self.removals * 2 < map.capacity() - map.count()) return;
            map.rehash(ctx);
            self.removals = 0;
        }

        fn reset(self: *Tombstones) void {
            self.removals = 0;
        }

        fn sync(self: *Tombstones, map: *Map) void {
            if (map.capacity() == self.capacity) return;
            self.capacity = map.capacity();
            self.removals = 0;
        }
    };

    /// Below this many slots an emptied map keeps its storage.
    const kept_capacity = 64;

    /// Where a record whose count reached zero waits, bounded, before it is
    /// freed (the integrator's ruling, 2026-11-10 21:41 UTC). A value an
    /// attribute cycles through - `el.id = i & 1 ? 'x' : 'y'`, a classList
    /// toggle, setAttribute over a handful of values - would otherwise go
    /// through a free, a map removal, a malloc and a map insert on every
    /// change (the cost pair measured +18-26% against main's dupe and free).
    /// Gecko is the precedent: an nsDynamicAtom whose count reaches zero
    /// stays in its table, and only past kAtomGCThreshold unused atoms (10,000;
    /// 20 in DEBUG) are they swept (xpcom/ds/nsAtom.h:177-193,
    /// nsAtomTable.cpp:547). Blink and WebKit free an AtomString at its last
    /// reference, at once. Crane takes Gecko's reuse and none of its sweep:
    /// at most `max_records` records and `max_bytes` bytes wait; a record of
    /// more than `max_record_bytes` never waits (a page cannot park
    /// megabytes); a full ring frees its OLDEST record - one, synchronously,
    /// on the owning thread - and the table's end frees the rest. A record
    /// the ring holds is never counted: an intern that finds it takes it out.
    const Parking = struct {
        slots: [max_records]u32 = undefined,
        len: usize = 0,
        /// The parked records' bytes, headers included.
        bytes: usize = 0,

        pub const max_records = 256;
        pub const max_bytes = 16 * 1024;
        pub const max_record_bytes = 256;

        fn indexOf(self: *const Parking, slot: u32) ?usize {
            var i = self.len;
            while (i > 0) {
                i -= 1;
                if (self.slots[i] == slot) return i;
            }
            return null;
        }

        /// Take out the record at `index`; the younger ones move down one,
        /// in order. One range check covers the shift (every index in it is
        /// under `len`, so under `max_records`): the slice copy it replaces
        /// paid a dozen bounds checks even when nothing moved - reviving the
        /// newest record, an `el.id = 'x' / 'y'` toggle (the cost pair's
        /// setter row, 2026-11-11).
        fn removeAt(self: *Parking, index: usize) u32 {
            const len = self.len;
            if (index >= len or len > max_records) @panic("an attribute value ring index out of range");
            const slot = self.slots[index];
            var at = index + 1;
            while (at < len) : (at += 1) self.slots[at - 1] = self.slots[at];
            self.len = len - 1;
            return slot;
        }
    };

    pub fn init(allocator: std.mem.Allocator) Table {
        return .{ .allocator = allocator };
    }

    fn context(self: *const Table) SlotContext {
        return .{ .ids = &self.ids };
    }

    /// The table's end, with its Browser's scope: every record still in it
    /// (an engine-less test's element no teardown reached), the map, the
    /// slots.
    pub fn deinit(self: *Table) void {
        var keys = self.records.keyIterator();
        while (keys.next()) |slot| destroy(self.allocator, self.ids.get(slot.*));
        // Every record is gone: the lists' references with them.
        for (self.class_names.items) |names| if (names) |n| destroyClassNames(self.allocator, n);
        self.class_names.deinit(self.allocator);
        self.operand_slots.deinit(self.allocator);
        self.records.deinit(self.allocator);
        self.ids.deinit(self.allocator);
    }

    /// How many distinct values the table holds, the parked included.
    pub fn count(self: *const Table) usize {
        return self.records.count();
    }

    /// How many records an attribute or a holder counts now.
    pub fn liveCount(self: *const Table) usize {
        return self.records.count() - self.parked.len;
    }

    /// The parked records and their bytes (headers included).
    pub fn parkedRecords(self: *const Table) usize {
        return self.parked.len;
    }

    pub fn parkedBytes(self: *const Table) usize {
        return self.parked.bytes;
    }

    /// The record `id` names, checked: a freed slot, or (Debug) a slot freed
    /// and reused since the id was handed out, panics.
    pub inline fn get(self: *const Table, id: ValueId) *const Value {
        const slot = id.slot();
        if (debug_checks and self.ids.generation(slot) != id.generation()) @panic("a stale attribute value id");
        return self.recordAt(slot);
    }

    /// The record in `slot` (counted in Debug: `slot_reads`).
    inline fn recordAt(self: *const Table, slot: u32) *Value {
        if (debug_checks) @constCast(self).slot_reads += 1;
        return self.ids.get(slot);
    }

    /// The id of `bytes`' record, parked or counted, without a reference;
    /// null when there is none (and .empty for "").
    pub fn find(self: *const Table, bytes: []const u8) ?ValueId {
        if (bytes.len == 0) return .empty;
        const key: BytesKey = .{ .bytes = bytes, .hash = hashOf(bytes) };
        var found: ?*Value = null;
        const slot = self.records.getKeyAdapted(key, KeyAdapter{ .table = self, .found = &found }) orelse return null;
        return ValueId.of(slot, self.ids.generation(slot), found.?.flags());
    }

    /// `id`'s bytes.
    pub inline fn bytesOf(self: *const Table, id: ValueId) []const u8 {
        if (id == .empty) return "";
        return self.get(id).bytes();
    }

    /// A counted reference to the record of `bytes`, made the first time
    /// they are asked for; .empty for "". The caller keeps it until its
    /// `release`.
    pub fn intern(self: *Table, bytes: []const u8) error{OutOfMemory}!ValueId {
        if (bytes.len == 0) return .empty;
        const key: BytesKey = .{ .bytes = bytes, .hash = hashOf(bytes) };
        var found: ?*Value = null;
        if (self.records.getKeyAdapted(key, KeyAdapter{ .table = self, .found = &found })) |slot| {
            // One read of the record - the compare's: its count and its id's
            // flags.
            const value: *Value = found.?;
            // A parked record comes back: out of the ring, with its id.
            if (value.references == 0) self.unpark(slot, value);
            if (value.references == std.math.maxInt(u32)) @panic("an attribute value record's count overflowed");
            value.references += 1;
            return ValueId.of(slot, self.ids.generation(slot), value.flags());
        }
        self.tombstones.beforeInsert(&self.records, self.context());
        try self.records.ensureUnusedCapacityContext(self.allocator, 1, self.context());
        const value = try create(self.allocator, bytes);
        errdefer destroy(self.allocator, value);
        const slot = try self.ids.take(self.allocator, value, ValueId.limit);
        // Placed by the hash already computed: one pass over the bytes.
        const placed = self.records.getOrPutAssumeCapacityAdapted(key, KeyAdapter{ .table = self, .found = &found });
        if (debug_checks and placed.found_existing) @panic("an attribute value record interned twice");
        placed.key_ptr.* = slot;
        self.bytes_held += value.blockSize();
        return ValueId.of(slot, self.ids.generation(slot), value.flags());
    }

    /// One more reference to `id` (none for .empty), checked for overflow in
    /// every build.
    pub fn retain(self: *Table, id: ValueId) void {
        if (id == .empty) return;
        const value: *Value = @constCast(self.get(id));
        if (value.references == std.math.maxInt(u32)) @panic("an attribute value record's count overflowed");
        value.references += 1;
    }

    /// Drop one reference to `id` (none for .empty); the last parks the
    /// record (`Parking`), or frees it now when it is too big to wait.
    pub fn release(self: *Table, id: ValueId) void {
        if (id == .empty) return;
        const value: *Value = @constCast(self.get(id));
        if (value.references == 0) @panic("an attribute value record released more often than it was kept");
        value.references -= 1;
        if (value.references != 0) return;
        self.park(id.slot(), value);
    }

    /// A record whose count reached zero: parked, or freed now when it is
    /// too big to wait. A full ring frees its oldest first (`Parking`). A
    /// record's size here is its block and its ClassNames' (which it keeps
    /// while parked), so the ring's bounds hold both.
    fn park(self: *Table, slot: u32, value: *Value) void {
        const size = self.parkedSize(slot, value);
        if (size > Parking.max_record_bytes) return self.free(slot, value);
        // A freed record's list releases its tokens, which can park (and
        // evict) in turn: the loop re-reads the ring each time round.
        while (self.parked.len == Parking.max_records or self.parked.bytes + size > Parking.max_bytes) {
            const oldest = self.parked.removeAt(0);
            const evicted: *Value = self.recordAt(oldest);
            self.parked.bytes -= self.parkedSize(oldest, evicted);
            self.free(oldest, evicted);
        }
        self.parked.slots[self.parked.len] = slot;
        self.parked.len += 1;
        self.parked.bytes += size;
    }

    /// What a parked record weighs: its block and its ClassNames. A parked
    /// record's ClassNames never change (only a counted record is read as
    /// classes: `classNames`), so parking and unparking agree.
    fn parkedSize(self: *const Table, slot: u32, value: *const Value) usize {
        if (!value.mayHaveClassNames()) return value.blockSize();
        const names = self.classNamesAt(slot) orelse return value.blockSize();
        return value.blockSize() + ClassNames.blockSize(names.len);
    }

    /// A parked record an intern found: out of the ring.
    fn unpark(self: *Table, slot: u32, value: *const Value) void {
        const index = self.parked.indexOf(slot) orelse @panic("an attribute value record with no reference was not parked");
        _ = self.parked.removeAt(index);
        self.parked.bytes -= self.parkedSize(slot, value);
    }

    /// Free a record with no reference: out of the map (which hashes its
    /// bytes to find its slot) first, then the slot, then the block - and
    /// then its ClassNames, whose tokens' releases may park or free other
    /// records, against a table that no longer has this one.
    fn free(self: *Table, slot: u32, value: *Value) void {
        if (debug_checks and value.references != 0) @panic("a counted attribute value record freed");
        const names = if (value.mayHaveClassNames()) self.takeClassNames(slot) else null;
        if (slot < self.operand_slots.bit_length and self.operand_slots.isSet(slot)) {
            // A class selector's cached id named this record: every such id
            // is stale from now on (`operand_frees`).
            self.operand_slots.unset(slot);
            self.operand_frees +%= 1;
        }
        const removed = self.records.removeContext(slot, self.context());
        if (debug_checks and !removed) @panic("a released attribute value record was not in its Browser's table");
        self.ids.give(slot);
        self.bytes_held -= value.blockSize();
        destroy(self.allocator, value);
        self.afterRemove();
        if (names) |n| self.releaseClassNames(n);
    }

    // ------------------------------------------------------------------
    // Class reads (lane nd2 batch 3)
    // ------------------------------------------------------------------

    /// `slot`'s ClassNames, if a class read made them.
    inline fn classNamesAt(self: *const Table, slot: u32) ?*ClassNames {
        if (debug_checks) @constCast(self).class_names_reads += 1;
        if (slot >= self.class_names.items.len) return null;
        return self.class_names.items[slot];
    }

    /// Take `slot`'s ClassNames out of the table (its record is going).
    fn takeClassNames(self: *Table, slot: u32) ?*ClassNames {
        const names = self.classNamesAt(slot) orelse return null;
        self.class_names.items[slot] = null;
        self.class_lists -= 1;
        self.class_bytes -= ClassNames.blockSize(names.len);
        return names;
    }

    /// Let go of a ClassNames' references and free it.
    fn releaseClassNames(self: *Table, names: *ClassNames) void {
        // The block is out of the table: the releases (which can free other
        // records and their lists) never reach it.
        for (names.tokens()) |token| self.release(token);
        self.release(names.folded);
        destroyClassNames(self.allocator, names);
    }

    /// The ClassNames of value `id` (a counted record), made on its first
    /// class read: Blink's SpaceSplitString::Data::Create, WebKit's
    /// SpaceSplitStringData::create - the value split once, whatever reads it
    /// after.
    pub fn classNames(self: *Table, id: ValueId) error{OutOfMemory}!*const ClassNames {
        if (self.classNamesAt(id.slot())) |names| return names;
        return self.makeClassNames(id);
    }

    /// DOM's ordered set parser over `id`'s bytes ("split on ASCII
    /// whitespace", then each token appended unless the set has it), every
    /// token interned. Interning never frees a record, so the bytes being
    /// split - the record's own - stay put throughout.
    fn makeClassNames(self: *Table, id: ValueId) error{OutOfMemory}!*ClassNames {
        const slot = id.slot();
        const value = self.get(id);
        // Only a counted record is read as classes (an element's value, a
        // DOMTokenList's own): a parked record's size must not change.
        if (debug_checks and value.references == 0) @panic("a class read of a value no attribute holds");
        // Checked in every build: park, revive and free skip the lists of a
        // value that may have none (`Value.mayHaveClassNames`), so a list
        // made for one would outlive its record. Every caller asks only for
        // a value of several tokens or with an upper-case letter.
        if (!value.mayHaveClassNames()) @panic("a token list asked for a lowercase one-token value");
        if (slot >= self.class_names.items.len) try self.class_names.appendNTimes(self.allocator, null, slot + 1 - self.class_names.items.len);
        self.class_scans += 1;

        var tokens: std.ArrayListUnmanaged(ValueId) = .empty;
        defer tokens.deinit(self.allocator);
        errdefer for (tokens.items) |token| self.release(token);
        // Past `small_set` tokens a set finds the duplicates (Blink's
        // CreateVector keeps a HashSet once a second distinct token comes),
        // so a value of n tokens splits in O(n).
        const small_set = 8;
        var seen: std.AutoHashMapUnmanaged(ValueId, void) = .empty;
        defer seen.deinit(self.allocator);
        if (!id.isOneToken()) {
            var it = std.mem.tokenizeAny(u8, value.bytes(), " \t\n\r\x0C");
            while (it.next()) |text| {
                const token = try self.intern(text);
                const duplicate = if (tokens.items.len < small_set)
                    std.mem.indexOfScalar(ValueId, tokens.items, token) != null
                else blk: {
                    if (seen.count() == 0) for (tokens.items) |t| try seen.put(self.allocator, t, {});
                    break :blk (try seen.getOrPut(self.allocator, token)).found_existing;
                };
                if (duplicate) {
                    self.release(token);
                    continue;
                }
                tokens.append(self.allocator, token) catch |err| {
                    self.release(token);
                    return err;
                };
            }
        }
        const size = ClassNames.blockSize(tokens.items.len);
        const memory = self.allocator.rawAlloc(size, .of(ClassNames), @returnAddress()) orelse return error.OutOfMemory;
        const names: *ClassNames = @ptrCast(@alignCast(memory));
        names.* = .{ .len = @intCast(tokens.items.len), .folded = .empty };
        @memcpy(@constCast(names.tokens()), tokens.items);
        tokens.clearRetainingCapacity();
        self.class_names.items[slot] = names;
        self.class_lists += 1;
        self.class_bytes += size;
        return names;
    }

    /// Whether value `id`'s classes include `token` - a one-token record's
    /// id (or .empty, which no class is). id == id: a one-token value is its
    /// own class, any other value's are its list's (Blink's
    /// Data::Contains, a scan of the vector).
    pub fn hasToken(self: *Table, id: ValueId, token: ValueId) error{OutOfMemory}!bool {
        // The same record: a class only if it is one token (a value of
        // several is no token of itself; .empty is none).
        if (id == token) return id.isOneToken();
        if (id.isOneToken() or id == .empty) return false;
        const names = try self.classNames(id);
        return std.mem.indexOfScalar(ValueId, names.tokens(), token) != null;
    }

    /// `hasToken` in a quirks-mode document: `folded_token` is the class
    /// name ASCII-lowercased (`operandOf(.., true)`), compared with the
    /// tokens of `id` ASCII-lowercased (`foldedOf`) - Blink's
    /// SetClassFoldingCase and CSSSelector::SetValue(value,
    /// match_lower_case), then the same identity compare.
    pub fn hasFoldedToken(self: *Table, id: ValueId, folded_token: ValueId) error{OutOfMemory}!bool {
        if (id == .empty) return false;
        return self.hasToken(try self.foldedOf(id), folded_token);
    }

    /// The record of `id`'s value ASCII-lowercased: itself when it has no
    /// upper-case letter, else made on the first quirks-mode read and
    /// counted by `id`'s ClassNames (Blink's ContainsNoAsciiUpper check,
    /// then ToAsciiLower).
    pub fn foldedOf(self: *Table, id: ValueId) error{OutOfMemory}!ValueId {
        if (id.isLowercase()) return id;
        const names: *ClassNames = @constCast(try self.classNames(id));
        if (names.folded != .empty) return names.folded;
        var buffer: [256]u8 = undefined;
        var scratch: std.heap.BufferFirstAllocator = .init(&buffer, self.allocator);
        const allocator = scratch.allocator();
        const bytes = self.get(id).bytes();
        const lower = try allocator.alloc(u8, bytes.len);
        defer allocator.free(lower);
        _ = std.ascii.lowerString(lower, bytes);
        // Interning never frees, so `names` stays this record's.
        names.folded = try self.intern(lower);
        return names.folded;
    }

    /// A class name's id for a check of many elements' tokens (a class
    /// selector's operand, getElementsByClassName's names), with NO count
    /// kept - .empty when the name can be no token (empty, or holding ASCII
    /// whitespace: Blink's token vector never holds such a name, so `.a\ b`
    /// matches no element), null when it cannot be kept as an id (too long
    /// to wait in the ring: compare bytes). `folded` (quirks mode): the name
    /// ASCII-lowercased.
    ///
    /// The record is made if it is missing and then released: parked when no
    /// attribute has it - so a token list made later finds this record and
    /// this id - and marked (`operand_slots`), so its free moves
    /// `operand_frees`. A caller keeps the id only while `operand_frees` has
    /// not moved; a caller that reads no other record's value in between
    /// (getElementsByClassName's refill) may use it at once.
    pub fn operandOf(self: *Table, name: []const u8, folded: bool) error{OutOfMemory}!?ValueId {
        if (name.len == 0) return .empty;
        const flags = ValueId.flagsOf(name);
        if (flags & ValueId.one_token_bit == 0) return .empty;
        // Past the ring's per-record cap the record would be freed at its
        // release (room left for a ClassNames block a one-token record can
        // have: its folded record's link).
        if (@sizeOf(Value) + name.len + @sizeOf(ClassNames) > Parking.max_record_bytes) return null;
        var buffer: [Parking.max_record_bytes]u8 = undefined;
        const text = if (folded and flags & ValueId.lowercase_bit == 0) std.ascii.lowerString(buffer[0..name.len], name) else name;
        const id = try self.intern(text);
        const slot = id.slot();
        if (slot >= self.operand_slots.bit_length) {
            self.operand_slots.resize(self.allocator, @max(slot + 1, self.operand_slots.bit_length * 2), false) catch |err| {
                self.release(id);
                return err;
            };
        }
        self.operand_slots.set(slot);
        // Parked (a one-token record has no ClassNames, so it fits the
        // per-record cap checked above) or still counted elsewhere: it
        // stays until a free moves `operand_frees`.
        self.release(id);
        return id;
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
        smaller.ensureTotalCapacityContext(self.allocator, self.records.count(), self.context()) catch {
            self.tombstones.noteRemoval(&self.records);
            return;
        };
        var keys = self.records.keyIterator();
        while (keys.next()) |slot| smaller.putAssumeCapacityNoClobberContext(slot.*, {}, self.context());
        self.records.deinit(self.allocator);
        self.records = smaller;
        self.tombstones.reset();
    }
};

/// One record: header and bytes in one block, through the allocator's raw
/// entry point (written in full at once; Z5). Its one reference is the
/// caller's.
fn create(allocator: std.mem.Allocator, bytes: []const u8) error{OutOfMemory}!*Value {
    if (bytes.len > max_value_bytes) return error.OutOfMemory;
    const total = @sizeOf(Value) + bytes.len;
    const memory = allocator.rawAlloc(total, .of(Value), @returnAddress()) orelse return error.OutOfMemory;
    const value: *Value = @ptrCast(@alignCast(memory));
    value.* = .{ .references = 1, .len_and_flags = @as(u32, @intCast(bytes.len)) | ValueId.flagsOf(bytes) };
    @memcpy(memory[@sizeOf(Value)..total], bytes);
    return value;
}

/// Free a record's block; Debug poisons it first (the raw entry point does
/// not), so a view read after its record went reads 0xAA.
fn destroy(allocator: std.mem.Allocator, value: *const Value) void {
    const block: [*]u8 = @ptrCast(@constCast(value));
    const memory = block[0..value.blockSize()];
    if (debug_checks) @memset(memory, 0xAA);
    allocator.rawFree(memory, .of(Value), @returnAddress());
}

/// Free a ClassNames block (its references let go already, or every record
/// gone with the table); Debug poisons it.
fn destroyClassNames(allocator: std.mem.Allocator, names: *ClassNames) void {
    const block: [*]u8 = @ptrCast(names);
    const memory = block[0..ClassNames.blockSize(names.len)];
    if (debug_checks) @memset(memory, 0xAA);
    allocator.rawFree(memory, .of(ClassNames), @returnAddress());
}

// ============================================================================
// A Browser's values, through its scope
// ============================================================================

/// A counted reference to `bytes` in `scope`'s table (.empty for ""), which
/// the caller keeps until its `release`.
pub fn intern(scope: *runtime.BrowserScope, bytes: []const u8) error{OutOfMemory}!ValueId {
    if (bytes.len == 0) return .empty;
    element_name.checkOwnerThread(scope);
    // Every attribute write's call, kept small enough to need no frame: the
    // table is made out of line (`firstTable`), so this is a load and a jump
    // to Table.intern. Batch 3's class reads gave Table.intern three more
    // callers and the compiler stopped inlining it here; with the table's
    // making inlined too, each write paid two frames and two stack checks
    // (~35 instructions; the cost pair's setter row, 2026-11-11). Forcing
    // Table.intern inline here instead copied its body, and the copies' new
    // callers pushed the lookup and the unpark out of line in both.
    const table = scope.existingTable(.attribute_values, Table) orelse try firstTable(scope);
    return table.intern(bytes);
}

/// `scope`'s values table, made on its first value: out of line, as it runs
/// once per Browser (`intern`).
noinline fn firstTable(scope: *runtime.BrowserScope) error{OutOfMemory}!*Table {
    return scope.table(.attribute_values, Table);
}

/// One more reference to `id` in `scope`'s table.
pub fn retain(scope: *runtime.BrowserScope, id: ValueId) void {
    if (id == .empty) return;
    element_name.checkOwnerThread(scope);
    scope.existingTable(.attribute_values, Table).?.retain(id);
}

/// Drop a reference `intern` or `retain` gave. After the scope's tables
/// ended (its end freed every record) it touches nothing.
pub fn release(scope: *runtime.BrowserScope, id: ValueId) void {
    if (id == .empty) return;
    const table = scope.existingTable(.attribute_values, Table) orelse return;
    element_name.checkOwnerThread(scope);
    table.release(id);
}

/// `scope`'s table, if it has made one: what a reader decodes ids with.
pub fn tableOf(scope: *runtime.BrowserScope) ?*const Table {
    return scope.existingTable(.attribute_values, Table);
}

/// `scope`'s table for a CLASS read (the class selector, classList,
/// getElementsByClassName), if it has made one - writable, because a class
/// read makes a value's ClassNames on its first read (`Table.classNames`)
/// and a class name's record (`Table.operandOf`): a cache Blink's and
/// WebKit's class reads fill the same way (SpaceSplitString::Data::Create
/// inserts into its shared map). Only on the Browser's window agent's
/// thread, as every table write.
pub fn classTable(scope: *runtime.BrowserScope) ?*Table {
    const table = scope.existingTable(.attribute_values, Table) orelse return null;
    element_name.checkOwnerThread(scope);
    return table;
}

/// `id`'s bytes in `table` ("" for .empty; any other id needs the table its
/// element's Browser made).
pub inline fn bytesIn(table: ?*const Table, id: ValueId) []const u8 {
    if (id == .empty) return "";
    return table.?.get(id).bytes();
}

/// A reference a holder takes on a value for a span in which script can
/// run (the change steps, an event dispatch): `const held = Hold.take(scope,
/// id); defer held.end();`. Its bytes stay valid until `end`, whatever the
/// script does to the attribute.
pub const Hold = struct {
    scope: *runtime.BrowserScope,
    id: ValueId,

    pub fn take(scope: *runtime.BrowserScope, id: ValueId) Hold {
        retain(scope, id);
        return .{ .scope = scope, .id = id };
    }

    /// The held bytes.
    pub fn bytes(self: Hold) []const u8 {
        return bytesIn(tableOf(self.scope), self.id);
    }

    pub fn end(self: Hold) void {
        release(self.scope, self.id);
    }
};

// ============================================================================
// Tests
// ============================================================================

/// Every parked record has no reference, and the ring's bytes add up
/// (the ruling's condition: the ring never holds a counted record).
fn expectParkingSound(table: *const Table) !void {
    var bytes: usize = 0;
    for (table.parked.slots[0..table.parked.len]) |slot| {
        const value = table.ids.get(slot);
        try std.testing.expectEqual(@as(u32, 0), value.references);
        bytes += table.parkedSize(slot, value);
    }
    try std.testing.expectEqual(bytes, table.parkedBytes());
    try std.testing.expect(table.parkedRecords() <= Table.Parking.max_records);
    try std.testing.expect(table.parkedBytes() <= Table.Parking.max_bytes);
}

test "a value is interned once per Browser; its last release parks it" {
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    defer scope.deinit();

    try std.testing.expectEqual(ValueId.empty, try intern(&scope, ""));
    try std.testing.expect(tableOf(&scope) == null);

    const a = try intern(&scope, "btn btn-primary btn-large");
    try std.testing.expect(try intern(&scope, "btn btn-primary btn-large") == a);
    const table = tableOf(&scope).?;
    try std.testing.expectEqual(@as(u32, 2), table.get(a).references);
    try std.testing.expectEqualStrings("btn btn-primary btn-large", bytesIn(table, a));
    try std.testing.expectEqual(@as(usize, 8 + "btn btn-primary btn-large".len), table.bytes_held);
    // Case and length count.
    const b = try intern(&scope, "BTN btn-primary btn-large");
    try std.testing.expect(b != a);
    try std.testing.expectEqual(@as(usize, 2), table.liveCount());

    release(&scope, a);
    try std.testing.expectEqual(@as(usize, 2), table.liveCount());
    release(&scope, a);
    try std.testing.expectEqual(@as(usize, 1), table.liveCount());
    try std.testing.expectEqual(@as(usize, 1), table.parkedRecords());
    try expectParkingSound(table);
    release(&scope, b);
    try std.testing.expectEqual(@as(usize, 0), table.liveCount());
    try std.testing.expectEqual(@as(usize, 2), table.parkedRecords());
    release(&scope, .empty);
}

test "a parked record comes back with its id and a count of one, and leaves the ring" {
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    defer scope.deinit();
    const x = try intern(&scope, "x");
    release(&scope, x);
    const table = tableOf(&scope).?;
    try std.testing.expectEqual(@as(usize, 1), table.parkedRecords());
    const again = try intern(&scope, "x");
    try std.testing.expectEqual(x, again);
    try std.testing.expectEqual(@as(u32, 1), table.get(again).references);
    try std.testing.expectEqual(@as(usize, 0), table.parkedRecords());
    try std.testing.expectEqual(@as(usize, 0), table.parkedBytes());
    try expectParkingSound(table);
    release(&scope, again);
}

test "a found value is read by its slot once: no second read for its id's flags or its count" {
    // The one read is the lookup's compare: the found path takes its count
    // and its id's flags from the record the compare read, not from its slot
    // again (a second read after eqlBytes reloads the slot array with its
    // checks: ~10 instructions an attribute write, the cost pair 2026-11-11).
    if (!debug_checks) return error.SkipZigTest;
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    defer scope.deinit();
    const first = try intern(&scope, "x");
    const table = (classTable(&scope)).?;
    // Counted: the found path of a value an attribute holds.
    var reads = table.slot_reads;
    const again = try table.intern("x");
    try std.testing.expectEqual(first, again);
    try std.testing.expectEqual(reads + 1, table.slot_reads);
    // Parked: the found path that takes it out of the ring.
    table.release(again);
    table.release(first);
    reads = table.slot_reads;
    const back = try table.intern("x");
    try std.testing.expectEqual(first, back);
    try std.testing.expectEqual(reads + 1, table.slot_reads);
    table.release(back);
}

test "an attribute write's lookup compares keys inline: no call per probed slot" {
    // The cost pair's setter and set/get rows (lane nd2 batch 3, 2026-11-11:
    // +72 and +69 instructions an op against batch 2): once batch 3's class
    // reads gave the adapted lookup more callers, the compiler kept
    // KeyAdapter.eql out of line - a call, a frame and two reloads of the
    // slot array on every probed slot. Batch 2's console inlined it.
    const convention = @typeInfo(@TypeOf(KeyAdapter.eql)).@"fn".attrs.@"callconv";
    try std.testing.expect(std.meta.activeTag(convention) == .@"inline");
}

test "a value that is its own classes and its own fold never looks for a token list" {
    if (!debug_checks) return error.SkipZigTest;
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    defer scope.deinit();
    // A token list made for another value first, so the lists' array is
    // longer than the slots below: a lookup would read it.
    const classes = try intern(&scope, "a b");
    defer release(&scope, classes);
    const table = classTable(&scope).?;
    _ = try table.classNames(classes);
    try std.testing.expect(table.class_names.items.len > 0);
    // el.id = 'x' / 'y': a release parks, an intern unparks - neither has a
    // list to weigh (a lowercase one-token value has none: `makeClassNames`).
    const x = try intern(&scope, "x");
    var reads = table.class_names_reads;
    release(&scope, x);
    const back = try intern(&scope, "x");
    try std.testing.expectEqual(x, back);
    release(&scope, back);
    try std.testing.expectEqual(reads, table.class_names_reads);
    // A value over the ring's cap is freed at its release: no list to take.
    const long: [Table.Parking.max_record_bytes + 1]u8 = @splat('z');
    reads = table.class_names_reads;
    release(&scope, try intern(&scope, &long));
    try std.testing.expect(table.find(&long) == null);
    try std.testing.expectEqual(reads, table.class_names_reads);
    // Control: a value with an upper-case letter can have a list (its
    // folded record's), so its ring trips look.
    const upper = try intern(&scope, "X");
    reads = table.class_names_reads;
    release(&scope, upper);
    release(&scope, try intern(&scope, "X"));
    try std.testing.expect(table.class_names_reads > reads);
    try expectParkingSound(table);
}

test "the ring takes a record out at its front, middle or end and keeps the rest in order" {
    var ring: Table.Parking = .{};
    for (0..5) |i| {
        ring.slots[i] = @intCast(10 + i);
        ring.len += 1;
    }
    try std.testing.expectEqual(@as(u32, 14), ring.removeAt(4)); // the newest
    try std.testing.expectEqual(@as(u32, 10), ring.removeAt(0)); // the oldest
    try std.testing.expectEqual(@as(u32, 12), ring.removeAt(1));
    try std.testing.expectEqualSlices(u32, &.{ 11, 13 }, ring.slots[0..ring.len]);
    try std.testing.expectEqual(@as(?usize, 1), ring.indexOf(13));
    try std.testing.expectEqual(@as(?usize, null), ring.indexOf(12));
    _ = ring.removeAt(0);
    _ = ring.removeAt(0);
    try std.testing.expectEqual(@as(usize, 0), ring.len);
}

test "a value id's slot ignores its flags and generation" {
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    defer scope.deinit();
    // Every flag combination: one token and lowercase, one token with an
    // upper-case letter, several tokens, several with an upper-case letter.
    const values = [_][]const u8{ "x", "X", "x y", "X y" };
    var ids: [values.len]ValueId = undefined;
    for (values, &ids) |text, *id| id.* = try intern(&scope, text);
    defer for (ids) |id| release(&scope, id);
    const table = tableOf(&scope).?;
    for (values, ids) |text, id| {
        try std.testing.expectEqualStrings(text, table.bytesOf(id));
        try std.testing.expectEqual(id, table.find(text).?);
    }
    try std.testing.expect(ids[0].isOneToken() and ids[0].isLowercase());
    try std.testing.expect(ids[1].isOneToken() and !ids[1].isLowercase());
    try std.testing.expect(!ids[2].isOneToken() and ids[2].isLowercase());
    try std.testing.expect(!ids[3].isOneToken() and !ids[3].isLowercase());
}

test "a million distinct values end at the table's size plus at most the ring" {
    // The churn tests' allocator (tests/test_runner/poisoning.zig
    // ChurnAllocator: poisoned frees and the leak check, no stack traces):
    // std.testing.allocator's capture at every allocation and free made this
    // test 73 s on chat2 against 8 s on server1.
    var churn = @import("root").poisoning.ChurnAllocator.init("attribute_values: a million distinct values");
    errdefer churn.deinit() catch {};
    {
        var scope = runtime.BrowserScope.init(churn.allocator());
        defer scope.deinit();
        try millionDistinctValues(&scope);
    }
    try churn.deinit();
}

fn millionDistinctValues(scope: *runtime.BrowserScope) !void {
    const keep = try intern(scope, "kept");
    const table = tableOf(scope).?;
    const start = table.count();
    var buffer: [24]u8 = undefined;
    for (0..1_000_000) |i| release(scope, try intern(scope, try std.fmt.bufPrint(&buffer, "value {d}", .{i})));
    try std.testing.expect(table.count() <= start + Table.Parking.max_records);
    try std.testing.expectEqual(@as(usize, 1), table.liveCount());
    try std.testing.expect(table.ids.len() <= start + Table.Parking.max_records + 1);
    try expectParkingSound(table);
    release(scope, keep);
}

test "the ring is bounded by bytes, and a record over the per-record cap is freed at once" {
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    defer scope.deinit();
    var big: [Table.Parking.max_record_bytes]u8 = undefined;
    @memset(&big, 'b');
    const id = try intern(&scope, &big);
    const table = tableOf(&scope).?;
    release(&scope, id);
    // 8 + 256 bytes > the cap: freed, never parked.
    try std.testing.expectEqual(@as(usize, 0), table.count());
    try std.testing.expectEqual(@as(usize, 0), table.parkedRecords());
    // 200-byte values: the 16 KiB bound parks 78 of them, not 256.
    var value: [200]u8 = undefined;
    for (0..300) |i| {
        @memset(&value, 'a' + @as(u8, @intCast(i % 26)));
        value[0] = @intCast(i & 0xFF);
        value[1] = @intCast(i >> 8);
        release(&scope, try intern(&scope, &value));
    }
    try std.testing.expectEqual(@as(usize, Table.Parking.max_bytes / 208), table.parkedRecords());
    try expectParkingSound(table);
}

test "a hold keeps a value's bytes across the release of its attribute's reference" {
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    defer scope.deinit();
    const id = try intern(&scope, "old");
    const held = Hold.take(&scope, id);
    release(&scope, id);
    try std.testing.expectEqualStrings("old", held.bytes());
    held.end();
    try std.testing.expectEqual(@as(usize, 0), tableOf(&scope).?.liveCount());
}

test "values that come and go keep ids dense and the map small" {
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    defer scope.deinit();
    var live: [64]ValueId = undefined;
    var buffer: [24]u8 = undefined;
    for (&live, 0..) |*slot, i| slot.* = try intern(&scope, try std.fmt.bufPrint(&buffer, "v{d}", .{i}));
    const table = tableOf(&scope).?;
    for (64..50_064) |i| {
        const at = i % live.len;
        release(&scope, live[at]);
        live[at] = try intern(&scope, try std.fmt.bufPrint(&buffer, "v{d}", .{i}));
        const slots = infra.tombstones.slotCounts(&table.records);
        if (slots.free * 4 < slots.capacity - slots.live) return error.TombstonesBuiltUp;
    }
    // The live values and, at most, the ring.
    try std.testing.expect(table.ids.len() <= 64 + Table.Parking.max_records + 1);
    for (live) |id| release(&scope, id);
    try std.testing.expectEqual(@as(usize, 0), table.liveCount());
    try expectParkingSound(table);
}

// ----------------------------------------------------------------------------
// Class reads (lane nd2 batch 3)
// ----------------------------------------------------------------------------

/// The live ClassNames bytes add up, and the counters agree with the slots.
fn expectClassNamesSound(table: *const Table) !void {
    var lists: usize = 0;
    var bytes: usize = 0;
    for (table.class_names.items, 0..) |names, slot| {
        const n = names orelse continue;
        try std.testing.expect(table.ids.isLive(@intCast(slot)));
        for (n.tokens()) |token| {
            try std.testing.expect(token.isOneToken());
            try std.testing.expect(table.get(token).references > 0);
        }
        lists += 1;
        bytes += ClassNames.blockSize(n.len);
    }
    try std.testing.expectEqual(lists, table.class_lists);
    try std.testing.expectEqual(bytes, table.class_bytes);
}

test "a value's id says whether it is one token and whether it has an upper-case letter" {
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    defer scope.deinit();
    const cases = [_]struct { []const u8, bool, bool }{
        .{ "card", true, true },
        .{ "Card", true, false },
        .{ "a b", false, true },
        .{ " a", false, true },
        .{ "a\x0Bb", true, true }, // VT is no ASCII whitespace
        .{ "a\x0Cb", false, true },
        .{ "\t", false, true },
        .{ "\u{C9}cole", true, true }, // only ASCII letters are upper case here
    };
    for (cases) |case| {
        const id = try intern(&scope, case[0]);
        defer release(&scope, id);
        try std.testing.expectEqual(case[1], id.isOneToken());
        try std.testing.expectEqual(case[2], id.isLowercase());
        try std.testing.expectEqualStrings(case[0], tableOf(&scope).?.bytesOf(id));
        // The same record, the same id, flags and all.
        try std.testing.expectEqual(id, tableOf(&scope).?.find(case[0]).?);
    }
    try std.testing.expect(ValueId.empty.isLowercase());
    try std.testing.expect(!ValueId.empty.isOneToken());
}

test "a value's flags agree with a byte-by-byte reading at every length and position, VT and the tail included" {
    const specials = [_]u8{ ' ', '\t', '\n', 0x0B, 0x0C, '\r', 'A', 'Z', '@', '[', 0x08, 0x0E, 0x00, 0xC9 };
    var buffer: [70]u8 = undefined;
    for (0..buffer.len + 1) |len| {
        @memset(buffer[0..len], 'q');
        try std.testing.expectEqual(reference(buffer[0..len]), ValueId.flagsOf(buffer[0..len]));
        for (0..len) |at| for (specials) |c| {
            @memset(buffer[0..len], 'q');
            buffer[at] = c;
            try std.testing.expectEqual(reference(buffer[0..len]), ValueId.flagsOf(buffer[0..len]));
        };
    }
}

/// The flags by the definition: Infra's ASCII whitespace, ASCII upper case.
fn reference(bytes: []const u8) u32 {
    var one_token = bytes.len != 0;
    var lowercase = true;
    for (bytes) |c| {
        if (isAsciiWhitespace(c)) one_token = false;
        if (c >= 'A' and c <= 'Z') lowercase = false;
    }
    return (if (one_token) ValueId.one_token_bit else 0) | (if (lowercase) ValueId.lowercase_bit else 0);
}

test "a value is split once by DOM's ordered set parser; its tokens are counted records, let go with it" {
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    defer scope.deinit();
    const id = try intern(&scope, " b\ta b\n\x0Cc\r a ");
    const table = (classTable(&scope)).?;
    const names = try table.classNames(id);
    try std.testing.expectEqual(@as(usize, 3), names.tokens().len);
    for (names.tokens(), [_][]const u8{ "b", "a", "c" }) |token, want| try std.testing.expectEqualStrings(want, table.bytesOf(token));
    try std.testing.expectEqual(@as(usize, 1), table.class_scans);
    // Read again: the same block, no new pass.
    try std.testing.expectEqual(names, try table.classNames(id));
    try std.testing.expectEqual(@as(usize, 1), table.class_scans);
    try std.testing.expect(try table.hasToken(id, table.find("a").?));
    try std.testing.expect(!try table.hasToken(id, table.find(" b\ta b\n\x0Cc\r a ").?));
    try std.testing.expect(!try table.hasToken(id, .empty));
    // The value and its three tokens are counted.
    try std.testing.expectEqual(@as(usize, 4), table.liveCount());
    try expectClassNamesSound(table);
    // Its last release parks it with its list; the tokens stay counted.
    release(&scope, id);
    try std.testing.expectEqual(@as(usize, 3), table.liveCount());
    try std.testing.expectEqual(@as(usize, 1), table.class_lists);
    try expectParkingSound(table);
    try expectClassNamesSound(table);
}

test "a value of only whitespace has no tokens; a one-token value is its own" {
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    defer scope.deinit();
    const blank = try intern(&scope, " \t ");
    defer release(&scope, blank);
    const one = try intern(&scope, "solo");
    defer release(&scope, one);
    const table = (classTable(&scope)).?;
    try std.testing.expectEqual(@as(usize, 0), (try table.classNames(blank)).tokens().len);
    try std.testing.expect(try table.hasToken(one, one));
    try std.testing.expect(!try table.hasToken(blank, one));
    // A one-token value needs no list for an identical-to read.
    try std.testing.expectEqual(@as(usize, 1), table.class_lists);
}

test "quirks reads: the folded record is made once, counted by the value's list" {
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    defer scope.deinit();
    const id = try intern(&scope, "Foo BAR baz");
    const table = (classTable(&scope)).?;
    const foo = (try table.operandOf("FOO", true)).?;
    try std.testing.expectEqualStrings("foo", table.bytesOf(foo));
    try std.testing.expect(try table.hasFoldedToken(id, foo));
    try std.testing.expect(try table.hasFoldedToken(id, (try table.operandOf("bar", true)).?));
    try std.testing.expect(!try table.hasToken(id, (try table.operandOf("foo", false)).?));
    const folded = try table.foldedOf(id);
    try std.testing.expectEqualStrings("foo bar baz", table.bytesOf(folded));
    try std.testing.expectEqual(folded, try table.foldedOf(id));
    // A lowercase value is its own fold.
    try std.testing.expectEqual(folded, try table.foldedOf(folded));
    try expectClassNamesSound(table);
    release(&scope, id);
    try expectParkingSound(table);
}

test "a class name with whitespace is no operand; one too long to park is compared as bytes" {
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    defer scope.deinit();
    const keep = try intern(&scope, "x");
    defer release(&scope, keep);
    const table = (classTable(&scope)).?;
    try std.testing.expectEqual(ValueId.empty, (try table.operandOf("a b", false)).?);
    try std.testing.expectEqual(ValueId.empty, (try table.operandOf("", false)).?);
    var long: [Table.Parking.max_record_bytes]u8 = undefined;
    @memset(&long, 'q');
    try std.testing.expect((try table.operandOf(&long, false)) == null);
    // A short name's record stays (parked) after the call.
    const id = (try table.operandOf("short", false)).?;
    try std.testing.expectEqual(id, table.find("short").?);
}

test "freeing a record an operand names moves operand_frees; freeing any other does not" {
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    defer scope.deinit();
    const keep = try intern(&scope, "x");
    defer release(&scope, keep);
    const table = (classTable(&scope)).?;
    const name = (try table.operandOf("named", false)).?;
    _ = name;
    // A long value freed at its release is no operand.
    var long: [400]u8 = undefined;
    @memset(&long, 'L');
    release(&scope, try intern(&scope, &long));
    try std.testing.expectEqual(@as(u64, 0), table.operand_frees);
    // Fill the ring until "named" is evicted.
    var buffer: [24]u8 = undefined;
    var i: usize = 0;
    while (table.find("named") != null) : (i += 1) release(&scope, try intern(&scope, try std.fmt.bufPrint(&buffer, "v{d}", .{i})));
    try std.testing.expectEqual(@as(u64, 1), table.operand_frees);
    try expectParkingSound(table);
}

test "a value of 20,000 tokens, most of them repeats, splits into its distinct tokens" {
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    defer scope.deinit();
    var text: std.ArrayListUnmanaged(u8) = .empty;
    defer text.deinit(std.testing.allocator);
    for (0..20_000) |i| {
        var buffer: [16]u8 = undefined;
        try text.appendSlice(std.testing.allocator, try std.fmt.bufPrint(&buffer, "t{d} ", .{i % 500}));
    }
    const id = try intern(&scope, text.items);
    defer release(&scope, id);
    const table = (classTable(&scope)).?;
    const names = try table.classNames(id);
    try std.testing.expectEqual(@as(usize, 500), names.tokens().len);
    try std.testing.expectEqualStrings("t499", table.bytesOf(names.tokens()[499]));
    try expectClassNamesSound(table);
}

test "a freed record's list lets its tokens go, and a cascade through the ring keeps it sound" {
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    defer scope.deinit();
    const table = blk: {
        const k = try intern(&scope, "k");
        release(&scope, k);
        break :blk (classTable(&scope)).?;
    };
    // 300 parked values, each with a list of four tokens of its own.
    var buffer: [64]u8 = undefined;
    for (0..300) |i| {
        const id = try intern(&scope, try std.fmt.bufPrint(&buffer, "a{d} b{d} c{d} d{d}", .{ i, i, i, i }));
        _ = try table.classNames(id);
        release(&scope, id);
        try expectParkingSound(table);
    }
    try expectClassNamesSound(table);
    try std.testing.expect(table.parkedRecords() <= Table.Parking.max_records);
}
