//! Generated from: html.idl
//! Generated at: 2025-11-28T19:51:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HTMLMediaElementImpl = @import("impls").HTMLMediaElement;
const mixins = @import("mixins");
const HTMLElement = @import("interfaces").HTMLElement;
const DOMStringMap = @import("interfaces").DOMStringMap;
const TextTrackKind = @import("enums").TextTrackKind;
const CSSOMString = @import("typedefs").CSSOMString;
const HTMLCollection = @import("interfaces").HTMLCollection;
const TogglePopoverOptions = @import("dictionaries").TogglePopoverOptions;
const DOMPointInit = @import("dictionaries").DOMPointInit;
const GeometryNode = @import("typedefs").GeometryNode;
const NamedNodeMap = @import("interfaces").NamedNodeMap;
const CSSStyleDeclaration = @import("interfaces").CSSStyleDeclaration;
const USVString = @import("interfaces").USVString;
const TrustedType = @import("typedefs").TrustedType;
const Element = @import("interfaces").Element;
const CheckVisibilityOptions = @import("dictionaries").CheckVisibilityOptions;
const ScrollIntoViewOptions = @import("dictionaries").ScrollIntoViewOptions;
const BoxQuadOptions = @import("dictionaries").BoxQuadOptions;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const FocusableAreasOption = @import("dictionaries").FocusableAreasOption;
const EventListener = @import("interfaces").EventListener;
const CSSStyleProperties = @import("interfaces").CSSStyleProperties;
const CSSPseudoElement = @import("interfaces").CSSPseudoElement;
const ShowPopoverOptions = @import("dictionaries").ShowPopoverOptions;
const ViewTransitionUpdateCallback = @import("callbacks").ViewTransitionUpdateCallback;
const MediaProvider = @import("typedefs").MediaProvider;
const CanPlayTypeResult = @import("enums").CanPlayTypeResult;
const Node = @import("interfaces").Node;
const TextTrackList = @import("interfaces").TextTrackList;
const TimeRanges = @import("interfaces").TimeRanges;
const CustomElementRegistry = @import("interfaces").CustomElementRegistry;
const Animation = @import("interfaces").Animation;
const Range = @import("interfaces").Range;
const Event = @import("interfaces").Event;
const FocusOptions = @import("dictionaries").FocusOptions;
const DOMRectList = @import("interfaces").DOMRectList;
const KeyframeAnimationOptions = @import("dictionaries").KeyframeAnimationOptions;
const Document = @import("interfaces").Document;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const GetHTMLOptions = @import("dictionaries").GetHTMLOptions;
const DOMString = @import("typedefs").DOMString;
const ScrollToOptions = @import("dictionaries").ScrollToOptions;
const HTMLSlotElement = @import("interfaces").HTMLSlotElement;
const DOMQuad = @import("interfaces").DOMQuad;
const DOMRectReadOnly = @import("interfaces").DOMRectReadOnly;
const OnErrorEventHandler = @import("typedefs").OnErrorEventHandler;
const StylePropertyMapReadOnly = @import("interfaces").StylePropertyMapReadOnly;
const DOMTokenList = @import("interfaces").DOMTokenList;
const StartViewTransitionOptions = @import("dictionaries").StartViewTransitionOptions;
const EditContext = @import("interfaces").EditContext;
const DOMRect = @import("interfaces").DOMRect;
const ElementInternals = @import("interfaces").ElementInternals;
const MediaStream = @import("interfaces").MediaStream;
const ViewTransition = @import("interfaces").ViewTransition;
const VideoTrackList = @import("interfaces").VideoTrackList;
const SpatialNavigationSearchOptions = @import("dictionaries").SpatialNavigationSearchOptions;
const GetAnimationsOptions = @import("dictionaries").GetAnimationsOptions;
const EventHandler = @import("typedefs").EventHandler;
const ConvertCoordinateOptions = @import("dictionaries").ConvertCoordinateOptions;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const RemotePlayback = @import("interfaces").RemotePlayback;
const MediaKeys = @import("interfaces").MediaKeys;
const AudioTrackList = @import("interfaces").AudioTrackList;
const SpatialNavigationDirection = @import("enums").SpatialNavigationDirection;
const StylePropertyMap = @import("interfaces").StylePropertyMap;
const ShadowRoot = @import("interfaces").ShadowRoot;
const Attr = @import("interfaces").Attr;
const TrustedHTML = @import("interfaces").TrustedHTML;
const DOMQuadInit = @import("dictionaries").DOMQuadInit;
const NodeList = @import("interfaces").NodeList;
const FullscreenOptions = @import("dictionaries").FullscreenOptions;
const Observable = @import("interfaces").Observable;
const DOMPoint = @import("interfaces").DOMPoint;
const TextTrack = @import("interfaces").TextTrack;
const PointerLockOptions = @import("dictionaries").PointerLockOptions;
const GetRootNodeOptions = @import("dictionaries").GetRootNodeOptions;
const ShadowRootInit = @import("dictionaries").ShadowRootInit;
const MediaError = @import("interfaces").MediaError;

