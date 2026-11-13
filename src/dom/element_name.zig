//! An element's qualified name as ONE record every element of that name
//! shares (lane nd2, batch 1, phase N2; tmp/redesign/nodedata-design.md 4.1
//! N2, tmp/redesign/nodedata/techniques.md T2).
//!
//! DOM 4.9: an element has a namespace, a namespace prefix and a local name,
//! fixed by "create an element", and its qualified name and "HTML-uppercased
//! qualified name" (tagName) follow from them. Every element kept them in
//! its own state - a 32-byte ?DOMString namespace and a 24-byte DOMString
//! local name in its ElementData, a 32-byte ?DOMString prefix in its rare
//! data - though on real pages 91-100% of them are the static strings of a
//! handful of names (crane-layout.md P2: 20-73 distinct qualified names per
//! page against 737-19,713 elements). The engines keep one pointer instead:
//!
//! - Blink: `Element::tag_name_` is a QualifiedName, a pointer to a
//!   QualifiedNameImpl {prefix_, local_name_, namespace_, local_name_upper_}
//!   (core/dom/qualified_name.h). The names html_names.json5, svg_names and
//!   mathml_names define are static ("is_static_", made once at start-up);
//!   any other is interned in the QualifiedNameCache, a HashSet keyed by
//!   (prefix, local name, namespace) (qualified_name.cc,
//!   QNameComponentsTranslator). `QualifiedName::Matches` is "same impl, or
//!   same local name and namespace" - the prefix does not count.
//!   HTMLElement::nodeName answers `LocalNameUpper()` for an unprefixed
//!   element of an HTML document.
//! - WebKit: QualifiedName / QualifiedNameImpl the same shape (m_prefix,
//!   m_localName, m_namespaceURI, m_localNameUpper, its Namespace and
//!   NodeName ids; Source/WebCore/dom/QualifiedName.h), interned in a
//!   per-thread QualifiedNameCache (QualifiedName.cpp).
//! - Gecko: `nsINode::mNodeInfo` points to a NodeInfo {mName, mPrefix,
//!   mNamespaceID, ...} with mQualifiedName and mNodeName precomputed -
//!   mNodeName the ASCII uppercase for an XHTML element of an HTML document
//!   (dom/base/NodeInfo.cpp) - shared through its document's
//!   nsNodeInfoManager (dom/base/nsNodeInfoManager.cpp, GetNodeInfo).
//!
//! Here `dom.element_data.ElementData.name` points to an `ElementName`:
//! - STATIC for the HTML, SVG and MathML element names html_core's tag table
//!   knows (html/parser/tag_name_intern.zig, `internElementName`): `const`
//!   comptime data, no process state - an element in its namespace, with no
//!   prefix and exactly that local name;
//! - else INTERNED in its Browser's name table (`Table`, the BrowserScope's
//!   `.element_names` table): custom elements, createElementNS with any
//!   namespace, prefixed and case-preserved names. Exact for every
//!   namespace, prefix and local name - never a lossy enum (Lightpanda's
//!   `.unknown`, tmp/redesign/nodedata-design.md 4.3).
//!
//! An interned record lives exactly as long as the elements that name it
//! (lane nd2 batch 1-fix; tmp/redesign/node-memory-plan-v2.md B2). Batch 1
//! kept every record for its Browser's life, so `createElement('x-' + i)`
//! held about 131 bytes per distinct name until the Browser ended - a
//! regression against main, which freed each element's own copy with the
//! element (review appendix-nd2.md F1). Every engine bounds its names the
//! same way, and so does this:
//!
//! 1. A dynamic record is COUNTED: one reference per element whose
//!    ElementData names it (`references`; `intern` hands out a counted
//!    reference, `release` drops one). A static record never touches a
//!    count - Blink's `is_static` QualifiedNameImpls (qualified_name.cc,
//!    QualifiedName::QualifiedName and ~QualifiedNameImpl), WebKit's
//!    HTMLNames / SVGNames made once and never freed (QualifiedName.cpp),
//!    Gecko's static atoms.
//! 2. The table is WEAK: the last release removes the record from it and
//!    frees it then and there, on the owning thread - no deferred sweep.
//!    Blink's and WebKit's ~QualifiedNameImpl erase the record from the
//!    QualifiedNameCache as it dies; Gecko's NodeInfo::LastRelease removes
//!    itself from its nsNodeInfoManager (nsNodeInfoManager::RemoveNodeInfo,
//!    which also clears its non-owning recent-use cache, mRecentlyUsedNodeInfos).
//!    Gecko's deferred atom sweep exists only for cross-thread release (bug
//!    1275755) and is not copied (review oss/report.md R8).
//! 3. The count is checked for overflow in every build (string_cache's
//!    overflow became a use-after-free: review R8); so is a release with
//!    nothing kept (it would free a record twice).
//! 4. The table is its Browser's window agent's: a Debug check on every
//!    intern and release says so (the agent's claim on the Browser's DOM
//!    memory, `runtime.gc.ExternalMemory.thread`). It takes no lock: only
//!    the window agent's thread makes and frees elements - workers have no
//!    DOM - and Blink's lockless name cache reached from a worker became a
//!    use-after-free (cbb47f9c5a34, 2026-04-22: review R8), which the check
//!    exists to catch first.
//! 5. Records come from the Browser's GENERAL allocator, never the state
//!    arena: a record is mostly page-chosen bytes, and the arena's class
//!    lists are where freed node State blocks go, so a record could have
//!    landed in a collected div's block (node-memory-architecture.md 3.2:
//!    "a block whose bytes the page controls holds no raw pointer";
//!    appendix-nd2.md F3).
//!
//! Every structure that keeps a record beyond one call counts it, and there
//! is one: ElementData.name, written only by Element (`ElementData.rename`).
//! Nothing caches a record without a count (no reader keys anything by a
//! record's address across calls: the NthIndexCache lives one query), so the
//! free path has no cache to clear. What a record hands out - its strings,
//! through ElementData's accessors, dom.node_creation.ElementNames and
//! Element's localName / namespaceURI / prefix / tagName getters - is
//! BORROWED: valid while the element it was read from lives, as an
//! element's own copy was before N2. A reader that keeps one longer copies
//! it.
//!
//! The precomputed fields are what the hot readers need: the qualified name
//! (serialization, getElementsByTagName, the selector matcher) and its ASCII
//! uppercase (tagName and nodeName of an HTML element in an HTML document),
//! so neither getter allocates.
//!
//! Spec: https://dom.spec.whatwg.org/#concept-element-qualified-name
//! Spec: https://dom.spec.whatwg.org/#element-html-uppercased-qualified-name

