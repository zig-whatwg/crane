//! HTML's media owner steps that have no IDL member. Installed at process start.
//! lint-impls: hook for MediaError, TextTrack, TextTrackList, TextTrackCue, TextTrackCueList, HTMLTrackElement, HTMLSourceElement, HTMLMediaElement
const std = @import("std");
const runtime = @import("runtime");
const Hook = @import("hook.zig").Hook;
const Link = @import("same_object.zig").Link;
const engine = @import("engine");

pub const ErrorCode = enum(u16) { aborted = 1, network = 2, decode = 3, source_not_supported = 4 };
pub const Kind = enum { subtitles, captions, descriptions, chapters, metadata };
pub const Readiness = enum(u16) { not_loaded = 0, loading = 1, loaded = 2, failed = 3 };
pub const Mode = enum { disabled, hidden, showing };
pub const TrackOperations = struct {
    create: *const fn (runtime.Context, Kind, runtime.DOMString, runtime.DOMString, runtime.DOMString) anyerror!*runtime.Instance,
    update: *const fn (*runtime.Instance, Kind, runtime.DOMString, runtime.DOMString, runtime.DOMString) anyerror!void,
    set_readiness: *const fn (*runtime.Instance, Readiness) void,
    readiness: *const fn (*runtime.Instance) Readiness,
    link_element: *const fn (*runtime.Instance, *runtime.Instance) void,
    element_destroyed: *const fn (*runtime.Instance) void,
    /// Empty the text track's list of cues (a track element's src changed).
    clear_cues: *const fn (*runtime.Instance) void,
    /// The media element whose list of text tracks the track is now in, or
    /// null when it left it.
    link_media: *const fn (*runtime.Instance, ?*runtime.Instance) void,
    /// A cue in the track's list of cues has a new start or end time.
    cue_times_changed: *const fn (*runtime.Instance, *runtime.Instance) void,
    /// The track's own list of cues (a TextTrackCueList), if made - whatever
    /// its mode.
    cue_list: *const fn (*runtime.Instance) ?*runtime.Instance,
    /// The track keeps a VTTRegion its WebVTT file made (until its src
    /// changes).
    keep_region: *const fn (*runtime.Instance, *runtime.Instance) void,
    /// A format parser's cues, added as addCue() adds each, newly introduced
    /// to the track's media element together.
    add_cues: *const fn (*runtime.Instance, []const *runtime.Instance) anyerror!void,
};
/// A text track cue's state that has no IDL member (HTML 4.8.11.11.1): the
/// text track whose list of cues holds it, its active flag, and when it was
/// last added to a list (text track cue order's last key). TextTrackCue's.
pub const CueOperations = struct {
    /// The cue is now in `track`'s list of cues (null: in none), added at
    /// `order`.
    set_track: *const fn (*runtime.Instance, ?*runtime.Instance, u64) void,
    active: *const fn (*runtime.Instance) bool,
    set_active: *const fn (*runtime.Instance, bool) void,
    order: *const fn (*runtime.Instance) u64,
    /// The cue has a wrapper now (its list handed it to script): it draws
    /// the edges it keeps (its track).
    exposed: *const fn (*runtime.Instance) void,
};
/// A cue list entry: the cue, and whether the list's edge to it is drawn
/// (TextTrackCueList.zig).
pub const CueEntry = struct {
    link: Link,
    exposed: bool = false,
};
/// What removing a cue from a list left: a cue only the list owned (no
/// wrapper reaches it), for the caller to free once done with it, or one its
/// wrapper owns.
pub const Removed = enum { owned, wrapped };
/// A TextTrackCueList's contents (HTML 4.8.11.11.5), kept in text track cue
/// order. TextTrackCueList's.
pub const CueListOperations = struct {
    /// A track's own list (`owns`: it owns its unexposed cues) or a view.
    create: *const fn (runtime.Context, bool) anyerror!*runtime.Instance,
    add: *const fn (*runtime.Instance, *runtime.Instance) anyerror!void,
    /// Null when the list does not hold the cue.
    remove: *const fn (*runtime.Instance, *runtime.Instance) ?Removed,
    clear: *const fn (*runtime.Instance) void,
    reorder: *const fn (*runtime.Instance, *runtime.Instance) void,
    /// The cues still live (a cue made in another realm goes with that
    /// realm's end, whatever holds it), borrowed until the list next
    /// changes. Reading them hands none to script.
    items: *const fn (*runtime.Instance) []const CueEntry,
    /// The cue is going to script: the list keeps it by an edge from now on.
    expose: *const fn (*runtime.Instance, *runtime.Instance) void,
};
/// VTTCue's part of a cue's exposure: its region's edge.
const FormatExposed = *const fn (*runtime.Instance) void;
const CreateError = *const fn (runtime.Context, ErrorCode) anyerror!*runtime.Instance;
const ModeChanged = *const fn (*runtime.Instance, Mode, Mode) void;
const SourceURL = *const fn (*runtime.Instance) ?[]const u8;
const DelaysLoad = *const fn (*runtime.Instance) bool;
const ParentChanged = *const fn (*runtime.Instance, ?*runtime.Instance, ?*runtime.Instance) void;
const TrackModeChanged = *const fn (*runtime.Instance) void;
/// What changed in a media element's text tracks' cues (HTML 4.8.11.8, the
/// list of newly introduced cues and time marches on's triggers).
pub const CueChange = union(enum) {
    /// A cue was added to the list of cues of a track in the media element's
    /// list of text tracks.
    cue_added: *runtime.Instance,
    /// Cues a format parser added together (borrowed for the call).
    cues_added: []const *runtime.Instance,
    /// A text track joined the media element's list of text tracks.
    track_added: *runtime.Instance,
    /// A cue left a track's list of cues.
    cue_removed,
    /// A text track left the list of text tracks.
    track_removed,
    /// A cue's start or end time changed.
    cue_times,
};
const CuesChanged = *const fn (*runtime.Instance, CueChange) void;
/// A video's natural size in CSS pixels (HTML 4.8.8), 0x0 when it has none.
pub const VideoSize = struct { width: u32 = 0, height: u32 = 0 };
const NaturalSize = *const fn (*runtime.Instance) VideoSize;
pub const ListOperations = struct {
    create: *const fn (runtime.Context) anyerror!*runtime.Instance,
    append: *const fn (*runtime.Instance, *runtime.Instance) anyerror!void,
    remove: *const fn (*runtime.Instance, *runtime.Instance) void,
};
/// Read-only HTML 4.16.3 inputs; returned by value and never retained.
pub const SelectorState = struct {
    paused: bool,
    seeking: bool,
    network_state: u16,
    ready_state: u16,
    stalled: bool,
    muted: bool,
    volume: f64,
    volume_locked: bool,
};
pub const SelectorStateReader = *const fn (*runtime.Instance) ?SelectorState;

