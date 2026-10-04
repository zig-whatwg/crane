//! HTML 9.2.5–9.2.6, independent of an engine or network connection.
const std = @import("std");
test {
    _ = @import("retry_test.zig");
}
const infra = @import("infra");
const eventsource = @import("eventsource");
const Parser = eventsource.Parser;
const Message = eventsource.Message;
const allocator = std.testing.allocator;

test {
    _ = @import("connection_test.zig");
    _ = @import("registry_test.zig");
}

fn release(messages: *infra.List(Message)) void {
    for (messages.toSliceMut()) |*message| message.deinit(allocator);
    messages.deinit();
}

test "a message is delivered only at a blank line, before EOF" {
    var parser = Parser.init(allocator);
    defer parser.deinit();
    var messages = infra.List(Message).init(allocator);
    defer release(&messages);
    try parser.feed("data: hello\n", &messages);
    try std.testing.expectEqual(@as(usize, 0), messages.len);
    try parser.feed("\n", &messages);
    try std.testing.expectEqual(@as(usize, 1), messages.len);
    const message = messages.get(0).?;
    try std.testing.expectEqualStrings("hello", message.data);
    try std.testing.expectEqualStrings("message", message.event_type);
    try std.testing.expectEqualStrings("", message.last_event_id);
}

test "every chunk split preserves BOM, UTF-8 and CRLF" {
    const input = "\xef\xbb\xbfdata: a\xc3\xa9\xf0\x9f\x8c\x8d\r\ndata: b\r\n\r\n";
    for (0..input.len + 1) |split| {
        var parser = Parser.init(allocator);
        defer parser.deinit();
        var messages = infra.List(Message).init(allocator);
        defer release(&messages);
        try parser.feed(input[0..split], &messages);
        try parser.feed(input[split..], &messages);
        try std.testing.expectEqual(@as(usize, 1), messages.len);
        try std.testing.expectEqualStrings("aé🌍\nb", messages.get(0).?.data);
    }
}

test "CR LF and CRLF work in one-byte chunks and only one BOM is removed" {
    const input = "\xef\xbb\xbfdata: one\r\r\ndata: two\n\n\xef\xbb\xbfdata: ignored\r\ndata: three\r\n\r\n";
    var parser = Parser.init(allocator);
    defer parser.deinit();
    var messages = infra.List(Message).init(allocator);
    defer release(&messages);
    for (0..input.len) |i| try parser.feed(input[i..][0..1], &messages);
    try std.testing.expectEqual(@as(usize, 3), messages.len);
    try std.testing.expectEqualStrings("one", messages.get(0).?.data);
    try std.testing.expectEqualStrings("two", messages.get(1).?.data);
    try std.testing.expectEqualStrings("three", messages.get(2).?.data);
}

test "field names are literal and only one leading space is removed" {
    var parser = Parser.init(allocator);
    defer parser.deinit();
    var messages = infra.List(Message).init(allocator);
    defer release(&messages);
    try parser.feed(":comment\nData:ignored\n data:ignored\ndata\x00:ignored\ndata:  first:part\ndata\ndata:\x00\n\n", &messages);
    try std.testing.expectEqual(@as(usize, 1), messages.len);
    try std.testing.expectEqualStrings(" first:part\n\n\x00", messages.get(0).?.data);
}

test "event names reset on dispatch, including an empty-data block" {
    var parser = Parser.init(allocator);
    defer parser.deinit();
    var messages = infra.List(Message).init(allocator);
    defer release(&messages);
    try parser.feed("event: ignored\n\nevent: custom\ndata: one\n\ndata:\n\nevent:\ndata: three\n\n", &messages);
    try std.testing.expectEqual(@as(usize, 3), messages.len);
    try std.testing.expectEqualStrings("custom", messages.get(0).?.event_type);
    try std.testing.expectEqualStrings("message", messages.get(1).?.event_type);
    try std.testing.expectEqualStrings("", messages.get(1).?.data);
    try std.testing.expectEqualStrings("message", messages.get(2).?.event_type);
}