const std = @import("std");
const builtin = @import("builtin");
const infra = @import("infra");
const runtime = @import("runtime");

/// The namespaces an element's code branches on, one byte in the record: a
/// reader asks `name.namespace == .html`, not for a string compare. `other`
/// is any namespace not listed - the record keeps its exact string.
pub const Namespace = enum(u8) {
    none,
    html,
    svg,
    mathml,
    xlink,
    xml,
    xmlns,
    other,
};

/// The Namespace of `uri` (null: none).
pub fn namespaceOf(uri: ?[]const u8) Namespace {
    const ns = uri orelse return .none;
    const named = .{
        .{ infra.namespaces.HTML_NAMESPACE, Namespace.html },
        .{ infra.namespaces.SVG_NAMESPACE, Namespace.svg },
        .{ infra.namespaces.MATHML_NAMESPACE, Namespace.mathml },
        .{ infra.namespaces.XLINK_NAMESPACE, Namespace.xlink },
        .{ infra.namespaces.XML_NAMESPACE, Namespace.xml },
        .{ infra.namespaces.XMLNS_NAMESPACE, Namespace.xmlns },
    };
    inline for (named) |entry| {
        if (std.mem.eql(u8, ns, entry[0])) return entry[1];
    }
    return .other;
}

/// The namespace string every element and attribute in one of the six named
/// namespaces (Infra 8) shares, or null for any other: an element's
/// namespace was a 28-byte copy per element.
pub fn internNamespace(namespace: []const u8) ?[]const u8 {
    const named = [_][]const u8{
        infra.namespaces.HTML_NAMESPACE,  infra.namespaces.SVG_NAMESPACE, infra.namespaces.MATHML_NAMESPACE,
        infra.namespaces.XLINK_NAMESPACE, infra.namespaces.XML_NAMESPACE, infra.namespaces.XMLNS_NAMESPACE,
    };
    inline for (named) |ns| {
        if (std.mem.eql(u8, namespace, ns)) return ns;
    }
    return null;
}

