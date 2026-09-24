//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const WindowImpl = @import("impls").Window;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const PushManagerAttribute = @import("mixins").PushManagerAttribute;
const GlobalEventHandlers = @import("mixins").GlobalEventHandlers;
const WindowEventHandlers = @import("mixins").WindowEventHandlers;
const WindowOrWorkerGlobalScope = @import("mixins").WindowOrWorkerGlobalScope;
const AnimationFrameProvider = @import("mixins").AnimationFrameProvider;
const WindowSessionStorage = @import("mixins").WindowSessionStorage;
const WindowLocalStorage = @import("mixins").WindowLocalStorage;
const External = @import("interfaces").External;
const CSSOMString = @import("typedefs").CSSOMString;
const Navigator = @import("interfaces").Navigator;
const FetchLaterResult = @import("interfaces").FetchLaterResult;
const ImageBitmapSource = @import("typedefs").ImageBitmapSource;
const TimerHandler = @import("typedefs").TimerHandler;
const USVString = @import("typedefs").USVString;
const History = @import("interfaces").History;
const VisualViewport = @import("interfaces").VisualViewport;
const FileSystemFileHandle = @import("interfaces").FileSystemFileHandle;
const Element = @import("interfaces").Element;
const PushManager = @import("interfaces").PushManager;
const Scheduler = @import("interfaces").Scheduler;
const Crypto = @import("interfaces").Crypto;
const Location = @import("interfaces").Location;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const ImageBitmapOptions = @import("dictionaries").ImageBitmapOptions;
const CSSStyleProperties = @import("interfaces").CSSStyleProperties;
const CookieStore = @import("interfaces").CookieStore;
const IdleRequestCallback = @import("callbacks").IdleRequestCallback;
const PortalHost = @import("interfaces").PortalHost;
const FrameRequestCallback = @import("callbacks").FrameRequestCallback;
const CustomElementRegistry = @import("interfaces").CustomElementRegistry;
const RequestInit = @import("dictionaries").RequestInit;
const Storage = @import("interfaces").Storage;
const Event = @import("interfaces").Event;
const DirectoryPickerOptions = @import("dictionaries").DirectoryPickerOptions;
const SaveFilePickerOptions = @import("dictionaries").SaveFilePickerOptions;
const Response = @import("interfaces").Response;
const DocumentPictureInPicture = @import("interfaces").DocumentPictureInPicture;
const Document = @import("interfaces").Document;
const FileSystemDirectoryHandle = @import("interfaces").FileSystemDirectoryHandle;
const OnErrorEventHandler = @import("typedefs").OnErrorEventHandler;
const ByteString = @import("typedefs").ByteString;
const DigitalGoodsService = @import("interfaces").DigitalGoodsService;
const ScrollToOptions = @import("dictionaries").ScrollToOptions;
const OpenFilePickerOptions = @import("dictionaries").OpenFilePickerOptions;
const StructuredSerializeOptions = @import("dictionaries").StructuredSerializeOptions;
const DOMString = @import("typedefs").DOMString;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DeferredRequestInit = @import("dictionaries").DeferredRequestInit;
const Navigation = @import("interfaces").Navigation;
const WindowPostMessageOptions = @import("dictionaries").WindowPostMessageOptions;
const EventHandler = @import("typedefs").EventHandler;
const Fence = @import("interfaces").Fence;
const SharedStorage = @import("interfaces").SharedStorage;
const QueryOptions = @import("dictionaries").QueryOptions;
const OnBeforeUnloadEventHandler = @import("typedefs").OnBeforeUnloadEventHandler;
const ImageBitmap = @import("interfaces").ImageBitmap;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const SpatialNavigationDirection = @import("enums").SpatialNavigationDirection;
const WindowProxy = @import("typedefs").WindowProxy;
const ScreenDetails = @import("interfaces").ScreenDetails;
const RequestInfo = @import("typedefs").RequestInfo;
const Screen = @import("interfaces").Screen;
const VoidFunction = @import("callbacks").VoidFunction;
const IDBFactory = @import("interfaces").IDBFactory;
const BarProp = @import("interfaces").BarProp;
const TrustedTypePolicyFactory = @import("interfaces").TrustedTypePolicyFactory;
const Performance = @import("interfaces").Performance;
const CacheStorage = @import("interfaces").CacheStorage;
const Observable = @import("interfaces").Observable;
const IdleRequestOptions = @import("dictionaries").IdleRequestOptions;
const LaunchQueue = @import("interfaces").LaunchQueue;
const SpeechSynthesis = @import("interfaces").SpeechSynthesis;
const Viewport = @import("interfaces").Viewport;
const MediaQueryList = @import("interfaces").MediaQueryList;
const Selection = @import("interfaces").Selection;