pub const Implementation = struct {
    selector_state: ?SelectorStateReader = null,
    create_error: ?CreateError = null,
    track: ?TrackOperations = null,
    mode_changed: ?ModeChanged = null,
    source_url: ?SourceURL = null,
    delays_load: ?DelaysLoad = null,
    list: ?ListOperations = null,
    cue: ?CueOperations = null,
    vtt_cue_exposed: ?FormatExposed = null,
    cue_list: ?CueListOperations = null,
    parent_changed: ?ParentChanged = null,
    track_mode_changed: ?TrackModeChanged = null,
    cues_changed: ?CuesChanged = null,
    video_size: ?NaturalSize = null,
};
// process-wide: hook table written only by its owners at process start (B0); immutable while Browsers run, comptime in B9
var implementation: Hook(?Implementation) = .init(null);

/// The table as installed so far, for an owner to fill its part of and
/// `implementation.install` whole: several owners fill this table, and an
/// install of the table already there writes nothing (src/dom/hook.zig).
fn installed() Implementation {
    return implementation.get() orelse .{};
}
pub fn installMediaError(create: CreateError) void {
    var table = installed();
    table.create_error = create;
    implementation.install(table);
}
pub fn installTextTrack(operations: TrackOperations) void {
    var table = installed();
    table.track = operations;
    implementation.install(table);
}
pub fn installTrackElement(changed: ModeChanged) void {
    var table = installed();
    table.mode_changed = changed;
    implementation.install(table);
}
pub fn installSourceElement(url: SourceURL) void {
    var table = installed();
    table.source_url = url;
    implementation.install(table);
}
pub fn installMediaElement(delays_load: DelaysLoad, parent_changed: ParentChanged, mode_changed: TrackModeChanged, cues_changed: CuesChanged, video_size: NaturalSize, selector_state: SelectorStateReader) void {
    var table = installed();
    table.delays_load = delays_load;
    table.parent_changed = parent_changed;
    table.track_mode_changed = mode_changed;
    table.cues_changed = cues_changed;
    table.video_size = video_size;
    table.selector_state = selector_state;
    implementation.install(table);
}
pub fn selectorState(element: *runtime.Instance) ?SelectorState {
    const read = (implementation.get() orelse return null).selector_state orelse return null;
    return read(element);
}