/// One element qualified name. Its names are immutable once made; shared by
/// every element of the name (in its Browser, for an interned one; by every
/// Browser, for a static one). Borrowed slices: valid while an element that
/// names it lives.
pub const ElementName = struct {
    /// DOM 4.9 namespace; null for none. One of the six named namespaces is
    /// Infra's static string (`internNamespace`).
    namespace_uri: ?[]const u8,
    /// DOM 4.9 namespace prefix; null for none (every element the HTML
    /// parser makes).
    prefix: ?[]const u8,
    /// DOM 4.9 local name.
    local_name: []const u8,
    /// DOM 4.9 qualified name: the local name if the prefix is null, else
    /// the prefix, ":", and the local name.
    qualified_name: []const u8,
    /// The qualified name in ASCII uppercase: tagName's "HTML-uppercased
    /// qualified name" for an HTML element whose node document is an HTML
    /// document (`tagName`). Only a record in the HTML namespace keeps a
    /// copy: tagName reads it for no other, so any other's is
    /// `qualified_name` itself.
    qualified_name_upper: []const u8,
    /// An interned record's references: the elements whose ElementData
    /// names it (each `intern` counts one, each `release` drops one, and
    /// the last frees it). A static record's stays 0: it is never counted.
    /// Written only by this file's table, on its Browser's window agent's
    /// thread - the one field that changes, so a record is `*const` to
    /// everyone else.
    references: u32 = 0,
    /// `namespace_uri`'s Namespace.
    namespace: Namespace,
    /// One of html_core's static records rather than a Browser's.
    is_static: bool,

    /// Whether this is an element in the HTML namespace.
    pub fn isHtml(self: *const ElementName) bool {
        return self.namespace == .html;
    }

    /// Whether this name is `local_name` in `namespace` (one of the
    /// enumerated namespaces), whatever its prefix: Blink's
    /// `Element::HasTagName`, which compares a QualifiedName's local name and
    /// namespace (`QualifiedName::Matches`).
    pub fn is(self: *const ElementName, namespace: Namespace, local_name: []const u8) bool {
        std.debug.assert(namespace != .other);
        return self.namespace == namespace and eqlBytes(self.local_name, local_name);
    }

    /// Blink's and WebKit's `QualifiedName::matches`: the same record, or
    /// the same local name and namespace (the prefix does not count).
    pub fn matches(self: *const ElementName, other: *const ElementName) bool {
        if (self == other) return true;
        if (self.namespace != other.namespace) return false;
        if (!eqlBytes(self.local_name, other.local_name)) return false;
        if (self.namespace != .other) return true;
        return std.mem.eql(u8, self.namespace_uri.?, other.namespace_uri.?);
    }

    /// Whether this is exactly the name (`namespace_uri`, `prefix`,
    /// `local_name`): a record's identity in its table.
    pub fn eql(self: *const ElementName, namespace_uri: ?[]const u8, prefix: ?[]const u8, local_name: []const u8) bool {
        return optionalEql(self.namespace_uri, namespace_uri) and optionalEql(self.prefix, prefix) and std.mem.eql(u8, self.local_name, local_name);
    }

    /// DOM 4.9 tagName: the HTML-uppercased qualified name - "If this is in
    /// the HTML namespace and its node document is an HTML document, then
    /// set qualifiedName to qualifiedName in ASCII uppercase" - else the
    /// qualified name as written.
    ///
    /// Spec: https://dom.spec.whatwg.org/#dom-element-tagname
    pub fn tagName(self: *const ElementName, node_document_is_html: bool) []const u8 {
        return if (self.namespace == .html and node_document_is_html) self.qualified_name_upper else self.qualified_name;
    }

    /// A static record: `local_name` in `namespace_uri` with no prefix, its
    /// uppercase computed at compile time. For html_core's tag table.
    pub fn initStatic(comptime namespace_uri: []const u8, comptime local_name: []const u8) ElementName {
        return .{
            .namespace_uri = namespace_uri,
            .prefix = null,
            .local_name = local_name,
            .qualified_name = local_name,
            .qualified_name_upper = comptime upperComptime(local_name),
            .namespace = comptime namespaceOf(namespace_uri),
            .is_static = true,
        };
    }

    fn upperComptime(comptime bytes: []const u8) []const u8 {
        var buffer: [bytes.len]u8 = undefined;
        for (bytes, 0..) |c, i| buffer[i] = std.ascii.toUpper(c);
        const final = buffer;
        return &final;
    }
};