pub const Window = struct {
    pub const Meta = struct {
        pub const name = "Window";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{
            PushManagerAttribute,
            GlobalEventHandlers,
            WindowEventHandlers,
            WindowOrWorkerGlobalScope,
            AnimationFrameProvider,
            WindowSessionStorage,
            WindowLocalStorage,
        };
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "Global", .value = .{ .identifier = "Window" } },
            .{ .name = "LegacyUnenumerableNamedProperties" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "window", "get_window", null },
            .{ "self", "get_self", "set_self" },
            .{ "document", "get_document", null },
            .{ "name", "get_name", "set_name" },
            .{ "location", "get_location", "set_location" },
            .{ "history", "get_history", null },
            .{ "navigation", "get_navigation", "set_navigation" },
            .{ "customElements", "get_customElements", null },
            .{ "locationbar", "get_locationbar", "set_locationbar" },
            .{ "menubar", "get_menubar", "set_menubar" },
            .{ "personalbar", "get_personalbar", "set_personalbar" },
            .{ "scrollbars", "get_scrollbars", "set_scrollbars" },
            .{ "statusbar", "get_statusbar", "set_statusbar" },
            .{ "toolbar", "get_toolbar", "set_toolbar" },
            .{ "status", "get_status", "set_status" },
            .{ "closed", "get_closed", null },
            .{ "frames", "get_frames", "set_frames" },
            .{ "length", "get_length", "set_length" },
            .{ "top", "get_top", null },
            .{ "opener", "get_opener", "set_opener" },
            .{ "parent", "get_parent", "set_parent" },
            .{ "frameElement", "get_frameElement", null },
            .{ "navigator", "get_navigator", null },
            .{ "clientInformation", "get_clientInformation", "set_clientInformation" },
            .{ "originAgentCluster", "get_originAgentCluster", null },
            .{ "ondeviceorientation", "get_ondeviceorientation", "set_ondeviceorientation" },
            .{ "ondeviceorientationabsolute", "get_ondeviceorientationabsolute", "set_ondeviceorientationabsolute" },
            .{ "ondevicemotion", "get_ondevicemotion", "set_ondevicemotion" },
            .{ "viewport", "get_viewport", "set_viewport" },
            .{ "cookieStore", "get_cookieStore", null },
            .{ "credentialless", "get_credentialless", null },
            .{ "speechSynthesis", "get_speechSynthesis", null },
            .{ "fence", "get_fence", null },
            .{ "documentPictureInPicture", "get_documentPictureInPicture", null },
            .{ "event", "get_event", "set_event" },
            .{ "orientation", "get_orientation", null },
            .{ "onorientationchange", "get_onorientationchange", "set_onorientationchange" },
            .{ "sharedStorage", "get_sharedStorage", null },
            .{ "onappinstalled", "get_onappinstalled", "set_onappinstalled" },
            .{ "onbeforeinstallprompt", "get_onbeforeinstallprompt", "set_onbeforeinstallprompt" },
            .{ "external", "get_external", "set_external" },
            .{ "screen", "get_screen", "set_screen" },
            .{ "visualViewport", "get_visualViewport", "set_visualViewport" },
            .{ "innerWidth", "get_innerWidth", "set_innerWidth" },
            .{ "innerHeight", "get_innerHeight", "set_innerHeight" },
            .{ "scrollX", "get_scrollX", "set_scrollX" },
            .{ "pageXOffset", "get_pageXOffset", "set_pageXOffset" },
            .{ "scrollY", "get_scrollY", "set_scrollY" },
            .{ "pageYOffset", "get_pageYOffset", "set_pageYOffset" },
            .{ "screenX", "get_screenX", "set_screenX" },
            .{ "screenLeft", "get_screenLeft", "set_screenLeft" },
            .{ "screenY", "get_screenY", "set_screenY" },
            .{ "screenTop", "get_screenTop", "set_screenTop" },
            .{ "outerWidth", "get_outerWidth", "set_outerWidth" },
            .{ "outerHeight", "get_outerHeight", "set_outerHeight" },
            .{ "devicePixelRatio", "get_devicePixelRatio", "set_devicePixelRatio" },
            .{ "launchQueue", "get_launchQueue", null },
            .{ "portalHost", "get_portalHost", null },
            .{ "pushManager", "get_pushManager", null },
            .{ "onabort", "get_onabort", "set_onabort" },
            .{ "onauxclick", "get_onauxclick", "set_onauxclick" },
            .{ "onbeforeinput", "get_onbeforeinput", "set_onbeforeinput" },
            .{ "onbeforematch", "get_onbeforematch", "set_onbeforematch" },
            .{ "onbeforetoggle", "get_onbeforetoggle", "set_onbeforetoggle" },
            .{ "onblur", "get_onblur", "set_onblur" },
            .{ "oncancel", "get_oncancel", "set_oncancel" },
            .{ "oncanplay", "get_oncanplay", "set_oncanplay" },
            .{ "oncanplaythrough", "get_oncanplaythrough", "set_oncanplaythrough" },
            .{ "onchange", "get_onchange", "set_onchange" },
            .{ "onclick", "get_onclick", "set_onclick" },
            .{ "onclose", "get_onclose", "set_onclose" },
            .{ "oncommand", "get_oncommand", "set_oncommand" },
            .{ "oncontextlost", "get_oncontextlost", "set_oncontextlost" },
            .{ "oncontextmenu", "get_oncontextmenu", "set_oncontextmenu" },
            .{ "oncontextrestored", "get_oncontextrestored", "set_oncontextrestored" },
            .{ "oncopy", "get_oncopy", "set_oncopy" },
            .{ "oncuechange", "get_oncuechange", "set_oncuechange" },
            .{ "oncut", "get_oncut", "set_oncut" },
            .{ "ondblclick", "get_ondblclick", "set_ondblclick" },
            .{ "ondrag", "get_ondrag", "set_ondrag" },
            .{ "ondragend", "get_ondragend", "set_ondragend" },
            .{ "ondragenter", "get_ondragenter", "set_ondragenter" },
            .{ "ondragleave", "get_ondragleave", "set_ondragleave" },
            .{ "ondragover", "get_ondragover", "set_ondragover" },
            .{ "ondragstart", "get_ondragstart", "set_ondragstart" },
            .{ "ondrop", "get_ondrop", "set_ondrop" },
            .{ "ondurationchange", "get_ondurationchange", "set_ondurationchange" },
            .{ "onemptied", "get_onemptied", "set_onemptied" },
            .{ "onended", "get_onended", "set_onended" },
            .{ "onerror", "get_onerror", "set_onerror" },
            .{ "onfocus", "get_onfocus", "set_onfocus" },
            .{ "onformdata", "get_onformdata", "set_onformdata" },
            .{ "oninput", "get_oninput", "set_oninput" },
            .{ "oninvalid", "get_oninvalid", "set_oninvalid" },
            .{ "onkeydown", "get_onkeydown", "set_onkeydown" },
            .{ "onkeypress", "get_onkeypress", "set_onkeypress" },
            .{ "onkeyup", "get_onkeyup", "set_onkeyup" },
            .{ "onload", "get_onload", "set_onload" },
            .{ "onloadeddata", "get_onloadeddata", "set_onloadeddata" },
            .{ "onloadedmetadata", "get_onloadedmetadata", "set_onloadedmetadata" },
            .{ "onloadstart", "get_onloadstart", "set_onloadstart" },
            .{ "onmousedown", "get_onmousedown", "set_onmousedown" },
            .{ "onmouseenter", "get_onmouseenter", "set_onmouseenter" },
            .{ "onmouseleave", "get_onmouseleave", "set_onmouseleave" },
            .{ "onmousemove", "get_onmousemove", "set_onmousemove" },
            .{ "onmouseout", "get_onmouseout", "set_onmouseout" },
            .{ "onmouseover", "get_onmouseover", "set_onmouseover" },
            .{ "onmouseup", "get_onmouseup", "set_onmouseup" },
            .{ "onpaste", "get_onpaste", "set_onpaste" },
            .{ "onpause", "get_onpause", "set_onpause" },
            .{ "onplay", "get_onplay", "set_onplay" },
            .{ "onplaying", "get_onplaying", "set_onplaying" },
            .{ "onprogress", "get_onprogress", "set_onprogress" },
            .{ "onratechange", "get_onratechange", "set_onratechange" },
            .{ "onreset", "get_onreset", "set_onreset" },
            .{ "onresize", "get_onresize", "set_onresize" },
            .{ "onscroll", "get_onscroll", "set_onscroll" },
            .{ "onscrollend", "get_onscrollend", "set_onscrollend" },
            .{ "onsecuritypolicyviolation", "get_onsecuritypolicyviolation", "set_onsecuritypolicyviolation" },
            .{ "onseeked", "get_onseeked", "set_onseeked" },
            .{ "onseeking", "get_onseeking", "set_onseeking" },
            .{ "onselect", "get_onselect", "set_onselect" },
            .{ "onslotchange", "get_onslotchange", "set_onslotchange" },
            .{ "onstalled", "get_onstalled", "set_onstalled" },
            .{ "onsubmit", "get_onsubmit", "set_onsubmit" },
            .{ "onsuspend", "get_onsuspend", "set_onsuspend" },
            .{ "ontimeupdate", "get_ontimeupdate", "set_ontimeupdate" },
            .{ "ontoggle", "get_ontoggle", "set_ontoggle" },
            .{ "onvolumechange", "get_onvolumechange", "set_onvolumechange" },
            .{ "onwaiting", "get_onwaiting", "set_onwaiting" },
            .{ "onwebkitanimationend", "get_onwebkitanimationend", "set_onwebkitanimationend" },
            .{ "onwebkitanimationiteration", "get_onwebkitanimationiteration", "set_onwebkitanimationiteration" },
            .{ "onwebkitanimationstart", "get_onwebkitanimationstart", "set_onwebkitanimationstart" },
            .{ "onwebkittransitionend", "get_onwebkittransitionend", "set_onwebkittransitionend" },
            .{ "onwheel", "get_onwheel", "set_onwheel" },
            .{ "onselectstart", "get_onselectstart", "set_onselectstart" },
            .{ "onselectionchange", "get_onselectionchange", "set_onselectionchange" },
            .{ "onanimationstart", "get_onanimationstart", "set_onanimationstart" },
            .{ "onanimationiteration", "get_onanimationiteration", "set_onanimationiteration" },
            .{ "onanimationend", "get_onanimationend", "set_onanimationend" },
            .{ "onanimationcancel", "get_onanimationcancel", "set_onanimationcancel" },
            .{ "ontransitionrun", "get_ontransitionrun", "set_ontransitionrun" },
            .{ "ontransitionstart", "get_ontransitionstart", "set_ontransitionstart" },
            .{ "ontransitionend", "get_ontransitionend", "set_ontransitionend" },
            .{ "ontransitioncancel", "get_ontransitioncancel", "set_ontransitioncancel" },
            .{ "onbeforexrselect", "get_onbeforexrselect", "set_onbeforexrselect" },
            .{ "onpointerover", "get_onpointerover", "set_onpointerover" },
            .{ "onpointerenter", "get_onpointerenter", "set_onpointerenter" },
            .{ "onpointerdown", "get_onpointerdown", "set_onpointerdown" },
            .{ "onpointermove", "get_onpointermove", "set_onpointermove" },
            .{ "onpointerrawupdate", "get_onpointerrawupdate", "set_onpointerrawupdate" },
            .{ "onpointerup", "get_onpointerup", "set_onpointerup" },
            .{ "onpointercancel", "get_onpointercancel", "set_onpointercancel" },
            .{ "onpointerout", "get_onpointerout", "set_onpointerout" },
            .{ "onpointerleave", "get_onpointerleave", "set_onpointerleave" },
            .{ "ongotpointercapture", "get_ongotpointercapture", "set_ongotpointercapture" },
            .{ "onlostpointercapture", "get_onlostpointercapture", "set_onlostpointercapture" },
            .{ "ontouchstart", "get_ontouchstart", "set_ontouchstart" },
            .{ "ontouchend", "get_ontouchend", "set_ontouchend" },
            .{ "ontouchmove", "get_ontouchmove", "set_ontouchmove" },
            .{ "ontouchcancel", "get_ontouchcancel", "set_ontouchcancel" },
            .{ "onfencedtreeclick", "get_onfencedtreeclick", "set_onfencedtreeclick" },
            .{ "onsnapchanged", "get_onsnapchanged", "set_onsnapchanged" },
            .{ "onsnapchanging", "get_onsnapchanging", "set_onsnapchanging" },
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
            .{ "origin", "get_origin", "set_origin" },
            .{ "isSecureContext", "get_isSecureContext", null },
            .{ "crossOriginIsolated", "get_crossOriginIsolated", null },
            .{ "indexedDB", "get_indexedDB", null },
            .{ "trustedTypes", "get_trustedTypes", null },
            .{ "performance", "get_performance", "set_performance" },
            .{ "caches", "get_caches", null },
            .{ "scheduler", "get_scheduler", "set_scheduler" },
            .{ "crypto", "get_crypto", null },
            .{ "sessionStorage", "get_sessionStorage", null },
            .{ "localStorage", "get_localStorage", null },
        };

        /// [PutForwards] attributes: setting the attribute forwards to a property on the value
        /// Format: { "attrName", "forwardedProperty" }
        pub const put_forwards_attributes = .{
            .{ "location", "href" },
        };

        /// [LegacyLenientThis] attributes: do NOT throw TypeError on invalid this
        /// Getters return undefined, setters silently return
        pub const lenient_this_attributes = .{
            "onmouseenter",
            "onmouseleave",
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "close", "call_close", 0 },
            .{ "stop", "call_stop", 0 },
            .{ "focus", "call_focus", 0 },
            .{ "blur", "call_blur", 0 },
            .{ "open", "call_open", 0 },
            .{ "alert", "call_alert", 0 },
            .{ "confirm", "call_confirm", 0 },
            .{ "prompt", "call_prompt", 0 },
            .{ "print", "call_print", 0 },
            .{ "postMessage", "call_postMessage", 1 },
            .{ "navigate", "call_navigate", 1 },
            .{ "showOpenFilePicker", "call_showOpenFilePicker", 0 },
            .{ "showSaveFilePicker", "call_showSaveFilePicker", 0 },
            .{ "showDirectoryPicker", "call_showDirectoryPicker", 0 },
            .{ "getDigitalGoodsService", "call_getDigitalGoodsService", 1 },
            .{ "getSelection", "call_getSelection", 0 },
            .{ "getScreenDetails", "call_getScreenDetails", 0 },
            .{ "getComputedStyle", "call_getComputedStyle", 1 },
            .{ "item", "call_item", 1 },
            .{ "fetchLater", "call_fetchLater", 1 },
            .{ "captureEvents", "call_captureEvents", 0 },
            .{ "releaseEvents", "call_releaseEvents", 0 },
            .{ "requestIdleCallback", "call_requestIdleCallback", 1 },
            .{ "cancelIdleCallback", "call_cancelIdleCallback", 1 },
            .{ "matchMedia", "call_matchMedia", 1 },
            .{ "moveTo", "call_moveTo", 2 },
            .{ "moveBy", "call_moveBy", 2 },
            .{ "resizeTo", "call_resizeTo", 2 },
            .{ "resizeBy", "call_resizeBy", 2 },
            .{ "scroll", "call_scroll", 0 },
            .{ "scrollTo", "call_scrollTo", 0 },
            .{ "scrollBy", "call_scrollBy", 0 },
            .{ "queryLocalFonts", "call_queryLocalFonts", 0 },
            .{ "reportError", "call_reportError", 1 },
            .{ "btoa", "call_btoa", 1 },
            .{ "atob", "call_atob", 1 },
            .{ "setTimeout", "call_setTimeout", 1 },
            .{ "clearTimeout", "call_clearTimeout", 0 },
            .{ "setInterval", "call_setInterval", 1 },
            .{ "clearInterval", "call_clearInterval", 0 },
            .{ "queueMicrotask", "call_queueMicrotask", 1 },
            .{ "createImageBitmap", "call_createImageBitmap", 1 },
            .{ "structuredClone", "call_structuredClone", 1 },
            .{ "fetch", "call_fetch", 1 },
            .{ "requestAnimationFrame", "call_requestAnimationFrame", 1 },
            .{ "cancelAnimationFrame", "call_cancelAnimationFrame", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "close",
            "stop",
            "focus",
            "blur",
            "open",
            "alert",
            "confirm",
            "prompt",
            "print",
            "postMessage",
            "navigate",
            "showOpenFilePicker",
            "showSaveFilePicker",
            "showDirectoryPicker",
            "getDigitalGoodsService",
            "getSelection",
            "getScreenDetails",
            "getComputedStyle",
            "item",
            "fetchLater",
            "captureEvents",
            "releaseEvents",
            "requestIdleCallback",
            "cancelIdleCallback",
            "matchMedia",
            "moveTo",
            "moveBy",
            "resizeTo",
            "resizeBy",
            "scroll",
            "scrollTo",
            "scrollBy",
            "queryLocalFonts",
            "reportError",
            "btoa",
            "atob",
            "setTimeout",
            "clearTimeout",
            "setInterval",
            "clearInterval",
            "queueMicrotask",
            "createImageBitmap",
            "structuredClone",
            "fetch",
            "requestAnimationFrame",
            "cancelAnimationFrame",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "window", "get_window", null },
            .{ "self", "get_self", "set_self" },
            .{ "document", "get_document", null },
            .{ "name", "get_name", "set_name" },
            .{ "location", "get_location", "set_location" },
            .{ "history", "get_history", null },
            .{ "navigation", "get_navigation", "set_navigation" },
            .{ "customElements", "get_customElements", null },
            .{ "locationbar", "get_locationbar", "set_locationbar" },
            .{ "menubar", "get_menubar", "set_menubar" },
            .{ "personalbar", "get_personalbar", "set_personalbar" },
            .{ "scrollbars", "get_scrollbars", "set_scrollbars" },
            .{ "statusbar", "get_statusbar", "set_statusbar" },
            .{ "toolbar", "get_toolbar", "set_toolbar" },
            .{ "status", "get_status", "set_status" },
            .{ "closed", "get_closed", null },
            .{ "frames", "get_frames", "set_frames" },
            .{ "length", "get_length", "set_length" },
            .{ "top", "get_top", null },
            .{ "opener", "get_opener", "set_opener" },
            .{ "parent", "get_parent", "set_parent" },
            .{ "frameElement", "get_frameElement", null },
            .{ "navigator", "get_navigator", null },
            .{ "clientInformation", "get_clientInformation", "set_clientInformation" },
            .{ "originAgentCluster", "get_originAgentCluster", null },
            .{ "ondeviceorientation", "get_ondeviceorientation", "set_ondeviceorientation" },
            .{ "ondeviceorientationabsolute", "get_ondeviceorientationabsolute", "set_ondeviceorientationabsolute" },
            .{ "ondevicemotion", "get_ondevicemotion", "set_ondevicemotion" },
            .{ "viewport", "get_viewport", "set_viewport" },
            .{ "cookieStore", "get_cookieStore", null },
            .{ "credentialless", "get_credentialless", null },
            .{ "speechSynthesis", "get_speechSynthesis", null },
            .{ "fence", "get_fence", null },
            .{ "documentPictureInPicture", "get_documentPictureInPicture", null },
            .{ "event", "get_event", "set_event" },
            .{ "orientation", "get_orientation", null },
            .{ "onorientationchange", "get_onorientationchange", "set_onorientationchange" },
            .{ "sharedStorage", "get_sharedStorage", null },
            .{ "onappinstalled", "get_onappinstalled", "set_onappinstalled" },
            .{ "onbeforeinstallprompt", "get_onbeforeinstallprompt", "set_onbeforeinstallprompt" },
            .{ "external", "get_external", "set_external" },
            .{ "screen", "get_screen", "set_screen" },
            .{ "visualViewport", "get_visualViewport", "set_visualViewport" },
            .{ "innerWidth", "get_innerWidth", "set_innerWidth" },
            .{ "innerHeight", "get_innerHeight", "set_innerHeight" },
            .{ "scrollX", "get_scrollX", "set_scrollX" },
            .{ "pageXOffset", "get_pageXOffset", "set_pageXOffset" },
            .{ "scrollY", "get_scrollY", "set_scrollY" },
            .{ "pageYOffset", "get_pageYOffset", "set_pageYOffset" },
            .{ "screenX", "get_screenX", "set_screenX" },
            .{ "screenLeft", "get_screenLeft", "set_screenLeft" },
            .{ "screenY", "get_screenY", "set_screenY" },
            .{ "screenTop", "get_screenTop", "set_screenTop" },
            .{ "outerWidth", "get_outerWidth", "set_outerWidth" },
            .{ "outerHeight", "get_outerHeight", "set_outerHeight" },
            .{ "devicePixelRatio", "get_devicePixelRatio", "set_devicePixelRatio" },
            .{ "launchQueue", "get_launchQueue", null },
            .{ "portalHost", "get_portalHost", null },
            .{ "pushManager", "get_pushManager", null },
            .{ "onabort", "get_onabort", "set_onabort" },
            .{ "onauxclick", "get_onauxclick", "set_onauxclick" },
            .{ "onbeforeinput", "get_onbeforeinput", "set_onbeforeinput" },
            .{ "onbeforematch", "get_onbeforematch", "set_onbeforematch" },
            .{ "onbeforetoggle", "get_onbeforetoggle", "set_onbeforetoggle" },
            .{ "onblur", "get_onblur", "set_onblur" },
            .{ "oncancel", "get_oncancel", "set_oncancel" },
            .{ "oncanplay", "get_oncanplay", "set_oncanplay" },
            .{ "oncanplaythrough", "get_oncanplaythrough", "set_oncanplaythrough" },
            .{ "onchange", "get_onchange", "set_onchange" },
            .{ "onclick", "get_onclick", "set_onclick" },
            .{ "onclose", "get_onclose", "set_onclose" },
            .{ "oncommand", "get_oncommand", "set_oncommand" },
            .{ "oncontextlost", "get_oncontextlost", "set_oncontextlost" },
            .{ "oncontextmenu", "get_oncontextmenu", "set_oncontextmenu" },
            .{ "oncontextrestored", "get_oncontextrestored", "set_oncontextrestored" },
            .{ "oncopy", "get_oncopy", "set_oncopy" },
            .{ "oncuechange", "get_oncuechange", "set_oncuechange" },
            .{ "oncut", "get_oncut", "set_oncut" },
            .{ "ondblclick", "get_ondblclick", "set_ondblclick" },
            .{ "ondrag", "get_ondrag", "set_ondrag" },
            .{ "ondragend", "get_ondragend", "set_ondragend" },
            .{ "ondragenter", "get_ondragenter", "set_ondragenter" },
            .{ "ondragleave", "get_ondragleave", "set_ondragleave" },
            .{ "ondragover", "get_ondragover", "set_ondragover" },
            .{ "ondragstart", "get_ondragstart", "set_ondragstart" },
            .{ "ondrop", "get_ondrop", "set_ondrop" },
            .{ "ondurationchange", "get_ondurationchange", "set_ondurationchange" },
            .{ "onemptied", "get_onemptied", "set_onemptied" },
            .{ "onended", "get_onended", "set_onended" },
            .{ "onerror", "get_onerror", "set_onerror" },
            .{ "onfocus", "get_onfocus", "set_onfocus" },
            .{ "onformdata", "get_onformdata", "set_onformdata" },
            .{ "oninput", "get_oninput", "set_oninput" },
            .{ "oninvalid", "get_oninvalid", "set_oninvalid" },
            .{ "onkeydown", "get_onkeydown", "set_onkeydown" },
            .{ "onkeypress", "get_onkeypress", "set_onkeypress" },
            .{ "onkeyup", "get_onkeyup", "set_onkeyup" },
            .{ "onload", "get_onload", "set_onload" },
            .{ "onloadeddata", "get_onloadeddata", "set_onloadeddata" },
            .{ "onloadedmetadata", "get_onloadedmetadata", "set_onloadedmetadata" },
            .{ "onloadstart", "get_onloadstart", "set_onloadstart" },
            .{ "onmousedown", "get_onmousedown", "set_onmousedown" },
            .{ "onmouseenter", "get_onmouseenter", "set_onmouseenter" },
            .{ "onmouseleave", "get_onmouseleave", "set_onmouseleave" },
            .{ "onmousemove", "get_onmousemove", "set_onmousemove" },
            .{ "onmouseout", "get_onmouseout", "set_onmouseout" },
            .{ "onmouseover", "get_onmouseover", "set_onmouseover" },
            .{ "onmouseup", "get_onmouseup", "set_onmouseup" },
            .{ "onpaste", "get_onpaste", "set_onpaste" },
            .{ "onpause", "get_onpause", "set_onpause" },
            .{ "onplay", "get_onplay", "set_onplay" },
            .{ "onplaying", "get_onplaying", "set_onplaying" },
            .{ "onprogress", "get_onprogress", "set_onprogress" },
            .{ "onratechange", "get_onratechange", "set_onratechange" },
            .{ "onreset", "get_onreset", "set_onreset" },
            .{ "onresize", "get_onresize", "set_onresize" },
            .{ "onscroll", "get_onscroll", "set_onscroll" },
            .{ "onscrollend", "get_onscrollend", "set_onscrollend" },
            .{ "onsecuritypolicyviolation", "get_onsecuritypolicyviolation", "set_onsecuritypolicyviolation" },
            .{ "onseeked", "get_onseeked", "set_onseeked" },
            .{ "onseeking", "get_onseeking", "set_onseeking" },
            .{ "onselect", "get_onselect", "set_onselect" },
            .{ "onslotchange", "get_onslotchange", "set_onslotchange" },
            .{ "onstalled", "get_onstalled", "set_onstalled" },
            .{ "onsubmit", "get_onsubmit", "set_onsubmit" },
            .{ "onsuspend", "get_onsuspend", "set_onsuspend" },
            .{ "ontimeupdate", "get_ontimeupdate", "set_ontimeupdate" },
            .{ "ontoggle", "get_ontoggle", "set_ontoggle" },
            .{ "onvolumechange", "get_onvolumechange", "set_onvolumechange" },
            .{ "onwaiting", "get_onwaiting", "set_onwaiting" },
            .{ "onwebkitanimationend", "get_onwebkitanimationend", "set_onwebkitanimationend" },
            .{ "onwebkitanimationiteration", "get_onwebkitanimationiteration", "set_onwebkitanimationiteration" },
            .{ "onwebkitanimationstart", "get_onwebkitanimationstart", "set_onwebkitanimationstart" },
            .{ "onwebkittransitionend", "get_onwebkittransitionend", "set_onwebkittransitionend" },
            .{ "onwheel", "get_onwheel", "set_onwheel" },
            .{ "onselectstart", "get_onselectstart", "set_onselectstart" },
            .{ "onselectionchange", "get_onselectionchange", "set_onselectionchange" },
            .{ "onanimationstart", "get_onanimationstart", "set_onanimationstart" },
            .{ "onanimationiteration", "get_onanimationiteration", "set_onanimationiteration" },
            .{ "onanimationend", "get_onanimationend", "set_onanimationend" },
            .{ "onanimationcancel", "get_onanimationcancel", "set_onanimationcancel" },
            .{ "ontransitionrun", "get_ontransitionrun", "set_ontransitionrun" },
            .{ "ontransitionstart", "get_ontransitionstart", "set_ontransitionstart" },
            .{ "ontransitionend", "get_ontransitionend", "set_ontransitionend" },
            .{ "ontransitioncancel", "get_ontransitioncancel", "set_ontransitioncancel" },
            .{ "onbeforexrselect", "get_onbeforexrselect", "set_onbeforexrselect" },
            .{ "onpointerover", "get_onpointerover", "set_onpointerover" },
            .{ "onpointerenter", "get_onpointerenter", "set_onpointerenter" },
            .{ "onpointerdown", "get_onpointerdown", "set_onpointerdown" },
            .{ "onpointermove", "get_onpointermove", "set_onpointermove" },
            .{ "onpointerrawupdate", "get_onpointerrawupdate", "set_onpointerrawupdate" },
            .{ "onpointerup", "get_onpointerup", "set_onpointerup" },
            .{ "onpointercancel", "get_onpointercancel", "set_onpointercancel" },
            .{ "onpointerout", "get_onpointerout", "set_onpointerout" },
            .{ "onpointerleave", "get_onpointerleave", "set_onpointerleave" },
            .{ "ongotpointercapture", "get_ongotpointercapture", "set_ongotpointercapture" },
            .{ "onlostpointercapture", "get_onlostpointercapture", "set_onlostpointercapture" },
            .{ "ontouchstart", "get_ontouchstart", "set_ontouchstart" },
            .{ "ontouchend", "get_ontouchend", "set_ontouchend" },
            .{ "ontouchmove", "get_ontouchmove", "set_ontouchmove" },
            .{ "ontouchcancel", "get_ontouchcancel", "set_ontouchcancel" },
            .{ "onfencedtreeclick", "get_onfencedtreeclick", "set_onfencedtreeclick" },
            .{ "onsnapchanged", "get_onsnapchanged", "set_onsnapchanged" },
            .{ "onsnapchanging", "get_onsnapchanging", "set_onsnapchanging" },
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
            .{ "origin", "get_origin", "set_origin" },
            .{ "isSecureContext", "get_isSecureContext", null },
            .{ "crossOriginIsolated", "get_crossOriginIsolated", null },
            .{ "indexedDB", "get_indexedDB", null },
            .{ "trustedTypes", "get_trustedTypes", null },
            .{ "performance", "get_performance", "set_performance" },
            .{ "caches", "get_caches", null },
            .{ "scheduler", "get_scheduler", "set_scheduler" },
            .{ "crypto", "get_crypto", null },
            .{ "sessionStorage", "get_sessionStorage", null },
            .{ "localStorage", "get_localStorage", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            window: typedefs.WindowProxy = undefined,
            self: typedefs.WindowProxy = undefined,
            document: *runtime.Instance = undefined,
            name: typedefs.DOMString = undefined,
            location: *runtime.Instance = undefined,
            history: *runtime.Instance = undefined,
            navigation: *runtime.Instance = undefined,
            customElements: *runtime.Instance = undefined,
            locationbar: *runtime.Instance = undefined,
            menubar: *runtime.Instance = undefined,
            personalbar: *runtime.Instance = undefined,
            scrollbars: *runtime.Instance = undefined,
            statusbar: *runtime.Instance = undefined,
            toolbar: *runtime.Instance = undefined,
            status: typedefs.DOMString = undefined,
            closed: bool = undefined,
            frames: typedefs.WindowProxy = undefined,
            length: u32 = undefined,
            top: ?typedefs.WindowProxy = null,
            opener: runtime.JSValue = undefined,
            parent: ?typedefs.WindowProxy = null,
            frameElement: ?*runtime.Instance = null,
            navigator: *runtime.Instance = undefined,
            clientInformation: *runtime.Instance = undefined,
            originAgentCluster: bool = undefined,
            viewport: *runtime.Instance = undefined,
            cookieStore: *runtime.Instance = undefined,
            credentialless: bool = undefined,
            speechSynthesis: *runtime.Instance = undefined,
            fence: ?*runtime.Instance = null,
            documentPictureInPicture: *runtime.Instance = undefined,
            event: union(enum) {
                Event: Event,
                undefined: void,
            } = undefined,
            orientation: i16 = undefined,
            sharedStorage: ?*runtime.Instance = null,
            external: *runtime.Instance = undefined,
            screen: *runtime.Instance = undefined,
            visualViewport: ?*runtime.Instance = null,
            innerWidth: i32 = undefined,
            innerHeight: i32 = undefined,
            scrollX: f64 = undefined,
            pageXOffset: f64 = undefined,
            scrollY: f64 = undefined,
            pageYOffset: f64 = undefined,
            screenX: i32 = undefined,
            screenLeft: i32 = undefined,
            screenY: i32 = undefined,
            screenTop: i32 = undefined,
            outerWidth: i32 = undefined,
            outerHeight: i32 = undefined,
            devicePixelRatio: f64 = undefined,
            launchQueue: *runtime.Instance = undefined,
            portalHost: ?*runtime.Instance = null,
            pushManager: *runtime.Instance = undefined,
            onerror: typedefs.OnErrorEventHandler = undefined,
            onbeforeunload: typedefs.OnBeforeUnloadEventHandler = undefined,
            origin: runtime.USVString = undefined,
            isSecureContext: bool = undefined,
            crossOriginIsolated: bool = undefined,
            indexedDB: *runtime.Instance = undefined,
            trustedTypes: *runtime.Instance = undefined,
            performance: *runtime.Instance = undefined,
            caches: *runtime.Instance = undefined,
            scheduler: *runtime.Instance = undefined,
            crypto: *runtime.Instance = undefined,
            sessionStorage: *runtime.Instance = undefined,
            localStorage: *runtime.Instance = undefined,
            cached_viewport: ?*runtime.Instance = null,
            cached_cookieStore: ?*runtime.Instance = null,
            cached_speechSynthesis: ?*runtime.Instance = null,
            cached_documentPictureInPicture: ?*runtime.Instance = null,
            cached_external: ?*runtime.Instance = null,
            cached_screen: ?*runtime.Instance = null,
            cached_visualViewport: ?*runtime.Instance = null,
            cached_indexedDB: ?*runtime.Instance = null,
            cached_caches: ?*runtime.Instance = null,
            cached_crypto: ?*runtime.Instance = null,
            _internal: ?*WindowImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_caches = &get_caches,
        .get_clientInformation = &get_clientInformation,
        .get_closed = &get_closed,
        .get_cookieStore = &get_cookieStore,
        .get_credentialless = &get_credentialless,
        .get_crossOriginIsolated = &get_crossOriginIsolated,
        .get_crypto = &get_crypto,
        .get_customElements = &get_customElements,
        .get_devicePixelRatio = &get_devicePixelRatio,
        .get_document = &get_document,
        .get_documentPictureInPicture = &get_documentPictureInPicture,
        .get_event = &get_event,
        .get_external = &get_external,
        .get_fence = &get_fence,
        .get_frameElement = &get_frameElement,
        .get_frames = &get_frames,
        .get_history = &get_history,
        .get_indexedDB = &get_indexedDB,
        .get_innerHeight = &get_innerHeight,
        .get_innerWidth = &get_innerWidth,
        .get_isSecureContext = &get_isSecureContext,
        .get_launchQueue = &get_launchQueue,
        .get_length = &get_length,
        .get_localStorage = &get_localStorage,
        .get_location = &get_location,
        .get_locationbar = &get_locationbar,
        .get_menubar = &get_menubar,
        .get_name = &get_name,
        .get_navigation = &get_navigation,
        .get_navigator = &get_navigator,
        .get_onabort = &get_onabort,
        .get_onafterprint = &get_onafterprint,
        .get_onanimationcancel = &get_onanimationcancel,
        .get_onanimationend = &get_onanimationend,
        .get_onanimationiteration = &get_onanimationiteration,
        .get_onanimationstart = &get_onanimationstart,
        .get_onappinstalled = &get_onappinstalled,
        .get_onauxclick = &get_onauxclick,
        .get_onbeforeinput = &get_onbeforeinput,
        .get_onbeforeinstallprompt = &get_onbeforeinstallprompt,
        .get_onbeforematch = &get_onbeforematch,
        .get_onbeforeprint = &get_onbeforeprint,
        .get_onbeforetoggle = &get_onbeforetoggle,
        .get_onbeforeunload = &get_onbeforeunload,
        .get_onbeforexrselect = &get_onbeforexrselect,
        .get_onblur = &get_onblur,
        .get_oncancel = &get_oncancel,
        .get_oncanplay = &get_oncanplay,
        .get_oncanplaythrough = &get_oncanplaythrough,
        .get_onchange = &get_onchange,
        .get_onclick = &get_onclick,
        .get_onclose = &get_onclose,
        .get_oncommand = &get_oncommand,
        .get_oncontextlost = &get_oncontextlost,
        .get_oncontextmenu = &get_oncontextmenu,
        .get_oncontextrestored = &get_oncontextrestored,
        .get_oncopy = &get_oncopy,
        .get_oncuechange = &get_oncuechange,
        .get_oncut = &get_oncut,
        .get_ondblclick = &get_ondblclick,
        .get_ondevicemotion = &get_ondevicemotion,
        .get_ondeviceorientation = &get_ondeviceorientation,
        .get_ondeviceorientationabsolute = &get_ondeviceorientationabsolute,
        .get_ondrag = &get_ondrag,
        .get_ondragend = &get_ondragend,
        .get_ondragenter = &get_ondragenter,
        .get_ondragleave = &get_ondragleave,
        .get_ondragover = &get_ondragover,
        .get_ondragstart = &get_ondragstart,
        .get_ondrop = &get_ondrop,
        .get_ondurationchange = &get_ondurationchange,
        .get_onemptied = &get_onemptied,
        .get_onended = &get_onended,
        .get_onerror = &get_onerror,
        .get_onfencedtreeclick = &get_onfencedtreeclick,
        .get_onfocus = &get_onfocus,
        .get_onformdata = &get_onformdata,
        .get_ongamepadconnected = &get_ongamepadconnected,
        .get_ongamepaddisconnected = &get_ongamepaddisconnected,
        .get_ongotpointercapture = &get_ongotpointercapture,
        .get_onhashchange = &get_onhashchange,
        .get_oninput = &get_oninput,
        .get_oninvalid = &get_oninvalid,
        .get_onkeydown = &get_onkeydown,
        .get_onkeypress = &get_onkeypress,
        .get_onkeyup = &get_onkeyup,
        .get_onlanguagechange = &get_onlanguagechange,
        .get_onload = &get_onload,
        .get_onloadeddata = &get_onloadeddata,
        .get_onloadedmetadata = &get_onloadedmetadata,
        .get_onloadstart = &get_onloadstart,
        .get_onlostpointercapture = &get_onlostpointercapture,
        .get_onmessage = &get_onmessage,
        .get_onmessageerror = &get_onmessageerror,
        .get_onmousedown = &get_onmousedown,
        .get_onmouseenter = &get_onmouseenter,
        .get_onmouseleave = &get_onmouseleave,
        .get_onmousemove = &get_onmousemove,
        .get_onmouseout = &get_onmouseout,
        .get_onmouseover = &get_onmouseover,
        .get_onmouseup = &get_onmouseup,
        .get_onoffline = &get_onoffline,
        .get_ononline = &get_ononline,
        .get_onorientationchange = &get_onorientationchange,
        .get_onpagehide = &get_onpagehide,
        .get_onpagereveal = &get_onpagereveal,
        .get_onpageshow = &get_onpageshow,
        .get_onpageswap = &get_onpageswap,
        .get_onpaste = &get_onpaste,
        .get_onpause = &get_onpause,
        .get_onplay = &get_onplay,
        .get_onplaying = &get_onplaying,
        .get_onpointercancel = &get_onpointercancel,
        .get_onpointerdown = &get_onpointerdown,
        .get_onpointerenter = &get_onpointerenter,
        .get_onpointerleave = &get_onpointerleave,
        .get_onpointermove = &get_onpointermove,
        .get_onpointerout = &get_onpointerout,
        .get_onpointerover = &get_onpointerover,
        .get_onpointerrawupdate = &get_onpointerrawupdate,
        .get_onpointerup = &get_onpointerup,
        .get_onpopstate = &get_onpopstate,
        .get_onportalactivate = &get_onportalactivate,
        .get_onprogress = &get_onprogress,
        .get_onratechange = &get_onratechange,
        .get_onrejectionhandled = &get_onrejectionhandled,
        .get_onreset = &get_onreset,
        .get_onresize = &get_onresize,
        .get_onscroll = &get_onscroll,
        .get_onscrollend = &get_onscrollend,
        .get_onsecuritypolicyviolation = &get_onsecuritypolicyviolation,
        .get_onseeked = &get_onseeked,
        .get_onseeking = &get_onseeking,
        .get_onselect = &get_onselect,
        .get_onselectionchange = &get_onselectionchange,
        .get_onselectstart = &get_onselectstart,
        .get_onslotchange = &get_onslotchange,
        .get_onsnapchanged = &get_onsnapchanged,
        .get_onsnapchanging = &get_onsnapchanging,
        .get_onstalled = &get_onstalled,
        .get_onstorage = &get_onstorage,
        .get_onsubmit = &get_onsubmit,
        .get_onsuspend = &get_onsuspend,
        .get_ontimeupdate = &get_ontimeupdate,
        .get_ontoggle = &get_ontoggle,
        .get_ontouchcancel = &get_ontouchcancel,
        .get_ontouchend = &get_ontouchend,
        .get_ontouchmove = &get_ontouchmove,
        .get_ontouchstart = &get_ontouchstart,
        .get_ontransitioncancel = &get_ontransitioncancel,
        .get_ontransitionend = &get_ontransitionend,
        .get_ontransitionrun = &get_ontransitionrun,
        .get_ontransitionstart = &get_ontransitionstart,
        .get_onunhandledrejection = &get_onunhandledrejection,
        .get_onunload = &get_onunload,
        .get_onvolumechange = &get_onvolumechange,
        .get_onwaiting = &get_onwaiting,
        .get_onwebkitanimationend = &get_onwebkitanimationend,
        .get_onwebkitanimationiteration = &get_onwebkitanimationiteration,
        .get_onwebkitanimationstart = &get_onwebkitanimationstart,
        .get_onwebkittransitionend = &get_onwebkittransitionend,
        .get_onwheel = &get_onwheel,
        .get_opener = &get_opener,
        .get_orientation = &get_orientation,
        .get_origin = &get_origin,
        .get_originAgentCluster = &get_originAgentCluster,
        .get_outerHeight = &get_outerHeight,
        .get_outerWidth = &get_outerWidth,
        .get_pageXOffset = &get_pageXOffset,
        .get_pageYOffset = &get_pageYOffset,
        .get_parent = &get_parent,
        .get_performance = &get_performance,
        .get_personalbar = &get_personalbar,
        .get_portalHost = &get_portalHost,
        .get_pushManager = &get_pushManager,
        .get_scheduler = &get_scheduler,
        .get_screen = &get_screen,
        .get_screenLeft = &get_screenLeft,
        .get_screenTop = &get_screenTop,
        .get_screenX = &get_screenX,
        .get_screenY = &get_screenY,
        .get_scrollX = &get_scrollX,
        .get_scrollY = &get_scrollY,
        .get_scrollbars = &get_scrollbars,
        .get_self = &get_self,
        .get_sessionStorage = &get_sessionStorage,
        .get_sharedStorage = &get_sharedStorage,
        .get_speechSynthesis = &get_speechSynthesis,
        .get_status = &get_status,
        .get_statusbar = &get_statusbar,
        .get_toolbar = &get_toolbar,
        .get_top = &get_top,
        .get_trustedTypes = &get_trustedTypes,
        .get_viewport = &get_viewport,
        .get_visualViewport = &get_visualViewport,
        .get_window = &get_window,

        .set_clientInformation = &set_clientInformation,
        .set_devicePixelRatio = &set_devicePixelRatio,
        .set_event = &set_event,
        .set_external = &set_external,
        .set_frames = &set_frames,
        .set_innerHeight = &set_innerHeight,
        .set_innerWidth = &set_innerWidth,
        .set_length = &set_length,
        .set_location = &set_location,
        .set_locationbar = &set_locationbar,
        .set_menubar = &set_menubar,
        .set_name = &set_name,
        .set_navigation = &set_navigation,
        .set_onabort = &set_onabort,
        .set_onafterprint = &set_onafterprint,
        .set_onanimationcancel = &set_onanimationcancel,
        .set_onanimationend = &set_onanimationend,
        .set_onanimationiteration = &set_onanimationiteration,
        .set_onanimationstart = &set_onanimationstart,
        .set_onappinstalled = &set_onappinstalled,
        .set_onauxclick = &set_onauxclick,
        .set_onbeforeinput = &set_onbeforeinput,
        .set_onbeforeinstallprompt = &set_onbeforeinstallprompt,
        .set_onbeforematch = &set_onbeforematch,
        .set_onbeforeprint = &set_onbeforeprint,
        .set_onbeforetoggle = &set_onbeforetoggle,
        .set_onbeforeunload = &set_onbeforeunload,
        .set_onbeforexrselect = &set_onbeforexrselect,
        .set_onblur = &set_onblur,
        .set_oncancel = &set_oncancel,
        .set_oncanplay = &set_oncanplay,
        .set_oncanplaythrough = &set_oncanplaythrough,
        .set_onchange = &set_onchange,
        .set_onclick = &set_onclick,
        .set_onclose = &set_onclose,
        .set_oncommand = &set_oncommand,
        .set_oncontextlost = &set_oncontextlost,
        .set_oncontextmenu = &set_oncontextmenu,
        .set_oncontextrestored = &set_oncontextrestored,
        .set_oncopy = &set_oncopy,
        .set_oncuechange = &set_oncuechange,
        .set_oncut = &set_oncut,
        .set_ondblclick = &set_ondblclick,
        .set_ondevicemotion = &set_ondevicemotion,
        .set_ondeviceorientation = &set_ondeviceorientation,
        .set_ondeviceorientationabsolute = &set_ondeviceorientationabsolute,
        .set_ondrag = &set_ondrag,
        .set_ondragend = &set_ondragend,
        .set_ondragenter = &set_ondragenter,
        .set_ondragleave = &set_ondragleave,
        .set_ondragover = &set_ondragover,
        .set_ondragstart = &set_ondragstart,
        .set_ondrop = &set_ondrop,
        .set_ondurationchange = &set_ondurationchange,
        .set_onemptied = &set_onemptied,
        .set_onended = &set_onended,
        .set_onerror = &set_onerror,
        .set_onfencedtreeclick = &set_onfencedtreeclick,
        .set_onfocus = &set_onfocus,
        .set_onformdata = &set_onformdata,
        .set_ongamepadconnected = &set_ongamepadconnected,
        .set_ongamepaddisconnected = &set_ongamepaddisconnected,
        .set_ongotpointercapture = &set_ongotpointercapture,
        .set_onhashchange = &set_onhashchange,
        .set_oninput = &set_oninput,
        .set_oninvalid = &set_oninvalid,
        .set_onkeydown = &set_onkeydown,
        .set_onkeypress = &set_onkeypress,
        .set_onkeyup = &set_onkeyup,
        .set_onlanguagechange = &set_onlanguagechange,
        .set_onload = &set_onload,
        .set_onloadeddata = &set_onloadeddata,
        .set_onloadedmetadata = &set_onloadedmetadata,
        .set_onloadstart = &set_onloadstart,
        .set_onlostpointercapture = &set_onlostpointercapture,
        .set_onmessage = &set_onmessage,
        .set_onmessageerror = &set_onmessageerror,
        .set_onmousedown = &set_onmousedown,
        .set_onmouseenter = &set_onmouseenter,
        .set_onmouseleave = &set_onmouseleave,
        .set_onmousemove = &set_onmousemove,
        .set_onmouseout = &set_onmouseout,
        .set_onmouseover = &set_onmouseover,
        .set_onmouseup = &set_onmouseup,
        .set_onoffline = &set_onoffline,
        .set_ononline = &set_ononline,
        .set_onorientationchange = &set_onorientationchange,
        .set_onpagehide = &set_onpagehide,
        .set_onpagereveal = &set_onpagereveal,
        .set_onpageshow = &set_onpageshow,
        .set_onpageswap = &set_onpageswap,
        .set_onpaste = &set_onpaste,
        .set_onpause = &set_onpause,
        .set_onplay = &set_onplay,
        .set_onplaying = &set_onplaying,
        .set_onpointercancel = &set_onpointercancel,
        .set_onpointerdown = &set_onpointerdown,
        .set_onpointerenter = &set_onpointerenter,
        .set_onpointerleave = &set_onpointerleave,
        .set_onpointermove = &set_onpointermove,
        .set_onpointerout = &set_onpointerout,
        .set_onpointerover = &set_onpointerover,
        .set_onpointerrawupdate = &set_onpointerrawupdate,
        .set_onpointerup = &set_onpointerup,
        .set_onpopstate = &set_onpopstate,
        .set_onportalactivate = &set_onportalactivate,
        .set_onprogress = &set_onprogress,
        .set_onratechange = &set_onratechange,
        .set_onrejectionhandled = &set_onrejectionhandled,
        .set_onreset = &set_onreset,
        .set_onresize = &set_onresize,
        .set_onscroll = &set_onscroll,
        .set_onscrollend = &set_onscrollend,
        .set_onsecuritypolicyviolation = &set_onsecuritypolicyviolation,
        .set_onseeked = &set_onseeked,
        .set_onseeking = &set_onseeking,
        .set_onselect = &set_onselect,
        .set_onselectionchange = &set_onselectionchange,
        .set_onselectstart = &set_onselectstart,
        .set_onslotchange = &set_onslotchange,
        .set_onsnapchanged = &set_onsnapchanged,
        .set_onsnapchanging = &set_onsnapchanging,
        .set_onstalled = &set_onstalled,
        .set_onstorage = &set_onstorage,
        .set_onsubmit = &set_onsubmit,
        .set_onsuspend = &set_onsuspend,
        .set_ontimeupdate = &set_ontimeupdate,
        .set_ontoggle = &set_ontoggle,
        .set_ontouchcancel = &set_ontouchcancel,
        .set_ontouchend = &set_ontouchend,
        .set_ontouchmove = &set_ontouchmove,
        .set_ontouchstart = &set_ontouchstart,
        .set_ontransitioncancel = &set_ontransitioncancel,
        .set_ontransitionend = &set_ontransitionend,
        .set_ontransitionrun = &set_ontransitionrun,
        .set_ontransitionstart = &set_ontransitionstart,
        .set_onunhandledrejection = &set_onunhandledrejection,
        .set_onunload = &set_onunload,
        .set_onvolumechange = &set_onvolumechange,
        .set_onwaiting = &set_onwaiting,
        .set_onwebkitanimationend = &set_onwebkitanimationend,
        .set_onwebkitanimationiteration = &set_onwebkitanimationiteration,
        .set_onwebkitanimationstart = &set_onwebkitanimationstart,
        .set_onwebkittransitionend = &set_onwebkittransitionend,
        .set_onwheel = &set_onwheel,
        .set_opener = &set_opener,
        .set_origin = &set_origin,
        .set_outerHeight = &set_outerHeight,
        .set_outerWidth = &set_outerWidth,
        .set_pageXOffset = &set_pageXOffset,
        .set_pageYOffset = &set_pageYOffset,
        .set_parent = &set_parent,
        .set_performance = &set_performance,
        .set_personalbar = &set_personalbar,
        .set_scheduler = &set_scheduler,
        .set_screen = &set_screen,
        .set_screenLeft = &set_screenLeft,
        .set_screenTop = &set_screenTop,
        .set_screenX = &set_screenX,
        .set_screenY = &set_screenY,
        .set_scrollX = &set_scrollX,
        .set_scrollY = &set_scrollY,
        .set_scrollbars = &set_scrollbars,
        .set_self = &set_self,
        .set_status = &set_status,
        .set_statusbar = &set_statusbar,
        .set_toolbar = &set_toolbar,
        .set_viewport = &set_viewport,
        .set_visualViewport = &set_visualViewport,

        .call_alert = &call_alert,
        .call_atob = &call_atob,
        .call_blur = &call_blur,
        .call_btoa = &call_btoa,
        .call_cancelAnimationFrame = &call_cancelAnimationFrame,
        .call_cancelIdleCallback = &call_cancelIdleCallback,
        .call_captureEvents = &call_captureEvents,
        .call_clearInterval = &call_clearInterval,
        .call_clearTimeout = &call_clearTimeout,
        .call_close = &call_close,
        .call_confirm = &call_confirm,
        .call_createImageBitmap = &call_createImageBitmap,
        .call_fetch = &call_fetch,
        .call_fetchLater = &call_fetchLater,
        .call_focus = &call_focus,
        .call_getComputedStyle = &call_getComputedStyle,
        .call_getDigitalGoodsService = &call_getDigitalGoodsService,
        .call_getScreenDetails = &call_getScreenDetails,
        .call_getSelection = &call_getSelection,
        .call_item = &call_item,
        .call_matchMedia = &call_matchMedia,
        .call_moveBy = &call_moveBy,
        .call_moveTo = &call_moveTo,
        .call_navigate = &call_navigate,
        .call_open = &call_open,
        .call_postMessage = &call_postMessage,
        .call_print = &call_print,
        .call_prompt = &call_prompt,
        .call_queryLocalFonts = &call_queryLocalFonts,
        .call_queueMicrotask = &call_queueMicrotask,
        .call_releaseEvents = &call_releaseEvents,
        .call_reportError = &call_reportError,
        .call_requestAnimationFrame = &call_requestAnimationFrame,
        .call_requestIdleCallback = &call_requestIdleCallback,
        .call_resizeBy = &call_resizeBy,
        .call_resizeTo = &call_resizeTo,
        .call_scroll = &call_scroll,
        .call_scrollBy = &call_scrollBy,
        .call_scrollTo = &call_scrollTo,
        .call_setInterval = &call_setInterval,
        .call_setTimeout = &call_setTimeout,
        .call_showDirectoryPicker = &call_showDirectoryPicker,
        .call_showOpenFilePicker = &call_showOpenFilePicker,
        .call_showSaveFilePicker = &call_showSaveFilePicker,
        .call_stop = &call_stop,
        .call_structuredClone = &call_structuredClone,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates, Meta.name, State);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return WindowImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return WindowImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WindowImpl.deinit(instance);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_window(instance: *runtime.Instance) anyerror!WindowProxy {
        return try WindowImpl.get_window(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_self(instance: *runtime.Instance) anyerror!WindowProxy {
        return try WindowImpl.get_self(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn set_self(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        // [Replaceable] - Create own property on the object using [[DefineOwnProperty]]
        // Per WebIDL spec: PropertyDescriptor{[[Value]]: V, [[Writable]]: true,
        //                                     [[Enumerable]]: true, [[Configurable]]: true}
        try runtime.defineOwnProperty(instance, "self", value);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_document(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WindowImpl.get_document(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try WindowImpl.get_name(instance);
    }

    pub fn set_name(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try WindowImpl.set_name(instance, value);
    }

    /// Extended attributes: [PutForwards=href], [LegacyUnforgeable]
    pub fn get_location(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WindowImpl.get_location(instance);
    }

    /// Extended attributes: [PutForwards=href], [LegacyUnforgeable]
    pub fn set_location(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [PutForwards] - Get target object and set the forwarded property
        // Per WebIDL spec: setting 'location' forwards to 'href' on the attribute's value
        const target = try get_location(instance);

        // Use JavaScript [[Set]] semantics to set the forwarded property
        // This respects prototype chain and user-defined setters
        try runtime.setPropertyOnInstance(target, "href", value);
    }

    pub fn get_history(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WindowImpl.get_history(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_navigation(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WindowImpl.get_navigation(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn set_navigation(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        // [Replaceable] - Create own property on the object using [[DefineOwnProperty]]
        // Per WebIDL spec: PropertyDescriptor{[[Value]]: V, [[Writable]]: true,
        //                                     [[Enumerable]]: true, [[Configurable]]: true}
        try runtime.defineOwnProperty(instance, "navigation", value);
    }

    pub fn get_customElements(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WindowImpl.get_customElements(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_locationbar(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WindowImpl.get_locationbar(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn set_locationbar(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        // [Replaceable] - Create own property on the object using [[DefineOwnProperty]]
        // Per WebIDL spec: PropertyDescriptor{[[Value]]: V, [[Writable]]: true,
        //                                     [[Enumerable]]: true, [[Configurable]]: true}
        try runtime.defineOwnProperty(instance, "locationbar", value);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_menubar(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WindowImpl.get_menubar(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn set_menubar(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        // [Replaceable] - Create own property on the object using [[DefineOwnProperty]]
        // Per WebIDL spec: PropertyDescriptor{[[Value]]: V, [[Writable]]: true,
        //                                     [[Enumerable]]: true, [[Configurable]]: true}
        try runtime.defineOwnProperty(instance, "menubar", value);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_personalbar(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WindowImpl.get_personalbar(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn set_personalbar(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        // [Replaceable] - Create own property on the object using [[DefineOwnProperty]]
        // Per WebIDL spec: PropertyDescriptor{[[Value]]: V, [[Writable]]: true,
        //                                     [[Enumerable]]: true, [[Configurable]]: true}
        try runtime.defineOwnProperty(instance, "personalbar", value);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_scrollbars(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WindowImpl.get_scrollbars(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn set_scrollbars(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        // [Replaceable] - Create own property on the object using [[DefineOwnProperty]]
        // Per WebIDL spec: PropertyDescriptor{[[Value]]: V, [[Writable]]: true,
        //                                     [[Enumerable]]: true, [[Configurable]]: true}
        try runtime.defineOwnProperty(instance, "scrollbars", value);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_statusbar(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WindowImpl.get_statusbar(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn set_statusbar(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        // [Replaceable] - Create own property on the object using [[DefineOwnProperty]]
        // Per WebIDL spec: PropertyDescriptor{[[Value]]: V, [[Writable]]: true,
        //                                     [[Enumerable]]: true, [[Configurable]]: true}
        try runtime.defineOwnProperty(instance, "statusbar", value);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_toolbar(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WindowImpl.get_toolbar(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn set_toolbar(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        // [Replaceable] - Create own property on the object using [[DefineOwnProperty]]
        // Per WebIDL spec: PropertyDescriptor{[[Value]]: V, [[Writable]]: true,
        //                                     [[Enumerable]]: true, [[Configurable]]: true}
        try runtime.defineOwnProperty(instance, "toolbar", value);
    }

    pub fn get_status(instance: *runtime.Instance) anyerror!DOMString {
        return try WindowImpl.get_status(instance);
    }

    pub fn set_status(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try WindowImpl.set_status(instance, value);
    }

    pub fn get_closed(instance: *runtime.Instance) anyerror!bool {
        return try WindowImpl.get_closed(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_frames(instance: *runtime.Instance) anyerror!WindowProxy {
        return try WindowImpl.get_frames(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn set_frames(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        // [Replaceable] - Create own property on the object using [[DefineOwnProperty]]
        // Per WebIDL spec: PropertyDescriptor{[[Value]]: V, [[Writable]]: true,
        //                                     [[Enumerable]]: true, [[Configurable]]: true}
        try runtime.defineOwnProperty(instance, "frames", value);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try WindowImpl.get_length(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn set_length(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        // [Replaceable] - Create own property on the object using [[DefineOwnProperty]]
        // Per WebIDL spec: PropertyDescriptor{[[Value]]: V, [[Writable]]: true,
        //                                     [[Enumerable]]: true, [[Configurable]]: true}
        try runtime.defineOwnProperty(instance, "length", value);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_top(instance: *runtime.Instance) anyerror!?WindowProxy {
        return try WindowImpl.get_top(instance);
    }

    pub fn get_opener(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try WindowImpl.get_opener(instance);
    }

    pub fn set_opener(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        try WindowImpl.set_opener(instance, value);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_parent(instance: *runtime.Instance) anyerror!?WindowProxy {
        return try WindowImpl.get_parent(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn set_parent(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        // [Replaceable] - Create own property on the object using [[DefineOwnProperty]]
        // Per WebIDL spec: PropertyDescriptor{[[Value]]: V, [[Writable]]: true,
        //                                     [[Enumerable]]: true, [[Configurable]]: true}
        try runtime.defineOwnProperty(instance, "parent", value);
    }

    pub fn get_frameElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try WindowImpl.get_frameElement(instance);
    }

    pub fn get_navigator(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WindowImpl.get_navigator(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_clientInformation(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WindowImpl.get_clientInformation(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn set_clientInformation(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        // [Replaceable] - Create own property on the object using [[DefineOwnProperty]]
        // Per WebIDL spec: PropertyDescriptor{[[Value]]: V, [[Writable]]: true,
        //                                     [[Enumerable]]: true, [[Configurable]]: true}
        try runtime.defineOwnProperty(instance, "clientInformation", value);
    }

    pub fn get_originAgentCluster(instance: *runtime.Instance) anyerror!bool {
        return try WindowImpl.get_originAgentCluster(instance);
    }

    /// Extended attributes: [SecureContext]
    pub fn get_ondeviceorientation(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_ondeviceorientation(instance);
    }

    /// Extended attributes: [SecureContext]
    pub fn set_ondeviceorientation(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_ondeviceorientation(instance, value);
    }

    /// Extended attributes: [SecureContext]
    pub fn get_ondeviceorientationabsolute(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_ondeviceorientationabsolute(instance);
    }

    /// Extended attributes: [SecureContext]
    pub fn set_ondeviceorientationabsolute(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_ondeviceorientationabsolute(instance, value);
    }

    /// Extended attributes: [SecureContext]
    pub fn get_ondevicemotion(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_ondevicemotion(instance);
    }

    /// Extended attributes: [SecureContext]
    pub fn set_ondevicemotion(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_ondevicemotion(instance, value);
    }

    /// Extended attributes: [SameObject], [Replaceable]
    pub fn get_viewport(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_viewport) |cached| {
            return cached;
        }
        const value = try WindowImpl.get_viewport(instance);
        state.own.cached_viewport = value;
        return value;
    }

    /// Extended attributes: [SameObject], [Replaceable]
    pub fn set_viewport(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        // [Replaceable] - Create own property on the object using [[DefineOwnProperty]]
        // Per WebIDL spec: PropertyDescriptor{[[Value]]: V, [[Writable]]: true,
        //                                     [[Enumerable]]: true, [[Configurable]]: true}
        try runtime.defineOwnProperty(instance, "viewport", value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_cookieStore(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_cookieStore) |cached| {
            return cached;
        }
        const value = try WindowImpl.get_cookieStore(instance);
        state.own.cached_cookieStore = value;
        return value;
    }

    pub fn get_credentialless(instance: *runtime.Instance) anyerror!bool {
        return try WindowImpl.get_credentialless(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_speechSynthesis(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_speechSynthesis) |cached| {
            return cached;
        }
        const value = try WindowImpl.get_speechSynthesis(instance);
        state.own.cached_speechSynthesis = value;
        return value;
    }

    pub fn get_fence(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try WindowImpl.get_fence(instance);
    }

    /// Extended attributes: [SameObject], [SecureContext]
    pub fn get_documentPictureInPicture(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_documentPictureInPicture) |cached| {
            return cached;
        }
        const value = try WindowImpl.get_documentPictureInPicture(instance);
        state.own.cached_documentPictureInPicture = value;
        return value;
    }

    /// Extended attributes: [Replaceable]
    pub fn get_event(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try WindowImpl.get_event(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn set_event(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        // [Replaceable] - Create own property on the object using [[DefineOwnProperty]]
        // Per WebIDL spec: PropertyDescriptor{[[Value]]: V, [[Writable]]: true,
        //                                     [[Enumerable]]: true, [[Configurable]]: true}
        try runtime.defineOwnProperty(instance, "event", value);
    }

    pub fn get_orientation(instance: *runtime.Instance) anyerror!i16 {
        return try WindowImpl.get_orientation(instance);
    }

    pub fn get_onorientationchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onorientationchange(instance);
    }

    pub fn set_onorientationchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onorientationchange(instance, value);
    }

    /// Extended attributes: [SecureContext]
    pub fn get_sharedStorage(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try WindowImpl.get_sharedStorage(instance);
    }

    pub fn get_onappinstalled(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onappinstalled(instance);
    }

    pub fn set_onappinstalled(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onappinstalled(instance, value);
    }

    pub fn get_onbeforeinstallprompt(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onbeforeinstallprompt(instance);
    }

    pub fn set_onbeforeinstallprompt(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onbeforeinstallprompt(instance, value);
    }

    /// Extended attributes: [Replaceable], [SameObject]
    pub fn get_external(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_external) |cached| {
            return cached;
        }
        const value = try WindowImpl.get_external(instance);
        state.own.cached_external = value;
        return value;
    }

    /// Extended attributes: [Replaceable], [SameObject]
    pub fn set_external(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        // [Replaceable] - Create own property on the object using [[DefineOwnProperty]]
        // Per WebIDL spec: PropertyDescriptor{[[Value]]: V, [[Writable]]: true,
        //                                     [[Enumerable]]: true, [[Configurable]]: true}
        try runtime.defineOwnProperty(instance, "external", value);
    }

    /// Extended attributes: [SameObject], [Replaceable]
    pub fn get_screen(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_screen) |cached| {
            return cached;
        }
        const value = try WindowImpl.get_screen(instance);
        state.own.cached_screen = value;
        return value;
    }

    /// Extended attributes: [SameObject], [Replaceable]
    pub fn set_screen(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        // [Replaceable] - Create own property on the object using [[DefineOwnProperty]]
        // Per WebIDL spec: PropertyDescriptor{[[Value]]: V, [[Writable]]: true,
        //                                     [[Enumerable]]: true, [[Configurable]]: true}
        try runtime.defineOwnProperty(instance, "screen", value);
    }

    /// Extended attributes: [SameObject], [Replaceable]
    pub fn get_visualViewport(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_visualViewport) |cached| {
            return cached;
        }
        const value = try WindowImpl.get_visualViewport(instance);
        state.own.cached_visualViewport = value;
        return value;
    }

    /// Extended attributes: [SameObject], [Replaceable]
    pub fn set_visualViewport(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        // [Replaceable] - Create own property on the object using [[DefineOwnProperty]]
        // Per WebIDL spec: PropertyDescriptor{[[Value]]: V, [[Writable]]: true,
        //                                     [[Enumerable]]: true, [[Configurable]]: true}
        try runtime.defineOwnProperty(instance, "visualViewport", value);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_innerWidth(instance: *runtime.Instance) anyerror!i32 {
        return try WindowImpl.get_innerWidth(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn set_innerWidth(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        // [Replaceable] - Create own property on the object using [[DefineOwnProperty]]
        // Per WebIDL spec: PropertyDescriptor{[[Value]]: V, [[Writable]]: true,
        //                                     [[Enumerable]]: true, [[Configurable]]: true}
        try runtime.defineOwnProperty(instance, "innerWidth", value);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_innerHeight(instance: *runtime.Instance) anyerror!i32 {
        return try WindowImpl.get_innerHeight(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn set_innerHeight(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        // [Replaceable] - Create own property on the object using [[DefineOwnProperty]]
        // Per WebIDL spec: PropertyDescriptor{[[Value]]: V, [[Writable]]: true,
        //                                     [[Enumerable]]: true, [[Configurable]]: true}
        try runtime.defineOwnProperty(instance, "innerHeight", value);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_scrollX(instance: *runtime.Instance) anyerror!f64 {
        return try WindowImpl.get_scrollX(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn set_scrollX(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        // [Replaceable] - Create own property on the object using [[DefineOwnProperty]]
        // Per WebIDL spec: PropertyDescriptor{[[Value]]: V, [[Writable]]: true,
        //                                     [[Enumerable]]: true, [[Configurable]]: true}
        try runtime.defineOwnProperty(instance, "scrollX", value);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_pageXOffset(instance: *runtime.Instance) anyerror!f64 {
        return try WindowImpl.get_pageXOffset(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn set_pageXOffset(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        // [Replaceable] - Create own property on the object using [[DefineOwnProperty]]
        // Per WebIDL spec: PropertyDescriptor{[[Value]]: V, [[Writable]]: true,
        //                                     [[Enumerable]]: true, [[Configurable]]: true}
        try runtime.defineOwnProperty(instance, "pageXOffset", value);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_scrollY(instance: *runtime.Instance) anyerror!f64 {
        return try WindowImpl.get_scrollY(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn set_scrollY(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        // [Replaceable] - Create own property on the object using [[DefineOwnProperty]]
        // Per WebIDL spec: PropertyDescriptor{[[Value]]: V, [[Writable]]: true,
        //                                     [[Enumerable]]: true, [[Configurable]]: true}
        try runtime.defineOwnProperty(instance, "scrollY", value);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_pageYOffset(instance: *runtime.Instance) anyerror!f64 {
        return try WindowImpl.get_pageYOffset(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn set_pageYOffset(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        // [Replaceable] - Create own property on the object using [[DefineOwnProperty]]
        // Per WebIDL spec: PropertyDescriptor{[[Value]]: V, [[Writable]]: true,
        //                                     [[Enumerable]]: true, [[Configurable]]: true}
        try runtime.defineOwnProperty(instance, "pageYOffset", value);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_screenX(instance: *runtime.Instance) anyerror!i32 {
        return try WindowImpl.get_screenX(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn set_screenX(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        // [Replaceable] - Create own property on the object using [[DefineOwnProperty]]
        // Per WebIDL spec: PropertyDescriptor{[[Value]]: V, [[Writable]]: true,
        //                                     [[Enumerable]]: true, [[Configurable]]: true}
        try runtime.defineOwnProperty(instance, "screenX", value);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_screenLeft(instance: *runtime.Instance) anyerror!i32 {
        return try WindowImpl.get_screenLeft(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn set_screenLeft(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        // [Replaceable] - Create own property on the object using [[DefineOwnProperty]]
        // Per WebIDL spec: PropertyDescriptor{[[Value]]: V, [[Writable]]: true,
        //                                     [[Enumerable]]: true, [[Configurable]]: true}
        try runtime.defineOwnProperty(instance, "screenLeft", value);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_screenY(instance: *runtime.Instance) anyerror!i32 {
        return try WindowImpl.get_screenY(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn set_screenY(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        // [Replaceable] - Create own property on the object using [[DefineOwnProperty]]
        // Per WebIDL spec: PropertyDescriptor{[[Value]]: V, [[Writable]]: true,
        //                                     [[Enumerable]]: true, [[Configurable]]: true}
        try runtime.defineOwnProperty(instance, "screenY", value);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_screenTop(instance: *runtime.Instance) anyerror!i32 {
        return try WindowImpl.get_screenTop(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn set_screenTop(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        // [Replaceable] - Create own property on the object using [[DefineOwnProperty]]
        // Per WebIDL spec: PropertyDescriptor{[[Value]]: V, [[Writable]]: true,
        //                                     [[Enumerable]]: true, [[Configurable]]: true}
        try runtime.defineOwnProperty(instance, "screenTop", value);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_outerWidth(instance: *runtime.Instance) anyerror!i32 {
        return try WindowImpl.get_outerWidth(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn set_outerWidth(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        // [Replaceable] - Create own property on the object using [[DefineOwnProperty]]
        // Per WebIDL spec: PropertyDescriptor{[[Value]]: V, [[Writable]]: true,
        //                                     [[Enumerable]]: true, [[Configurable]]: true}
        try runtime.defineOwnProperty(instance, "outerWidth", value);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_outerHeight(instance: *runtime.Instance) anyerror!i32 {
        return try WindowImpl.get_outerHeight(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn set_outerHeight(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        // [Replaceable] - Create own property on the object using [[DefineOwnProperty]]
        // Per WebIDL spec: PropertyDescriptor{[[Value]]: V, [[Writable]]: true,
        //                                     [[Enumerable]]: true, [[Configurable]]: true}
        try runtime.defineOwnProperty(instance, "outerHeight", value);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_devicePixelRatio(instance: *runtime.Instance) anyerror!f64 {
        return try WindowImpl.get_devicePixelRatio(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn set_devicePixelRatio(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        // [Replaceable] - Create own property on the object using [[DefineOwnProperty]]
        // Per WebIDL spec: PropertyDescriptor{[[Value]]: V, [[Writable]]: true,
        //                                     [[Enumerable]]: true, [[Configurable]]: true}
        try runtime.defineOwnProperty(instance, "devicePixelRatio", value);
    }

    pub fn get_launchQueue(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WindowImpl.get_launchQueue(instance);
    }

    pub fn get_portalHost(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try WindowImpl.get_portalHost(instance);
    }

    pub fn get_pushManager(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WindowImpl.get_pushManager(instance);
    }

    pub const get_onabort = mixins.GlobalEventHandlers.get_onabort;
    pub const set_onabort = mixins.GlobalEventHandlers.set_onabort;

    pub const get_onauxclick = mixins.GlobalEventHandlers.get_onauxclick;
    pub const set_onauxclick = mixins.GlobalEventHandlers.set_onauxclick;

    pub const get_onbeforeinput = mixins.GlobalEventHandlers.get_onbeforeinput;
    pub const set_onbeforeinput = mixins.GlobalEventHandlers.set_onbeforeinput;

    pub const get_onbeforematch = mixins.GlobalEventHandlers.get_onbeforematch;
    pub const set_onbeforematch = mixins.GlobalEventHandlers.set_onbeforematch;

    pub const get_onbeforetoggle = mixins.GlobalEventHandlers.get_onbeforetoggle;
    pub const set_onbeforetoggle = mixins.GlobalEventHandlers.set_onbeforetoggle;

    pub const get_onblur = mixins.GlobalEventHandlers.get_onblur;
    pub const set_onblur = mixins.GlobalEventHandlers.set_onblur;

    pub const get_oncancel = mixins.GlobalEventHandlers.get_oncancel;
    pub const set_oncancel = mixins.GlobalEventHandlers.set_oncancel;

    pub const get_oncanplay = mixins.GlobalEventHandlers.get_oncanplay;
    pub const set_oncanplay = mixins.GlobalEventHandlers.set_oncanplay;

    pub const get_oncanplaythrough = mixins.GlobalEventHandlers.get_oncanplaythrough;
    pub const set_oncanplaythrough = mixins.GlobalEventHandlers.set_oncanplaythrough;

    pub const get_onchange = mixins.GlobalEventHandlers.get_onchange;
    pub const set_onchange = mixins.GlobalEventHandlers.set_onchange;

    pub const get_onclick = mixins.GlobalEventHandlers.get_onclick;
    pub const set_onclick = mixins.GlobalEventHandlers.set_onclick;

    pub const get_onclose = mixins.GlobalEventHandlers.get_onclose;
    pub const set_onclose = mixins.GlobalEventHandlers.set_onclose;

    pub const get_oncommand = mixins.GlobalEventHandlers.get_oncommand;
    pub const set_oncommand = mixins.GlobalEventHandlers.set_oncommand;

    pub const get_oncontextlost = mixins.GlobalEventHandlers.get_oncontextlost;
    pub const set_oncontextlost = mixins.GlobalEventHandlers.set_oncontextlost;

    pub const get_oncontextmenu = mixins.GlobalEventHandlers.get_oncontextmenu;
    pub const set_oncontextmenu = mixins.GlobalEventHandlers.set_oncontextmenu;

    pub const get_oncontextrestored = mixins.GlobalEventHandlers.get_oncontextrestored;
    pub const set_oncontextrestored = mixins.GlobalEventHandlers.set_oncontextrestored;

    pub const get_oncopy = mixins.GlobalEventHandlers.get_oncopy;
    pub const set_oncopy = mixins.GlobalEventHandlers.set_oncopy;

    pub const get_oncuechange = mixins.GlobalEventHandlers.get_oncuechange;
    pub const set_oncuechange = mixins.GlobalEventHandlers.set_oncuechange;

    pub const get_oncut = mixins.GlobalEventHandlers.get_oncut;
    pub const set_oncut = mixins.GlobalEventHandlers.set_oncut;

    pub const get_ondblclick = mixins.GlobalEventHandlers.get_ondblclick;
    pub const set_ondblclick = mixins.GlobalEventHandlers.set_ondblclick;

    pub const get_ondrag = mixins.GlobalEventHandlers.get_ondrag;
    pub const set_ondrag = mixins.GlobalEventHandlers.set_ondrag;

    pub const get_ondragend = mixins.GlobalEventHandlers.get_ondragend;
    pub const set_ondragend = mixins.GlobalEventHandlers.set_ondragend;

    pub const get_ondragenter = mixins.GlobalEventHandlers.get_ondragenter;
    pub const set_ondragenter = mixins.GlobalEventHandlers.set_ondragenter;

    pub const get_ondragleave = mixins.GlobalEventHandlers.get_ondragleave;
    pub const set_ondragleave = mixins.GlobalEventHandlers.set_ondragleave;

    pub const get_ondragover = mixins.GlobalEventHandlers.get_ondragover;
    pub const set_ondragover = mixins.GlobalEventHandlers.set_ondragover;

    pub const get_ondragstart = mixins.GlobalEventHandlers.get_ondragstart;
    pub const set_ondragstart = mixins.GlobalEventHandlers.set_ondragstart;

    pub const get_ondrop = mixins.GlobalEventHandlers.get_ondrop;
    pub const set_ondrop = mixins.GlobalEventHandlers.set_ondrop;

    pub const get_ondurationchange = mixins.GlobalEventHandlers.get_ondurationchange;
    pub const set_ondurationchange = mixins.GlobalEventHandlers.set_ondurationchange;

    pub const get_onemptied = mixins.GlobalEventHandlers.get_onemptied;
    pub const set_onemptied = mixins.GlobalEventHandlers.set_onemptied;

    pub const get_onended = mixins.GlobalEventHandlers.get_onended;
    pub const set_onended = mixins.GlobalEventHandlers.set_onended;

    pub const get_onerror = mixins.GlobalEventHandlers.get_onerror;
    pub const set_onerror = mixins.GlobalEventHandlers.set_onerror;

    pub const get_onfocus = mixins.GlobalEventHandlers.get_onfocus;
    pub const set_onfocus = mixins.GlobalEventHandlers.set_onfocus;

    pub const get_onformdata = mixins.GlobalEventHandlers.get_onformdata;
    pub const set_onformdata = mixins.GlobalEventHandlers.set_onformdata;

    pub const get_oninput = mixins.GlobalEventHandlers.get_oninput;
    pub const set_oninput = mixins.GlobalEventHandlers.set_oninput;

    pub const get_oninvalid = mixins.GlobalEventHandlers.get_oninvalid;
    pub const set_oninvalid = mixins.GlobalEventHandlers.set_oninvalid;

    pub const get_onkeydown = mixins.GlobalEventHandlers.get_onkeydown;
    pub const set_onkeydown = mixins.GlobalEventHandlers.set_onkeydown;

    pub const get_onkeypress = mixins.GlobalEventHandlers.get_onkeypress;
    pub const set_onkeypress = mixins.GlobalEventHandlers.set_onkeypress;

    pub const get_onkeyup = mixins.GlobalEventHandlers.get_onkeyup;
    pub const set_onkeyup = mixins.GlobalEventHandlers.set_onkeyup;

    pub const get_onload = mixins.GlobalEventHandlers.get_onload;
    pub const set_onload = mixins.GlobalEventHandlers.set_onload;

    pub const get_onloadeddata = mixins.GlobalEventHandlers.get_onloadeddata;
    pub const set_onloadeddata = mixins.GlobalEventHandlers.set_onloadeddata;

    pub const get_onloadedmetadata = mixins.GlobalEventHandlers.get_onloadedmetadata;
    pub const set_onloadedmetadata = mixins.GlobalEventHandlers.set_onloadedmetadata;

    pub const get_onloadstart = mixins.GlobalEventHandlers.get_onloadstart;
    pub const set_onloadstart = mixins.GlobalEventHandlers.set_onloadstart;

    pub const get_onmousedown = mixins.GlobalEventHandlers.get_onmousedown;
    pub const set_onmousedown = mixins.GlobalEventHandlers.set_onmousedown;

    /// Extended attributes: [LegacyLenientThis]
    pub const get_onmouseenter = mixins.GlobalEventHandlers.get_onmouseenter;
    pub const set_onmouseenter = mixins.GlobalEventHandlers.set_onmouseenter;

    /// Extended attributes: [LegacyLenientThis]
    pub const get_onmouseleave = mixins.GlobalEventHandlers.get_onmouseleave;
    pub const set_onmouseleave = mixins.GlobalEventHandlers.set_onmouseleave;

    pub const get_onmousemove = mixins.GlobalEventHandlers.get_onmousemove;
    pub const set_onmousemove = mixins.GlobalEventHandlers.set_onmousemove;

    pub const get_onmouseout = mixins.GlobalEventHandlers.get_onmouseout;
    pub const set_onmouseout = mixins.GlobalEventHandlers.set_onmouseout;

    pub const get_onmouseover = mixins.GlobalEventHandlers.get_onmouseover;
    pub const set_onmouseover = mixins.GlobalEventHandlers.set_onmouseover;

    pub const get_onmouseup = mixins.GlobalEventHandlers.get_onmouseup;
    pub const set_onmouseup = mixins.GlobalEventHandlers.set_onmouseup;

    pub const get_onpaste = mixins.GlobalEventHandlers.get_onpaste;
    pub const set_onpaste = mixins.GlobalEventHandlers.set_onpaste;

    pub const get_onpause = mixins.GlobalEventHandlers.get_onpause;
    pub const set_onpause = mixins.GlobalEventHandlers.set_onpause;

    pub const get_onplay = mixins.GlobalEventHandlers.get_onplay;
    pub const set_onplay = mixins.GlobalEventHandlers.set_onplay;

    pub const get_onplaying = mixins.GlobalEventHandlers.get_onplaying;
    pub const set_onplaying = mixins.GlobalEventHandlers.set_onplaying;

    pub const get_onprogress = mixins.GlobalEventHandlers.get_onprogress;
    pub const set_onprogress = mixins.GlobalEventHandlers.set_onprogress;

    pub const get_onratechange = mixins.GlobalEventHandlers.get_onratechange;
    pub const set_onratechange = mixins.GlobalEventHandlers.set_onratechange;

    pub const get_onreset = mixins.GlobalEventHandlers.get_onreset;
    pub const set_onreset = mixins.GlobalEventHandlers.set_onreset;

    pub const get_onresize = mixins.GlobalEventHandlers.get_onresize;
    pub const set_onresize = mixins.GlobalEventHandlers.set_onresize;

    pub const get_onscroll = mixins.GlobalEventHandlers.get_onscroll;
    pub const set_onscroll = mixins.GlobalEventHandlers.set_onscroll;

    pub const get_onscrollend = mixins.GlobalEventHandlers.get_onscrollend;
    pub const set_onscrollend = mixins.GlobalEventHandlers.set_onscrollend;

    pub const get_onsecuritypolicyviolation = mixins.GlobalEventHandlers.get_onsecuritypolicyviolation;
    pub const set_onsecuritypolicyviolation = mixins.GlobalEventHandlers.set_onsecuritypolicyviolation;

    pub const get_onseeked = mixins.GlobalEventHandlers.get_onseeked;
    pub const set_onseeked = mixins.GlobalEventHandlers.set_onseeked;

    pub const get_onseeking = mixins.GlobalEventHandlers.get_onseeking;
    pub const set_onseeking = mixins.GlobalEventHandlers.set_onseeking;

    pub const get_onselect = mixins.GlobalEventHandlers.get_onselect;
    pub const set_onselect = mixins.GlobalEventHandlers.set_onselect;

    pub const get_onslotchange = mixins.GlobalEventHandlers.get_onslotchange;
    pub const set_onslotchange = mixins.GlobalEventHandlers.set_onslotchange;

    pub const get_onstalled = mixins.GlobalEventHandlers.get_onstalled;
    pub const set_onstalled = mixins.GlobalEventHandlers.set_onstalled;

    pub const get_onsubmit = mixins.GlobalEventHandlers.get_onsubmit;
    pub const set_onsubmit = mixins.GlobalEventHandlers.set_onsubmit;

    pub const get_onsuspend = mixins.GlobalEventHandlers.get_onsuspend;
    pub const set_onsuspend = mixins.GlobalEventHandlers.set_onsuspend;

    pub const get_ontimeupdate = mixins.GlobalEventHandlers.get_ontimeupdate;
    pub const set_ontimeupdate = mixins.GlobalEventHandlers.set_ontimeupdate;

    pub const get_ontoggle = mixins.GlobalEventHandlers.get_ontoggle;
    pub const set_ontoggle = mixins.GlobalEventHandlers.set_ontoggle;

    pub const get_onvolumechange = mixins.GlobalEventHandlers.get_onvolumechange;
    pub const set_onvolumechange = mixins.GlobalEventHandlers.set_onvolumechange;

    pub const get_onwaiting = mixins.GlobalEventHandlers.get_onwaiting;
    pub const set_onwaiting = mixins.GlobalEventHandlers.set_onwaiting;

    pub const get_onwebkitanimationend = mixins.GlobalEventHandlers.get_onwebkitanimationend;
    pub const set_onwebkitanimationend = mixins.GlobalEventHandlers.set_onwebkitanimationend;

    pub const get_onwebkitanimationiteration = mixins.GlobalEventHandlers.get_onwebkitanimationiteration;
    pub const set_onwebkitanimationiteration = mixins.GlobalEventHandlers.set_onwebkitanimationiteration;

    pub const get_onwebkitanimationstart = mixins.GlobalEventHandlers.get_onwebkitanimationstart;
    pub const set_onwebkitanimationstart = mixins.GlobalEventHandlers.set_onwebkitanimationstart;

    pub const get_onwebkittransitionend = mixins.GlobalEventHandlers.get_onwebkittransitionend;
    pub const set_onwebkittransitionend = mixins.GlobalEventHandlers.set_onwebkittransitionend;

    pub const get_onwheel = mixins.GlobalEventHandlers.get_onwheel;
    pub const set_onwheel = mixins.GlobalEventHandlers.set_onwheel;

    pub const get_onselectstart = mixins.GlobalEventHandlers.get_onselectstart;
    pub const set_onselectstart = mixins.GlobalEventHandlers.set_onselectstart;

    pub const get_onselectionchange = mixins.GlobalEventHandlers.get_onselectionchange;
    pub const set_onselectionchange = mixins.GlobalEventHandlers.set_onselectionchange;

    pub const get_onanimationstart = mixins.GlobalEventHandlers.get_onanimationstart;
    pub const set_onanimationstart = mixins.GlobalEventHandlers.set_onanimationstart;

    pub const get_onanimationiteration = mixins.GlobalEventHandlers.get_onanimationiteration;
    pub const set_onanimationiteration = mixins.GlobalEventHandlers.set_onanimationiteration;

    pub const get_onanimationend = mixins.GlobalEventHandlers.get_onanimationend;
    pub const set_onanimationend = mixins.GlobalEventHandlers.set_onanimationend;

    pub const get_onanimationcancel = mixins.GlobalEventHandlers.get_onanimationcancel;
    pub const set_onanimationcancel = mixins.GlobalEventHandlers.set_onanimationcancel;

    pub const get_ontransitionrun = mixins.GlobalEventHandlers.get_ontransitionrun;
    pub const set_ontransitionrun = mixins.GlobalEventHandlers.set_ontransitionrun;

    pub const get_ontransitionstart = mixins.GlobalEventHandlers.get_ontransitionstart;
    pub const set_ontransitionstart = mixins.GlobalEventHandlers.set_ontransitionstart;

    pub const get_ontransitionend = mixins.GlobalEventHandlers.get_ontransitionend;
    pub const set_ontransitionend = mixins.GlobalEventHandlers.set_ontransitionend;

    pub const get_ontransitioncancel = mixins.GlobalEventHandlers.get_ontransitioncancel;
    pub const set_ontransitioncancel = mixins.GlobalEventHandlers.set_ontransitioncancel;

    pub const get_onbeforexrselect = mixins.GlobalEventHandlers.get_onbeforexrselect;
    pub const set_onbeforexrselect = mixins.GlobalEventHandlers.set_onbeforexrselect;

    pub const get_onpointerover = mixins.GlobalEventHandlers.get_onpointerover;
    pub const set_onpointerover = mixins.GlobalEventHandlers.set_onpointerover;

    pub const get_onpointerenter = mixins.GlobalEventHandlers.get_onpointerenter;
    pub const set_onpointerenter = mixins.GlobalEventHandlers.set_onpointerenter;

    pub const get_onpointerdown = mixins.GlobalEventHandlers.get_onpointerdown;
    pub const set_onpointerdown = mixins.GlobalEventHandlers.set_onpointerdown;

    pub const get_onpointermove = mixins.GlobalEventHandlers.get_onpointermove;
    pub const set_onpointermove = mixins.GlobalEventHandlers.set_onpointermove;

    /// Extended attributes: [SecureContext]
    pub const get_onpointerrawupdate = mixins.GlobalEventHandlers.get_onpointerrawupdate;
    pub const set_onpointerrawupdate = mixins.GlobalEventHandlers.set_onpointerrawupdate;

    pub const get_onpointerup = mixins.GlobalEventHandlers.get_onpointerup;
    pub const set_onpointerup = mixins.GlobalEventHandlers.set_onpointerup;

    pub const get_onpointercancel = mixins.GlobalEventHandlers.get_onpointercancel;
    pub const set_onpointercancel = mixins.GlobalEventHandlers.set_onpointercancel;

    pub const get_onpointerout = mixins.GlobalEventHandlers.get_onpointerout;
    pub const set_onpointerout = mixins.GlobalEventHandlers.set_onpointerout;

    pub const get_onpointerleave = mixins.GlobalEventHandlers.get_onpointerleave;
    pub const set_onpointerleave = mixins.GlobalEventHandlers.set_onpointerleave;

    pub const get_ongotpointercapture = mixins.GlobalEventHandlers.get_ongotpointercapture;
    pub const set_ongotpointercapture = mixins.GlobalEventHandlers.set_ongotpointercapture;

    pub const get_onlostpointercapture = mixins.GlobalEventHandlers.get_onlostpointercapture;
    pub const set_onlostpointercapture = mixins.GlobalEventHandlers.set_onlostpointercapture;

    pub const get_ontouchstart = mixins.GlobalEventHandlers.get_ontouchstart;
    pub const set_ontouchstart = mixins.GlobalEventHandlers.set_ontouchstart;

    pub const get_ontouchend = mixins.GlobalEventHandlers.get_ontouchend;
    pub const set_ontouchend = mixins.GlobalEventHandlers.set_ontouchend;

    pub const get_ontouchmove = mixins.GlobalEventHandlers.get_ontouchmove;
    pub const set_ontouchmove = mixins.GlobalEventHandlers.set_ontouchmove;

    pub const get_ontouchcancel = mixins.GlobalEventHandlers.get_ontouchcancel;
    pub const set_ontouchcancel = mixins.GlobalEventHandlers.set_ontouchcancel;

    pub const get_onfencedtreeclick = mixins.GlobalEventHandlers.get_onfencedtreeclick;
    pub const set_onfencedtreeclick = mixins.GlobalEventHandlers.set_onfencedtreeclick;

    pub const get_onsnapchanged = mixins.GlobalEventHandlers.get_onsnapchanged;
    pub const set_onsnapchanged = mixins.GlobalEventHandlers.set_onsnapchanged;

    pub const get_onsnapchanging = mixins.GlobalEventHandlers.get_onsnapchanging;
    pub const set_onsnapchanging = mixins.GlobalEventHandlers.set_onsnapchanging;

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

    /// Extended attributes: [Replaceable]
    pub fn get_origin(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try WindowImpl.get_origin(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn set_origin(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        // [Replaceable] - Create own property on the object using [[DefineOwnProperty]]
        // Per WebIDL spec: PropertyDescriptor{[[Value]]: V, [[Writable]]: true,
        //                                     [[Enumerable]]: true, [[Configurable]]: true}
        try runtime.defineOwnProperty(instance, "origin", value);
    }

    pub fn get_isSecureContext(instance: *runtime.Instance) anyerror!bool {
        return try WindowImpl.get_isSecureContext(instance);
    }

    pub fn get_crossOriginIsolated(instance: *runtime.Instance) anyerror!bool {
        return try WindowImpl.get_crossOriginIsolated(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_indexedDB(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_indexedDB) |cached| {
            return cached;
        }
        const value = try WindowImpl.get_indexedDB(instance);
        state.own.cached_indexedDB = value;
        return value;
    }

    pub fn get_trustedTypes(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WindowImpl.get_trustedTypes(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_performance(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WindowImpl.get_performance(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn set_performance(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        // [Replaceable] - Create own property on the object using [[DefineOwnProperty]]
        // Per WebIDL spec: PropertyDescriptor{[[Value]]: V, [[Writable]]: true,
        //                                     [[Enumerable]]: true, [[Configurable]]: true}
        try runtime.defineOwnProperty(instance, "performance", value);
    }

    /// Extended attributes: [SecureContext], [SameObject]
    pub fn get_caches(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_caches) |cached| {
            return cached;
        }
        const value = try WindowImpl.get_caches(instance);
        state.own.cached_caches = value;
        return value;
    }

    /// Extended attributes: [Replaceable]
    pub fn get_scheduler(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WindowImpl.get_scheduler(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn set_scheduler(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        // [Replaceable] - Create own property on the object using [[DefineOwnProperty]]
        // Per WebIDL spec: PropertyDescriptor{[[Value]]: V, [[Writable]]: true,
        //                                     [[Enumerable]]: true, [[Configurable]]: true}
        try runtime.defineOwnProperty(instance, "scheduler", value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_crypto(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_crypto) |cached| {
            return cached;
        }
        const value = try WindowImpl.get_crypto(instance);
        state.own.cached_crypto = value;
        return value;
    }

    pub fn get_sessionStorage(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WindowImpl.get_sessionStorage(instance);
    }

    pub fn get_localStorage(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WindowImpl.get_localStorage(instance);
    }

    pub fn call_structuredClone(instance: *runtime.Instance, value: runtime.JSValue, options: webidl.Opt(StructuredSerializeOptions)) anyerror!runtime.JSValue {
        return try WindowImpl.call_structuredClone(instance, value, options);
    }

    pub fn call_atob(instance: *runtime.Instance, data: DOMString) anyerror!runtime.ByteString {
        return try WindowImpl.call_atob(instance, data);
    }

    pub fn call_btoa(instance: *runtime.Instance, data: DOMString) anyerror!DOMString {
        return try WindowImpl.call_btoa(instance, data);
    }

    pub fn call_open(instance: *runtime.Instance, url: webidl.Opt(runtime.USVString), target: webidl.Opt(DOMString), features: webidl.Opt(DOMString)) anyerror!?WindowProxy {
        return try WindowImpl.call_open(instance, url, target, features);
    }

    pub fn call_moveTo(instance: *runtime.Instance, x: i32, y: i32) anyerror!void {
        return try WindowImpl.call_moveTo(instance, x, y);
    }

    pub fn call_showSaveFilePicker(instance: *runtime.Instance, options: webidl.Opt(SaveFilePickerOptions)) anyerror!runtime.JSValue {
        return try WindowImpl.call_showSaveFilePicker(instance, options);
    }

    pub fn call_confirm(instance: *runtime.Instance, message: webidl.Opt(DOMString)) anyerror!bool {
        return try WindowImpl.call_confirm(instance, message);
    }

    pub fn call_requestIdleCallback(instance: *runtime.Instance, callback: IdleRequestCallback, options: webidl.Opt(IdleRequestOptions)) anyerror!u32 {
        return try WindowImpl.call_requestIdleCallback(instance, callback, options);
    }

    pub fn call_cancelIdleCallback(instance: *runtime.Instance, handle: u32) anyerror!void {
        return try WindowImpl.call_cancelIdleCallback(instance, handle);
    }

    pub fn call_getter(instance: *runtime.Instance, name: DOMString) anyerror!runtime.JSValue {
        return try WindowImpl.call_getter(instance, name);
    }

    pub fn call_focus(instance: *runtime.Instance) anyerror!void {
        return try WindowImpl.call_focus(instance);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_getDigitalGoodsService(instance: *runtime.Instance, serviceProvider: DOMString) anyerror!runtime.JSValue {
        return try WindowImpl.call_getDigitalGoodsService(instance, serviceProvider);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_getScreenDetails(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try WindowImpl.call_getScreenDetails(instance);
    }

    pub fn call_reportError(instance: *runtime.Instance, e: runtime.JSValue) anyerror!void {
        return try WindowImpl.call_reportError(instance, e);
    }

    pub fn call_clearTimeout(instance: *runtime.Instance, id: webidl.Opt(i32)) anyerror!void {
        return try WindowImpl.call_clearTimeout(instance, id);
    }

    pub fn call_clearInterval(instance: *runtime.Instance, id: webidl.Opt(i32)) anyerror!void {
        return try WindowImpl.call_clearInterval(instance, id);
    }

    pub fn call_queueMicrotask(instance: *runtime.Instance, callback: VoidFunction) anyerror!void {
        return try WindowImpl.call_queueMicrotask(instance, callback);
    }

    pub fn call_requestAnimationFrame(instance: *runtime.Instance, callback: FrameRequestCallback) anyerror!u32 {
        return try WindowImpl.call_requestAnimationFrame(instance, callback);
    }

    pub fn call_blur(instance: *runtime.Instance) anyerror!void {
        return try WindowImpl.call_blur(instance);
    }

    pub fn call_prompt(instance: *runtime.Instance, message: webidl.Opt(DOMString), default: webidl.Opt(DOMString)) anyerror!?DOMString {
        return try WindowImpl.call_prompt(instance, message, default);
    }

    pub fn call_postMessage(instance: *runtime.Instance, message: runtime.JSValue, targetOrigin: runtime.USVString, transfer: webidl.Opt(runtime.JSValue)) anyerror!void {
        return try WindowImpl.call_postMessage(instance, message, targetOrigin, transfer);
    }

    pub fn call_captureEvents(instance: *runtime.Instance) anyerror!void {
        return try WindowImpl.call_captureEvents(instance);
    }

    pub fn call_alert(instance: *runtime.Instance) anyerror!void {
        return try WindowImpl.call_alert(instance);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try WindowImpl.call_close(instance);
    }

    pub fn call_releaseEvents(instance: *runtime.Instance) anyerror!void {
        return try WindowImpl.call_releaseEvents(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_matchMedia(instance: *runtime.Instance, query: CSSOMString) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object

        return try WindowImpl.call_matchMedia(instance, query);
    }

    pub fn call_showDirectoryPicker(instance: *runtime.Instance, options: webidl.Opt(DirectoryPickerOptions)) anyerror!runtime.JSValue {
        return try WindowImpl.call_showDirectoryPicker(instance, options);
    }

    pub fn call_moveBy(instance: *runtime.Instance, x: i32, y: i32) anyerror!void {
        return try WindowImpl.call_moveBy(instance, x, y);
    }

    pub fn call_scrollBy(instance: *runtime.Instance, options: webidl.Opt(ScrollToOptions)) anyerror!runtime.JSValue {
        return try WindowImpl.call_scrollBy(instance, options);
    }

    pub fn call_queryLocalFonts(instance: *runtime.Instance, options: webidl.Opt(QueryOptions)) anyerror!runtime.JSValue {
        return try WindowImpl.call_queryLocalFonts(instance, options);
    }

    pub fn call_setTimeout(instance: *runtime.Instance, handler: TimerHandler, timeout: webidl.Opt(i32), arguments: []const runtime.JSValue) anyerror!i32 {
        return try WindowImpl.call_setTimeout(instance, handler, timeout, arguments);
    }

    pub fn call_scrollTo(instance: *runtime.Instance, options: webidl.Opt(ScrollToOptions)) anyerror!runtime.JSValue {
        return try WindowImpl.call_scrollTo(instance, options);
    }

    pub fn call_setInterval(instance: *runtime.Instance, handler: TimerHandler, timeout: webidl.Opt(i32), arguments: []const runtime.JSValue) anyerror!i32 {
        return try WindowImpl.call_setInterval(instance, handler, timeout, arguments);
    }

    pub fn call_print(instance: *runtime.Instance) anyerror!void {
        return try WindowImpl.call_print(instance);
    }

    pub fn call_navigate(instance: *runtime.Instance, dir: SpatialNavigationDirection) anyerror!void {
        return try WindowImpl.call_navigate(instance, dir);
    }

    pub fn call_createImageBitmap(instance: *runtime.Instance, image: ImageBitmapSource, options: webidl.Opt(ImageBitmapOptions)) anyerror!runtime.JSValue {
        return try WindowImpl.call_createImageBitmap(instance, image, options);
    }

    pub fn call_showOpenFilePicker(instance: *runtime.Instance, options: webidl.Opt(OpenFilePickerOptions)) anyerror!runtime.JSValue {
        return try WindowImpl.call_showOpenFilePicker(instance, options);
    }

    /// Extended attributes: [NewObject], [SecureContext]
    pub fn call_fetchLater(instance: *runtime.Instance, input: RequestInfo, init_data: webidl.Opt(DeferredRequestInit)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object

        return try WindowImpl.call_fetchLater(instance, input, init_data);
    }

    pub fn call_resizeTo(instance: *runtime.Instance, width: i32, height: i32) anyerror!void {
        return try WindowImpl.call_resizeTo(instance, width, height);
    }

    /// Extended attributes: [NewObject]
    pub fn call_fetch(instance: *runtime.Instance, input: RequestInfo, init_data: webidl.Opt(RequestInit)) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object

        return try WindowImpl.call_fetch(instance, input, init_data);
    }

    pub fn call_getSelection(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try WindowImpl.call_getSelection(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getComputedStyle(instance: *runtime.Instance, elt: *runtime.Instance, pseudoElt: webidl.Opt(?CSSOMString)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object

        return try WindowImpl.call_getComputedStyle(instance, elt, pseudoElt);
    }

    pub fn call_resizeBy(instance: *runtime.Instance, x: i32, y: i32) anyerror!void {
        return try WindowImpl.call_resizeBy(instance, x, y);
    }

    pub fn call_stop(instance: *runtime.Instance) anyerror!void {
        return try WindowImpl.call_stop(instance);
    }

    pub fn call_cancelAnimationFrame(instance: *runtime.Instance, handle: u32) anyerror!void {
        return try WindowImpl.call_cancelAnimationFrame(instance, handle);
    }

    pub fn call_scroll(instance: *runtime.Instance, options: webidl.Opt(ScrollToOptions)) anyerror!runtime.JSValue {
        return try WindowImpl.call_scroll(instance, options);
    }

    pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!?WindowProxy {
        return try WindowImpl.call_item(instance, index);
    }

    pub fn call_postMessage__1(instance: *runtime.Instance, message: runtime.JSValue, options: webidl.Opt(WindowPostMessageOptions)) anyerror!void {
        if (comptime @hasDecl(WindowImpl, "call_postMessage__1")) {
            return try WindowImpl.call_postMessage__1(instance, message, options);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn call_alert__1(instance: *runtime.Instance, message: DOMString) anyerror!void {
        if (comptime @hasDecl(WindowImpl, "call_alert__1")) {
            return try WindowImpl.call_alert__1(instance, message);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn call_scrollBy__1(instance: *runtime.Instance, x: f64, y: f64) anyerror!runtime.JSValue {
        if (comptime @hasDecl(WindowImpl, "call_scrollBy__1")) {
            return try WindowImpl.call_scrollBy__1(instance, x, y);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn call_scrollTo__1(instance: *runtime.Instance, x: f64, y: f64) anyerror!runtime.JSValue {
        if (comptime @hasDecl(WindowImpl, "call_scrollTo__1")) {
            return try WindowImpl.call_scrollTo__1(instance, x, y);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn call_createImageBitmap__1(instance: *runtime.Instance, image: ImageBitmapSource, sx: i32, sy: i32, sw: i32, sh: i32, options: webidl.Opt(ImageBitmapOptions)) anyerror!runtime.JSValue {
        if (comptime @hasDecl(WindowImpl, "call_createImageBitmap__1")) {
            return try WindowImpl.call_createImageBitmap__1(instance, image, sx, sy, sw, sh, options);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn call_scroll__1(instance: *runtime.Instance, x: f64, y: f64) anyerror!runtime.JSValue {
        if (comptime @hasDecl(WindowImpl, "call_scroll__1")) {
            return try WindowImpl.call_scroll__1(instance, x, y);
        } else {
            return error.NotImplemented;
        }
    }

    /// WebIDL overload sets: every overload of each overloaded operation,
    /// in IDL order, for the overload resolution algorithm
    /// (webidl.overload_resolution). The binding is installed for the first
    /// overload and forwards to the one the arguments select.
    pub const overloads = .{
        .{ "postMessage", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_postMessage", .args = &.{ .{ .kinds = &.{.any} }, .{ .kinds = &.{.string} }, .{ .kinds = &.{.sequence}, .optionality = .optional } } },
            .{ .function = "call_postMessage__1", .implemented = @hasDecl(WindowImpl, "call_postMessage__1"), .args = &.{ .{ .kinds = &.{.any} }, .{ .kinds = &.{.dictionary}, .optionality = .optional } } },
        } },
        .{ "alert", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_alert", .args = &.{} },
            .{ .function = "call_alert__1", .implemented = @hasDecl(WindowImpl, "call_alert__1"), .args = &.{.{ .kinds = &.{.string} }} },
        } },
        .{ "scrollBy", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_scrollBy", .args = &.{.{ .kinds = &.{.dictionary}, .optionality = .optional }} },
            .{ .function = "call_scrollBy__1", .implemented = @hasDecl(WindowImpl, "call_scrollBy__1"), .args = &.{ .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} } } },
        } },
        .{ "scrollTo", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_scrollTo", .args = &.{.{ .kinds = &.{.dictionary}, .optionality = .optional }} },
            .{ .function = "call_scrollTo__1", .implemented = @hasDecl(WindowImpl, "call_scrollTo__1"), .args = &.{ .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} } } },
        } },
        .{ "createImageBitmap", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_createImageBitmap", .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{.dictionary}, .optionality = .optional } } },
            .{ .function = "call_createImageBitmap__1", .implemented = @hasDecl(WindowImpl, "call_createImageBitmap__1"), .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.dictionary}, .optionality = .optional } } },
        } },
        .{ "scroll", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_scroll", .args = &.{.{ .kinds = &.{.dictionary}, .optionality = .optional }} },
            .{ .function = "call_scroll__1", .implemented = @hasDecl(WindowImpl, "call_scroll__1"), .args = &.{ .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} } } },
        } },
    };

    /// WebIDL [LegacyNullToEmptyString]: the values null converts to "" for
    /// (bit i = argument i; an attribute setter's value is bit 0).
    pub const legacy_null_to_empty = .{
        .{ "call_open", 0b100 },
    };

    /// Get supported property names for named property enumeration (Reflect.ownKeys, etc.)
    /// Per WebIDL spec §3.9.3, returns names in list order for proper enumeration
    pub fn getSupportedPropertyNames(instance: *runtime.Instance, allocator: std.mem.Allocator) ![]runtime.DOMString {
        return WindowImpl.getSupportedPropertyNames(instance, allocator);
    }
};