pub fn installTextTrackCue(operations: CueOperations) void {
    var table = installed();
    table.cue = operations;
    implementation.install(table);
}
pub fn installVTTCue(exposed: FormatExposed) void {
    var table = installed();
    table.vtt_cue_exposed = exposed;
    implementation.install(table);
}
pub fn installTextTrackCueList(operations: CueListOperations) void {
    var table = installed();
    table.cue_list = operations;
    implementation.install(table);
}
pub fn installTextTrackList(operations: ListOperations) void {
    var table = installed();
    table.list = operations;
    implementation.install(table);
}
pub fn createTextTrackList(ctx: runtime.Context) !*runtime.Instance {
    const list = (implementation.get() orelse return error.NotSupported).list orelse return error.NotSupported;
    return list.create(ctx);
}
pub fn appendTextTrack(object: *runtime.Instance, track: *runtime.Instance) !void {
    const list = (implementation.get() orelse return error.NotSupported).list orelse return error.NotSupported;
    return list.append(object, track);
}
pub fn removeTextTrack(object: *runtime.Instance, track: *runtime.Instance) void {
    const list = (implementation.get() orelse return).list orelse return;
    list.remove(object, track);
}
pub fn trackElementParentChanged(element: *runtime.Instance, old_parent: ?*runtime.Instance, new_parent: ?*runtime.Instance) void {
    const changed = (implementation.get() orelse return).parent_changed orelse return;
    changed(element, old_parent, new_parent);
}
pub fn textTrackModeChanged(media: *runtime.Instance) void {
    const changed = (implementation.get() orelse return).track_mode_changed orelse return;
    changed(media);
}
/// The media element's text tracks' cues changed (`CueChange`).
pub fn mediaCuesChanged(media: *runtime.Instance, change: CueChange) void {
    const changed = (implementation.get() orelse return).cues_changed orelse return;
    changed(media, change);
}