/// The name of an element "create an element" has not named yet: the
/// record ElementData starts with, for the moment between an element's
/// construction and its names. No element keeps it.
pub const unnamed: ElementName = .{
    .namespace_uri = null,
    .prefix = null,
    .local_name = "",
    .qualified_name = "",
    .qualified_name_upper = "",
    .namespace = .none,
    .is_static = true,
};

fn eqlBytes(a: []const u8, b: []const u8) bool {
    // A static name compared with its own table's string is the same
    // pointer: no byte compare.
    return a.len == b.len and (a.ptr == b.ptr or std.mem.eql(u8, a, b));
}

fn optionalEql(a: ?[]const u8, b: ?[]const u8) bool {
    const x = a orelse return b == null;
    const y = b orelse return false;
    return std.mem.eql(u8, x, y);
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

    fn of(record: *const ElementName) Key {
        return .{ .namespace_uri = record.namespace_uri, .prefix = record.prefix, .local_name = record.local_name };
    }
};

/// The map's own context: records hash by their names and are equal only
/// to themselves (the table holds one record per name).
const RecordContext = struct {
    pub fn hash(_: RecordContext, record: *const ElementName) u64 {
        return Key.of(record).hash();
    }
    pub fn eql(_: RecordContext, a: *const ElementName, b: *const ElementName) bool {
        return a == b;
    }
};

/// A lookup by name.
const KeyAdapter = struct {
    pub fn hash(_: KeyAdapter, key: Key) u64 {
        return key.hash();
    }
    pub fn eql(_: KeyAdapter, key: Key, record: *const ElementName) bool {
        return record.eql(key.namespace_uri, key.prefix, key.local_name);
    }
};

