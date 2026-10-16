//! A worker global scope's settings object keeps its origin as a record
//! (dom.origin_record), as a Window's does through its document: the same
//! object every time it is asked for, so an opaque origin is the same opaque
//! origin as itself (HTML "same origin" step 1) - Origin.from(self) in a
//! worker equals itself.
//!
//! HTML "set up a worker environment settings object", the origin: "a unique
//! opaque origin if worker global scope's url's scheme is "data", and
//! inherited origin otherwise." The record is made with the global scope, on
//! its thread, and released with it.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const global_settings = @import("dom").global_settings;

const allocator = testing.allocator;

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

test "a data: worker's origin is one opaque record, the same each time" {
    var realm: Realm = undefined;
    try realm.init();
    defer realm.deinit();

    const scope = try interfaces.DedicatedWorkerGlobalScope.initWith(allocator, &realm.ctx, .{ .url = "data:text/javascript,postMessage(1)" });
    defer interfaces.DedicatedWorkerGlobalScope.deinit(scope);

    const first = (try global_settings.shareableOriginOf(scope)) orelse return error.NoRecord;
    const second = (try global_settings.shareableOriginOf(scope)) orelse return error.NoRecord;
    try testing.expectEqual(first, second);
    try testing.expect(first.isOpaque());
    try testing.expect(global_settings.originRecordOf(scope) == first);
}

test "two data: workers have two opaque origins" {
    var realm: Realm = undefined;
    try realm.init();
    defer realm.deinit();

    const a = try interfaces.DedicatedWorkerGlobalScope.initWith(allocator, &realm.ctx, .{ .url = "data:,a" });
    defer interfaces.DedicatedWorkerGlobalScope.deinit(a);
    const b = try interfaces.DedicatedWorkerGlobalScope.initWith(allocator, &realm.ctx, .{ .url = "data:,b" });
    defer interfaces.DedicatedWorkerGlobalScope.deinit(b);

    const record_a = (try global_settings.shareableOriginOf(a)).?;
    const record_b = (try global_settings.shareableOriginOf(b)).?;
    try testing.expect(record_a != record_b);
    try testing.expect(!global_settings.sameOriginDomain(a, b));
}

test "a worker with a tuple origin keeps it as a record, rebuilt from its serialization" {
    var realm: Realm = undefined;
    try realm.init();
    defer realm.deinit();

    const scope = try interfaces.SharedWorkerGlobalScope.initWith(allocator, &realm.ctx, .{ .url = "http://a.test:8000/w.js" });
    defer interfaces.SharedWorkerGlobalScope.deinit(scope);

    const record = (try global_settings.shareableOriginOf(scope)) orelse return error.NoRecord;
    try testing.expectEqualStrings("http://a.test:8000", record.serialized.?);
    try testing.expect(!record.isOpaque());
    try testing.expectEqual(record, (try global_settings.shareableOriginOf(scope)).?);
}

test "a WorkerGlobalScope takes its url at construction; EventTarget does not" {
    try testing.expect(interfaces.WorkerGlobalScope.takesConstructionArg("url"));
    try testing.expect(interfaces.DedicatedWorkerGlobalScope.takesConstructionArg("url"));
    try testing.expect(!interfaces.EventTarget.takesConstructionArg("url"));
}
