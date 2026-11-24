//! HTML 4.8.11.11.1 / 4.8.11.11.5: a text track cue - the unit of
//! time-sensitive data in a text track - and its TextTrackCue object. The
//! format-specific data is the subclass's (VTTCue: WebVTT 9.1).
//!
//! A cue in a text track's list of cues keeps that track: `track` answers it
//! for as long as the cue is in the list, as Blink's TextTrackCue traces its
//! track_ (text_track_cue.h) - an edge from the cue's wrapper
//! (engine.traceChild), while the list keeps the cue. An edge needs the
//! cue's wrapper: a cue the WebVTT parser made has none until its list hands
//! it to script (TextTrackCueList.zig), and until then it names its track by
//! a link only - an edge waiting on an unwrapped owner would hold the track
//! as a root (engine.traceChild), through which the track's realm would keep
//! itself. `exposed` draws the edge then. A cue that leaves the list lets the
//! edge go. Its teardown never reads the track: the collector may have freed
//! it first (same_object.Link).
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");
const same_object = dom.same_object;
const hooks = dom.media_elements;
const TextTrackCue = interfaces.TextTrackCue;

pub const State = TextTrackCue.State;

const track_slot: engine.TracedSlot = .{ .name = "track" };

/// A text track cue (HTML 4.8.11.11.1).
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// The text track cue identifier.
    identifier: runtime.DOMString = .initEmpty(),
    /// The text track cue start and end times, in seconds (the end time is
    /// positive Infinity for an unbounded text track cue).
    start_time: f64 = 0,
    end_time: f64 = 0,
    /// The text track cue pause-on-exit flag.
    pause_on_exit: bool = false,
    /// The text track in whose list of cues this cue is, and whether this
    /// cue's edge to it is drawn.
    track: ?same_object.Link = null,
    track_traced: bool = false,
    /// The text track cue active flag.
    active: bool = false,
    /// When this cue was last added to its text track list of cues: text
    /// track cue order's last key ("in the order they were last added").
    order: u64 = 0,
};

pub fn installHooks() void {
    hooks.installTextTrackCue(.{ .set_track = setTrack, .active = isActive, .set_active = setActive, .order = orderOf, .exposed = exposed });
}

/// The cue's own construction steps; the generated chain runs EventTarget's
/// first. Every member starts at its initial value (InternalState); the
/// format's constructor sets the times (VTTCue()).
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    _ = args;
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator };
    instance.getState(State).own._internal = internal;
}

/// The cue's own teardown: the edge to its track goes (by name only - the
/// track may be gone), never the track.
pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        state.own._internal = null;
        if (internal.track_traced) engine.forgetTracedChild(instance, track_slot);
        internal.identifier.deinit(internal.allocator);
        internal.allocator.destroy(internal);
    }
}

fn internalOf(instance: *runtime.Instance) !*InternalState {
    return (instance.stateAs(State) orelse return error.InvalidStateError).own._internal orelse error.InvalidStateError;
}

/// The text track whose list of cues `cue` is now in (null: none), and the
/// time it was added there (`order`). The cue keeps the track while it is
/// in its list. Leaving the list unsets the active flag (HTML 4.8.11.11.1:
/// "whenever the text track cue is removed from its text track's text
/// track list of cues").
fn setTrack(cue: *runtime.Instance, track: ?*runtime.Instance, order: u64) void {
    const internal = (cue.stateAs(State) orelse return).own._internal orelse return;
    if (track) |owner| {
        internal.track = same_object.Link.to(owner);
        internal.order = order;
        // A cue with no wrapper yet draws its edge when it gets one
        // (`exposed`).
        if (hooks.mayBeWrapped(cue)) {
            engine.traceChild(cue, owner, track_slot);
            internal.track_traced = true;
        } else if (internal.track_traced) {
            engine.forgetTracedChild(cue, track_slot);
            internal.track_traced = false;
        }
    } else {
        internal.track = null;
        internal.active = false;
        if (internal.track_traced) engine.forgetTracedChild(cue, track_slot);
        internal.track_traced = false;
    }
}

/// The cue has a wrapper now: the edge to its track, if it is in one.
fn exposed(cue: *runtime.Instance) void {
    const internal = (cue.stateAs(State) orelse return).own._internal orelse return;
    const track = liveTrack(internal) orelse return;
    if (internal.track_traced) return;
    engine.traceChild(cue, track, track_slot);
    internal.track_traced = true;
}

fn isActive(cue: *runtime.Instance) bool {
    const internal = (cue.stateAs(State) orelse return false).own._internal orelse return false;
    return internal.active;
}

fn setActive(cue: *runtime.Instance, active: bool) void {
    const internal = (cue.stateAs(State) orelse return).own._internal orelse return;
    internal.active = active;
}

fn orderOf(cue: *runtime.Instance) u64 {
    const internal = (cue.stateAs(State) orelse return 0).own._internal orelse return 0;
    return internal.order;
}

/// The track that is live and still holds this cue.
fn liveTrack(internal: *const InternalState) ?*runtime.Instance {
    const link = internal.track orelse return null;
    return if (link.isLive()) link.instance else null;
}

/// "The text track in whose list of cues this's text track cue finds
/// itself, if any; or null otherwise."
pub fn get_track(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return liveTrack(try internalOf(instance));
}

pub fn get_id(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return (try internalOf(instance)).identifier.clone(instance.ctx.allocator);
}

pub fn set_id(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const internal = try internalOf(instance);
    const copy = try value.clone(internal.allocator);
    internal.identifier.deinit(internal.allocator);
    internal.identifier = copy;
}

pub fn get_startTime(instance: *runtime.Instance) anyerror!f64 {
    return (try internalOf(instance)).start_time;
}

/// "The text track cue start time must be set to the new value ... then, if
/// the TextTrackCue object's text track cue is in a text track's list of
/// cues, and that text track is in a media element's list of text tracks,
/// and the media element's show poster flag is not set, then run the time
/// marches on steps for that media element" - the track re-sorts its list
/// (text track cue order follows the start time) and tells its media
/// element (hooks.cueTimesChanged).
pub fn set_startTime(instance: *runtime.Instance, value: f64) anyerror!void {
    const internal = try internalOf(instance);
    internal.start_time = value;
    if (liveTrack(internal)) |track| hooks.cueTimesChanged(track, instance);
}

pub fn get_endTime(instance: *runtime.Instance) anyerror!f64 {
    return (try internalOf(instance)).end_time;
}

/// "On setting, if the new value is negative Infinity or a Not-a-Number
/// (NaN) value, then throw a TypeError exception. Otherwise, the text track
/// cue end time must be set to the new value", then time marches on as for
/// startTime.
pub fn set_endTime(instance: *runtime.Instance, value: f64) anyerror!void {
    if (std.math.isNan(value) or value == -std.math.inf(f64)) return error.TypeError;
    const internal = try internalOf(instance);
    internal.end_time = value;
    if (liveTrack(internal)) |track| hooks.cueTimesChanged(track, instance);
}

pub fn get_pauseOnExit(instance: *runtime.Instance) anyerror!bool {
    return (try internalOf(instance)).pause_on_exit;
}

pub fn set_pauseOnExit(instance: *runtime.Instance, value: bool) anyerror!void {
    (try internalOf(instance)).pause_on_exit = value;
}