/// A Browser's interned element names (its BrowserScope's `.element_names`
/// table, made on first use): one record per distinct name no static table
/// has that an element of the Browser names now - Blink's QualifiedNameCache
/// and Gecko's nsNodeInfoManager, per Browser as Crane's state rule asks
/// (src/AGENTS.md "Global state": a Browser owns it, never the process).
/// WEAK: it holds no reference; a record's last release removes it (see the
/// file's comment). Its window agent's thread only, so no lock.
pub const Table = struct {
    allocator: std.mem.Allocator,
    records: Map = .empty,
    /// When to drop the tombstones removals leave (infra.tombstones): a
    /// table whose names come and go would otherwise walk them on every
    /// miss.
    tombstones: infra.tombstones.TombstoneGuard = .{},

    const Map = std.HashMapUnmanaged(*const ElementName, void, RecordContext, 80);

    /// Below this many slots an emptied map keeps its storage (576 bytes),
    /// so one name made and dropped over and over allocates no map; above
    /// it, an emptied or mostly empty map gives its storage back.
    const kept_capacity = 64;

    pub fn init(allocator: std.mem.Allocator) Table {
        return .{ .allocator = allocator };
    }

    /// The table's end, with its Browser's scope (after every supplement):
    /// the map, and every record still in it. In a Browser none is - every
    /// element's state was ended by its teardown or by the Browser's
    /// teardown sweep (dom.teardown_sweeps, Browser.deinit) before the scope
    /// ends - but an engine-less scope's element that no teardown reached
    /// (a unit test's) still names one, and its state block goes with the
    /// arena, unread. A release after this finds no table (`release`) and
    /// touches nothing.
    pub fn deinit(self: *Table) void {
        var keys = self.records.keyIterator();
        while (keys.next()) |record| destroy(self.allocator, record.*);
        self.records.deinit(self.allocator);
    }

    /// How many names the table holds.
    pub fn count(self: *const Table) usize {
        return self.records.count();
    }

    /// A counted reference to the record of exactly (`namespace_uri`,
    /// `prefix`, `local_name`), made from the table's allocator the first
    /// time the name is asked for: the caller keeps it until its `release`.
    /// `namespace_uri` is never "" (DOM's algorithms make an empty namespace
    /// null before an element is named).
    pub fn intern(self: *Table, namespace_uri: ?[]const u8, prefix: ?[]const u8, local_name: []const u8) error{OutOfMemory}!*const ElementName {
        if (debug_checks and namespace_uri != null and namespace_uri.?.len == 0) @panic("an element name's namespace is \"\", not null");
        const key: Key = .{ .namespace_uri = namespace_uri, .prefix = prefix, .local_name = local_name };
        if (self.records.getKeyAdapted(key, KeyAdapter{})) |found| {
            retain(found);
            return found;
        }
        self.tombstones.beforeInsert(&self.records);
        try self.records.ensureUnusedCapacity(self.allocator, 1);
        const record = try create(self.allocator, namespace_uri, prefix, local_name);
        self.records.putAssumeCapacityNoClobber(record, {});
        return record;
    }

    /// Drop one reference to `record`, one of this table's; the last
    /// removes it from the table and frees it, now.
    pub fn release(self: *Table, record: *const ElementName) void {
        if (debug_checks and record.is_static) @panic("a static element name is never counted");
        const counted: *ElementName = @constCast(record);
        if (counted.references == 0) @panic("an element name record released more often than it was kept");
        counted.references -= 1;
        if (counted.references != 0) return;
        const removed = self.records.remove(record);
        if (debug_checks and !removed) @panic("a released element name record was not in its Browser's table");
        destroy(self.allocator, record);
        self.afterRemove();
    }

    /// The map after a removal: emptied, it lets its storage go (above
    /// `kept_capacity`) or clears it; mostly empty, it shrinks - WTF's
    /// HashTable shrinks below a sixth full (HashTable::ShrinkIfNeeded,
    /// kMinLoad 6), and Blink's QualifiedNameCache is one; else the removal
    /// is counted, and the next insert drops the tombstones once they could
    /// take half the unused slots (`tombstones`).
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

    /// The live records into a map their own size, which has no tombstones.
    /// Out of memory, the map keeps its size and counts the removal.
    fn shrink(self: *Table) void {
        var smaller: Map = .empty;
        smaller.ensureTotalCapacity(self.allocator, self.records.count()) catch {
            self.tombstones.noteRemoval(&self.records);
            return;
        };
        var keys = self.records.keyIterator();
        while (keys.next()) |record| smaller.putAssumeCapacityNoClobber(record.*, {});
        self.records.deinit(self.allocator);
        self.records = smaller;
        self.tombstones.reset();
    }
};

/// Debug-only checks (tmp/redesign/node-memory-plan-v2.md B8: a
/// `std.debug.assert` runs in ReleaseSafe too): the owner thread and the
/// table's own consistency. The count checks are production checks.
const debug_checks = builtin.mode == .debug;

/// One more reference to an interned record: its count, checked for
/// overflow in every build (string_cache's count overflow became a
/// use-after-free: review oss/report.md R8).
fn retain(record: *const ElementName) void {
    const counted: *ElementName = @constCast(record);
    if (counted.references == std.math.maxInt(u32)) @panic("an element name record's count overflowed");
    counted.references += 1;
}

