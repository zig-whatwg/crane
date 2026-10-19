//! MessageEvent construction owns its values and only UA construction can
//! attach an origin record. Each allocation trial has an independent scope.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const OriginRecord = dom.origin_record.OriginRecord;
// Use the public constructor's dictionary type without adding a test-module
// dependency to build.zig.
const MessageEventInit = @FieldType(@typeInfo(@TypeOf(interfaces.MessageEvent.call_constructor)).@"fn".params[2].type.?, "value");

fn construct(ctx: runtime.Context, record: ?*OriginRecord) !*runtime.Instance {
    const dictionary = MessageEventInit{
        .base = .{ .bubbles = true, .cancelable = true, .composed = true },
        .data = runtime.JSValue.fromStringRef("payload"),
        .origin = "https://sender.test",
        .lastEventId = runtime.DOMString.initInterned("last-id"),
    };
    if (record) |actual| {
        return interfaces.MessageEvent.initWith(ctx.allocator, ctx, .{
            .message_type = runtime.DOMString.initInterned("message"),
            .message_init = dictionary,
            .message_origin_record = actual,
        });
    }
    return interfaces.MessageEvent.call_constructor(ctx, runtime.DOMString.initInterned("message"), .passed(dictionary));
}

fn constructionTrial(allocator: std.mem.Allocator, record: ?*OriginRecord) !void {
    var scope = runtime.BrowserScope.init(allocator);
    defer scope.deinit();
    var ctx = try runtime.ContextData.init(allocator, .{});
    ctx.browser_scope = &scope;
    defer ctx.deinit();
    const before: u32 = if (record) |actual| actual.refs else 0;
    const event = construct(&ctx, record) catch |err| {
        if (record) |actual| try std.testing.expectEqual(before, actual.refs);
        return err;
    };
    runtime.Instance.deinit(event);
    if (record) |actual| try std.testing.expectEqual(before, actual.refs);
}

test "MessageEvent script construction preserves fields and has no extractable origin" {
    interfaces.process_hooks.startHooksForTest();
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    defer scope.deinit();
    var ctx = try runtime.ContextData.init(std.testing.allocator, .{});
    ctx.browser_scope = &scope;
    defer ctx.deinit();
    const event = try construct(&ctx, null);
    defer runtime.Instance.deinit(event);
    try std.testing.expectEqualStrings("payload", (try interfaces.MessageEvent.get_data(event)).string.data);
    const text = try interfaces.MessageEvent.get_origin(event);
    defer std.testing.allocator.free(text);
    try std.testing.expectEqualStrings("https://sender.test", text);
    try std.testing.expectEqualStrings("last-id", (try interfaces.MessageEvent.get_lastEventId(event)).asSlice());
    try std.testing.expect(try interfaces.Event.get_bubbles(event));
    try std.testing.expect(try interfaces.Event.get_cancelable(event));
    try std.testing.expect(try interfaces.Event.get_composed(event));
    try std.testing.expect(!try interfaces.Event.get_isTrusted(event));
    try std.testing.expect((try dom.extract_origin.extract(event)) == null);
}

test "UA MessageEvent construction keeps an opaque origin until reinitialization" {
    interfaces.process_hooks.startHooksForTest();
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    defer scope.deinit();
    var ctx = try runtime.ContextData.init(std.testing.allocator, .{});
    ctx.browser_scope = &scope;
    defer ctx.deinit();
    const record = try OriginRecord.create(std.testing.allocator, "null");
    defer record.release();
    const event = try construct(&ctx, record);
    defer runtime.Instance.deinit(event);
    const extracted = (try dom.extract_origin.extract(event)) orelse return error.NoOriginRecord;
    defer extracted.release();
    try std.testing.expectEqual(record, extracted);
    const text = try interfaces.MessageEvent.get_origin(event);
    defer std.testing.allocator.free(text);
    try std.testing.expectEqualStrings("null", text);
    try interfaces.MessageEvent.call_initMessageEvent(event, runtime.DOMString.initInterned("changed"), .notPassed(), .notPassed(), .notPassed(), .passed("null"), .notPassed(), .notPassed(), .notPassed());
    try std.testing.expect((try dom.extract_origin.extract(event)) == null);
    try std.testing.expectEqual(@as(u32, 2), record.refs);
}

test "MessageEvent construction unwinds every allocation failure with and without an origin record" {
    interfaces.process_hooks.startHooksForTest();
    try std.testing.checkAllAllocationFailures(std.testing.allocator, constructionTrial, .{@as(?*OriginRecord, null)});
    const record = try OriginRecord.create(std.testing.allocator, "null");
    defer record.release();
    try std.testing.checkAllAllocationFailures(std.testing.allocator, constructionTrial, .{@as(?*OriginRecord, record)});
    try std.testing.expectEqual(@as(u32, 1), record.refs);
}
