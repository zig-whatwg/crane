//! HTML's origin (7.1.1) as the object Documents share: "Origins can be
//! shared, e.g., among multiple Document objects. Furthermore, origins are
//! generally immutable. Only the domain of a tuple origin can be changed,
//! and only through the document.domain API."
//!
//! A document whose origin HTML says IS another's - an initial about:blank
//! document and its creator's, a srcdoc document and its container
//! document's, a javascript: URL's document and its initiator's, a document
//! made by new Document() or createHTMLDocument() and the associated
//! Document's, a clone and its original - holds the same record, so
//! document.domain set through either changes both
//! (windows/document-domain-nested-set.window.js).
//!
//! Ownership: reference counted. Every holder - a Document (its
//! InternalState.origin), a navigation's initiator snapshot, a navigable's
//! next document - holds one reference and releases it exactly once; the
//! last release frees the record, whoever made it. So a shared origin
//! outlives the document that made it: the creator can navigate away or be
//! torn down while the about:blank document it made keeps its origin, domain
//! included. WebKit's design, taken here (not its code): SecurityOrigin is
//! RefCounted, a Document holds it through its SecurityContext, and an
//! inheriting document is given its creator's (Document::initSecurityContext
//! shares the owner's SecurityOriginPolicy, which document.domain mutates -
//! SecurityOrigin::setDomainFromDOM).
//!
//! Threads: a record's holders are one Browser's documents and its window
//! agent's navigations, which all run on that Browser's one thread
//! (docs/instances.md: a Browser is one thread for its window agent plus one
//! per worker). A document shares its origin only with documents its own
//! agent makes; a worker, another Browser and every fetch get the
//! serialization, never the record. So the count is a plain integer, and
//! builds with runtime safety check that every retain, release and domain
//! change happens on the thread that made the record. Two Browsers on two
//! threads never meet in one record, and there is no process-wide state.
//!
//! Allocation: the record is allocated by, and freed with, the allocator of
//! the document that made it - its Browser's, which every holder outlives.
//!
//! Spec: https://html.spec.whatwg.org/multipage/browsers.html#concept-origin
//! Spec: https://html.spec.whatwg.org/multipage/browsers.html#same-origin-domain

const std = @import("std");
const Allocator = std.mem.Allocator;

/// One origin, shared by every document whose origin it is.
pub const OriginRecord = struct {
    allocator: Allocator,
    /// One per holder; the last `release` frees the record.
    refs: u32,
    /// The serialization of the origin ("null" for an opaque origin), owned.
    /// Null while the document that made the record still derives its
    /// origin from its URL and its window, as every browsing-context
    /// document did before records: `resolve` records it once, when the
    /// origin is first shared - a document made with it (new Document(),
    /// createHTMLDocument(), a clone) has no window to derive it from.
    serialized: ?[]const u8,
    /// HTML "domain": null, or a host serialized, which the document.domain
    /// setter sets (`setDomain`). Owned.
    domain: ?[]const u8 = null,
    thread: ThreadCheck,

    /// A document's own origin, whose serialization is not known yet
    /// (`serialized`).
    pub fn createOwn(allocator: Allocator) error{OutOfMemory}!*OriginRecord {
        const record = try allocator.create(OriginRecord);
        record.* = .{ .allocator = allocator, .refs = 1, .serialized = null, .thread = .init() };
        return record;
    }

    /// An origin whose serialization is known: "null" makes a new opaque
    /// origin, which is the same opaque origin only as itself.
    pub fn create(allocator: Allocator, serialized: []const u8) error{OutOfMemory}!*OriginRecord {
        const record = try createOwn(allocator);
        errdefer allocator.destroy(record);
        record.serialized = try allocator.dupe(u8, serialized);
        return record;
    }

    /// Another reference to this record, for a new holder.
    pub fn retain(self: *OriginRecord) *OriginRecord {
        self.thread.check();
        std.debug.assert(self.refs > 0);
        self.refs += 1;
        return self;
    }

    /// Give up one reference; the last frees the record.
    pub fn release(self: *OriginRecord) void {
        self.thread.check();
        std.debug.assert(self.refs > 0);
        self.refs -= 1;
        if (self.refs > 0) return;
        const allocator = self.allocator;
        if (self.serialized) |s| allocator.free(s);
        if (self.domain) |d| allocator.free(d);
        allocator.destroy(self);
    }

    /// Whether the calling thread is the one this record belongs to - the
    /// check every retain, release and change asserts where runtime safety
    /// is on. Always true without it (nothing is recorded).
    pub fn isOnOwnerThread(self: *const OriginRecord) bool {
        return self.thread.isCurrent();
    }

    /// Whether this is an opaque origin (one resolved to "null").
    pub fn isOpaque(self: *const OriginRecord) bool {
        const serialized = self.serialized orelse return false;
        return std.mem.eql(u8, serialized, "null");
    }

    /// Record the serialization of a document's own origin, if it is not
    /// known yet. An origin's tuple never changes, so a later call keeps the
    /// first answer.
    pub fn resolve(self: *OriginRecord, serialized: []const u8) error{OutOfMemory}!void {
        self.thread.check();
        if (self.serialized != null) return;
        self.serialized = try self.allocator.dupe(u8, serialized);
    }

    /// The document.domain setter's step 7: "Set this's origin's domain to
    /// the result of parsing the given value" - `domain`, a host already
    /// parsed and serialized. Every holder sees it.
    pub fn setDomain(self: *OriginRecord, domain: []const u8) error{OutOfMemory}!void {
        self.thread.check();
        const copy = try self.allocator.dupe(u8, domain);
        if (self.domain) |old| self.allocator.free(old);
        self.domain = copy;
    }
};

