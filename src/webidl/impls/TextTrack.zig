//! HTML 4.8.11.11: a text track - its attributes, readiness, mode and list of
//! cues.
//!
//! The text track list of cues is the TextTrackCueList `cues` answers (made
//! with the track's first cue or first `cues` read, and kept from then on:
//! Blink's TextTrack::EnsureTextTrackCueList), in text track cue order; it
//! keeps its cues, and each cue keeps this track (TextTrackCue.zig). The
//! track knows the media element whose list of text tracks it is in
//! (`media`, a weak link: the media element's TextTrackList keeps the
//! track, never the other way), to tell it of a mode change - the pending
//! text track change notification, which a track made by addTextTrack()
//! has as much as a track element's (track-change-event.html).
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const enums = @import("enums");
const typedefs = @import("typedefs");
const dom = @import("dom");
const hooks = dom.media_elements;
const same_object = @import("dom").same_object;
pub const State = interfaces.TextTrack.State;
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    kind: hooks.Kind = .subtitles,
    label: runtime.DOMString = .initEmpty(),
    language: runtime.DOMString = .initEmpty(),
    id: runtime.DOMString = .initEmpty(),
    mode: hooks.Mode = .disabled,
    readiness: hooks.Readiness = .not_loaded,
    element: ?same_object.Link = null,
    /// The media element whose list of text tracks holds this track.
    media: ?same_object.Link = null,
    /// The text track list of cues (a TextTrackCueList), once made.
    cues: ?*runtime.Instance = null,
    cues_keep: same_object.KeptChild = .{},
    active: ?*runtime.Instance = null,
    active_keep: same_object.KeptChild = .{},
    /// The rules for updating the text track rendering the list of cues is
    /// associated with: the interface of the first cue added to it.
    rules: ?[]const u8 = null,
    /// Counts the cues added to the list: text track cue order's last key.
    added: u64 = 0,
    /// The VTTRegion objects this track's WebVTT file made, each kept by an
    /// edge until the track's src changes: an unexposed cue names its region
    /// by a link only (VTTCue.zig).
    regions: std.ArrayListUnmanaged(same_object.Link) = .empty,
};
pub fn installHooks() void {
    hooks.installTextTrack(.{
        .create = create,
        .update = update,
        .set_readiness = setReadiness,
        .readiness = readiness,
        .link_element = linkElement,
        .element_destroyed = elementDestroyed,
        .clear_cues = clearCues,
        .link_media = linkMedia,
        .cue_times_changed = cueTimesChanged,
        .cue_list = cueList,
        .keep_region = keepRegion,
        .add_cues = addCues,
    });
}
pub fn init(allocator: std.mem.Allocator, comptime StateType: type, vtable: *const runtime.VTable, ctx: runtime.Context) !*runtime.Instance {
    const instance = try interfaces.EventTarget.initWithState(allocator, StateType, vtable, ctx);
    instance.getState(State).own._internal = null;
    errdefer instance.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(instance));
    const data = try allocator.create(InternalState);
    data.* = .{ .allocator = allocator };
    instance.getState(State).own._internal = data;
    return instance;
}
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |data| {
        state.own._internal = null;
        // A wrapper-held child is freed by the collector, never eagerly here;
        // so are the cues the list keeps, which this teardown never reads.
        if (data.cues) |child| data.cues_keep.release(child, severCues);
        if (data.active) |child| data.active_keep.release(child, severCues);
        // The regions' edges go with this track's wrapper.
        data.regions.deinit(data.allocator);
        data.label.deinit(data.allocator);
        data.language.deinit(data.allocator);
        data.id.deinit(data.allocator);
        data.allocator.destroy(data);
    }
    interfaces.EventTarget.deinit(instance);
}
fn severCues(_: *runtime.Instance) void {}
fn internal(instance: *runtime.Instance) *InternalState {
    return instance.getState(State).own._internal.?;
}
fn create(ctx: runtime.Context, kind: hooks.Kind, label: runtime.DOMString, language: runtime.DOMString, id: runtime.DOMString) !*runtime.Instance {
    // Association steps: independent owned values, disabled, not loaded.
    const track = try interfaces.TextTrack.init(ctx.allocator, ctx);
    errdefer track.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(track));
    try update(track, kind, label, language, id);
    return track;
}
fn update(track: *runtime.Instance, kind: hooks.Kind, label: runtime.DOMString, language: runtime.DOMString, id: runtime.DOMString) !void {
    const data = internal(track);
    // Commit all attributes together; OOM cannot leave borrowed or mixed values.
    var new_label = try label.clone(data.allocator);
    errdefer new_label.deinit(data.allocator);
    var new_language = try language.clone(data.allocator);
    errdefer new_language.deinit(data.allocator);
    const new_id = try id.clone(data.allocator);
    data.label.deinit(data.allocator);
    data.language.deinit(data.allocator);
    data.id.deinit(data.allocator);
    data.kind = kind;
    data.label = new_label;
    data.language = new_language;
    data.id = new_id;
}
fn setReadiness(track: *runtime.Instance, value: hooks.Readiness) void {
    internal(track).readiness = value;
}
fn readiness(track: *runtime.Instance) hooks.Readiness {
    return internal(track).readiness;
}
fn linkElement(track: *runtime.Instance, element: *runtime.Instance) void {
    internal(track).element = same_object.Link.to(element);
    engine.traceChild(track, element, .{ .name = "trackElement" });
}
fn elementDestroyed(track: *runtime.Instance) void {
    // GC-safe sever: no engine operation, exactly the shadow-host precedent.
    if (track.getState(State).own._internal) |data| data.element = null;
}
/// The media element whose list of text tracks this track joined (null: it
/// left it). Leaving the list unsets every cue's active flag (HTML
/// 4.8.11.11.1: "whenever the text track itself is removed from its media
/// element's list of text tracks").
fn linkMedia(track: *runtime.Instance, media: ?*runtime.Instance) void {
    const data = internal(track);
    const previous = liveMedia(data);
    data.media = if (media) |element| same_object.Link.to(element) else null;
    if (media) |element| {
        // Its cues are newly introduced cues of the media element (4.8.11.8)
        // - a track with no list yet has none.
        if (data.cues != null) hooks.mediaCuesChanged(element, .{ .track_added = track });
    } else {
        deactivateCues(data);
        if (previous) |element| hooks.mediaCuesChanged(element, .track_removed);
    }
}
fn liveMedia(data: *const InternalState) ?*runtime.Instance {
    const link = data.media orelse return null;
    return if (link.isLive()) link.instance else null;
}
/// Unset the active flag of every cue in the list.
fn deactivateCues(data: *InternalState) void {
    const list = data.cues orelse return;
    for (hooks.cueListItems(list)) |cue| hooks.setCueActive(cue.link.instance, false);
}
/// The text track list of cues, made with its first use and kept: the
/// track's wrapper keeps it from then on.
fn ensureCues(track: *runtime.Instance) !*runtime.Instance {
    const data = internal(track);
    if (data.cues) |list| return list;
    const list = try hooks.createCueList(track.ctx, true);
    data.cues = list;
    data.cues_keep.made(list);
    data.cues_keep.handOut(track, list, .{ .name = "cues" });
    return list;
}
fn cueList(track: *runtime.Instance) ?*runtime.Instance {
    return internal(track).cues;
}
fn regionSlot(buffer: []u8, region: *runtime.Instance) engine.TracedSlot {
    return .{ .name = std.fmt.bufPrint(buffer, "region:{x}", .{@intFromPtr(region)}) catch unreachable };
}
/// A VTTRegion this track's WebVTT file made: kept by an edge (its wrapper
/// is made now - a file has a handful of REGION blocks) until src changes.
fn keepRegion(track: *runtime.Instance, region: *runtime.Instance) void {
    const data = internal(track);
    data.regions.append(data.allocator, same_object.Link.to(region)) catch return;
    var buffer: [32]u8 = undefined;
    engine.traceChild(track, region, regionSlot(&buffer, region));
}
/// A track element's src was set, changed or removed: "immediately empty the
/// element's text track's text track list of cues". The file's regions go
/// too: a cue script holds keeps its own by an edge.
fn clearCues(track: *runtime.Instance) void {
    const data = internal(track);
    for (data.regions.items) |region| {
        var buffer: [32]u8 = undefined;
        engine.forgetTracedChild(track, regionSlot(&buffer, region.instance));
    }
    data.regions.clearRetainingCapacity();
    const list = data.cues orelse return;
    // Each cue leaves the list - its track and active flag go with it -
    // before the list lets the cues go.
    const had_cues = hooks.cueListItems(list).len != 0;
    for (hooks.cueListItems(list)) |cue| hooks.setCueTrack(cue.link.instance, null, 0);
    // The list frees the cues it alone owned.
    hooks.cueListClear(list);
    if (had_cues) if (liveMedia(data)) |media| hooks.mediaCuesChanged(media, .cue_removed);
}
/// A cue in the list has a new start or end time: its place in text track
/// cue order follows.
fn cueTimesChanged(track: *runtime.Instance, cue: *runtime.Instance) void {
    const data = internal(track);
    const list = data.cues orelse return;
    hooks.cueListReorder(list, cue);
    if (liveMedia(data)) |media| hooks.mediaCuesChanged(media, .cue_times);
}
pub fn get_kind(instance: *runtime.Instance) anyerror!enums.TextTrackKind {
    return @fromBackingInt(@intCast(@backingInt(internal(instance).kind)));
}
pub fn get_label(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return internal(instance).label.clone(instance.ctx.allocator);
}
pub fn get_language(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return internal(instance).language.clone(instance.ctx.allocator);
}
pub fn get_id(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return internal(instance).id.clone(instance.ctx.allocator);
}
pub fn get_inBandMetadataTrackDispatchType(_: *runtime.Instance) anyerror!runtime.DOMString {
    return .initEmpty();
}
pub fn get_mode(instance: *runtime.Instance) anyerror!enums.TextTrackMode {
    return @fromBackingInt(@intCast(@backingInt(internal(instance).mode)));
}
/// "The mode setter steps are to set this's mode to the mode switching on
/// the given value." A changed mode is what two algorithms wait for: the
/// track's media element's pending text track change notification (HTML
/// 4.8.11.11.1, for any track in a media element's list of text tracks) and,
/// for a track element's track, the track processing model (4.8.11.11.3).
pub fn set_mode(instance: *runtime.Instance, value: enums.TextTrackMode) anyerror!void {
    const data = internal(instance);
    const mode: hooks.Mode = @fromBackingInt(@intCast(@backingInt(value)));
    const old = data.mode;
    if (old == mode) return;
    data.mode = mode;
    // A disabled track has no active cues (4.8.11.11.1: the active flag is
    // unset when the track "has its text track mode changed to disabled").
    if (mode == .disabled) deactivateCues(data);
    // A severed or reused slab slot is never read, even during forced native
    // teardown.
    if (liveMedia(data)) |media| hooks.textTrackModeChanged(media);
    if (data.element) |link| if (link.isLive()) hooks.trackModeChanged(link.instance, old, mode);
}
/// "1. If this's mode is the text track disabled mode, then return null.
/// 2. Return a live TextTrackCueList object that represents the subset of
/// this's text track list of cues whose end times occur at or after the
/// earliest possible position when the script started, in text track cue
/// order" - the same object each time.
///
/// The subset: every engine answers the whole list - Chrome, Firefox and
/// Safari keep no second list for `cues` (Blink TextTrack::cues returns
/// EnsureTextTrackCueList(); Gecko TextTrack::GetCues returns mCueList;
/// WebKit TextTrack::cues returns ensureTextTrackCueList()), and
/// track-cue-negative-timestamp.html / interfaces/TextTrack/cues.html expect
/// cues ending before the earliest possible position to be listed. No newer
/// spec is involved: golden rule 2 takes the browsers' whole list.
pub fn get_cues(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const data = internal(instance);
    if (data.mode == .disabled) return null;
    return try ensureCues(instance);
}
/// "1. If this's mode is the text track disabled mode, then return null.
/// 2. Return a live TextTrackCueList object that represents the subset of
/// this's text track list of cues whose active flag was set when the script
/// started, in text track cue order" - the same object each time, brought up
/// to date with the cues' active flags on each read (Blink's
/// TextTrack::activeCues: cues_->CollectActiveCues(*active_cues_)).
pub fn get_activeCues(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const data = internal(instance);
    if (data.mode == .disabled) return null;
    if (data.active == null) {
        const list = try hooks.createCueList(instance.ctx, false);
        data.active = list;
        data.active_keep.made(list);
        data.active_keep.handOut(instance, list, .{ .name = "activeCues" });
    }
    const active = data.active.?;
    // Drop the cues no longer active (or no longer in the list), then add
    // the active ones: the list keeps its own order. The first read prunes
    // the dead; removing one cue at a time leaves the rest where they were.
    var index = hooks.cueListItems(active).len;
    while (index > 0) {
        index -= 1;
        const held = hooks.cueListItems(active);
        if (index >= held.len) continue;
        const cue = held[index].link.instance;
        if (!hooks.cueActive(cue) or (interfaces.TextTrackCue.get_track(cue) catch null) != instance) _ = hooks.cueListRemove(active, cue);
    }
    if (data.cues) |list| for (hooks.cueListItems(list)) |cue| {
        if (hooks.cueActive(cue.link.instance)) try hooks.cueListAdd(active, cue.link.instance);
    };
    return active;
}
pub fn get_sourceBuffer(_: *runtime.Instance) anyerror!?*runtime.Instance {
    return null;
}
/// The addCue(cue) method steps.
pub fn call_addCue(instance: *runtime.Instance, cue: *runtime.Instance) anyerror!void {
    try addCue(instance, cue);
    // A newly introduced cue of this track's media element (4.8.11.8).
    if (liveMedia(internal(instance))) |media| hooks.mediaCuesChanged(media, .{ .cue_added = cue });
}
/// The parser's output, added cue by cue as addCue() adds one, and then
/// newly introduced to the media element at once: one time marches on for
/// the file, not one per cue (Blink's TextTrack::AddListOfCues and
/// CueTimeline::AddCues).
fn addCues(track: *runtime.Instance, cues: []const *runtime.Instance) !void {
    var added: usize = 0;
    defer if (added != 0) if (liveMedia(internal(track))) |media| hooks.mediaCuesChanged(media, .{ .cues_added = cues[0..added] });
    for (cues) |cue| {
        try addCue(track, cue);
        added += 1;
    }
}
/// addCue(cue) steps 1-5.
fn addCue(instance: *runtime.Instance, cue: *runtime.Instance) !void {
    const data = internal(instance);
    // 1. list: this's text track list of cues.
    const list = try ensureCues(instance);
    // 2. A list with no rules yet takes those appropriate to cue - its
    // interface's (WebVTT's for a VTTCue).
    const rules = cue.vtable.name;
    if (data.rules == null) data.rules = rules;
    // 3. Other rules than the list's: InvalidStateError.
    if (!std.mem.eql(u8, data.rules.?, rules)) return error.InvalidStateError;
    // 4. A cue in a text track list of cues leaves it first.
    if (try interfaces.TextTrackCue.get_track(cue)) |previous| try interfaces.TextTrack.call_removeCue(previous, cue);
    // 5. Add cue to list, in text track cue order: it is the list's newest.
    data.added += 1;
    hooks.setCueTrack(cue, instance, data.added);
    hooks.cueListAdd(list, cue) catch |err| {
        hooks.setCueTrack(cue, null, 0);
        return err;
    };
}
/// The removeCue(cue) method steps.
pub fn call_removeCue(instance: *runtime.Instance, cue: *runtime.Instance) anyerror!void {
    const data = internal(instance);
    // 1. A cue not in this's text track list of cues: NotFoundError.
    const list = data.cues orelse return error.NotFoundError;
    // 2. Remove it: it is in no track's list now.
    const removed = hooks.cueListRemove(list, cue) orelse return error.NotFoundError;
    hooks.setCueTrack(cue, null, 0);
    // A cue only the list owned (no wrapper reaches it) goes whole.
    if (removed == .owned) runtime.gc.releaseOwned(cue);
    if (liveMedia(data)) |media| hooks.mediaCuesChanged(media, .cue_removed);
}