pub fn createError(ctx: runtime.Context, code: ErrorCode) !*runtime.Instance {
    const create = (implementation.get() orelse return error.NotSupported).create_error orelse return error.NotSupported;
    return create(ctx, code);
}
pub fn createTrackElementTrack(ctx: runtime.Context, kind: Kind, label: runtime.DOMString, language: runtime.DOMString, id: runtime.DOMString) !*runtime.Instance {
    const track = (implementation.get() orelse return error.NotSupported).track orelse return error.NotSupported;
    return track.create(ctx, kind, label, language, id);
}
pub fn updateTrackAttributes(object: *runtime.Instance, kind: Kind, label: runtime.DOMString, language: runtime.DOMString, id: runtime.DOMString) !void {
    const track = (implementation.get() orelse return error.NotSupported).track orelse return error.NotSupported;
    return track.update(object, kind, label, language, id);
}
/// Uninstalled setters/notifications are no-ops; readiness defaults to not_loaded.
pub fn setTrackReadiness(object: *runtime.Instance, readiness: Readiness) void {
    const track = (implementation.get() orelse return).track orelse return;
    track.set_readiness(object, readiness);
}
pub fn trackReadiness(object: *runtime.Instance) Readiness {
    const track = (implementation.get() orelse return .not_loaded).track orelse return .not_loaded;
    return track.readiness(object);
}
pub fn linkTrackElement(object: *runtime.Instance, element: *runtime.Instance) void {
    const track = (implementation.get() orelse return).track orelse return;
    track.link_element(object, element);
}
pub fn trackElementDestroyed(object: *runtime.Instance) void {
    const track = (implementation.get() orelse return).track orelse return;
    track.element_destroyed(object);
}
pub fn trackModeChanged(element: *runtime.Instance, old_mode: Mode, new_mode: Mode) void {
    const changed = (implementation.get() orelse return).mode_changed orelse return;
    changed(element, old_mode, new_mode);
}
/// Borrowed until src changes or the source is destroyed; copy before script.
pub fn sourceURL(element: *runtime.Instance) ?[]const u8 {
    const url = (implementation.get() orelse return null).source_url orelse return null;
    return url(element);
}
/// The natural size of a video element's video: the media element owns the
/// decoder that knows it, and HTMLVideoElement's videoWidth and videoHeight
/// read it here. 0x0 when uninstalled.
pub fn videoSize(element: *runtime.Instance) VideoSize {
    const size = (implementation.get() orelse return .{}).video_size orelse return .{};
    return size(element);
}
pub fn mediaDelaysLoadEvent(document: *runtime.Instance) bool {
    const delays_load = (implementation.get() orelse return false).delays_load orelse return false;
    return delays_load(document);
}

/// Text track cues (TextTrackCue's state with no IDL member). Uninstalled:
/// no track, never active, order 0.
pub fn setCueTrack(cue: *runtime.Instance, track: ?*runtime.Instance, order: u64) void {
    const operations = (implementation.get() orelse return).cue orelse return;
    operations.set_track(cue, track, order);
}
pub fn cueActive(cue: *runtime.Instance) bool {
    const operations = (implementation.get() orelse return false).cue orelse return false;
    return operations.active(cue);
}
pub fn setCueActive(cue: *runtime.Instance, active: bool) void {
    const operations = (implementation.get() orelse return).cue orelse return;
    operations.set_active(cue, active);
}
pub fn cueOrder(cue: *runtime.Instance) u64 {
    const operations = (implementation.get() orelse return 0).cue orelse return 0;
    return operations.order(cue);
}
/// The cue has a wrapper now: TextTrackCue's edges, then its format's.
pub fn cueExposed(cue: *runtime.Instance) void {
    const table = implementation.get() orelse return;
    if (table.cue) |operations| operations.exposed(cue);
    if (table.vtt_cue_exposed) |exposed| exposed(cue);
}
/// Whether script may hold a wrapper of `instance` now - false only when
/// the engine can prove none reaches it (runtime.instance_lifecycle
/// .provablyUnwrapped). Edges are drawn from wrappers: an object that
/// keeps others by edges draws them only once it has one.
pub fn mayBeWrapped(instance: *const runtime.Instance) bool {
    return !runtime.instance_lifecycle.provablyUnwrapped(engine.capabilities.wrap_tracking != .unsupported, instance);
}
/// TextTrackCueList contents (TextTrackCueList's).
pub fn createCueList(ctx: runtime.Context, owns: bool) !*runtime.Instance {
    const operations = (implementation.get() orelse return error.NotSupported).cue_list orelse return error.NotSupported;
    return operations.create(ctx, owns);
}
pub fn cueListAdd(list: *runtime.Instance, cue: *runtime.Instance) !void {
    const operations = (implementation.get() orelse return error.NotSupported).cue_list orelse return error.NotSupported;
    return operations.add(list, cue);
}
pub fn cueListRemove(list: *runtime.Instance, cue: *runtime.Instance) ?Removed {
    const operations = (implementation.get() orelse return null).cue_list orelse return null;
    return operations.remove(list, cue);
}
pub fn cueListClear(list: *runtime.Instance) void {
    const operations = (implementation.get() orelse return).cue_list orelse return;
    operations.clear(list);
}
pub fn cueListReorder(list: *runtime.Instance, cue: *runtime.Instance) void {
    const operations = (implementation.get() orelse return).cue_list orelse return;
    operations.reorder(list, cue);
}
pub fn cueListItems(list: *runtime.Instance) []const CueEntry {
    const operations = (implementation.get() orelse return &.{}).cue_list orelse return &.{};
    return operations.items(list);
}
pub fn cueListExpose(list: *runtime.Instance, cue: *runtime.Instance) void {
    const operations = (implementation.get() orelse return).cue_list orelse return;
    operations.expose(list, cue);
}
/// Text tracks (TextTrack's).
pub fn clearTrackCues(track: *runtime.Instance) void {
    const operations = (implementation.get() orelse return).track orelse return;
    operations.clear_cues(track);
}
pub fn linkTrackMedia(track: *runtime.Instance, media: ?*runtime.Instance) void {
    const operations = (implementation.get() orelse return).track orelse return;
    operations.link_media(track, media);
}
pub fn cueTimesChanged(track: *runtime.Instance, cue: *runtime.Instance) void {
    const operations = (implementation.get() orelse return).track orelse return;
    operations.cue_times_changed(track, cue);
}
pub fn trackCueList(track: *runtime.Instance) ?*runtime.Instance {
    const operations = (implementation.get() orelse return null).track orelse return null;
    return operations.cue_list(track);
}
pub fn addTrackCues(track: *runtime.Instance, cues: []const *runtime.Instance) !void {
    const operations = (implementation.get() orelse return error.NotSupported).track orelse return error.NotSupported;
    return operations.add_cues(track, cues);
}
pub fn keepTrackRegion(track: *runtime.Instance, region: *runtime.Instance) void {
    const operations = (implementation.get() orelse return).track orelse return;
    operations.keep_region(track, region);
}

