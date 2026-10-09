//! HTML's media owner steps that have no IDL member. Installed at process start.
//! lint-impls: hook for MediaError, TextTrack, TextTrackList, HTMLTrackElement, HTMLSourceElement, HTMLMediaElement
const std = @import("std");
const runtime = @import("runtime");
const process_start = @import("process_start.zig");

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
};
const CreateError = *const fn (runtime.Context, ErrorCode) anyerror!*runtime.Instance;
const ModeChanged = *const fn (*runtime.Instance, Mode, Mode) void;
const SourceURL = *const fn (*runtime.Instance) ?[]const u8;
const DelaysLoad = *const fn (*runtime.Instance) bool;
const ParentChanged = *const fn (*runtime.Instance, ?*runtime.Instance, ?*runtime.Instance) void;
const TrackModeChanged = *const fn (*runtime.Instance) void;
/// A video's natural size in CSS pixels (HTML 4.8.8), 0x0 when it has none.
pub const VideoSize = struct { width: u32 = 0, height: u32 = 0 };
const NaturalSize = *const fn (*runtime.Instance) VideoSize;
pub const ListOperations = struct {
    create: *const fn (runtime.Context) anyerror!*runtime.Instance,
    append: *const fn (*runtime.Instance, *runtime.Instance) anyerror!void,
    remove: *const fn (*runtime.Instance, *runtime.Instance) void,
};
pub const Implementation = struct {
    create_error: ?CreateError = null,
    track: ?TrackOperations = null,
    mode_changed: ?ModeChanged = null,
    source_url: ?SourceURL = null,
    delays_load: ?DelaysLoad = null,
    list: ?ListOperations = null,
    parent_changed: ?ParentChanged = null,
    track_mode_changed: ?TrackModeChanged = null,
    video_size: ?NaturalSize = null,
};
// process-wide: hook table written only by its owners at process start (B0); immutable while Browsers run, comptime in B9
var implementation: ?Implementation = null;

fn installing() *Implementation {
    process_start.assertInstalling();
    if (implementation == null) implementation = .{};
    return &implementation.?;
}
pub fn installMediaError(create: CreateError) void {
    installing().create_error = create;
}
pub fn installTextTrack(operations: TrackOperations) void {
    installing().track = operations;
}
pub fn installTrackElement(changed: ModeChanged) void {
    installing().mode_changed = changed;
}
pub fn installSourceElement(url: SourceURL) void {
    installing().source_url = url;
}
pub fn installMediaElement(delays_load: DelaysLoad, parent_changed: ParentChanged, mode_changed: TrackModeChanged, video_size: NaturalSize) void {
    const table = installing();
    table.delays_load = delays_load;
    table.parent_changed = parent_changed;
    table.track_mode_changed = mode_changed;
    table.video_size = video_size;
}
pub fn installTextTrackList(operations: ListOperations) void {
    installing().list = operations;
}
pub fn createTextTrackList(ctx: runtime.Context) !*runtime.Instance {
    const list = (implementation orelse return error.NotSupported).list orelse return error.NotSupported;
    return list.create(ctx);
}
pub fn appendTextTrack(object: *runtime.Instance, track: *runtime.Instance) !void {
    const list = (implementation orelse return error.NotSupported).list orelse return error.NotSupported;
    return list.append(object, track);
}
pub fn removeTextTrack(object: *runtime.Instance, track: *runtime.Instance) void {
    const list = (implementation orelse return).list orelse return;
    list.remove(object, track);
}
pub fn trackElementParentChanged(element: *runtime.Instance, old_parent: ?*runtime.Instance, new_parent: ?*runtime.Instance) void {
    const changed = (implementation orelse return).parent_changed orelse return;
    changed(element, old_parent, new_parent);
}
pub fn textTrackModeChanged(media: *runtime.Instance) void {
    const changed = (implementation orelse return).track_mode_changed orelse return;
    changed(media);
}

pub fn createError(ctx: runtime.Context, code: ErrorCode) !*runtime.Instance {
    const create = (implementation orelse return error.NotSupported).create_error orelse return error.NotSupported;
    return create(ctx, code);
}
pub fn createTrackElementTrack(ctx: runtime.Context, kind: Kind, label: runtime.DOMString, language: runtime.DOMString, id: runtime.DOMString) !*runtime.Instance {
    const track = (implementation orelse return error.NotSupported).track orelse return error.NotSupported;
    return track.create(ctx, kind, label, language, id);
}
pub fn updateTrackAttributes(object: *runtime.Instance, kind: Kind, label: runtime.DOMString, language: runtime.DOMString, id: runtime.DOMString) !void {
    const track = (implementation orelse return error.NotSupported).track orelse return error.NotSupported;
    return track.update(object, kind, label, language, id);
}
/// Uninstalled setters/notifications are no-ops; readiness defaults to not_loaded.
pub fn setTrackReadiness(object: *runtime.Instance, readiness: Readiness) void {
    const track = (implementation orelse return).track orelse return;
    track.set_readiness(object, readiness);
}
pub fn trackReadiness(object: *runtime.Instance) Readiness {
    const track = (implementation orelse return .not_loaded).track orelse return .not_loaded;
    return track.readiness(object);
}
pub fn linkTrackElement(object: *runtime.Instance, element: *runtime.Instance) void {
    const track = (implementation orelse return).track orelse return;
    track.link_element(object, element);
}
pub fn trackElementDestroyed(object: *runtime.Instance) void {
    const track = (implementation orelse return).track orelse return;
    track.element_destroyed(object);
}
pub fn trackModeChanged(element: *runtime.Instance, old_mode: Mode, new_mode: Mode) void {
    const changed = (implementation orelse return).mode_changed orelse return;
    changed(element, old_mode, new_mode);
}
/// Borrowed until src changes or the source is destroyed; copy before script.
pub fn sourceURL(element: *runtime.Instance) ?[]const u8 {
    const url = (implementation orelse return null).source_url orelse return null;
    return url(element);
}
/// The natural size of a video element's video: the media element owns the
/// decoder that knows it, and HTMLVideoElement's videoWidth and videoHeight
/// read it here. 0x0 when uninstalled.
pub fn videoSize(element: *runtime.Instance) VideoSize {
    const size = (implementation orelse return .{}).video_size orelse return .{};
    return size(element);
}
pub fn mediaDelaysLoadEvent(document: *runtime.Instance) bool {
    const delays_load = (implementation orelse return false).delays_load orelse return false;
    return delays_load(document);
}

test "uninstalled media hooks define every fallback without accessing an instance" {
    const saved = implementation;
    defer implementation = saved;
    implementation = null;
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
}
