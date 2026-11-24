//! HTML 4.8.11.11.5: a TextTrackCueList - "a dynamically updating list of
//! text track cues in a given order". A text track's `cues` list IS its text
//! track list of cues (Blink's TextTrack holds its cues_ TextTrackCueList the
//! same way); its `activeCues` list is a view of the cues whose active flag
//! is set. Both are kept in text track cue order.
//!
//! A track's list owns its cues the way an owner keeps a [SameObject] child
//! (same_object.KeptChild: made, then handed out): a cue the WebVTT parser
//! made is the list's alone, with no wrapper, until script first reaches it -
//! the list's getters, or an enter/exit event at it (`expose`) - and only
//! then does the list draw its edge to the cue (engine.traceChild, which
//! makes the wrapper), one slot per cue, and the cue its own edges
//! (hooks.cueExposed). Blink makes a cue's wrapper on access too; a
//! 1,000-cue file makes no wrapper until script reads a cue. A cue that
//! leaves the list unexposed has no other owner, and the list frees it whole
//! (runtime.gc.releaseOwned: no engine call, so its teardown may run in the
//! collector's); an exposed one is its wrapper's, and only the edge goes.
//!
//! A cue made in another realm goes with that realm's end whatever keeps it
//! (lesson architecture-a-traced-edge-keeps-an-object-from-the-collector-
//! not-from-its-realm-s-end.md): every read drops the cues whose slab slot
//! changed (`prune`). The activeCues view owns nothing and draws no edges:
//! each of its cues is in its track's own list, which exposes it.
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");
const hooks = dom.media_elements;
const Link = dom.same_object.Link;
const TextTrackCueList = interfaces.TextTrackCueList;

pub const State = TextTrackCueList.State;

/// A cue and whether the list's edge to it is drawn - the cue has a wrapper
/// then, and is its wrapper's to free.
const Entry = hooks.CueEntry;

pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// A track's own list owns its cues; a view (activeCues) does not.
    owns: bool = true,
    /// The cues, in text track cue order.
    cues: std.ArrayListUnmanaged(Entry) = .empty,
};

fn slot(buffer: []u8, cue: *runtime.Instance) engine.TracedSlot {
    return .{ .name = std.fmt.bufPrint(buffer, "cue:{x}", .{@intFromPtr(cue)}) catch unreachable };
}

pub fn installHooks() void {
    hooks.installTextTrackCueList(.{ .create = create, .add = add, .remove = remove, .clear = clear, .reorder = reorder, .items = items, .expose = expose });
}

pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    _ = args;
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator };
    instance.getState(State).own._internal = internal;
}

/// The list's teardown - its wrapper's end, or its realm's: an exposed cue's
/// edge goes by name (the collector may have freed the cue first); a cue it
/// still owns, unexposed, goes whole.
pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        state.own._internal = null;
        for (internal.cues.items) |entry| release(instance, internal, entry);
        internal.cues.deinit(internal.allocator);
        internal.allocator.destroy(internal);
    }
}

fn internalOf(instance: *runtime.Instance) ?*InternalState {
    return (instance.stateAs(State) orelse return null).own._internal;
}

fn create(ctx: runtime.Context, owns: bool) !*runtime.Instance {
    const list = try TextTrackCueList.init(ctx.allocator, ctx);
    internalOf(list).?.owns = owns;
    return list;
}

/// The list lets `entry`'s cue go: its edge if it drew one; the cue itself
/// if no wrapper can reach it (an owning list's unexposed cue).
fn release(list: *runtime.Instance, internal: *const InternalState, entry: Entry) void {
    if (entry.exposed) {
        var buffer: [32]u8 = undefined;
        engine.forgetTracedChild(list, slot(&buffer, entry.link.instance));
        return;
    }
    if (internal.owns and entry.link.isLive() and !hooks.mayBeWrapped(entry.link.instance)) runtime.gc.releaseOwned(entry.link.instance);
}

/// Whether `a` comes before `b` in text track cue order (HTML 4.8.11.11.1):
/// by start time, earliest first; then by end time, latest first; then in
/// the order they were last added to their list, oldest first. (The first
/// key - the cues' text tracks' order in the media element's list - is one
/// track for one list.)
fn before(a: *runtime.Instance, b: *runtime.Instance) bool {
    const a_start = interfaces.TextTrackCue.get_startTime(a) catch 0;
    const b_start = interfaces.TextTrackCue.get_startTime(b) catch 0;
    if (a_start != b_start) return a_start < b_start;
    const a_end = interfaces.TextTrackCue.get_endTime(a) catch 0;
    const b_end = interfaces.TextTrackCue.get_endTime(b) catch 0;
    if (a_end != b_end) return a_end > b_end;
    return hooks.cueOrder(a) < hooks.cueOrder(b);
}

/// Where `cue` goes in text track cue order: after every cue before it.
fn insertionIndex(cues: []const Entry, cue: *runtime.Instance) usize {
    var low: usize = 0;
    var high: usize = cues.len;
    while (low < high) {
        const middle = low + (high - low) / 2;
        if (before(cues[middle].link.instance, cue)) low = middle + 1 else high = middle;
    }
    return low;
}

/// Drop the cues whose slot no longer holds them (their realm ended).
fn prune(list: *runtime.Instance, internal: *InternalState) void {
    var index: usize = 0;
    while (index < internal.cues.items.len) {
        const entry = internal.cues.items[index];
        if (entry.link.isLive()) {
            index += 1;
            continue;
        }
        if (entry.exposed) {
            var buffer: [32]u8 = undefined;
            engine.forgetTracedChild(list, slot(&buffer, entry.link.instance));
        }
        _ = internal.cues.orderedRemove(index);
    }
}

