//! A Document's origin is a construction fact (impls boundary B2: facts
//! given at construction travel the generated chain as construction
//! arguments): `interfaces.Document.initWith(.., .{ .origin = record })`
//! makes a document whose origin IS `record` - shared with the document it
//! came from - and with no argument a document has an origin of its own.
//! The record is reference counted: each document holds one reference, a
//! navigation's snapshot holds another, and std.testing.allocator fails a
//! test that leaks or frees one twice.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

const allocator = testing.allocator;
const document_origin = dom.document_origin;

const Realm = struct {
    ctx: runtime.ContextData,

    fn init(self: *Realm) !void {
        interfaces.process_hooks.startHooksForTest();
        runtime.initializeRuntime(allocator);
        self.ctx = try runtime.ContextData.init(allocator, .{});
    }

    fn deinit(self: *Realm) void {
        self.ctx.deinit();
        runtime.deinitializeRuntime();
    }
};

test "Document takes its origin as a construction argument" {
    try testing.expect(interfaces.Document.takesConstructionArg("origin"));
    // Nothing else on Node's chain does.
    try testing.expect(!interfaces.Node.takesConstructionArg("origin"));
    try testing.expect(!interfaces.HTMLDivElement.takesConstructionArg("origin"));
}

test "a document made with another's origin shares its record, domain included" {
    var realm: Realm = undefined;
    try realm.init();
    defer realm.deinit();

    const creator = try interfaces.Document.init(allocator, &realm.ctx);
    defer interfaces.Document.deinit(creator);
    const record = document_origin.record(creator) orelse return error.TestExpectedOrigin;
    const made = try interfaces.Document.initWith(allocator, &realm.ctx, .{ .origin = record });
    defer interfaces.Document.deinit(made);
    try testing.expect(document_origin.record(made) == record);

    // document.domain's step 7 sets the shared record's domain: both
    // documents see it.
    try testing.expectEqual(@as(?[]const u8, null), document_origin.domain(made));
    try record.setDomain("example.test");
    try testing.expectEqualStrings("example.test", document_origin.domain(made).?);
    try testing.expectEqualStrings("example.test", document_origin.domain(creator).?);
}

test "a document made without an origin has one of its own" {
    var realm: Realm = undefined;
    try realm.init();
    defer realm.deinit();

    const a = try interfaces.Document.init(allocator, &realm.ctx);
    defer interfaces.Document.deinit(a);
    const b = try interfaces.Document.init(allocator, &realm.ctx);
    defer interfaces.Document.deinit(b);
    const a_record = document_origin.record(a) orelse return error.TestExpectedOrigin;
    const b_record = document_origin.record(b) orelse return error.TestExpectedOrigin;
    try testing.expect(a_record != b_record);
    try a_record.setDomain("example.test");
    try testing.expectEqual(@as(?[]const u8, null), document_origin.domain(b));
}

test "the shared origin outlives the document that made it" {
    var realm: Realm = undefined;
    try realm.init();
    defer realm.deinit();

    // The creator goes first: its inheriting document keeps the origin.
    const creator = try interfaces.Document.init(allocator, &realm.ctx);
    const record = document_origin.record(creator) orelse return error.TestExpectedOrigin;
    try record.setDomain("example.test");
    const inheritor = try interfaces.Document.initWith(allocator, &realm.ctx, .{ .origin = record });
    defer interfaces.Document.deinit(inheritor);
    interfaces.Document.deinit(creator);
    try testing.expectEqualStrings("example.test", document_origin.domain(inheritor).?);
}

test "a navigation's origin snapshot outlives its creator document's teardown" {
    var realm: Realm = undefined;
    try realm.init();
    defer realm.deinit();

    // Navigate step 4's initiator origin snapshot is the source document's
    // origin, held by the queued navigation (Location's and the iframe's
    // javascript: navigations): the source document may be torn down before
    // the task runs, and the snapshot - its serialization resolved, its
    // domain as set - stays readable until the task releases it.
    const source = try interfaces.Document.init(allocator, &realm.ctx);
    try dom.document_internals.setURL(source, "https://a.example.test/page");
    const shared = (try document_origin.shareable(source)) orelse return error.TestExpectedOrigin;
    const snapshot = shared.retain();
    defer snapshot.release();
    try snapshot.setDomain("example.test");
    interfaces.Document.deinit(source);
    try testing.expectEqualStrings("https://a.example.test", snapshot.serialized.?);
    try testing.expectEqualStrings("example.test", snapshot.domain.?);
}

test "a windowless document made with an origin serializes it, not its URL" {
    var realm: Realm = undefined;
    try realm.init();
    defer realm.deinit();

    // new Document() and createHTMLDocument() make an about:blank document
    // whose origin is the associated Document's: its domain getter answers
    // that origin's host, not about:blank's opaque origin's empty string.
    const associated = try interfaces.Document.init(allocator, &realm.ctx);
    defer interfaces.Document.deinit(associated);
    try dom.document_internals.setURL(associated, "https://sub.example.test/page");
    const record = (try document_origin.shareable(associated)) orelse return error.TestExpectedOrigin;
    const made = try interfaces.Document.initWith(allocator, &realm.ctx, .{ .origin = record });
    defer interfaces.Document.deinit(made);
    try dom.document_internals.setURL(made, "about:blank");
    const domain = try interfaces.Document.get_domain(made);
    defer made.ctx.allocator.free(domain);
    try testing.expectEqualStrings("sub.example.test", domain);
    try record.setDomain("example.test");
    const relaxed = try interfaces.Document.get_domain(made);
    defer made.ctx.allocator.free(relaxed);
    try testing.expectEqualStrings("example.test", relaxed);
}
