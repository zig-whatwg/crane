//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HTMLFrameSetElementImpl = @import("impls").HTMLFrameSetElement;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const HTMLElement = @import("interfaces").HTMLElement;
const WindowEventHandlers = @import("mixins").WindowEventHandlers;
const DOMStringMap = @import("interfaces").DOMStringMap;
const CSSOMString = @import("typedefs").CSSOMString;
const HTMLCollection = @import("interfaces").HTMLCollection;
const TogglePopoverOptions = @import("dictionaries").TogglePopoverOptions;
const DOMPointInit = @import("dictionaries").DOMPointInit;
const GeometryNode = @import("typedefs").GeometryNode;
const NamedNodeMap = @import("interfaces").NamedNodeMap;
const CSSStyleDeclaration = @import("interfaces").CSSStyleDeclaration;
const USVString = @import("typedefs").USVString;
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
const DOMRect = @import("interfaces").DOMRect;
const ElementInternals = @import("interfaces").ElementInternals;
const ViewTransition = @import("interfaces").ViewTransition;
const SpatialNavigationSearchOptions = @import("dictionaries").SpatialNavigationSearchOptions;
const EventHandler = @import("typedefs").EventHandler;
const GetAnimationsOptions = @import("dictionaries").GetAnimationsOptions;
const ConvertCoordinateOptions = @import("dictionaries").ConvertCoordinateOptions;
const OnBeforeUnloadEventHandler = @import("typedefs").OnBeforeUnloadEventHandler;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
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
const PointerLockOptions = @import("dictionaries").PointerLockOptions;
const GetRootNodeOptions = @import("dictionaries").GetRootNodeOptions;
const ShadowRootInit = @import("dictionaries").ShadowRootInit;