pub const HTMLMediaElement = struct {
    pub const Meta = struct {
        pub const name = "HTMLMediaElement";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *HTMLElement;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "error", "get_error", null },
            .{ "src", "get_src", "set_src" },
            .{ "srcObject", "get_srcObject", "set_srcObject" },
            .{ "currentSrc", "get_currentSrc", null },
            .{ "crossOrigin", "get_crossOrigin", "set_crossOrigin" },
            .{ "networkState", "get_networkState", null },
            .{ "preload", "get_preload", "set_preload" },
            .{ "buffered", "get_buffered", null },
            .{ "readyState", "get_readyState", null },
            .{ "seeking", "get_seeking", null },
            .{ "currentTime", "get_currentTime", "set_currentTime" },
            .{ "duration", "get_duration", null },
            .{ "paused", "get_paused", null },
            .{ "defaultPlaybackRate", "get_defaultPlaybackRate", "set_defaultPlaybackRate" },
            .{ "playbackRate", "get_playbackRate", "set_playbackRate" },
            .{ "preservesPitch", "get_preservesPitch", "set_preservesPitch" },
            .{ "played", "get_played", null },
            .{ "seekable", "get_seekable", null },
            .{ "ended", "get_ended", null },
            .{ "autoplay", "get_autoplay", "set_autoplay" },
            .{ "loop", "get_loop", "set_loop" },
            .{ "controls", "get_controls", "set_controls" },
            .{ "volume", "get_volume", "set_volume" },
            .{ "muted", "get_muted", "set_muted" },
            .{ "defaultMuted", "get_defaultMuted", "set_defaultMuted" },
            .{ "audioTracks", "get_audioTracks", null },
            .{ "videoTracks", "get_videoTracks", null },
            .{ "textTracks", "get_textTracks", null },
            .{ "sinkId", "get_sinkId", null },
            .{ "remote", "get_remote", null },
            .{ "disableRemotePlayback", "get_disableRemotePlayback", "set_disableRemotePlayback" },
            .{ "mediaKeys", "get_mediaKeys", null },
            .{ "onencrypted", "get_onencrypted", "set_onencrypted" },
            .{ "onwaitingforkey", "get_onwaitingforkey", "set_onwaitingforkey" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "load", "call_load", 0 },
            .{ "canPlayType", "call_canPlayType", 1 },
            .{ "fastSeek", "call_fastSeek", 1 },
            .{ "getStartDate", "call_getStartDate", 0 },
            .{ "play", "call_play", 0 },
            .{ "pause", "call_pause", 0 },
            .{ "addTextTrack", "call_addTextTrack", 1 },
            .{ "setSinkId", "call_setSinkId", 1 },
            .{ "setMediaKeys", "call_setMediaKeys", 1 },
            .{ "captureStream", "call_captureStream", 0 },
        };
        
        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "NETWORK_EMPTY", "get_NETWORK_EMPTY" },
            .{ "NETWORK_IDLE", "get_NETWORK_IDLE" },
            .{ "NETWORK_LOADING", "get_NETWORK_LOADING" },
            .{ "NETWORK_NO_SOURCE", "get_NETWORK_NO_SOURCE" },
            .{ "HAVE_NOTHING", "get_HAVE_NOTHING" },
            .{ "HAVE_METADATA", "get_HAVE_METADATA" },
            .{ "HAVE_CURRENT_DATA", "get_HAVE_CURRENT_DATA" },
            .{ "HAVE_FUTURE_DATA", "get_HAVE_FUTURE_DATA" },
            .{ "HAVE_ENOUGH_DATA", "get_HAVE_ENOUGH_DATA" },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "load",
            "canPlayType",
            "fastSeek",
            "getStartDate",
            "play",
            "pause",
            "addTextTrack",
            "setSinkId",
            "setMediaKeys",
            "captureStream",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
            "getRootNode",
            "hasChildNodes",
            "normalize",
            "cloneNode",
            "isEqualNode",
            "isSameNode",
            "compareDocumentPosition",
            "contains",
            "lookupPrefix",
            "lookupNamespaceURI",
            "isDefaultNamespace",
            "insertBefore",
            "appendChild",
            "replaceChild",
            "removeChild",
            "hasAttributes",
            "getAttributeNames",
            "getAttribute",
            "getAttributeNS",
            "setAttribute",
            "setAttributeNS",
            "removeAttribute",
            "removeAttributeNS",
            "toggleAttribute",
            "hasAttribute",
            "hasAttributeNS",
            "getAttributeNode",
            "getAttributeNodeNS",
            "setAttributeNode",
            "setAttributeNodeNS",
            "removeAttributeNode",
            "attachShadow",
            "closest",
            "matches",
            "webkitMatchesSelector",
            "getElementsByTagName",
            "getElementsByTagNameNS",
            "getElementsByClassName",
            "insertAdjacentElement",
            "insertAdjacentText",
            "getSpatialNavigationContainer",
            "focusableAreas",
            "spatialNavigationSearch",
            "requestFullscreen",
            "requestPointerLock",
            "setPointerCapture",
            "releasePointerCapture",
            "hasPointerCapture",
            "computedStyleMap",
            "pseudo",
            "startViewTransition",
            "setHTMLUnsafe",
            "getHTML",
            "insertAdjacentHTML",
            "getClientRects",
            "getBoundingClientRect",
            "checkVisibility",
            "scrollIntoView",
            "scroll",
            "scroll",
            "scrollTo",
            "scrollTo",
            "scrollBy",
            "scrollBy",
            "animate",
            "getAnimations",
            "getRegionFlowRanges",
            "prepend",
            "append",
            "replaceChildren",
            "moveBefore",
            "querySelector",
            "querySelectorAll",
            "before",
            "after",
            "replaceWith",
            "remove",
            "getBoxQuads",
            "convertQuadFromNode",
            "convertRectFromNode",
            "convertPointFromNode",
            "click",
            "attachInternals",
            "showPopover",
            "hidePopover",
            "togglePopover",
            "focus",
            "blur",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "error", "get_error", null },
            .{ "src", "get_src", "set_src" },
            .{ "srcObject", "get_srcObject", "set_srcObject" },
            .{ "currentSrc", "get_currentSrc", null },
            .{ "crossOrigin", "get_crossOrigin", "set_crossOrigin" },
            .{ "networkState", "get_networkState", null },
            .{ "preload", "get_preload", "set_preload" },
            .{ "buffered", "get_buffered", null },
            .{ "readyState", "get_readyState", null },
            .{ "seeking", "get_seeking", null },
            .{ "currentTime", "get_currentTime", "set_currentTime" },
            .{ "duration", "get_duration", null },
            .{ "paused", "get_paused", null },
            .{ "defaultPlaybackRate", "get_defaultPlaybackRate", "set_defaultPlaybackRate" },
            .{ "playbackRate", "get_playbackRate", "set_playbackRate" },
            .{ "preservesPitch", "get_preservesPitch", "set_preservesPitch" },
            .{ "played", "get_played", null },
            .{ "seekable", "get_seekable", null },
            .{ "ended", "get_ended", null },
            .{ "autoplay", "get_autoplay", "set_autoplay" },
            .{ "loop", "get_loop", "set_loop" },
            .{ "controls", "get_controls", "set_controls" },
            .{ "volume", "get_volume", "set_volume" },
            .{ "muted", "get_muted", "set_muted" },
            .{ "defaultMuted", "get_defaultMuted", "set_defaultMuted" },
            .{ "audioTracks", "get_audioTracks", null },
            .{ "videoTracks", "get_videoTracks", null },
            .{ "textTracks", "get_textTracks", null },
            .{ "sinkId", "get_sinkId", null },
            .{ "remote", "get_remote", null },
            .{ "disableRemotePlayback", "get_disableRemotePlayback", "set_disableRemotePlayback" },
            .{ "mediaKeys", "get_mediaKeys", null },
            .{ "onencrypted", "get_onencrypted", "set_onencrypted" },
            .{ "onwaitingforkey", "get_onwaitingforkey", "set_onwaitingforkey" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            @"error": ?*runtime.Instance = null,
            src: runtime.USVString = undefined,
            srcObject: ?MediaProvider = null,
            currentSrc: runtime.USVString = undefined,
            crossOrigin: ?runtime.DOMString = null,
            networkState: u16 = undefined,
            preload: runtime.DOMString = undefined,
            buffered: *runtime.Instance = undefined,
            readyState: u16 = undefined,
            seeking: bool = undefined,
            currentTime: f64 = undefined,
            duration: f64 = undefined,
            paused: bool = undefined,
            defaultPlaybackRate: f64 = undefined,
            playbackRate: f64 = undefined,
            preservesPitch: bool = undefined,
            played: *runtime.Instance = undefined,
            seekable: *runtime.Instance = undefined,
            ended: bool = undefined,
            autoplay: bool = undefined,
            loop: bool = undefined,
            controls: bool = undefined,
            volume: f64 = undefined,
            muted: bool = undefined,
            defaultMuted: bool = undefined,
            audioTracks: *runtime.Instance = undefined,
            videoTracks: *runtime.Instance = undefined,
            textTracks: *runtime.Instance = undefined,
            sinkId: runtime.DOMString = undefined,
            remote: *runtime.Instance = undefined,
            disableRemotePlayback: bool = undefined,
            mediaKeys: ?*runtime.Instance = null,
            onencrypted: EventHandler = undefined,
            onwaitingforkey: EventHandler = undefined,
            cached_audioTracks: ?*runtime.Instance = null,
            cached_videoTracks: ?*runtime.Instance = null,
            cached_textTracks: ?*runtime.Instance = null,
            cached_remote: ?*runtime.Instance = null,
            _internal: ?*HTMLMediaElementImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned short NETWORK_EMPTY = 0;
    pub fn get_NETWORK_EMPTY() u16 {
        return 0;
    }

    /// WebIDL constant: const unsigned short NETWORK_IDLE = 1;
    pub fn get_NETWORK_IDLE() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short NETWORK_LOADING = 2;
    pub fn get_NETWORK_LOADING() u16 {
        return 2;
    }

    /// WebIDL constant: const unsigned short NETWORK_NO_SOURCE = 3;
    pub fn get_NETWORK_NO_SOURCE() u16 {
        return 3;
    }

    /// WebIDL constant: const unsigned short HAVE_NOTHING = 0;
    pub fn get_HAVE_NOTHING() u16 {
        return 0;
    }

    /// WebIDL constant: const unsigned short HAVE_METADATA = 1;
    pub fn get_HAVE_METADATA() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short HAVE_CURRENT_DATA = 2;
    pub fn get_HAVE_CURRENT_DATA() u16 {
        return 2;
    }

    /// WebIDL constant: const unsigned short HAVE_FUTURE_DATA = 3;
    pub fn get_HAVE_FUTURE_DATA() u16 {
        return 3;
    }

    /// WebIDL constant: const unsigned short HAVE_ENOUGH_DATA = 4;
    pub fn get_HAVE_ENOUGH_DATA() u16 {
        return 4;
    }

    const delegates = .{

        .get_HAVE_CURRENT_DATA = &get_HAVE_CURRENT_DATA,
        .get_HAVE_ENOUGH_DATA = &get_HAVE_ENOUGH_DATA,
        .get_HAVE_FUTURE_DATA = &get_HAVE_FUTURE_DATA,
        .get_HAVE_METADATA = &get_HAVE_METADATA,
        .get_HAVE_NOTHING = &get_HAVE_NOTHING,
        .get_NETWORK_EMPTY = &get_NETWORK_EMPTY,
        .get_NETWORK_IDLE = &get_NETWORK_IDLE,
        .get_NETWORK_LOADING = &get_NETWORK_LOADING,
        .get_NETWORK_NO_SOURCE = &get_NETWORK_NO_SOURCE,
        .get_audioTracks = &get_audioTracks,
        .get_autoplay = &get_autoplay,
        .get_buffered = &get_buffered,
        .get_controls = &get_controls,
        .get_crossOrigin = &get_crossOrigin,
        .get_currentSrc = &get_currentSrc,
        .get_currentTime = &get_currentTime,
        .get_defaultMuted = &get_defaultMuted,
        .get_defaultPlaybackRate = &get_defaultPlaybackRate,
        .get_disableRemotePlayback = &get_disableRemotePlayback,
        .get_duration = &get_duration,
        .get_ended = &get_ended,
        .get_error = &get_error,
        .get_loop = &get_loop,
        .get_mediaKeys = &get_mediaKeys,
        .get_muted = &get_muted,
        .get_networkState = &get_networkState,
        .get_onencrypted = &get_onencrypted,
        .get_onwaitingforkey = &get_onwaitingforkey,
        .get_paused = &get_paused,
        .get_playbackRate = &get_playbackRate,
        .get_played = &get_played,
        .get_preload = &get_preload,
        .get_preservesPitch = &get_preservesPitch,
        .get_readyState = &get_readyState,
        .get_remote = &get_remote,
        .get_seekable = &get_seekable,
        .get_seeking = &get_seeking,
        .get_sinkId = &get_sinkId,
        .get_src = &get_src,
        .get_srcObject = &get_srcObject,
        .get_textTracks = &get_textTracks,
        .get_videoTracks = &get_videoTracks,
        .get_volume = &get_volume,

        .set_autoplay = &set_autoplay,
        .set_controls = &set_controls,
        .set_crossOrigin = &set_crossOrigin,
        .set_currentTime = &set_currentTime,
        .set_defaultMuted = &set_defaultMuted,
        .set_defaultPlaybackRate = &set_defaultPlaybackRate,
        .set_disableRemotePlayback = &set_disableRemotePlayback,
        .set_loop = &set_loop,
        .set_muted = &set_muted,
        .set_onencrypted = &set_onencrypted,
        .set_onwaitingforkey = &set_onwaitingforkey,
        .set_playbackRate = &set_playbackRate,
        .set_preload = &set_preload,
        .set_preservesPitch = &set_preservesPitch,
        .set_src = &set_src,
        .set_srcObject = &set_srcObject,
        .set_volume = &set_volume,

        .call_addTextTrack = &call_addTextTrack,
        .call_canPlayType = &call_canPlayType,
        .call_captureStream = &call_captureStream,
        .call_fastSeek = &call_fastSeek,
        .call_getStartDate = &call_getStartDate,
        .call_load = &call_load,
        .call_pause = &call_pause,
        .call_play = &call_play,
        .call_setMediaKeys = &call_setMediaKeys,
        .call_setSinkId = &call_setSinkId,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return HTMLMediaElementImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HTMLMediaElementImpl.deinit(instance);
    }

    pub fn get_error(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try HTMLMediaElementImpl.get_error(instance);
    }

    /// Extended attributes: [CEReactions], [ReflectURL]
    pub fn get_src(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HTMLMediaElementImpl.get_src(instance);
    }

    /// Extended attributes: [CEReactions], [ReflectURL]
    pub fn set_src(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLMediaElementImpl.set_src(instance, value);
    }

    pub fn get_srcObject(instance: *runtime.Instance) anyerror!?MediaProvider {
        return try HTMLMediaElementImpl.get_srcObject(instance);
    }

    pub fn set_srcObject(instance: *runtime.Instance, value: MediaProvider) anyerror!void {
        try HTMLMediaElementImpl.set_srcObject(instance, value);
    }

    pub fn get_currentSrc(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HTMLMediaElementImpl.get_currentSrc(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_crossOrigin(instance: *runtime.Instance) anyerror!?DOMString {
        return try HTMLMediaElementImpl.get_crossOrigin(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_crossOrigin(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLMediaElementImpl.set_crossOrigin(instance, value);
    }

    pub fn get_networkState(instance: *runtime.Instance) anyerror!u16 {
        return try HTMLMediaElementImpl.get_networkState(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_preload(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLMediaElementImpl.get_preload(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_preload(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLMediaElementImpl.set_preload(instance, value);
    }

    pub fn get_buffered(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try HTMLMediaElementImpl.get_buffered(instance);
    }

    pub fn get_readyState(instance: *runtime.Instance) anyerror!u16 {
        return try HTMLMediaElementImpl.get_readyState(instance);
    }

    pub fn get_seeking(instance: *runtime.Instance) anyerror!bool {
        return try HTMLMediaElementImpl.get_seeking(instance);
    }

    pub fn get_currentTime(instance: *runtime.Instance) anyerror!f64 {
        return try HTMLMediaElementImpl.get_currentTime(instance);
    }

    pub fn set_currentTime(instance: *runtime.Instance, value: f64) anyerror!void {
        try HTMLMediaElementImpl.set_currentTime(instance, value);
    }

    pub fn get_duration(instance: *runtime.Instance) anyerror!f64 {
        return try HTMLMediaElementImpl.get_duration(instance);
    }

    pub fn get_paused(instance: *runtime.Instance) anyerror!bool {
        return try HTMLMediaElementImpl.get_paused(instance);
    }

    pub fn get_defaultPlaybackRate(instance: *runtime.Instance) anyerror!f64 {
        return try HTMLMediaElementImpl.get_defaultPlaybackRate(instance);
    }

    pub fn set_defaultPlaybackRate(instance: *runtime.Instance, value: f64) anyerror!void {
        try HTMLMediaElementImpl.set_defaultPlaybackRate(instance, value);
    }

    pub fn get_playbackRate(instance: *runtime.Instance) anyerror!f64 {
        return try HTMLMediaElementImpl.get_playbackRate(instance);
    }

    pub fn set_playbackRate(instance: *runtime.Instance, value: f64) anyerror!void {
        try HTMLMediaElementImpl.set_playbackRate(instance, value);
    }

    pub fn get_preservesPitch(instance: *runtime.Instance) anyerror!bool {
        return try HTMLMediaElementImpl.get_preservesPitch(instance);
    }

    pub fn set_preservesPitch(instance: *runtime.Instance, value: bool) anyerror!void {
        try HTMLMediaElementImpl.set_preservesPitch(instance, value);
    }

    pub fn get_played(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try HTMLMediaElementImpl.get_played(instance);
    }

    pub fn get_seekable(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try HTMLMediaElementImpl.get_seekable(instance);
    }

    pub fn get_ended(instance: *runtime.Instance) anyerror!bool {
        return try HTMLMediaElementImpl.get_ended(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_autoplay(instance: *runtime.Instance) anyerror!bool {
        return try HTMLMediaElementImpl.get_autoplay(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_autoplay(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLMediaElementImpl.set_autoplay(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_loop(instance: *runtime.Instance) anyerror!bool {
        return try HTMLMediaElementImpl.get_loop(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_loop(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLMediaElementImpl.set_loop(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_controls(instance: *runtime.Instance) anyerror!bool {
        return try HTMLMediaElementImpl.get_controls(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_controls(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLMediaElementImpl.set_controls(instance, value);
    }

    pub fn get_volume(instance: *runtime.Instance) anyerror!f64 {
        return try HTMLMediaElementImpl.get_volume(instance);
    }

    pub fn set_volume(instance: *runtime.Instance, value: f64) anyerror!void {
        try HTMLMediaElementImpl.set_volume(instance, value);
    }

    pub fn get_muted(instance: *runtime.Instance) anyerror!bool {
        return try HTMLMediaElementImpl.get_muted(instance);
    }

    pub fn set_muted(instance: *runtime.Instance, value: bool) anyerror!void {
        try HTMLMediaElementImpl.set_muted(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="muted"]
    pub fn get_defaultMuted(instance: *runtime.Instance) anyerror!bool {
        return try HTMLMediaElementImpl.get_defaultMuted(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="muted"]
    pub fn set_defaultMuted(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLMediaElementImpl.set_defaultMuted(instance, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_audioTracks(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_audioTracks) |cached| {
            return cached;
        }
        const value = try HTMLMediaElementImpl.get_audioTracks(instance);
        state.own.cached_audioTracks = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_videoTracks(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_videoTracks) |cached| {
            return cached;
        }
        const value = try HTMLMediaElementImpl.get_videoTracks(instance);
        state.own.cached_videoTracks = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_textTracks(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_textTracks) |cached| {
            return cached;
        }
        const value = try HTMLMediaElementImpl.get_textTracks(instance);
        state.own.cached_textTracks = value;
        return value;
    }

    /// Extended attributes: [SecureContext]
    pub fn get_sinkId(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLMediaElementImpl.get_sinkId(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_remote(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_remote) |cached| {
            return cached;
        }
        const value = try HTMLMediaElementImpl.get_remote(instance);
        state.own.cached_remote = value;
        return value;
    }

    /// Extended attributes: [CEReactions]
    pub fn get_disableRemotePlayback(instance: *runtime.Instance) anyerror!bool {
        return try HTMLMediaElementImpl.get_disableRemotePlayback(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_disableRemotePlayback(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLMediaElementImpl.set_disableRemotePlayback(instance, value);
    }

    /// Extended attributes: [SecureContext]
    pub fn get_mediaKeys(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try HTMLMediaElementImpl.get_mediaKeys(instance);
    }

    pub fn get_onencrypted(instance: *runtime.Instance) anyerror!EventHandler {
        return try HTMLMediaElementImpl.get_onencrypted(instance);
    }

    pub fn set_onencrypted(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try HTMLMediaElementImpl.set_onencrypted(instance, value);
    }

    pub fn get_onwaitingforkey(instance: *runtime.Instance) anyerror!EventHandler {
        return try HTMLMediaElementImpl.get_onwaitingforkey(instance);
    }

    pub fn set_onwaitingforkey(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try HTMLMediaElementImpl.set_onwaitingforkey(instance, value);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_setSinkId(instance: *runtime.Instance, sinkId: DOMString) anyerror!*const anyopaque {
        
        return try HTMLMediaElementImpl.call_setSinkId(instance, sinkId);
    }

    pub fn call_load(instance: *runtime.Instance) anyerror!void {
        return try HTMLMediaElementImpl.call_load(instance);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_setMediaKeys(instance: *runtime.Instance, mediaKeys: ?*runtime.Instance) anyerror!*const anyopaque {
        
        return try HTMLMediaElementImpl.call_setMediaKeys(instance, mediaKeys);
    }

    pub fn call_pause(instance: *runtime.Instance) anyerror!void {
        return try HTMLMediaElementImpl.call_pause(instance);
    }

    pub fn call_canPlayType(instance: *runtime.Instance, @"type": DOMString) anyerror!CanPlayTypeResult {
        
        return try HTMLMediaElementImpl.call_canPlayType(instance, @"type");
    }

    pub fn call_fastSeek(instance: *runtime.Instance, time: f64) anyerror!void {
        
        return try HTMLMediaElementImpl.call_fastSeek(instance, time);
    }

    pub fn call_captureStream(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try HTMLMediaElementImpl.call_captureStream(instance);
    }

    pub fn call_play(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try HTMLMediaElementImpl.call_play(instance);
    }

    pub fn call_getStartDate(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try HTMLMediaElementImpl.call_getStartDate(instance);
    }

    pub fn call_addTextTrack(instance: *runtime.Instance, kind: TextTrackKind, label: webidl.Opt(DOMString), language: webidl.Opt(DOMString)) anyerror!*runtime.Instance {
        
        return try HTMLMediaElementImpl.call_addTextTrack(instance, kind, label.value, language.value);
    }

};