test "ID commits on a blank line without data, persists, ignores NUL and resets" {
    var parser = Parser.init(allocator);
    defer parser.deinit();
    var messages = infra.List(Message).init(allocator);
    defer release(&messages);
    try parser.feed("id: …\n", &messages);
    try std.testing.expectEqualStrings("", parser.lastEventId());
    try parser.feed("\ndata: one\n\nid: no\x00pe\ndata: two\n\nid\ndata: three\n\n", &messages);
    try std.testing.expectEqual(@as(usize, 3), messages.len);
    try std.testing.expectEqualStrings("…", messages.get(0).?.last_event_id);
    try std.testing.expectEqualStrings("…", messages.get(1).?.last_event_id);
    try std.testing.expectEqualStrings("", messages.get(2).?.last_event_id);
    try std.testing.expectEqualStrings("", parser.lastEventId());
}

test "retry accepts decimal digits including zero, and rejects other syntax" {
    var parser = Parser.init(allocator);
    defer parser.deinit();
    var messages = infra.List(Message).init(allocator);
    defer release(&messages);
    try parser.feed("retry: 00042\n", &messages);
    try std.testing.expectEqual(@as(u64, 42), parser.reconnection_time);
    try parser.feed("retry: +9\nretry: -1\nretry: 3.2\nretry:  7\nretry: 9 \nretry: ９\n", &messages);
    try std.testing.expectEqual(@as(u64, 42), parser.reconnection_time);
    try parser.feed("retry: 0\n", &messages);
    try std.testing.expectEqual(@as(u64, 0), parser.reconnection_time);
}

test "malformed UTF-8 is replaced without swallowing ASCII or line endings" {
    var parser = Parser.init(allocator);
    defer parser.deinit();
    var messages = infra.List(Message).init(allocator);
    defer release(&messages);
    try parser.feed("data: \xc2X\xed\xa0\x80\xf0\x9f\n\n", &messages);
    try std.testing.expectEqual(@as(usize, 1), messages.len);
    try std.testing.expectEqualStrings("�X����", messages.get(0).?.data);
}

test "EOF discards incomplete messages and uncommitted IDs" {
    var parser = Parser.init(allocator);
    defer parser.deinit();
    var messages = infra.List(Message).init(allocator);
    defer release(&messages);
    try parser.feed("id: good\ndata: first\n\nid: bad\ndata: incomplete\n", &messages);
    parser.finish();
    try std.testing.expectEqual(@as(usize, 1), messages.len);
    try std.testing.expectEqualStrings("good", parser.lastEventId());
    try std.testing.expectEqualStrings("first", messages.get(0).?.data);
}

test "a new stream carries only committed ID and retry state, and recognizes a new BOM" {
    var parser = Parser.init(allocator);
    defer parser.deinit();
    var messages = infra.List(Message).init(allocator);
    defer release(&messages);
    try parser.feed("id: keep\nretry: 17\ndata: first\n\nid: discard\nevent: discard\ndata: unfinished", &messages);
    parser.finish();
    try parser.reset();
    try parser.feed("\xef\xbb\xbfdata: next\n\n", &messages);
    try std.testing.expectEqual(@as(usize, 2), messages.len);
    try std.testing.expectEqualStrings("next", messages.get(1).?.data);
    try std.testing.expectEqualStrings("message", messages.get(1).?.event_type);
    try std.testing.expectEqualStrings("keep", messages.get(1).?.last_event_id);
    try std.testing.expectEqual(@as(u64, 17), parser.reconnection_time);
}

fn allocationCase(a: std.mem.Allocator) !void {
    var parser = Parser.init(a);
    defer parser.deinit();
    var messages = infra.List(Message).init(a);
    defer {
        for (messages.toSliceMut()) |*message| message.deinit(a);
        messages.deinit();
    }
    try parser.feed("id: 1\nevent: ready\ndata: café\n\ndata: next\n\n", &messages);
}

test "partial parser and output allocations are released on allocation failure" {
    try std.testing.checkAllAllocationFailures(allocator, allocationCase, .{});
}