/// One record and its strings in ONE block of `allocator`: the local name,
/// the prefix, the namespace unless it is one of the six named ones (Infra's
/// string), the qualified name when there is a prefix (else the local name
/// is it), and its uppercase when the record is in the HTML namespace and it
/// differs. Its one reference is the caller's.
fn create(allocator: std.mem.Allocator, namespace_uri: ?[]const u8, prefix: ?[]const u8, local_name: []const u8) error{OutOfMemory}!*const ElementName {
    const static_namespace: ?[]const u8 = if (namespace_uri) |ns| internNamespace(ns) else null;
    const namespace_bytes: usize = if (namespace_uri) |ns| (if (static_namespace == null) ns.len else 0) else 0;
    const prefix_bytes: usize = if (prefix) |p| p.len else 0;
    const qualified_len: usize = if (prefix) |p| p.len + 1 + local_name.len else local_name.len;
    const qualified_bytes: usize = if (prefix != null) qualified_len else 0;
    // tagName reads the uppercase only for an element in the HTML namespace
    // (`ElementName.tagName`): no other record keeps a copy.
    const needs_upper = namespaceOf(namespace_uri) == .html and (hasLowerAscii(prefix orelse "") or hasLowerAscii(local_name));
    const upper_bytes: usize = if (needs_upper) qualified_len else 0;
    const total = @sizeOf(ElementName) + local_name.len + prefix_bytes + namespace_bytes + qualified_bytes + upper_bytes;

    const memory = try allocator.alignedAlloc(u8, .of(ElementName), total);
    var tail: []u8 = memory[@sizeOf(ElementName)..total];
    const local = copyInto(&tail, local_name);
    const own_prefix: ?[]const u8 = if (prefix) |p| copyInto(&tail, p) else null;
    const own_namespace: ?[]const u8 = if (namespace_uri) |ns| (static_namespace orelse copyInto(&tail, ns)) else null;
    const qualified: []const u8 = if (own_prefix) |p| joined: {
        const out = tail[0..qualified_len];
        @memcpy(out[0..p.len], p);
        out[p.len] = ':';
        @memcpy(out[p.len + 1 ..], local);
        tail = tail[qualified_len..];
        break :joined out;
    } else local;
    const upper: []const u8 = if (needs_upper) upper: {
        const out = tail[0..qualified_len];
        _ = std.ascii.upperString(out, qualified);
        tail = tail[qualified_len..];
        break :upper out;
    } else qualified;
    if (debug_checks and tail.len != 0) @panic("an element name record's strings did not fill its block");

    const record: *ElementName = @ptrCast(memory.ptr);
    record.* = .{
        .namespace_uri = own_namespace,
        .prefix = own_prefix,
        .local_name = local,
        .qualified_name = qualified,
        .qualified_name_upper = upper,
        .references = 1,
        .namespace = namespaceOf(own_namespace),
        .is_static = false,
    };
    if (debug_checks and blockSize(record) != total) @panic("an element name record's block size does not follow from its names");
    return record;
}

/// The size of `record`'s block (`create`), from its names: what it copied
/// is exactly what is not a static string or another of its slices.
fn blockSize(record: *const ElementName) usize {
    var total = @sizeOf(ElementName) + record.local_name.len;
    if (record.prefix) |p| total += p.len + record.qualified_name.len;
    if (record.namespace_uri) |ns| if (internNamespace(ns) == null) {
        total += ns.len;
    };
    if (record.qualified_name_upper.ptr != record.qualified_name.ptr) total += record.qualified_name_upper.len;
    return total;
}

/// Free an interned record's block.
fn destroy(allocator: std.mem.Allocator, record: *const ElementName) void {
    const block: [*]align(@alignOf(ElementName)) u8 = @ptrCast(@constCast(record));
    allocator.free(block[0..blockSize(record)]);
}

fn hasLowerAscii(bytes: []const u8) bool {
    for (bytes) |c| {
        if (std.ascii.isLower(c)) return true;
    }
    return false;
}

fn copyInto(tail: *[]u8, bytes: []const u8) []const u8 {
    const out = tail.*[0..bytes.len];
    @memcpy(out, bytes);
    tail.* = tail.*[bytes.len..];
    return out;
}

/// A counted reference to the record of (`namespace_uri`, `prefix`,
/// `local_name`) in `scope`'s table - for a name no static table has
/// (Element tries html_core's first, so a known name never gets a second
/// record). The caller keeps it until its `release`.
pub fn intern(scope: *runtime.BrowserScope, namespace_uri: ?[]const u8, prefix: ?[]const u8, local_name: []const u8) error{OutOfMemory}!*const ElementName {
    checkOwnerThread(scope);
    const table = try scope.table(.element_names, Table);
    return table.intern(namespace_uri, prefix, local_name);
}

/// Drop a reference `intern` gave - or nothing, for a static record. The
/// table is asked first: once `scope`'s tables have ended (its end), the
/// table's end freed every record still in it, so a record is read only
/// while its table lives.
pub fn release(scope: *runtime.BrowserScope, record: *const ElementName) void {
    const table = scope.existingTable(.element_names, Table) orelse return;
    if (record.is_static) return;
    checkOwnerThread(scope);
    table.release(record);
}

