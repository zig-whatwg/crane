//! The IndexedDB server's map of databases under a runner's churn (lane
//! hashmaps1): the server is its Browser's, alive for every page the
//! process loads; a database enters the map when first opened and leaves
//! it once nothing refers to it (`maybeForget`), and test pages name their
//! databases uniquely. std's map never grows while puts and removes
//! balance and never clears its tombstones (src/infra/tombstones.zig): a
//! 1,069-file runner sample found it starved in 45 of 258 samples.

const std = @import("std");
const testing = std.testing;
const idb = @import("storage").indexeddb;
const tombstones = @import("infra").tombstones;

test "the server's databases keep half their unused slots free while pages open and forget uniquely named ones" {
    var server = idb.IDBServer.init(testing.allocator);
    defer server.deinit();
    const key = idb.server.firstPartyKey("https://churn.example");
    // One database held across every page.
    const resident = try server.uniqueDatabase(key, "resident");
    defer server.release(resident);
    var name_buf: [64]u8 = undefined;
    var starved: usize = 0;
    var worst: usize = 0;
    var n: usize = 0;
    for (0..400) |_| {
        for (0..8) |i| {
            const name = try std.fmt.bufPrint(&name_buf, "db-{d}", .{n});
            n += 1;
            const database = try server.uniqueDatabase(key, name);
            if (i == 0) {
                if (!tombstones.slotCounts(&server.databases).halfOfUnusedFree()) starved += 1;
                worst = @max(worst, tombstones.meanMissProbe(&server.databases));
            }
            // Nothing else holds it: the server forgets it.
            server.release(database);
        }
    }
    try testing.expectEqual(@as(usize, 1), server.databases.count());
    if (starved != 0 or worst > 8) {
        const counts = tombstones.slotCounts(&server.databases);
        std.debug.print("IDBServer.databases: {d} of 400 pages began with fewer than half the unused slots free; worst mean miss {d} (capacity {d}, live {d}, free {d})\n", .{ starved, worst, counts.capacity, counts.live, counts.free });
        return error.TombstonesFilledTheMap;
    }
    // The resident is still the one the server finds.
    const again = try server.uniqueDatabase(key, "resident");
    defer server.release(again);
    try testing.expectEqual(resident, again);
}
