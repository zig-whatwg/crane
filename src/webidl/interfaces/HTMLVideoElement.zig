//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HTMLVideoElementImpl = @import("impls").HTMLVideoElement;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const HTMLMediaElement = @import("HTMLMediaElement.zig").HTMLMediaElement;
const DOMStringMap = @import("DOMStringMap.zig").DOMStringMap;
const CSSOMString = @import("typedefs").CSSOMString;
const HTMLCollection = @import("HTMLCollection.zig").HTMLCollection;
const TogglePopoverOptions = @import("dictionaries").TogglePopoverOptions;
const TextTrackKind = @import("enums").TextTrackKind;
const DOMPointInit = @import("dictionaries").DOMPointInit;
const GeometryNode = @import("typedefs").GeometryNode;
const NamedNodeMap = @import("NamedNodeMap.zig").NamedNodeMap;
const CSSStyleDeclaration = @import("CSSStyleDeclaration.zig").CSSStyleDeclaration;
const VideoFrameRequestCallback = @import("callbacks").VideoFrameRequestCallback;
const USVString = @import("typedefs").USVString;
const TrustedType = @import("typedefs").TrustedType;
const Element = @import("Element.zig").Element;
const CheckVisibilityOptions = @import("dictionaries").CheckVisibilityOptions;
const ScrollIntoViewOptions = @import("dictionaries").ScrollIntoViewOptions;
const BoxQuadOptions = @import("dictionaries").BoxQuadOptions;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const FocusableAreasOption = @import("dictionaries").FocusableAreasOption;
const EventListener = @import("EventListener.zig").EventListener;
const CSSStyleProperties = @import("CSSStyleProperties.zig").CSSStyleProperties;
const CSSPseudoElement = @import("CSSPseudoElement.zig").CSSPseudoElement;
const ShowPopoverOptions = @import("dictionaries").ShowPopoverOptions;
const ViewTransitionUpdateCallback = @import("callbacks").ViewTransitionUpdateCallback;
const Node = @import("Node.zig").Node;
const CustomElementRegistry = @import("CustomElementRegistry.zig").CustomElementRegistry;
const Animation = @import("Animation.zig").Animation;
const Range = @import("Range.zig").Range;
const Event = @import("Event.zig").Event;
const FocusOptions = @import("dictionaries").FocusOptions;
const MediaProvider = @import("typedefs").MediaProvider;
const TimeRanges = @import("TimeRanges.zig").TimeRanges;
const CanPlayTypeResult = @import("enums").CanPlayTypeResult;
const TextTrackList = @import("TextTrackList.zig").TextTrackList;
const DOMRectList = @import("DOMRectList.zig").DOMRectList;
const DOMString = @import("typedefs").DOMString;
const Document = @import("Document.zig").Document;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const GetHTMLOptions = @import("dictionaries").GetHTMLOptions;
const OnErrorEventHandler = @import("typedefs").OnErrorEventHandler;
const ScrollToOptions = @import("dictionaries").ScrollToOptions;
const HTMLSlotElement = @import("HTMLSlotElement.zig").HTMLSlotElement;
const DOMQuad = @import("DOMQuad.zig").DOMQuad;
const DOMRectReadOnly = @import("DOMRectReadOnly.zig").DOMRectReadOnly;
const KeyframeAnimationOptions = @import("dictionaries").KeyframeAnimationOptions;
const StylePropertyMapReadOnly = @import("StylePropertyMapReadOnly.zig").StylePropertyMapReadOnly;
const DOMTokenList = @import("DOMTokenList.zig").DOMTokenList;
const StartViewTransitionOptions = @import("dictionaries").StartViewTransitionOptions;
const EditContext = @import("EditContext.zig").EditContext;
const PictureInPictureWindow = @import("PictureInPictureWindow.zig").PictureInPictureWindow;
const DOMRect = @import("DOMRect.zig").DOMRect;
const ElementInternals = @import("ElementInternals.zig").ElementInternals;
const ViewTransition = @import("ViewTransition.zig").ViewTransition;
const MediaStream = @import("MediaStream.zig").MediaStream;
const VideoTrackList = @import("VideoTrackList.zig").VideoTrackList;
const VideoPlaybackQuality = @import("VideoPlaybackQuality.zig").VideoPlaybackQuality;
const SpatialNavigationSearchOptions = @import("dictionaries").SpatialNavigationSearchOptions;
const EventHandler = @import("typedefs").EventHandler;
const GetAnimationsOptions = @import("dictionaries").GetAnimationsOptions;
const ConvertCoordinateOptions = @import("dictionaries").ConvertCoordinateOptions;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const SpatialNavigationDirection = @import("enums").SpatialNavigationDirection;
const StylePropertyMap = @import("StylePropertyMap.zig").StylePropertyMap;
const ShadowRoot = @import("ShadowRoot.zig").ShadowRoot;
const Attr = @import("Attr.zig").Attr;
const TrustedHTML = @import("TrustedHTML.zig").TrustedHTML;
const DOMQuadInit = @import("dictionaries").DOMQuadInit;
const NodeList = @import("NodeList.zig").NodeList;
const FullscreenOptions = @import("dictionaries").FullscreenOptions;
const AudioTrackList = @import("AudioTrackList.zig").AudioTrackList;
const RemotePlayback = @import("RemotePlayback.zig").RemotePlayback;
const Observable = @import("Observable.zig").Observable;
const DOMPoint = @import("DOMPoint.zig").DOMPoint;
const MediaKeys = @import("MediaKeys.zig").MediaKeys;
const TextTrack = @import("TextTrack.zig").TextTrack;
const PointerLockOptions = @import("dictionaries").PointerLockOptions;
const GetRootNodeOptions = @import("dictionaries").GetRootNodeOptions;
const ShadowRootInit = @import("dictionaries").ShadowRootInit;
const MediaError = @import("MediaError.zig").MediaError;

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
            "scrollTo",
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
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
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
            onenterpictureinpicture: typedefs.EventHandler = undefined,
            onleavepictureinpicture: typedefs.EventHandler = undefined,
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

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return HTMLVideoElementImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HTMLVideoElementImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try HTMLVideoElementImpl.call_constructor(ctx);
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

    pub fn call_requestVideoFrameCallback(instance: *runtime.Instance, callback: VideoFrameRequestCallback) anyerror!u32 {
        
        return try HTMLVideoElementImpl.call_requestVideoFrameCallback(instance, callback);
    }

    pub fn call_cancelVideoFrameCallback(instance: *runtime.Instance, handle: u32) anyerror!void {
        
        return try HTMLVideoElementImpl.call_cancelVideoFrameCallback(instance, handle);
    }

    pub fn call_getVideoPlaybackQuality(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try HTMLVideoElementImpl.call_getVideoPlaybackQuality(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_requestPictureInPicture(instance: *runtime.Instance) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object
        return try HTMLVideoElementImpl.call_requestPictureInPicture(instance);
    }

};