fn indexOf(internal: *const InternalState, cue: *runtime.Instance) ?usize {
    for (internal.cues.items, 0..) |entry, index| if (entry.link.instance == cue and entry.link.isLive()) return index;
    return null;
}

/// Draw the owning list's edge to entry `index`'s cue - making its wrapper,
/// if script has not seen it - and have the cue draw its own.
fn exposeAt(list: *runtime.Instance, internal: *InternalState, index: usize) void {
    const entry = &internal.cues.items[index];
    if (entry.exposed or !internal.owns) return;
    const cue = entry.link.instance;
    var buffer: [32]u8 = undefined;
    engine.traceChild(list, cue, slot(&buffer, cue));
    entry.exposed = true;
    hooks.cueExposed(cue);
}

/// Add `cue`, in text track cue order. An owning list owns a cue no wrapper
/// reaches (the parser's), and keeps one script already holds by an edge at
/// once.
fn add(list: *runtime.Instance, cue: *runtime.Instance) !void {
    const internal = internalOf(list) orelse return error.InvalidStateError;
    prune(list, internal);
    if (indexOf(internal, cue) != null) return;
    const index = insertionIndex(internal.cues.items, cue);
    try internal.cues.insert(internal.allocator, index, .{ .link = Link.to(cue) });
    if (hooks.mayBeWrapped(cue)) exposeAt(list, internal, index);
}

/// `cue` is going to script (`expose`'s callers): from now on the list keeps
/// it by an edge.
fn expose(list: *runtime.Instance, cue: *runtime.Instance) void {
    const internal = internalOf(list) orelse return;
    const index = indexOf(internal, cue) orelse return;
    exposeAt(list, internal, index);
}

/// Remove `cue`: null when the list does not hold it; otherwise whether the
/// list owned it - an unexposed cue, which nothing else reaches now, for the
/// caller to free once it has let go of it (runtime.gc.releaseOwned).
fn remove(list: *runtime.Instance, cue: *runtime.Instance) ?hooks.Removed {
    const internal = internalOf(list) orelse return null;
    prune(list, internal);
    const index = indexOf(internal, cue) orelse return null;
    const entry = internal.cues.orderedRemove(index);
    if (entry.exposed) {
        var buffer: [32]u8 = undefined;
        engine.forgetTracedChild(list, slot(&buffer, cue));
        return .wrapped;
    }
    return if (internal.owns and !hooks.mayBeWrapped(cue)) .owned else .wrapped;
}

/// Remove every cue, freeing those the list owned.
fn clear(list: *runtime.Instance) void {
    const internal = internalOf(list) orelse return;
    // Taken out first: a cue's teardown never reads the list it left.
    var cues = internal.cues;
    internal.cues = .empty;
    defer cues.deinit(internal.allocator);
    for (cues.items) |entry| release(list, internal, entry);
}

/// `cue`'s start or end time changed: its place in text track cue order
/// follows. Its edge, if drawn, stays.
fn reorder(list: *runtime.Instance, cue: *runtime.Instance) void {
    const internal = internalOf(list) orelse return;
    prune(list, internal);
    const index = indexOf(internal, cue) orelse return;
    const entry = internal.cues.orderedRemove(index);
    // The capacity is there: the cue was in the list a moment ago.
    internal.cues.insertAssumeCapacity(insertionIndex(internal.cues.items, cue), entry);
}

/// The live cues, in text track cue order: borrowed until the list next
/// changes. Reading them does not hand them to script.
fn items(list: *runtime.Instance) []const Entry {
    const internal = internalOf(list) orelse return &.{};
    prune(list, internal);
    return internal.cues.items;
}

/// The cue at `index`, going to script: exposed in the list that owns it -
/// this one, or (for the activeCues view) its track's own list.
fn handOut(list: *runtime.Instance, index: usize) *runtime.Instance {
    const internal = internalOf(list).?;
    const cue = internal.cues.items[index].link.instance;
    if (internal.owns) {
        exposeAt(list, internal, index);
    } else if (interfaces.TextTrackCue.get_track(cue) catch null) |track| {
        if (hooks.trackCueList(track)) |owner| expose(owner, cue);
    }
    return cue;
}

/// "The length attribute must return the number of cues in the list
/// represented by the TextTrackCueList object."
pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
    return @intCast(items(instance).len);
}

/// The indexed getter: the index-th text track cue in the list. An index
/// that is not a supported property index has no value.
pub fn call_getter(instance: *runtime.Instance, index: u32) anyerror!*runtime.Instance {
    if (index >= items(instance).len) return error.IndexSizeError;
    return handOut(instance, index);
}

/// "When called with an argument other than the empty string, must return
/// the first text track cue in the list ... whose text track cue identifier
/// is id, if any, or null otherwise. If the argument is the empty string,
/// then the method must return null."
pub fn call_getCueById(instance: *runtime.Instance, id: runtime.DOMString) anyerror!?*runtime.Instance {
    if (id.asSlice().len == 0) return null;
    for (items(instance), 0..) |entry, index| {
        var cue_id = try interfaces.TextTrackCue.get_id(entry.link.instance);
        defer cue_id.deinit(instance.ctx.allocator);
        if (std.mem.eql(u8, cue_id.asSlice(), id.asSlice())) return handOut(instance, index);
    }
    return null;
}
