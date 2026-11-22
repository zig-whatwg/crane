//! The remote end's cross-thread queues (lane cdpt): a connection's outbound
//! FIFO keeps each producer's order while Browser threads and the devtools
//! thread push at once, and its writer drains it; a session link outlives
//! its session safely. Run under -Dsanitize-thread too (tests/AGENTS.md):
//! every push races the writer's take.
//!
//! Written in the CDP phase (user directive 2026-11-21 5:48 PM ET: implement
//! now, run every test in one later pass).

const std = @import("std");
const testing = std.testing;
const devtools = @import("devtools");

const Outbound = devtools.outbound.Outbound;
const SessionLink = devtools.outbound.SessionLink;
const LeakChecked = std.heap.DebugAllocator(.{ .thread_safe = true });

const producers = 4;
const per_producer = 500;

fn produce(link: *SessionLink, index: usize) void {
    var i: usize = 0;
    while (i < per_producer) : (i += 1) {
        const message = std.fmt.allocPrint(link.allocator, "{d}:{d}", .{ index, i }) catch return;
        link.send(message);
    }
}

test "every producer's messages come out whole and in its own order while a writer drains" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const out = try Outbound.create(allocator);
    defer out.release();

    var links: [producers]*SessionLink = undefined;
    for (&links, 0..) |*l, i| {
        var id: [8]u8 = undefined;
        l.* = try SessionLink.create(allocator, out, try std.fmt.bufPrint(&id, "S{d}", .{i}));
    }
    defer for (links) |l| l.release();

    var threads: [producers]std.Thread = undefined;
    for (&threads, 0..) |*t, i| t.* = try std.Thread.spawn(.{}, produce, .{ links[i], i });

    var next: [producers]usize = @splat(0);
    var taken: std.ArrayList(devtools.outbound.Item) = .empty;
    defer taken.deinit(allocator);
    var total: usize = 0;
    while (total < producers * per_producer) {
        out.wait(10 * std.time.ns_per_ms);
        taken.clearRetainingCapacity();
        _ = try out.takeAll(&taken);
        for (taken.items) |item| {
            defer allocator.free(item.bytes);
            const colon = std.mem.indexOfScalar(u8, item.bytes, ':').?;
            const producer = try std.fmt.parseInt(usize, item.bytes[0..colon], 10);
            const seq = try std.fmt.parseInt(usize, item.bytes[colon + 1 ..], 10);
            try testing.expectEqual(next[producer], seq);
            next[producer] += 1;
            total += 1;
        }
    }
    for (threads) |t| t.join();
}

test "a link whose session ended drops what its thread still sends, and frees it" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const out = try Outbound.create(allocator);
    defer out.release();
    const link = try SessionLink.create(allocator, out, "S");
    const kept = link.retain();
    link.end();
    link.release();
    const t = try std.Thread.spawn(.{}, produce, .{ kept, 0 });
    t.join();
    kept.release();
    var taken: std.ArrayList(devtools.outbound.Item) = .empty;
    defer taken.deinit(allocator);
    _ = try out.takeAll(&taken);
    try testing.expectEqual(@as(usize, 0), taken.items.len);
}
