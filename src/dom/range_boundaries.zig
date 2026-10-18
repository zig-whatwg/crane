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
const process_start = @import("process_start.zig");

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
/// Process-wide, written once at start-up (process_start.zig).
var providers: [4]?Provider = .{ null, null, null, null };

/// Called by each range impl when it creates a range. Idempotent.
pub fn install(provider: Provider) void {
    process_start.assertInstalling();
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

/// A live range's boundary points as it keeps them. A container is null only
/// before the range has boundary points.
pub const LivePoints = struct {
    start_container: ?*runtime.Instance,
    start_offset: u32,
    end_container: ?*runtime.Instance,
    end_offset: u32,
};

/// What a live Range supplies beyond its boundary points: the step
/// `createRange()` takes - "a new live range whose start and end are
/// (this, 0)" - which sets a Range's state and registers it with its node
/// document, neither of which Document may reach into; and the live-range
/// steps of the mutation algorithms (insert step 5, remove steps 4-7, "split
/// a Text node" steps 7.2-7.5, src/dom/mutation.zig), which read and move
/// the boundary points of each of a document's live ranges in place.
///
/// Those steps set a boundary point itself ("set its start to (parent,
/// index)", "decrease its start offset by 1"), not through "set the start or
/// end": no validation and no collapse - the steps keep the range valid.
/// Blink's and WebKit's Document walks its ranges the same way and calls each
/// Range's own boundary steps (Range::NodeWillBeRemoved, nodeChildrenChanged,
/// didSplitTextNode); a Range here also redraws the edges that hold its
/// boundary nodes, and tells a Selection it belongs to, as its own methods do.
pub const LiveRange = struct {
    /// Set `range`'s start and end to (node, offset) and make it a live range
    /// of node's node document.
    collapse: *const fn (range: *runtime.Instance, node: *runtime.Instance, offset: u32) anyerror!void,
    /// Move `range` to the live-range list of its start node's node document,
    /// if adoption has changed which document that is.
    update_owner_document: *const fn (range: *runtime.Instance) anyerror!void,
    /// `range`'s boundary points, or null for an object with no Range state.
    points: *const fn (range: *runtime.Instance) ?LivePoints,
    /// Set `range`'s start to (node, offset).
    set_start: *const fn (range: *runtime.Instance, node: *runtime.Instance, offset: u32) void,
    /// Set `range`'s end to (node, offset).
    set_end: *const fn (range: *runtime.Instance, node: *runtime.Instance, offset: u32) void,
    /// Set `range`'s start offset, its start node unchanged.
    set_start_offset: *const fn (range: *runtime.Instance, offset: u32) void,
    /// Set `range`'s end offset, its end node unchanged.
    set_end_offset: *const fn (range: *runtime.Instance, offset: u32) void,
};

/// Process-wide, written once at start-up (process_start.zig).
var live_range: ?LiveRange = null;

/// Called by Range's installHooks, once, at process start (process_start.zig).
pub fn installLiveRange(impl: LiveRange) void {
    process_start.assertInstalling();
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

/// The live-range steps' reach into live ranges: taken once per mutation and
/// asked once per range. Null before Range has installed it, when no
/// document can have a live range.
pub fn liveRange() ?*const LiveRange {
    if (live_range) |*impl| return impl;
    return null;
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
