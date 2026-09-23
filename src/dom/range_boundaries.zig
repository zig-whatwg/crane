//! DOM § 5.3 "boundary point", as the seam between AbstractRange and the two
//! kinds of range that carry one.
//!
//! `startContainer`, `startOffset`, `endContainer`, `endOffset` and `collapsed`
//! are AbstractRange attributes, so the binding answers them through
//! AbstractRange's impl for every range. The start and end themselves live in
//! the subclass that maintains them - a live Range updates its boundary points
//! on every tree mutation, a StaticRange never does - so AbstractRange cannot
//! own a copy without it going stale, and must not call either impl directly.
//! Each subclass installs a provider instead; the same shape as
//! `abort_algorithms.zig`.
//!
//! lint-impls: hook for Range, StaticRange

const runtime = @import("runtime");

/// A range's start and end.
pub const Boundaries = struct {
    start_container: *runtime.Instance,
    start_offset: u32,
    end_container: *runtime.Instance,
    end_offset: u32,
};

/// Answers for the ranges of one kind: null when `range` is not of that kind,
/// or has no boundary points yet.
pub const Provider = *const fn (range: *runtime.Instance) ?Boundaries;

/// One slot per kind of range - Range and StaticRange - with room to spare.
/// Per thread, as a worker's ranges live on its own thread.
threadlocal var providers: [4]?Provider = .{ null, null, null, null };

/// Called by each range impl when it creates a range. Idempotent.
pub fn install(provider: Provider) void {
    for (&providers) |*slot| {
        if (slot.*) |existing| {
            if (existing == provider) return;
            continue;
        }
        slot.* = provider;
        return;
    }
}

/// `range`'s start and end, from whichever kind of range it is.
pub fn of(range: *runtime.Instance) ?Boundaries {
    for (providers) |slot| {
        const provider = slot orelse return null;
        if (provider(range)) |b| return b;
    }
    return null;
}

/// What a live Range supplies beyond its boundary points: the step
/// `createRange()` takes - "a new live range whose start and end are
/// (this, 0)" - which sets a Range's state and registers it with its node
/// document, neither of which Document may reach into.
pub const LiveRange = struct {
    /// Set `range`'s start and end to (node, offset) and make it a live range
    /// of node's node document.
    collapse: *const fn (range: *runtime.Instance, node: *runtime.Instance, offset: u32) anyerror!void,
    /// Move `range` to the live-range list of its start node's node document,
    /// if adoption has changed which document that is.
    update_owner_document: *const fn (range: *runtime.Instance) anyerror!void,
};

/// Per thread, like the ranges themselves.
threadlocal var live_range: ?LiveRange = null;

/// Called by the Range impl when it creates a range. Idempotent.
pub fn installLiveRange(impl: LiveRange) void {
    live_range = impl;
}

/// Collapse a just-created live `range` at (node, offset) and register it.
pub fn collapseLive(range: *runtime.Instance, node: *runtime.Instance, offset: u32) !void {
    const impl = live_range orelse return error.NotSupported;
    return impl.collapse(range, node, offset);
}

/// A tree moved to another document: `range`, one of the old document's
/// live ranges, follows its start node if that moved with the tree.
pub fn updateOwnerDocument(range: *runtime.Instance) !void {
    const impl = live_range orelse return;
    return impl.update_owner_document(range);
}

test "install is idempotent and `of` asks each provider in turn" {
    const std = @import("std");
    const saved = providers;
    defer providers = saved;
    providers = .{ null, null, null, null };

    var a: runtime.Instance = undefined;
    var b: runtime.Instance = undefined;
    const Fake = struct {
        var target: ?*runtime.Instance = null;
        fn never(_: *runtime.Instance) ?Boundaries {
            return null;
        }
        fn only(range: *runtime.Instance) ?Boundaries {
            if (range != target) return null;
            return .{ .start_container = range, .start_offset = 1, .end_container = range, .end_offset = 2 };
        }
    };
    Fake.target = &a;

    try std.testing.expect(of(&a) == null);
    install(&Fake.never);
    install(&Fake.only);
    install(&Fake.never);
    try std.testing.expect(providers[2] == null);

    const got = of(&a) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(u32, 1), got.start_offset);
    try std.testing.expectEqual(@as(u32, 2), got.end_offset);
    try std.testing.expect(of(&b) == null);
}
