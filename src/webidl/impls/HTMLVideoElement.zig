//! Implementation for HTMLVideoElement interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const dom = @import("dom");
const HTMLVideoElement = interfaces.HTMLVideoElement;
const images = dom.style.engine.available_images;

pub const State = HTMLVideoElement.State;

pub const ImplError = error{
    NotImplemented,
};

/// The element's poster frame fetch, made the first time it has a poster
/// (`determinePosterFrame`): a video with none keeps no state.
pub const InternalState = struct {
    poster: ?*images.Loader = null,

    pub fn deinit(self: *InternalState) void {
        const loader = self.poster;
        self.poster = null;
        if (loader) |value| value.destroy();
    }
};
const Registry = runtime.InstanceRegistry(.html_video_element, InternalState);

pub fn installHooks() void {
    // A namespace-wide poster step: "video"'s own element steps are
    // HTMLMediaElement's (its src), which one element entry would replace.
    dom.attribute_change_steps.installForAttribute("http://www.w3.org/1999/xhtml", "poster", .{ .change = &posterChangeSteps });
    dom.orphan_states.installRegistrySweep(Registry);
    dom.document_fetches.install(.{ .discard = discardRealm, .prepare_abort = prepareAbort, .abort = abortDocument });
}

/// The video element's attribute change steps for its poster (any other HTML
/// element's poster attribute means nothing).
fn posterChangeSteps(instance: *runtime.Instance, _: []const u8, _: ?[]const u8, value: ?[]const u8, namespace: ?[]const u8) void {
    if (namespace != null) return;
    const data = dom.element_data.of(instance) orelse return;
    if (!std.mem.eql(u8, data.localName(), "video")) return;
    determinePosterFrame(instance, value);
}

/// HTML 4.8.9: "when the element is created or when the poster attribute is
/// set, changed, or removed, the user agent must run the following steps to
/// determine the element's poster frame (regardless of the value of the
/// element's show poster flag)" - the parser's attributes too, whose change
/// steps run as the element is created (dom.element_attributes.setParsed).
/// A renderer would show the frame; without one the fetch is still made, as
/// all three browsers make it (resource-timing/initiator-type/video.html's
/// "<video poster>": Chrome 157, Firefox 160 and Safari 27.2 pass).
///
/// Step 6, the lazy load resumption steps, not done, stated: Crane's video,
/// img and audio load at once (dom.lazy_load_observer observes iframes only).
fn determinePosterFrame(instance: *runtime.Instance, poster: ?[]const u8) void {
    // 1. "If there is an existing instance of this algorithm running for this
    //    video element, abort that instance of this algorithm without
    //    changing the poster frame."
    const existing = Registry.get(instance);
    if (existing) |internal| if (internal.poster) |loader| loader.cancel();
    // 2. "If the poster attribute's value is the empty string or if the
    //    attribute is absent: ... There is no poster frame; return."
    const value = poster orelse return;
    if (value.len == 0) return;
    const internal = existing orelse blk: {
        const made = Registry.createIn(instance, runtime.arenaOf(instance)) catch return;
        made.* = .{};
        break :blk made;
    };
    if (internal.poster == null) internal.poster = images.Loader.create(instance) catch return;
    // 3-4. Encoding-parse the value relative to the node document; failure is
    //    no poster frame (the loader starts nothing). 5. "A new request whose
    //    URL is url, client is the element's node document's relevant settings
    //    object, destination is "image", initiator type is "video",
    //    credentials mode is "include", and whose use-URL-credentials flag is
    //    set." 7. Fetch it, delaying the node document's load event. 8. An
    //    image obtained is the poster frame; otherwise there is none - and no
    //    event fires either way.
    internal.poster.?.start(value, .{ .initiator = .video, .fire_events = false }) catch {};
}

fn discardRealm(realm: runtime.Context) void {
    var iterator = Registry.iterator(realm.browserScope() orelse return) orelse return;
    while (iterator.next()) |entry| if (entry.internal.poster) |loader| {
        if (loader.realm == realm) loader.cancel();
    };
}

fn prepareAbort(document: *runtime.Instance) bool {
    var iterator = Registry.iterator(runtime.BrowserScope.ofInstance(document)) orelse return false;
    var marked = false;
    while (iterator.next()) |entry| if (entry.internal.poster) |loader| {
        marked = loader.markAbort(document) or marked;
    };
    return marked;
}

fn abortDocument(document: *runtime.Instance) void {
    var iterator = Registry.iterator(runtime.BrowserScope.ofInstance(document)) orelse return;
    while (iterator.next()) |entry| if (entry.internal.poster) |loader| loader.abortMarked(document);
}

/// Initialize instance (creates the instance)
/// Chains to parent class: HTMLElement -> Element -> Node -> EventTarget
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    // Chain through HTMLMediaElement so its load state is initialized.
    const instance = try interfaces.HTMLMediaElement.initWithState(allocator, StateType, vtable, ctx);
    // HTMLVideoElement has no additional initialization
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // The poster frame's fetch, if it had one.
    if (Registry.get(instance)) |internal| internal.deinit();
    Registry.remove(instance);
    // Chain to parent class
    interfaces.HTMLMediaElement.deinit(instance);
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(instance: *runtime.Instance) !void {
    _ = instance;
    // TODO: Implement constructor logic with parameters
}

/// The videoWidth getter steps (HTML 4.8.8):
/// 1. If this's readyState attribute is HAVE_NOTHING, then return 0.
/// 2. Return the natural width of the video in CSS pixels.
pub fn get_videoWidth(instance: *runtime.Instance) anyerror!u32 {
    if (try interfaces.HTMLMediaElement.get_readyState(instance) == interfaces.HTMLMediaElement.get_HAVE_NOTHING()) return 0;
    return dom.media_elements.videoSize(instance).width;
}

/// The videoHeight getter steps (HTML 4.8.8):
/// 1. If this's readyState attribute is HAVE_NOTHING, then return 0.
/// 2. Return the natural height of the video in CSS pixels.
pub fn get_videoHeight(instance: *runtime.Instance) anyerror!u32 {
    if (try interfaces.HTMLMediaElement.get_readyState(instance) == interfaces.HTMLMediaElement.get_HAVE_NOTHING()) return 0;
    return dom.media_elements.videoSize(instance).height;
}

/// Getter for disablePictureInPicture
pub fn get_disablePictureInPicture(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for disablePictureInPicture
pub fn set_disablePictureInPicture(instance: *runtime.Instance, value: bool) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: cancelVideoFrameCallback
pub fn call_cancelVideoFrameCallback(instance: *runtime.Instance, handle: u32) anyerror!void {
    _ = instance;
    _ = handle;
    return error.NotImplemented;
}

/// Operation: requestPictureInPicture
pub fn call_requestPictureInPicture(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: requestVideoFrameCallback
pub fn call_requestVideoFrameCallback(instance: *runtime.Instance, callback: callbacks.VideoFrameRequestCallback) anyerror!u32 {
    _ = instance;
    _ = callback;
    return error.NotImplemented;
}

/// Operation: getVideoPlaybackQuality
pub fn call_getVideoPlaybackQuality(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}
