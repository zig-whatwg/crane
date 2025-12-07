//! Generated from: html.idl
//! Generated at: 2025-12-07T20:02:42Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const HTMLVideoElementImpl = @import("impls").HTMLVideoElement;
const mixins = @import("mixins");
const HTMLMediaElement = @import("interfaces").HTMLMediaElement;
const DOMStringMap = @import("interfaces").DOMStringMap;
const CSSOMString = @import("typedefs").CSSOMString;
const HTMLCollection = @import("interfaces").HTMLCollection;
const TogglePopoverOptions = @import("dictionaries").TogglePopoverOptions;
const TextTrackKind = @import("enums").TextTrackKind;
const DOMPointInit = @import("dictionaries").DOMPointInit;
const GeometryNode = @import("typedefs").GeometryNode;
const NamedNodeMap = @import("interfaces").NamedNodeMap;
const CSSStyleDeclaration = @import("interfaces").CSSStyleDeclaration;
const VideoFrameRequestCallback = @import("callbacks").VideoFrameRequestCallback;
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
const Node = @import("interfaces").Node;
const CustomElementRegistry = @import("interfaces").CustomElementRegistry;
const Animation = @import("interfaces").Animation;
const Range = @import("interfaces").Range;
const Event = @import("interfaces").Event;
const FocusOptions = @import("dictionaries").FocusOptions;
const MediaProvider = @import("typedefs").MediaProvider;
const TimeRanges = @import("interfaces").TimeRanges;
const CanPlayTypeResult = @import("enums").CanPlayTypeResult;
const TextTrackList = @import("interfaces").TextTrackList;
const DOMRectList = @import("interfaces").DOMRectList;
const DOMString = @import("typedefs").DOMString;
const Document = @import("interfaces").Document;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const GetHTMLOptions = @import("dictionaries").GetHTMLOptions;
const OnErrorEventHandler = @import("typedefs").OnErrorEventHandler;
const ScrollToOptions = @import("dictionaries").ScrollToOptions;
const HTMLSlotElement = @import("interfaces").HTMLSlotElement;
const DOMQuad = @import("interfaces").DOMQuad;
const DOMRectReadOnly = @import("interfaces").DOMRectReadOnly;
const KeyframeAnimationOptions = @import("dictionaries").KeyframeAnimationOptions;
const StylePropertyMapReadOnly = @import("interfaces").StylePropertyMapReadOnly;
const DOMTokenList = @import("interfaces").DOMTokenList;
const StartViewTransitionOptions = @import("dictionaries").StartViewTransitionOptions;
const EditContext = @import("interfaces").EditContext;
const PictureInPictureWindow = @import("interfaces").PictureInPictureWindow;
const DOMRect = @import("interfaces").DOMRect;
const ElementInternals = @import("interfaces").ElementInternals;
const ViewTransition = @import("interfaces").ViewTransition;
const MediaStream = @import("interfaces").MediaStream;
const VideoTrackList = @import("interfaces").VideoTrackList;
const VideoPlaybackQuality = @import("interfaces").VideoPlaybackQuality;
const SpatialNavigationSearchOptions = @import("dictionaries").SpatialNavigationSearchOptions;
const EventHandler = @import("typedefs").EventHandler;
const GetAnimationsOptions = @import("dictionaries").GetAnimationsOptions;
const ConvertCoordinateOptions = @import("dictionaries").ConvertCoordinateOptions;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const SpatialNavigationDirection = @import("enums").SpatialNavigationDirection;
const StylePropertyMap = @import("interfaces").StylePropertyMap;
const ShadowRoot = @import("interfaces").ShadowRoot;
const Attr = @import("interfaces").Attr;
const TrustedHTML = @import("interfaces").TrustedHTML;
const DOMQuadInit = @import("dictionaries").DOMQuadInit;
const NodeList = @import("interfaces").NodeList;
const FullscreenOptions = @import("dictionaries").FullscreenOptions;
const AudioTrackList = @import("interfaces").AudioTrackList;
const RemotePlayback = @import("interfaces").RemotePlayback;
const Observable = @import("interfaces").Observable;
const DOMPoint = @import("interfaces").DOMPoint;
const MediaKeys = @import("interfaces").MediaKeys;
const TextTrack = @import("interfaces").TextTrack;
const PointerLockOptions = @import("dictionaries").PointerLockOptions;
const GetRootNodeOptions = @import("dictionaries").GetRootNodeOptions;
const ShadowRootInit = @import("dictionaries").ShadowRootInit;
const MediaError = @import("interfaces").MediaError;