/// The thread a record belongs to, checked where runtime safety is on: a
/// retain or release from any other thread would race on the count.
const ThreadCheck = struct {
    id: if (std.debug.runtime_safety) std.Thread.Id else void,

    fn init() ThreadCheck {
        return .{ .id = if (std.debug.runtime_safety) std.Thread.getCurrentId() else {} };
    }

    fn isCurrent(self: ThreadCheck) bool {
        if (!std.debug.runtime_safety) return true;
        return self.id == std.Thread.getCurrentId();
    }

    fn check(self: ThreadCheck) void {
        if (std.debug.runtime_safety) std.debug.assert(self.isCurrent());
    }
};

/// An origin as a security check reads it, borrowed for the call: its
/// serialization ("null" for an opaque origin) - for a browsing-context
/// document, its window's - and its record, whose identity and domain the
/// serialization does not carry. A holder with no record has a null domain.
pub const Origin = struct {
    serialized: []const u8,
    record: ?*const OriginRecord = null,

    fn domain(self: Origin) ?[]const u8 {
        const record = self.record orelse return null;
        return record.domain;
    }
};

/// HTML "same origin".
/// Spec: https://html.spec.whatwg.org/multipage/browsers.html#same-origin
pub fn sameOrigin(a: Origin, b: Origin) bool {
    // 1. "If A and B are the same opaque origin, then return true." One
    // record is one origin, opaque or not.
    if (a.record != null and a.record == b.record) return true;
    // 2. "If A and B are both tuple origins and their schemes, hosts, and
    // port are identical, then return true." A serialization alone names
    // no opaque origin.
    if (isOpaqueSerialization(a.serialized) or isOpaqueSerialization(b.serialized)) return false;
    return std.mem.eql(u8, a.serialized, b.serialized);
}

/// HTML "same origin-domain".
/// Spec: https://html.spec.whatwg.org/multipage/browsers.html#same-origin-domain
pub fn sameOriginDomain(a: Origin, b: Origin) bool {
    // 1. "If A and B are the same opaque origin, then return true." One
    // record is one origin: for a tuple origin its scheme and domain are
    // identical too, so 2.1 or 2.2 holds.
    if (a.record != null and a.record == b.record) return true;
    // 2. "If A and B are both tuple origins": the domains are the records'.
    return sameOriginDomainValues(a.serialized, a.domain(), b.serialized, b.domain());
}

/// HTML "same origin-domain" over canonical origin serializations and the
/// separately stored domains. Serialization deliberately omits the domain.
/// The caller handles known shared identity first (`sameOriginDomain`):
/// "null" alone cannot distinguish opaque origins. All slices are borrowed
/// for this call.
/// Spec: https://html.spec.whatwg.org/multipage/browsers.html#same-origin-domain
pub fn sameOriginDomainValues(a_origin: []const u8, a_domain: ?[]const u8, b_origin: []const u8, b_domain: ?[]const u8) bool {
    // 1. No opaque identity can be recovered from its serialization.
    if (isOpaqueSerialization(a_origin) or isOpaqueSerialization(b_origin)) return false;
    // 2.1. A domain opt-in requires the other origin to opt in too.
    if (a_domain) |domain| {
        const other_domain = b_domain orelse return false;
        const a_scheme = a_origin[0 .. std.mem.indexOfScalar(u8, a_origin, ':') orelse a_origin.len];
        const b_scheme = b_origin[0 .. std.mem.indexOfScalar(u8, b_origin, ':') orelse b_origin.len];
        return std.mem.eql(u8, a_scheme, b_scheme) and std.mem.eql(u8, domain, other_domain);
    }
    // 2.2-3. Canonical serialization compares scheme, host and port only.
    return b_domain == null and std.mem.eql(u8, a_origin, b_origin);
}

fn isOpaqueSerialization(serialized: []const u8) bool {
    return std.mem.eql(u8, serialized, "null");
}