test "uninstalled media hooks define every fallback without accessing an instance" {
    const override = implementation.overrideForTest(null);
    defer override.restore();
    var instance: runtime.Instance = undefined;
    var ctx: runtime.ContextData = undefined;
    try std.testing.expectError(error.NotSupported, createError(&ctx, .aborted));
    try std.testing.expectError(error.NotSupported, createTrackElementTrack(&ctx, .subtitles, .initEmpty(), .initEmpty(), .initEmpty()));
    try std.testing.expectError(error.NotSupported, updateTrackAttributes(&instance, .metadata, .initEmpty(), .initEmpty(), .initEmpty()));
    setTrackReadiness(&instance, .failed);
    try std.testing.expectEqual(Readiness.not_loaded, trackReadiness(&instance));
    linkTrackElement(&instance, &instance);
    trackElementDestroyed(&instance);
    trackModeChanged(&instance, .disabled, .hidden);
    try std.testing.expect(sourceURL(&instance) == null);
    try std.testing.expect(!mediaDelaysLoadEvent(&instance));
    try std.testing.expectEqual(VideoSize{ .width = 0, .height = 0 }, videoSize(&instance));
    try std.testing.expectError(error.NotSupported, createTextTrackList(&ctx));
    try std.testing.expectError(error.NotSupported, appendTextTrack(&instance, &instance));
    removeTextTrack(&instance, &instance);
    trackElementParentChanged(&instance, null, null);
    textTrackModeChanged(&instance);
    mediaCuesChanged(&instance, .cue_removed);
    setCueTrack(&instance, null, 0);
    try std.testing.expect(!cueActive(&instance));
    setCueActive(&instance, true);
    try std.testing.expectEqual(@as(u64, 0), cueOrder(&instance));
    try std.testing.expectError(error.NotSupported, createCueList(&ctx, true));
    try std.testing.expectError(error.NotSupported, cueListAdd(&instance, &instance));
    try std.testing.expect(cueListRemove(&instance, &instance) == null);
    cueListExpose(&instance, &instance);
    cueExposed(&instance);
    try std.testing.expect(trackCueList(&instance) == null);
    keepTrackRegion(&instance, &instance);
    cueListClear(&instance);
    cueListReorder(&instance, &instance);
    try std.testing.expectEqual(@as(usize, 0), cueListItems(&instance).len);
    clearTrackCues(&instance);
    linkTrackMedia(&instance, null);
    cueTimesChanged(&instance, &instance);
}
