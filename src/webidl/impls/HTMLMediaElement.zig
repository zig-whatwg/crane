//! Implementation for HTMLMediaElement interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const HTMLMediaElement = interfaces.HTMLMediaElement;

pub const State = HTMLMediaElement.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
pub const InternalState = struct {};

/// Initialize instance (creates the instance)
/// Chains to parent class: HTMLElement -> Element -> Node -> EventTarget
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    // Chain to parent class (HTMLElement)
    const HTMLElementImpl = @import("HTMLElement.zig");
    const instance = try HTMLElementImpl.init(allocator, StateType, vtable, ctx);
    // HTMLMediaElement has no additional initialization
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // HTMLMediaElement has no additional cleanup
    // Chain to parent class
    const HTMLElementImpl = @import("HTMLElement.zig");
    HTMLElementImpl.deinit(instance);
}

/// Getter for error
pub fn get_error(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for src
pub fn get_src(instance: *runtime.Instance) anyerror!runtime.USVString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for srcObject
pub fn get_srcObject(instance: *runtime.Instance) anyerror!?typedefs.MediaProvider {
    _ = instance;
    return null;
}

/// Getter for currentSrc
pub fn get_currentSrc(instance: *runtime.Instance) anyerror!runtime.USVString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for crossOrigin
pub fn get_crossOrigin(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for networkState
/// Per HTML spec: Returns the network state of the media.
/// Stub: Returns NETWORK_EMPTY (0) - no data yet
pub fn get_networkState(instance: *runtime.Instance) anyerror!u16 {
    _ = instance;
    return 0; // NETWORK_EMPTY
}

/// Getter for preload
pub fn get_preload(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for buffered
pub fn get_buffered(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for readyState
/// Per HTML spec: Returns the ready state of the media.
/// Stub: Returns HAVE_NOTHING (0) - no data available
pub fn get_readyState(instance: *runtime.Instance) anyerror!u16 {
    _ = instance;
    return 0; // HAVE_NOTHING
}

/// Getter for seeking
pub fn get_seeking(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for currentTime
/// Per HTML spec: Returns the current playback position in seconds.
/// Stub: Returns 0 (beginning of media)
pub fn get_currentTime(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return 0.0;
}

/// Getter for duration
/// Per HTML spec: Returns the length of the media in seconds, or NaN.
/// Stub: Returns NaN (no media loaded)
pub fn get_duration(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return std.math.nan(f64);
}

/// Getter for paused
/// Per HTML spec: Returns true if playback is paused.
/// Stub: Always returns true (not playing)
pub fn get_paused(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return true; // Always paused in stub
}

/// Getter for defaultPlaybackRate
pub fn get_defaultPlaybackRate(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for playbackRate
pub fn get_playbackRate(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for preservesPitch
pub fn get_preservesPitch(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for played
pub fn get_played(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for seekable
pub fn get_seekable(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ended
pub fn get_ended(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for autoplay
pub fn get_autoplay(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for loop
pub fn get_loop(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for controls
pub fn get_controls(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for volume
pub fn get_volume(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for muted
pub fn get_muted(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for defaultMuted
pub fn get_defaultMuted(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for audioTracks
pub fn get_audioTracks(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for videoTracks
pub fn get_videoTracks(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for textTracks
pub fn get_textTracks(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for sinkId
pub fn get_sinkId(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for remote
pub fn get_remote(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for disableRemotePlayback
pub fn get_disableRemotePlayback(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for mediaKeys
pub fn get_mediaKeys(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for onencrypted
pub fn get_onencrypted(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onwaitingforkey
pub fn get_onwaitingforkey(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for src
pub fn set_src(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for srcObject
pub fn set_srcObject(instance: *runtime.Instance, value: ?typedefs.MediaProvider) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for crossOrigin
pub fn set_crossOrigin(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for preload
pub fn set_preload(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for currentTime
pub fn set_currentTime(instance: *runtime.Instance, value: f64) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for defaultPlaybackRate
pub fn set_defaultPlaybackRate(instance: *runtime.Instance, value: f64) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for playbackRate
pub fn set_playbackRate(instance: *runtime.Instance, value: f64) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for preservesPitch
pub fn set_preservesPitch(instance: *runtime.Instance, value: bool) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for autoplay
pub fn set_autoplay(instance: *runtime.Instance, value: bool) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for loop
pub fn set_loop(instance: *runtime.Instance, value: bool) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for controls
pub fn set_controls(instance: *runtime.Instance, value: bool) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for volume
pub fn set_volume(instance: *runtime.Instance, value: f64) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for muted
pub fn set_muted(instance: *runtime.Instance, value: bool) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for defaultMuted
pub fn set_defaultMuted(instance: *runtime.Instance, value: bool) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for disableRemotePlayback
pub fn set_disableRemotePlayback(instance: *runtime.Instance, value: bool) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onencrypted
pub fn set_onencrypted(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onwaitingforkey
pub fn set_onwaitingforkey(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: setSinkId
pub fn call_setSinkId(instance: *runtime.Instance, sinkId: runtime.DOMString) anyerror!runtime.JSValue {
    _ = instance;
    _ = sinkId;
    return error.NotImplemented;
}

/// Operation: load
/// Per HTML spec: Resets the element to its initial state and selects a media resource.
/// Stub: No-op
pub fn call_load(instance: *runtime.Instance) anyerror!void {
    _ = instance;
    // No-op in stub - no actual media loading
}

/// Operation: setMediaKeys
pub fn call_setMediaKeys(instance: *runtime.Instance, mediaKeys: ?*runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    _ = mediaKeys;
    return error.NotImplemented;
}

/// Operation: pause
/// Per HTML spec: Pauses the media resource.
/// Stub: No-op (already paused)
pub fn call_pause(instance: *runtime.Instance) anyerror!void {
    _ = instance;
    // No-op - already paused in stub implementation
}

/// Operation: canPlayType
/// Per HTML spec: Returns how confident the user agent is it can play the given type.
/// Stub: Returns empty string ("" - cannot play anything)
pub fn call_canPlayType(instance: *runtime.Instance, @"type": runtime.DOMString) anyerror!enums.CanPlayTypeResult {
    _ = instance;
    _ = @"type";
    return .__; // Empty string = cannot play
}

/// Operation: fastSeek
pub fn call_fastSeek(instance: *runtime.Instance, time: f64) anyerror!void {
    _ = instance;
    _ = time;
    return error.NotImplemented;
}

/// Operation: captureStream
pub fn call_captureStream(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: play
/// Per HTML spec: Starts playback of the media resource.
/// Returns a Promise that resolves when playback starts successfully.
///
/// For WPT infrastructure tests (e.g., allowed-to-play.html), this Promise
/// resolves immediately since we don't actually play media - there's nothing
/// to wait for. Real media playback would involve loading, buffering, etc.
pub fn call_play(instance: *runtime.Instance) anyerror!runtime.JSValue {
    // Get the engine interface and context for Promise creation
    const engine = instance.ctx.engine orelse {
        // No engine available - return undefined as fallback
        return runtime.JSValue.jsUndefined;
    };
    const engine_ctx = instance.ctx.engine_ctx orelse {
        return runtime.JSValue.jsUndefined;
    };

    // Create a Promise through the engine abstraction
    const allocator = instance.ctx.allocator;
    const promise_handle = engine.createPromise(engine_ctx, allocator) catch {
        return runtime.JSValue.jsUndefined;
    };

    // Resolve the promise immediately with undefined (null = undefined in V8)
    // Per HTML spec, play() returns a Promise that resolves when playback starts.
    // Since we don't actually play media, we resolve immediately.
    engine.resolvePromise(engine_ctx, promise_handle, null) catch {
        // If resolve fails, still return the promise (it will be pending forever)
    };

    // Get the JS Promise object
    const promise_ptr = engine.getPromiseObject(promise_handle);

    // Clean up the handle (Promise object is still valid, managed by GC)
    if (engine.destroyPromiseHandle) |destroy_fn| {
        destroy_fn(promise_handle, allocator);
    }

    return runtime.JSValue.fromPromise(promise_ptr);
}

/// Operation: getStartDate
pub fn call_getStartDate(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: addTextTrack
pub fn call_addTextTrack(instance: *runtime.Instance, kind: enums.TextTrackKind, label: webidl.Opt(runtime.DOMString), language: webidl.Opt(runtime.DOMString)) anyerror!*runtime.Instance {
    _ = instance;
    _ = kind;
    _ = label;
    _ = language;
    return error.NotImplemented;
}
