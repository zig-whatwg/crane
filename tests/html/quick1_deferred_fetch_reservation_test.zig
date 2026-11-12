//! Fetch 4.12.1, the deferred-fetch quota a navigable container reserves
//! for a cross-origin nested document (lane quick1 batch 1, C15; the RED
//! obligation of feature-queue "DEFERRED-FETCH QUOTA RESERVATION ON
//! NAVIGABLE CONTAINERS", transferred from Codex row 126's
//! tests/fetch/fx1_deferred_fetch_test.zig:73-102).
//!
//! "The available deferred-fetch quota" step 6 for a nested control
//! document reads its container's reserved quota: normal quota (64 KiB)
//! when "deferred-fetch" is allowed and the container reserved it, minimal
//! quota (8 KiB) when "deferred-fetch-minimal" is allowed and it reserved
//! that, else 0; step 8.1 takes every container's reservation out of its
//! parent's quota; steps 9-11 never go below 0.
//!
//! RED at 9a7434fdee9: nothing reserves, and a nested control document's
//! quota is always 0 (deferred_fetches.zig "reads 0 today").
const std = @import("std");
const testing = std.testing;
const dom = @import("dom");
const deferred = dom.deferred_fetches;

const kib: u64 = 1024;

const Child = struct { allowed: bool, minimal: bool, reserved: deferred.ReservedQuota, expected: u64 };

test "a nested control document's quota is its container's reservation, when its policy allows that one" {
    const cases = [_]Child{
        // A normal child.
        .{ .allowed = true, .minimal = true, .reserved = .normal, .expected = 64 * kib },
        // A minimal child.
        .{ .allowed = true, .minimal = true, .reserved = .minimal, .expected = 8 * kib },
        // A minimal-only child.
        .{ .allowed = false, .minimal = true, .reserved = .minimal, .expected = 8 * kib },
        // Mismatched: a minimal-only container never holds the normal reservation.
        .{ .allowed = false, .minimal = true, .reserved = .normal, .expected = 0 },
        // Mismatched the other way.
        .{ .allowed = true, .minimal = false, .reserved = .minimal, .expected = 0 },
        // Nothing reserved.
        .{ .allowed = true, .minimal = true, .reserved = .none, .expected = 0 },
    };
    for (cases) |case| {
        const got = deferred.quotaFrom(.{
            .is_top_level = false,
            .policy = .{ .deferred_fetch = case.allowed, .deferred_fetch_minimal = case.minimal },
            .reserved = case.reserved,
        });
        testing.expectEqual(case.expected, got) catch |err| {
            std.debug.print("allowed {} minimal {} reserved {s}\n", .{ case.allowed, case.minimal, @tagName(case.reserved) });
            return err;
        };
    }
}

test "a top-level control document: 512 KiB with deferred-fetch-minimal, 640 KiB without, 0 when not allowed" {
    try testing.expectEqual(64 * kib, deferred.quotaFrom(.{ .is_top_level = true, .policy = .{ .deferred_fetch = true, .deferred_fetch_minimal = true } }));
    // The per-origin cap is 64 KiB: the totals show once the containers'
    // reservations bring them below it - 512 KiB less 449 KiB, and 640 KiB
    // less 577 KiB, leave 63 KiB; 640 KiB less 449 KiB is still capped.
    const with_minimal: deferred.Policy = .{ .deferred_fetch = true, .deferred_fetch_minimal = true };
    const without_minimal: deferred.Policy = .{ .deferred_fetch = true, .deferred_fetch_minimal = false };
    try testing.expectEqual(63 * kib, deferred.quotaFrom(.{ .is_top_level = true, .policy = with_minimal, .reserved_by_containers = 449 * kib }));
    try testing.expectEqual(64 * kib, deferred.quotaFrom(.{ .is_top_level = true, .policy = without_minimal, .reserved_by_containers = 449 * kib }));
    try testing.expectEqual(63 * kib, deferred.quotaFrom(.{ .is_top_level = true, .policy = without_minimal, .reserved_by_containers = 577 * kib }));
    try testing.expectEqual(@as(u64, 0), deferred.quotaFrom(.{ .is_top_level = true, .policy = .{ .deferred_fetch = false, .deferred_fetch_minimal = true } }));
}

test "the quota saturates at 0: a container reserving 64 KiB out of an 8 KiB quota leaves nothing, never an underflow" {
    try testing.expectEqual(@as(u64, 0), deferred.quotaFrom(.{
        .is_top_level = false,
        .policy = .{ .deferred_fetch = true, .deferred_fetch_minimal = true },
        .reserved = .minimal,
        .reserved_by_containers = 64 * kib,
    }));
    // A pending record larger than any quota.
    try testing.expectEqual(@as(u64, 0), deferred.quotaFrom(.{
        .is_top_level = true,
        .policy = .{ .deferred_fetch = true, .deferred_fetch_minimal = true },
        .pending = std.math.maxInt(u64),
    }));
}

test "steps 7-11: the request origin's 64 KiB, less what its own pending records take" {
    try testing.expectEqual(64 * kib - 10, deferred.quotaFrom(.{
        .is_top_level = true,
        .policy = .{ .deferred_fetch = true, .deferred_fetch_minimal = true },
        .pending = 10,
        .pending_same_origin = 10,
    }));
    // Another origin's records take from the quota only.
    try testing.expectEqual(64 * kib, deferred.quotaFrom(.{
        .is_top_level = true,
        .policy = .{ .deferred_fetch = true, .deferred_fetch_minimal = true },
        .pending = 10,
    }));
    // A minimal child: its 8 KiB is below the origin's 64 KiB.
    try testing.expectEqual(8 * kib - 100, deferred.quotaFrom(.{
        .is_top_level = false,
        .policy = .{ .deferred_fetch = false, .deferred_fetch_minimal = true },
        .reserved = .minimal,
        .pending = 100,
        .pending_same_origin = 100,
    }));
}

test "reserve deferred-fetch quota step 4: the minimal reservations a top-level document can still give" {
    // 128 KiB / 8 KiB = 16 minimal reservations.
    try testing.expect(deferred.minimalReservationAvailable(0));
    try testing.expect(deferred.minimalReservationAvailable(15));
    try testing.expect(!deferred.minimalReservationAvailable(16));
}
