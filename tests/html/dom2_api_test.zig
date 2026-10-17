//! DOM 4.13 algorithm regressions with a fresh Browser thread.
const std = @import("std");
const browser_mod = @import("browser");

fn runIsolated(comptime exercise: fn () anyerror!void) !void {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            exercise() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

// Native-only: Blink still skips serialization for an absent name (Q12).
test "removing a missing PI attribute serializes data and queues characterData" {
    try runIsolated(exerciseMissingPiAttribute);
}

test "cloning a PI copies data without factory validation" {
    try runIsolated(exercisePiClone);
}

fn exercisePiClone() !void {
    const allocator = std.testing.allocator;
    const browser = try browser_mod.Browser.init(allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    const result = try page.evaluateScriptToString(
        \\(() => {
        \\  const pi = document.createProcessingInstruction('test', 'valid');
        \\  pi.data = 'changed ?> data';
        \\  const copy = pi.cloneNode();
        \\  return [copy.target, copy.data, copy.ownerDocument === pi.ownerDocument].join('|');
        \\})()
    , allocator);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("test|changed ?> data|true", result);
}

fn exerciseMissingPiAttribute() !void {
    const allocator = std.testing.allocator;
    const browser = try browser_mod.Browser.init(allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    const result = try page.evaluateScriptToString(
        \\(() => {
        \\  const pi = document.createProcessingInstruction('test', "a='b'");
        \\  const observer = new MutationObserver(() => {});
        \\  observer.observe(pi, { characterData: true, characterDataOldValue: true });
        \\  pi.removeAttribute('missing');
        \\  const records = observer.takeRecords();
        \\  const result = [pi.data, records.length, records[0]?.type,
        \\    records[0]?.oldValue, records[0]?.target === pi].join('|');
        \\  observer.disconnect();
        \\  return result;
        \\})()
    , allocator);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("a=\"b\"|1|characterData|a='b'|true", result);
}