pub const HTMLFrameSetElement = struct {
    pub const Meta = struct {
        pub const name = "HTMLFrameSetElement";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = HTMLElement.State;
        pub const ParentInterface = HTMLElement;
        pub const MixinTypes = &.{
            WindowEventHandlers,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "cols", "get_cols", "set_cols" },
            .{ "rows", "get_rows", "set_rows" },
            .{ "onafterprint", "get_onafterprint", "set_onafterprint" },
            .{ "onbeforeprint", "get_onbeforeprint", "set_onbeforeprint" },
            .{ "onbeforeunload", "get_onbeforeunload", "set_onbeforeunload" },
            .{ "onhashchange", "get_onhashchange", "set_onhashchange" },
            .{ "onlanguagechange", "get_onlanguagechange", "set_onlanguagechange" },
            .{ "onmessage", "get_onmessage", "set_onmessage" },
            .{ "onmessageerror", "get_onmessageerror", "set_onmessageerror" },
            .{ "onoffline", "get_onoffline", "set_onoffline" },
            .{ "ononline", "get_ononline", "set_ononline" },
            .{ "onpagehide", "get_onpagehide", "set_onpagehide" },
            .{ "onpagereveal", "get_onpagereveal", "set_onpagereveal" },
            .{ "onpageshow", "get_onpageshow", "set_onpageshow" },
            .{ "onpageswap", "get_onpageswap", "set_onpageswap" },
            .{ "onpopstate", "get_onpopstate", "set_onpopstate" },
            .{ "onrejectionhandled", "get_onrejectionhandled", "set_onrejectionhandled" },
            .{ "onstorage", "get_onstorage", "set_onstorage" },
            .{ "onunhandledrejection", "get_onunhandledrejection", "set_onunhandledrejection" },
            .{ "onunload", "get_onunload", "set_onunload" },
            .{ "ongamepadconnected", "get_ongamepadconnected", "set_ongamepadconnected" },
            .{ "ongamepaddisconnected", "get_ongamepaddisconnected", "set_ongamepaddisconnected" },
            .{ "onportalactivate", "get_onportalactivate", "set_onportalactivate" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

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
            .{ "cols", "get_cols", "set_cols" },
            .{ "rows", "get_rows", "set_rows" },
            .{ "onafterprint", "get_onafterprint", "set_onafterprint" },
            .{ "onbeforeprint", "get_onbeforeprint", "set_onbeforeprint" },
            .{ "onbeforeunload", "get_onbeforeunload", "set_onbeforeunload" },
            .{ "onhashchange", "get_onhashchange", "set_onhashchange" },
            .{ "onlanguagechange", "get_onlanguagechange", "set_onlanguagechange" },
            .{ "onmessage", "get_onmessage", "set_onmessage" },
            .{ "onmessageerror", "get_onmessageerror", "set_onmessageerror" },
            .{ "onoffline", "get_onoffline", "set_onoffline" },
            .{ "ononline", "get_ononline", "set_ononline" },
            .{ "onpagehide", "get_onpagehide", "set_onpagehide" },
            .{ "onpagereveal", "get_onpagereveal", "set_onpagereveal" },
            .{ "onpageshow", "get_onpageshow", "set_onpageshow" },
            .{ "onpageswap", "get_onpageswap", "set_onpageswap" },
            .{ "onpopstate", "get_onpopstate", "set_onpopstate" },
            .{ "onrejectionhandled", "get_onrejectionhandled", "set_onrejectionhandled" },
            .{ "onstorage", "get_onstorage", "set_onstorage" },
            .{ "onunhandledrejection", "get_onunhandledrejection", "set_onunhandledrejection" },
            .{ "onunload", "get_onunload", "set_onunload" },
            .{ "ongamepadconnected", "get_ongamepadconnected", "set_ongamepadconnected" },
            .{ "ongamepaddisconnected", "get_ongamepaddisconnected", "set_ongamepaddisconnected" },
            .{ "onportalactivate", "get_onportalactivate", "set_onportalactivate" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            cols: typedefs.DOMString = undefined,
            rows: typedefs.DOMString = undefined,
            onbeforeunload: typedefs.OnBeforeUnloadEventHandler = undefined,
            _internal: ?*HTMLFrameSetElementImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_cols = &get_cols,
        .get_onafterprint = &get_onafterprint,
        .get_onbeforeprint = &get_onbeforeprint,
        .get_onbeforeunload = &get_onbeforeunload,
        .get_ongamepadconnected = &get_ongamepadconnected,
        .get_ongamepaddisconnected = &get_ongamepaddisconnected,
        .get_onhashchange = &get_onhashchange,
        .get_onlanguagechange = &get_onlanguagechange,
        .get_onmessage = &get_onmessage,
        .get_onmessageerror = &get_onmessageerror,
        .get_onoffline = &get_onoffline,
        .get_ononline = &get_ononline,
        .get_onpagehide = &get_onpagehide,
        .get_onpagereveal = &get_onpagereveal,
        .get_onpageshow = &get_onpageshow,
        .get_onpageswap = &get_onpageswap,
        .get_onpopstate = &get_onpopstate,
        .get_onportalactivate = &get_onportalactivate,
        .get_onrejectionhandled = &get_onrejectionhandled,
        .get_onstorage = &get_onstorage,
        .get_onunhandledrejection = &get_onunhandledrejection,
        .get_onunload = &get_onunload,
        .get_rows = &get_rows,

        .set_cols = &set_cols,
        .set_onafterprint = &set_onafterprint,
        .set_onbeforeprint = &set_onbeforeprint,
        .set_onbeforeunload = &set_onbeforeunload,
        .set_ongamepadconnected = &set_ongamepadconnected,
        .set_ongamepaddisconnected = &set_ongamepaddisconnected,
        .set_onhashchange = &set_onhashchange,
        .set_onlanguagechange = &set_onlanguagechange,
        .set_onmessage = &set_onmessage,
        .set_onmessageerror = &set_onmessageerror,
        .set_onoffline = &set_onoffline,
        .set_ononline = &set_ononline,
        .set_onpagehide = &set_onpagehide,
        .set_onpagereveal = &set_onpagereveal,
        .set_onpageshow = &set_onpageshow,
        .set_onpageswap = &set_onpageswap,
        .set_onpopstate = &set_onpopstate,
        .set_onportalactivate = &set_onportalactivate,
        .set_onrejectionhandled = &set_onrejectionhandled,
        .set_onstorage = &set_onstorage,
        .set_onunhandledrejection = &set_onunhandledrejection,
        .set_onunload = &set_onunload,
        .set_rows = &set_rows,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates, Meta.name, State);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return HTMLFrameSetElementImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return HTMLFrameSetElementImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HTMLFrameSetElementImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try HTMLFrameSetElementImpl.call_constructor(ctx);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_cols(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLFrameSetElementImpl.get_cols(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_cols(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();

        try HTMLFrameSetElementImpl.set_cols(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_rows(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLFrameSetElementImpl.get_rows(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_rows(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();

        try HTMLFrameSetElementImpl.set_rows(instance, value);
    }

    pub const get_onafterprint = mixins.WindowEventHandlers.get_onafterprint;
    pub const set_onafterprint = mixins.WindowEventHandlers.set_onafterprint;

    pub const get_onbeforeprint = mixins.WindowEventHandlers.get_onbeforeprint;
    pub const set_onbeforeprint = mixins.WindowEventHandlers.set_onbeforeprint;

    pub const get_onbeforeunload = mixins.WindowEventHandlers.get_onbeforeunload;
    pub const set_onbeforeunload = mixins.WindowEventHandlers.set_onbeforeunload;

    pub const get_onhashchange = mixins.WindowEventHandlers.get_onhashchange;
    pub const set_onhashchange = mixins.WindowEventHandlers.set_onhashchange;

    pub const get_onlanguagechange = mixins.WindowEventHandlers.get_onlanguagechange;
    pub const set_onlanguagechange = mixins.WindowEventHandlers.set_onlanguagechange;

    pub const get_onmessage = mixins.WindowEventHandlers.get_onmessage;
    pub const set_onmessage = mixins.WindowEventHandlers.set_onmessage;

    pub const get_onmessageerror = mixins.WindowEventHandlers.get_onmessageerror;
    pub const set_onmessageerror = mixins.WindowEventHandlers.set_onmessageerror;

    pub const get_onoffline = mixins.WindowEventHandlers.get_onoffline;
    pub const set_onoffline = mixins.WindowEventHandlers.set_onoffline;

    pub const get_ononline = mixins.WindowEventHandlers.get_ononline;
    pub const set_ononline = mixins.WindowEventHandlers.set_ononline;

    pub const get_onpagehide = mixins.WindowEventHandlers.get_onpagehide;
    pub const set_onpagehide = mixins.WindowEventHandlers.set_onpagehide;

    pub const get_onpagereveal = mixins.WindowEventHandlers.get_onpagereveal;
    pub const set_onpagereveal = mixins.WindowEventHandlers.set_onpagereveal;

    pub const get_onpageshow = mixins.WindowEventHandlers.get_onpageshow;
    pub const set_onpageshow = mixins.WindowEventHandlers.set_onpageshow;

    pub const get_onpageswap = mixins.WindowEventHandlers.get_onpageswap;
    pub const set_onpageswap = mixins.WindowEventHandlers.set_onpageswap;

    pub const get_onpopstate = mixins.WindowEventHandlers.get_onpopstate;
    pub const set_onpopstate = mixins.WindowEventHandlers.set_onpopstate;

    pub const get_onrejectionhandled = mixins.WindowEventHandlers.get_onrejectionhandled;
    pub const set_onrejectionhandled = mixins.WindowEventHandlers.set_onrejectionhandled;

    pub const get_onstorage = mixins.WindowEventHandlers.get_onstorage;
    pub const set_onstorage = mixins.WindowEventHandlers.set_onstorage;

    pub const get_onunhandledrejection = mixins.WindowEventHandlers.get_onunhandledrejection;
    pub const set_onunhandledrejection = mixins.WindowEventHandlers.set_onunhandledrejection;

    pub const get_onunload = mixins.WindowEventHandlers.get_onunload;
    pub const set_onunload = mixins.WindowEventHandlers.set_onunload;

    pub const get_ongamepadconnected = mixins.WindowEventHandlers.get_ongamepadconnected;
    pub const set_ongamepadconnected = mixins.WindowEventHandlers.set_ongamepadconnected;

    pub const get_ongamepaddisconnected = mixins.WindowEventHandlers.get_ongamepaddisconnected;
    pub const set_ongamepaddisconnected = mixins.WindowEventHandlers.set_ongamepaddisconnected;

    pub const get_onportalactivate = mixins.WindowEventHandlers.get_onportalactivate;
    pub const set_onportalactivate = mixins.WindowEventHandlers.set_onportalactivate;
};
