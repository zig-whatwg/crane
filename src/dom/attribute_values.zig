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
/// a record of its Browser's table. In a Debug build bits 24-31 are its
/// slot's generation.
pub const ValueId = enum(u32) {
    empty = 0,
    _,

    const generation_shift = 24;
    const index_bits: u32 = if (debug_checks) generation_shift else 32;
    const index_mask: u32 = if (debug_checks) (@as(u32, 1) << index_bits) - 1 else std.math.maxInt(u32);
    /// The slots a table may hold (slot + 1 must fit the index bits).
    pub const limit: usize = index_mask - 1;

    fn of(slot_index: u32, slot_generation: u8) ValueId {
        const stamp: u32 = if (debug_checks) @as(u32, slot_generation) << generation_shift else 0;
        return @fromBackingInt(@intCast(stamp | (slot_index + 1)));
    }

    fn slot(self: ValueId) u32 {
        return (@backingInt(self) & index_mask) - 1;
    }

    fn generation(self: ValueId) u8 {
        return if (debug_checks) @intCast(@backingInt(self) >> generation_shift) else 0;
    }
};

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
    /// Its length in bytes.
    len: u32,

    comptime {
        std.debug.assert(@sizeOf(Value) == 8);
    }

    /// Its bytes, borrowed while it is counted.
    pub inline fn bytes(self: *const Value) []const u8 {
        const base: [*]const u8 = @ptrCast(self);
        return base[@sizeOf(Value)..][0..self.len];
    }

    fn blockSize(self: *const Value) usize {
        return @sizeOf(Value) + self.len;
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
    ids: *const attribute_names.IdSlots(Value),
    pub fn hash(_: KeyAdapter, key: BytesKey) u64 {
        return key.hash;
    }
    pub fn eql(adapter: KeyAdapter, key: BytesKey, slot: u32) bool {
        const value = adapter.ids.get(slot);
        return value.len == key.bytes.len and std.mem.eql(u8, value.bytes(), key.bytes);
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
    /// Removals since the map last had no tombstones: past half the unused
    /// slots, the next insert rehashes it in place (infra.tombstones' rule;
    /// its guard cannot rehash a map whose context has state).
    removals: usize = 0,
    /// The bytes of the records alive (headers included): a measurement.
    bytes_held: usize = 0,

    const Map = std.HashMapUnmanaged(u32, void, SlotContext, 80);

    /// Below this many slots an emptied map keeps its storage.
    const kept_capacity = 64;

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
        self.records.deinit(self.allocator);
        self.ids.deinit(self.allocator);
    }

    /// How many distinct values the table holds.
    pub fn count(self: *const Table) usize {
        return self.records.count();
    }

    /// The record `id` names, checked: a freed slot, or (Debug) a slot freed
    /// and reused since the id was handed out, panics.
    pub inline fn get(self: *const Table, id: ValueId) *const Value {
        const slot = id.slot();
        if (debug_checks and self.ids.generation(slot) != id.generation()) @panic("a stale attribute value id");
        return self.ids.get(slot);
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
        if (self.records.getKeyAdapted(key, KeyAdapter{ .ids = &self.ids })) |slot| {
            const id = ValueId.of(slot, self.ids.generation(slot));
            self.retain(id);
            return id;
        }
        self.beforeInsert();
        try self.records.ensureUnusedCapacityContext(self.allocator, 1, self.context());
        const value = try create(self.allocator, bytes);
        errdefer destroy(self.allocator, value);
        const slot = try self.ids.take(self.allocator, value, ValueId.limit);
        // Placed by the hash already computed: one pass over the bytes.
        const placed = self.records.getOrPutAssumeCapacityAdapted(key, KeyAdapter{ .ids = &self.ids });
        if (debug_checks and placed.found_existing) @panic("an attribute value record interned twice");
        placed.key_ptr.* = slot;
        self.bytes_held += value.blockSize();
        return ValueId.of(slot, self.ids.generation(slot));
    }

    /// One more reference to `id` (none for .empty), checked for overflow in
    /// every build.
    pub fn retain(self: *Table, id: ValueId) void {
        if (id == .empty) return;
        const value: *Value = @constCast(self.get(id));
        if (value.references == std.math.maxInt(u32)) @panic("an attribute value record's count overflowed");
        value.references += 1;
    }

    /// Drop one reference to `id` (none for .empty); the last removes the
    /// record from the table, frees it and frees its slot, now.
    pub fn release(self: *Table, id: ValueId) void {
        if (id == .empty) return;
        const value: *Value = @constCast(self.get(id));
        if (value.references == 0) @panic("an attribute value record released more often than it was kept");
        value.references -= 1;
        if (value.references != 0) return;
        // The map hashes the record's bytes to find its slot: out of the map
        // first, then the slot, then the block.
        const removed = self.records.removeContext(id.slot(), self.context());
        if (debug_checks and !removed) @panic("a released attribute value record was not in its Browser's table");
        self.ids.give(id.slot());
        self.bytes_held -= value.blockSize();
        destroy(self.allocator, value);
        self.afterRemove();
    }

    /// Before an insert: drop the tombstones once they could take half the
    /// unused slots (infra.tombstones' rule), so a churn of values never
    /// walks them on every miss.
    fn beforeInsert(self: *Table) void {
        if (self.removals == 0) return;
        const unused = self.records.capacity() - self.records.count();
        if (self.removals * 2 < unused) return;
        self.records.rehash(self.context());
        self.removals = 0;
    }

    /// The map after a removal (dom.element_name.Table's rule: WTF's
    /// HashTable shrinks below a sixth full).
    fn afterRemove(self: *Table) void {
        const capacity = self.records.capacity();
        const live = self.records.count();
        if (live == 0) {
            if (capacity > kept_capacity) self.records.clearAndFree(self.allocator) else self.records.clearRetainingCapacity();
            self.removals = 0;
        } else if (capacity > kept_capacity and live * 6 < capacity) {
            self.shrink();
        } else {
            self.removals += 1;
        }
    }

    fn shrink(self: *Table) void {
        var smaller: Map = .empty;
        smaller.ensureTotalCapacityContext(self.allocator, self.records.count(), self.context()) catch {
            self.removals += 1;
            return;
        };
        var keys = self.records.keyIterator();
        while (keys.next()) |slot| smaller.putAssumeCapacityNoClobberContext(slot.*, {}, self.context());
        self.records.deinit(self.allocator);
        self.records = smaller;
        self.removals = 0;
    }
};