pub const HTMLVideoElement = struct {
    pub const Meta = struct {
        pub const name = "HTMLVideoElement";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = HTMLMediaElement.State;
        pub const ParentInterface = HTMLMediaElement;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "width", "get_width", "set_width" },
            .{ "height", "get_height", "set_height" },
            .{ "videoWidth", "get_videoWidth", null },
            .{ "videoHeight", "get_videoHeight", null },
            .{ "poster", "get_poster", "set_poster" },
            .{ "playsInline", "get_playsInline", "set_playsInline" },
            .{ "onenterpictureinpicture", "get_onenterpictureinpicture", "set_onenterpictureinpicture" },
            .{ "onleavepictureinpicture", "get_onleavepictureinpicture", "set_onleavepictureinpicture" },
            .{ "disablePictureInPicture", "get_disablePictureInPicture", "set_disablePictureInPicture" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "requestPictureInPicture", "call_requestPictureInPicture", 0 },
            .{ "requestVideoFrameCallback", "call_requestVideoFrameCallback", 1 },
            .{ "cancelVideoFrameCallback", "call_cancelVideoFrameCallback", 1 },
            .{ "getVideoPlaybackQuality", "call_getVideoPlaybackQuality", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "requestPictureInPicture",
            "requestVideoFrameCallback",
            "cancelVideoFrameCallback",
            "getVideoPlaybackQuality",
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
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "width", "get_width", "set_width" },
            .{ "height", "get_height", "set_height" },
            .{ "videoWidth", "get_videoWidth", null },
            .{ "videoHeight", "get_videoHeight", null },
            .{ "poster", "get_poster", "set_poster" },
            .{ "playsInline", "get_playsInline", "set_playsInline" },
            .{ "onenterpictureinpicture", "get_onenterpictureinpicture", "set_onenterpictureinpicture" },
            .{ "onleavepictureinpicture", "get_onleavepictureinpicture", "set_onleavepictureinpicture" },
            .{ "disablePictureInPicture", "get_disablePictureInPicture", "set_disablePictureInPicture" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            width: u32 = undefined,
            height: u32 = undefined,
            videoWidth: u32 = undefined,
            videoHeight: u32 = undefined,
            poster: runtime.USVString = undefined,
            playsInline: bool = undefined,
            onenterpictureinpicture: EventHandler = undefined,
            onleavepictureinpicture: EventHandler = undefined,
            disablePictureInPicture: bool = undefined,
            _internal: ?*HTMLVideoElementImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_disablePictureInPicture = &get_disablePictureInPicture,
        .get_height = &get_height,
        .get_onenterpictureinpicture = &get_onenterpictureinpicture,
        .get_onleavepictureinpicture = &get_onleavepictureinpicture,
        .get_playsInline = &get_playsInline,
        .get_poster = &get_poster,
        .get_videoHeight = &get_videoHeight,
        .get_videoWidth = &get_videoWidth,
        .get_width = &get_width,

        .set_disablePictureInPicture = &set_disablePictureInPicture,
        .set_height = &set_height,
        .set_onenterpictureinpicture = &set_onenterpictureinpicture,
        .set_onleavepictureinpicture = &set_onleavepictureinpicture,
        .set_playsInline = &set_playsInline,
        .set_poster = &set_poster,
        .set_width = &set_width,

        .call_cancelVideoFrameCallback = &call_cancelVideoFrameCallback,
        .call_getVideoPlaybackQuality = &call_getVideoPlaybackQuality,
        .call_requestPictureInPicture = &call_requestPictureInPicture,
        .call_requestVideoFrameCallback = &call_requestVideoFrameCallback,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return HTMLVideoElementImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HTMLVideoElementImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try HTMLVideoElementImpl.call_constructor(allocator, ctx);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_width(instance: *runtime.Instance) anyerror!u32 {
        return try HTMLVideoElementImpl.get_width(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_width(instance: *runtime.Instance, value: u32) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLVideoElementImpl.set_width(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_height(instance: *runtime.Instance) anyerror!u32 {
        return try HTMLVideoElementImpl.get_height(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_height(instance: *runtime.Instance, value: u32) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLVideoElementImpl.set_height(instance, value);
    }

    pub fn get_videoWidth(instance: *runtime.Instance) anyerror!u32 {
        return try HTMLVideoElementImpl.get_videoWidth(instance);
    }

    pub fn get_videoHeight(instance: *runtime.Instance) anyerror!u32 {
        return try HTMLVideoElementImpl.get_videoHeight(instance);
    }

    /// Extended attributes: [CEReactions], [ReflectURL]
    pub fn get_poster(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HTMLVideoElementImpl.get_poster(instance);
    }

    /// Extended attributes: [CEReactions], [ReflectURL]
    pub fn set_poster(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLVideoElementImpl.set_poster(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_playsInline(instance: *runtime.Instance) anyerror!bool {
        return try HTMLVideoElementImpl.get_playsInline(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_playsInline(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLVideoElementImpl.set_playsInline(instance, value);
    }

    pub fn get_onenterpictureinpicture(instance: *runtime.Instance) anyerror!EventHandler {
        return try HTMLVideoElementImpl.get_onenterpictureinpicture(instance);
    }

    pub fn set_onenterpictureinpicture(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try HTMLVideoElementImpl.set_onenterpictureinpicture(instance, value);
    }

    pub fn get_onleavepictureinpicture(instance: *runtime.Instance) anyerror!EventHandler {
        return try HTMLVideoElementImpl.get_onleavepictureinpicture(instance);
    }

    pub fn set_onleavepictureinpicture(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try HTMLVideoElementImpl.set_onleavepictureinpicture(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_disablePictureInPicture(instance: *runtime.Instance) anyerror!bool {
        return try HTMLVideoElementImpl.get_disablePictureInPicture(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_disablePictureInPicture(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLVideoElementImpl.set_disablePictureInPicture(instance, value);
    }

    pub fn call_cancelVideoFrameCallback(instance: *runtime.Instance, handle: u32) anyerror!void {
        
        return try HTMLVideoElementImpl.call_cancelVideoFrameCallback(instance, handle);
    }

    /// Extended attributes: [NewObject]
    pub fn call_requestPictureInPicture(instance: *runtime.Instance) anyerror!*const anyopaque {
        // [NewObject] - Caller owns the returned object
        return try HTMLVideoElementImpl.call_requestPictureInPicture(instance);
    }

    pub fn call_requestVideoFrameCallback(instance: *runtime.Instance, callback: VideoFrameRequestCallback) anyerror!u32 {
        
        return try HTMLVideoElementImpl.call_requestVideoFrameCallback(instance, callback);
    }

    pub fn call_getVideoPlaybackQuality(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try HTMLVideoElementImpl.call_getVideoPlaybackQuality(instance);
    }

};
