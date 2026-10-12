//! HTML 7.1.1: "Origins can be shared, e.g., among multiple Document
//! objects. Furthermore, origins are generally immutable. Only the domain of
//! a tuple origin can be changed, and only through the document.domain API."
//!
//! Crane's origin object is dom.origin_record.OriginRecord: reference
//! counted, one reference per holder. Every test here runs on
//! std.testing.allocator, so a record a test leaves behind - or frees twice -
//! fails it.
const std = @import("std");
const testing = std.testing;
const dom = @import("dom");

const origin_record = dom.origin_record;
const OriginRecord = origin_record.OriginRecord;

const allocator = testing.allocator;

test "a record lives until its last holder releases it" {
    const record = try OriginRecord.create(allocator, "https://a.example.test");
    const second = record.retain();
    try testing.expect(second == record);
    record.release();
    // The second holder still reads it.
    try testing.expectEqualStrings("https://a.example.test", second.serialized.?);
    second.release();
}

test "a domain set through one holder is the domain every holder sees" {
    // The creator's document and its initial about:blank child share one
    // origin: document.domain set in either changes both
    // (windows/document-domain-nested-set.window.js).
    const creator = try OriginRecord.create(allocator, "https://sub.example.test");
    defer creator.release();
    const child = creator.retain();
    defer child.release();
    try testing.expectEqual(@as(?[]const u8, null), creator.domain);
    try child.setDomain("example.test");
    try testing.expectEqualStrings("example.test", creator.domain.?);
    // Setting it again replaces the owned copy.
    try creator.setDomain("sub.example.test");
    try testing.expectEqualStrings("sub.example.test", child.domain.?);
}

test "a shared record outlives the document that made it" {
    // The creator goes first - navigated away, or torn down - and the
    // inheriting document keeps the origin, domain included.
    const creator = try OriginRecord.create(allocator, "https://sub.example.test");
    try creator.setDomain("example.test");
    const inheritor = creator.retain();
    creator.release();
    try testing.expectEqualStrings("example.test", inheritor.domain.?);
    try testing.expectEqualStrings("https://sub.example.test", inheritor.serialized.?);
    inheritor.release();
}

test "a document's own record resolves its serialization once" {
    // A browsing-context document's origin is still derived from its URL and
    // window; its record learns the serialization when it is first shared.
    const own = try OriginRecord.createOwn(allocator);
    defer own.release();
    try testing.expectEqual(@as(?[]const u8, null), own.serialized);
    try own.resolve("https://a.example.test:8000");
    try testing.expectEqualStrings("https://a.example.test:8000", own.serialized.?);
    // An origin's tuple never changes: a later resolution is not a new origin.
    try own.resolve("https://b.example.test");
    try testing.expectEqualStrings("https://a.example.test:8000", own.serialized.?);
}

test "an opaque record is the same opaque origin only with itself" {
    const a = try OriginRecord.create(allocator, "null");
    defer a.release();
    const b = try OriginRecord.create(allocator, "null");
    defer b.release();
    try testing.expect(a.isOpaque());
    const view_a: origin_record.Origin = .{ .serialized = "null", .record = a };
    const view_b: origin_record.Origin = .{ .serialized = "null", .record = b };
    // 1. "If A and B are the same opaque origin, then return true."
    try testing.expect(origin_record.sameOrigin(view_a, view_a));
    try testing.expect(origin_record.sameOriginDomain(view_a, view_a));
    try testing.expect(!origin_record.sameOrigin(view_a, view_b));
    try testing.expect(!origin_record.sameOriginDomain(view_a, view_b));
    // A serialization alone names no opaque origin.
    try testing.expect(!origin_record.sameOriginDomain(.{ .serialized = "null" }, .{ .serialized = "null" }));
}

test "same origin-domain reads each record's domain" {
    const a = try OriginRecord.create(allocator, "https://a.example.test:8000");
    defer a.release();
    const b = try OriginRecord.create(allocator, "https://b.example.test:8001");
    defer b.release();
    const view_a: origin_record.Origin = .{ .serialized = "https://a.example.test:8000", .record = a };
    const view_b: origin_record.Origin = .{ .serialized = "https://b.example.test:8001", .record = b };
    try testing.expect(!origin_record.sameOriginDomain(view_a, view_b));
    // One side opting in is not enough (2.1 needs both non-null).
    try a.setDomain("example.test");
    try testing.expect(!origin_record.sameOriginDomain(view_a, view_b));
    try testing.expect(!origin_record.sameOriginDomain(view_b, view_a));
    // Both: hosts and ports no longer participate, schemes still do.
    try b.setDomain("example.test");
    try testing.expect(origin_record.sameOriginDomain(view_a, view_b));
    try testing.expect(!origin_record.sameOrigin(view_a, view_b));
    const http: origin_record.Origin = .{ .serialized = "http://b.example.test", .record = b };
    try testing.expect(!origin_record.sameOriginDomain(view_a, http));
}

test "one shared record is same origin-domain with itself whatever its domain" {
    // A document and the about:blank document that inherited its origin:
    // the same origin object, so its domain is identical on both sides even
    // when only one of them set it.
    const shared = try OriginRecord.create(allocator, "https://a.example.test");
    defer shared.release();
    try shared.setDomain("example.test");
    const parent: origin_record.Origin = .{ .serialized = "https://a.example.test", .record = shared };
    const child: origin_record.Origin = .{ .serialized = "https://a.example.test", .record = shared };
    try testing.expect(origin_record.sameOriginDomain(parent, child));
    // A different record with the same tuple and no domain is not.
    const other = try OriginRecord.create(allocator, "https://a.example.test");
    defer other.release();
    try testing.expect(!origin_record.sameOriginDomain(parent, .{ .serialized = "https://a.example.test", .record = other }));
    try testing.expect(origin_record.sameOrigin(parent, .{ .serialized = "https://a.example.test", .record = other }));
}

test "serialized origin-domain comparison keeps ports only before opting in" {
    const compare = origin_record.sameOriginDomainValues;
    try testing.expect(compare("https://a.example.test:8000", null, "https://a.example.test:8000", null));
    try testing.expect(!compare("https://a.example.test:8000", null, "https://a.example.test:8001", null));
    try testing.expect(!compare("https://a.example.test:8000", "example.test", "https://a.example.test:8000", null));
    try testing.expect(compare("https://a.example.test:8000", "example.test", "https://b.example.test:8001", "example.test"));
    try testing.expect(!compare("http://a.example.test", "example.test", "https://b.example.test", "example.test"));
    try testing.expect(!compare("null", null, "null", null));
}

test "a record touched from another thread fails its thread check" {
    // A record's count is not atomic: its holders are one Browser's, on that
    // Browser's thread. Where runtime safety is on, every retain, release
    // and domain change asserts it - this pins the predicate the assertion
    // uses, from a thread that is not the record's.
    if (!std.debug.runtime_safety) return error.SkipZigTest;
    const record = try OriginRecord.create(allocator, "https://a.example.test");
    defer record.release();
    try testing.expect(record.isOnOwnerThread());
    var seen_from_other_thread = true;
    const thread = try std.Thread.spawn(.{}, struct {
        fn run(r: *const OriginRecord, out: *bool) void {
            out.* = r.isOnOwnerThread();
        }
    }.run, .{ record, &seen_from_other_thread });
    thread.join();
    try testing.expect(!seen_from_other_thread);
}