/// Debug: `scope`'s names are made and freed on its window agent's thread -
/// the thread whose agent claimed the Browser's DOM memory
/// (runtime.gc.ExternalMemory.claim, at the agent's start; released at its
/// end). A scope no agent has claimed (an engine-less test's, a Browser's
/// last sweep after its agent let go) is not checked, as its DOM memory is
/// not (ExternalMemory.checkThread).
pub fn checkOwnerThread(scope: *runtime.BrowserScope) void {
    if (comptime !debug_checks or @TypeOf(scope.dom_memory.thread) == void) return;
    const owner = scope.dom_memory.thread orelse return;
    if (owner != std.Thread.getCurrentId()) @panic("a Browser's element names were used on a thread other than its window agent's");
}

// ============================================================================
// Tests
// ============================================================================

test "a name is interned once per table, exact in every part, its strings in one block" {
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    defer scope.deinit();

    const html = infra.namespaces.HTML_NAMESPACE;
    const a = try intern(&scope, html, null, "x-foo");
    try std.testing.expect(try intern(&scope, html, null, "x-foo") == a);
    try std.testing.expect(a.namespace_uri.?.ptr == html.ptr);
    try std.testing.expect(a.namespace == .html and !a.is_static and a.prefix == null);
    try std.testing.expectEqualStrings("x-foo", a.qualified_name);
    try std.testing.expectEqualStrings("X-FOO", a.qualified_name_upper);
    try std.testing.expect(a.qualified_name.ptr == a.local_name.ptr);

    // Prefix, namespace and case each make another name.
    const prefixed = try intern(&scope, html, "p", "x-foo");
    const other_ns = try intern(&scope, "urn:x", null, "x-foo");
    const upper = try intern(&scope, html, null, "X-FOO");
    const no_ns = try intern(&scope, null, null, "x-foo");
    for ([_]*const ElementName{ prefixed, other_ns, upper, no_ns }) |name| try std.testing.expect(name != a);
    try std.testing.expectEqualStrings("p:x-foo", prefixed.qualified_name);
    try std.testing.expectEqualStrings("P:X-FOO", prefixed.qualified_name_upper);
    try std.testing.expectEqualStrings("urn:x", other_ns.namespace_uri.?);
    try std.testing.expect(other_ns.namespace == .other);
    // An all-uppercase name is its own uppercase: no second copy.
    try std.testing.expect(upper.qualified_name_upper.ptr == upper.qualified_name.ptr);
    try std.testing.expect(no_ns.namespace == .none and no_ns.namespace_uri == null);
    try std.testing.expectEqual(@as(usize, 5), (try scope.table(.element_names, Table)).count());

    // Blink's Matches: namespace and local name, not the prefix.
    try std.testing.expect(prefixed.matches(a) and a.matches(prefixed));
    try std.testing.expect(!other_ns.matches(a) and !upper.matches(a));
    try std.testing.expect(other_ns.matches(try intern(&scope, "urn:x", "q", "x-foo")));
    try std.testing.expect(!other_ns.matches(try intern(&scope, "urn:y", null, "x-foo")));
    try std.testing.expect(a.is(.html, "x-foo") and prefixed.is(.html, "x-foo") and !a.is(.svg, "x-foo"));
}

test "tagName uppercases only an HTML element of an HTML document" {
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    defer scope.deinit();
    const html = try intern(&scope, infra.namespaces.HTML_NAMESPACE, "p", "Div");
    try std.testing.expectEqualStrings("P:DIV", html.tagName(true));
    try std.testing.expectEqualStrings("p:Div", html.tagName(false));
    const svg = try intern(&scope, infra.namespaces.SVG_NAMESPACE, null, "fooBar");
    try std.testing.expectEqualStrings("fooBar", svg.tagName(true));
    // Only ASCII letters uppercase.
    const accented = try intern(&scope, infra.namespaces.HTML_NAMESPACE, null, "x-\u{e9}t\u{e9}");
    try std.testing.expectEqualStrings("X-\u{e9}T\u{e9}", accented.tagName(true));
}

test "a static record is comptime data in its namespace" {
    const div = comptime ElementName.initStatic(infra.namespaces.HTML_NAMESPACE, "div");
    try std.testing.expect(div.is_static and div.namespace == .html and div.prefix == null);
    try std.testing.expectEqualStrings("DIV", div.qualified_name_upper);
    try std.testing.expect(div.namespace_uri.?.ptr == infra.namespaces.HTML_NAMESPACE.ptr);
    const path = comptime ElementName.initStatic(infra.namespaces.SVG_NAMESPACE, "foreignObject");
    try std.testing.expect(path.namespace == .svg);
    try std.testing.expectEqualStrings("FOREIGNOBJECT", path.qualified_name_upper);
    try std.testing.expect(namespaceOf(null) == .none and namespaceOf("urn:x") == .other and namespaceOf(infra.namespaces.MATHML_NAMESPACE) == .mathml);
}