/// One record: header and bytes in one block, through the allocator's raw
/// entry point (written in full at once; Z5). Its one reference is the
/// caller's.
fn create(allocator: std.mem.Allocator, bytes: []const u8) error{OutOfMemory}!*Value {
    if (bytes.len > std.math.maxInt(u32) - @sizeOf(Value)) return error.OutOfMemory;
    const total = @sizeOf(Value) + bytes.len;
    const memory = allocator.rawAlloc(total, .of(Value), @returnAddress()) orelse return error.OutOfMemory;
    const value: *Value = @ptrCast(@alignCast(memory));
    value.* = .{ .references = 1, .len = @intCast(bytes.len) };
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

// ============================================================================
// A Browser's values, through its scope
// ============================================================================

/// A counted reference to `bytes` in `scope`'s table (.empty for ""), which
/// the caller keeps until its `release`.
pub fn intern(scope: *runtime.BrowserScope, bytes: []const u8) error{OutOfMemory}!ValueId {
    if (bytes.len == 0) return .empty;
    element_name.checkOwnerThread(scope);
    const table = try scope.table(.attribute_values, Table);
    return table.intern(bytes);
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

test "a value is interned once per Browser and freed with its last reference" {
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
    try std.testing.expectEqual(@as(usize, 2), table.count());

    release(&scope, a);
    try std.testing.expectEqual(@as(usize, 2), table.count());
    release(&scope, a);
    try std.testing.expectEqual(@as(usize, 1), table.count());
    // Its slot is the next value's.
    const c = try intern(&scope, "x");
    try std.testing.expectEqual(a.slot(), c.slot());
    if (debug_checks) try std.testing.expect(c != a);
    release(&scope, b);
    release(&scope, c);
    try std.testing.expectEqual(@as(usize, 0), table.count());
    try std.testing.expectEqual(@as(usize, 0), table.bytes_held);
    release(&scope, .empty);
}

test "a hold keeps a value's bytes across the release of its attribute's reference" {
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    defer scope.deinit();
    const id = try intern(&scope, "old");
    const held = Hold.take(&scope, id);
    release(&scope, id);
    try std.testing.expectEqualStrings("old", held.bytes());
    held.end();
    try std.testing.expectEqual(@as(usize, 0), tableOf(&scope).?.count());
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
    try std.testing.expectEqual(@as(usize, 64), table.ids.len());
    for (live) |id| release(&scope, id);
    try std.testing.expectEqual(@as(usize, 0), table.count());
}