test "a record is counted: the last release frees it, and the map shrinks with the names it holds" {
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    defer scope.deinit();
    const html = infra.namespaces.HTML_NAMESPACE;

    const a = try intern(&scope, html, null, "x-a");
    try std.testing.expect(try intern(&scope, html, null, "x-a") == a);
    try std.testing.expectEqual(@as(u32, 2), a.references);
    const table = scope.existingTable(.element_names, Table).?;
    release(&scope, a);
    try std.testing.expectEqual(@as(usize, 1), table.count());
    release(&scope, a);
    try std.testing.expectEqual(@as(usize, 0), table.count());
    // A static record is never counted: releasing one changes nothing.
    release(&scope, &unnamed);

    // Many names at once, then gone: the map gives its storage back.
    var held: std.ArrayList(*const ElementName) = .empty;
    defer held.deinit(std.testing.allocator);
    var buffer: [16]u8 = undefined;
    for (0..10_000) |i| try held.append(std.testing.allocator, try intern(&scope, html, null, try std.fmt.bufPrint(&buffer, "x-{d}", .{i})));
    try std.testing.expect(table.records.capacity() > 10_000);
    for (held.items[3..]) |record| release(&scope, record);
    try std.testing.expectEqual(@as(usize, 3), table.count());
    try std.testing.expect(table.records.capacity() <= Table.kept_capacity);
    try std.testing.expectEqualStrings("x-2", held.items[2].local_name);
    for (held.items[0..3]) |record| release(&scope, record);
    try std.testing.expectEqual(@as(usize, 0), table.count());
}

test "names that come and go keep the map's unused slots free of tombstones" {
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    defer scope.deinit();
    const ns = "urn:churn";

    // 500 names alive at any moment, 50,000 made and dropped: every new
    // name is an insert after removals, and every miss probes to a free slot.
    var live: [500]*const ElementName = undefined;
    var buffer: [16]u8 = undefined;
    for (&live, 0..) |*slot, i| slot.* = try intern(&scope, ns, null, try std.fmt.bufPrint(&buffer, "n{d}", .{i}));
    const table = scope.existingTable(.element_names, Table).?;
    for (500..50_500) |i| {
        const at = i % live.len;
        release(&scope, live[at]);
        live[at] = try intern(&scope, ns, null, try std.fmt.bufPrint(&buffer, "n{d}", .{i}));
        // The guard keeps half the unused slots free at each insert; the
        // insert itself may take one.
        const slots = infra.tombstones.slotCounts(&table.records);
        if (slots.free * 4 < slots.capacity - slots.live) return error.TombstonesBuiltUp;
    }
    try std.testing.expectEqual(@as(usize, 500), table.count());
    try std.testing.expect(table.records.capacity() <= 1024);
    for (live) |record| release(&scope, record);
    try std.testing.expectEqual(@as(usize, 0), table.count());
}

test "a record not in the HTML namespace keeps no uppercase copy, and its block is exactly its strings" {
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    defer scope.deinit();
    const feed = try intern(&scope, null, null, "feed");
    try std.testing.expect(feed.qualified_name_upper.ptr == feed.qualified_name.ptr);
    const entry = try intern(&scope, "urn:atom", "a", "entry");
    try std.testing.expect(entry.qualified_name_upper.ptr == entry.qualified_name.ptr);
    try std.testing.expectEqual(@sizeOf(ElementName) + "entry".len + "a".len + "a:entry".len + "urn:atom".len, blockSize(entry));
    const html = try intern(&scope, infra.namespaces.HTML_NAMESPACE, "h", "x-item");
    try std.testing.expectEqualStrings("H:X-ITEM", html.qualified_name_upper);
    try std.testing.expectEqual(@sizeOf(ElementName) + "x-item".len + "h".len + 2 * "h:x-item".len, blockSize(html));
    for ([_]*const ElementName{ feed, entry, html }) |record| release(&scope, record);
}
