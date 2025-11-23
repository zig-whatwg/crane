//! Generated from: html.idl
//! Generated at: 2025-11-23T20:06:13Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WindowImpl = @import("impls").Window;
const EventTarget = @import("interfaces").EventTarget;
const PushManagerAttribute = @import("interfaces").PushManagerAttribute;
const GlobalEventHandlers = @import("interfaces").GlobalEventHandlers;
const WindowEventHandlers = @import("interfaces").WindowEventHandlers;
const WindowOrWorkerGlobalScope = @import("interfaces").WindowOrWorkerGlobalScope;
const AnimationFrameProvider = @import("interfaces").AnimationFrameProvider;
const WindowSessionStorage = @import("interfaces").WindowSessionStorage;
const WindowLocalStorage = @import("interfaces").WindowLocalStorage;
const External = @import("interfaces").External;
const CSSOMString = @import("typedefs").CSSOMString;
const Navigator = @import("interfaces").Navigator;
const FetchLaterResult = @import("interfaces").FetchLaterResult;
const ImageBitmapSource = @import("typedefs").ImageBitmapSource;
const TimerHandler = @import("typedefs").TimerHandler;
const USVString = @import("interfaces").USVString;
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
const ByteString = @import("interfaces").ByteString;
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
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
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
            .{ "self", "get_self", null },
            .{ "document", "get_document", null },
            .{ "name", "get_name", "set_name" },
            .{ "location", "get_location", null },
            .{ "history", "get_history", null },
            .{ "navigation", "get_navigation", null },
            .{ "customElements", "get_customElements", null },
            .{ "locationbar", "get_locationbar", null },
            .{ "menubar", "get_menubar", null },
            .{ "personalbar", "get_personalbar", null },
            .{ "scrollbars", "get_scrollbars", null },
            .{ "statusbar", "get_statusbar", null },
            .{ "toolbar", "get_toolbar", null },
            .{ "status", "get_status", "set_status" },
            .{ "closed", "get_closed", null },
            .{ "frames", "get_frames", null },
            .{ "length", "get_length", null },
            .{ "top", "get_top", null },
            .{ "opener", "get_opener", "set_opener" },
            .{ "parent", "get_parent", null },
            .{ "frameElement", "get_frameElement", null },
            .{ "navigator", "get_navigator", null },
            .{ "clientInformation", "get_clientInformation", null },
            .{ "originAgentCluster", "get_originAgentCluster", null },
            .{ "ondeviceorientation", "get_ondeviceorientation", "set_ondeviceorientation" },
            .{ "ondeviceorientationabsolute", "get_ondeviceorientationabsolute", "set_ondeviceorientationabsolute" },
            .{ "ondevicemotion", "get_ondevicemotion", "set_ondevicemotion" },
            .{ "viewport", "get_viewport", null },
            .{ "cookieStore", "get_cookieStore", null },
            .{ "credentialless", "get_credentialless", null },
            .{ "speechSynthesis", "get_speechSynthesis", null },
            .{ "fence", "get_fence", null },
            .{ "documentPictureInPicture", "get_documentPictureInPicture", null },
            .{ "event", "get_event", null },
            .{ "orientation", "get_orientation", null },
            .{ "onorientationchange", "get_onorientationchange", "set_onorientationchange" },
            .{ "sharedStorage", "get_sharedStorage", null },
            .{ "onappinstalled", "get_onappinstalled", "set_onappinstalled" },
            .{ "onbeforeinstallprompt", "get_onbeforeinstallprompt", "set_onbeforeinstallprompt" },
            .{ "external", "get_external", null },
            .{ "screen", "get_screen", null },
            .{ "visualViewport", "get_visualViewport", null },
            .{ "innerWidth", "get_innerWidth", null },
            .{ "innerHeight", "get_innerHeight", null },
            .{ "scrollX", "get_scrollX", null },
            .{ "pageXOffset", "get_pageXOffset", null },
            .{ "scrollY", "get_scrollY", null },
            .{ "pageYOffset", "get_pageYOffset", null },
            .{ "screenX", "get_screenX", null },
            .{ "screenLeft", "get_screenLeft", null },
            .{ "screenY", "get_screenY", null },
            .{ "screenTop", "get_screenTop", null },
            .{ "outerWidth", "get_outerWidth", null },
            .{ "outerHeight", "get_outerHeight", null },
            .{ "devicePixelRatio", "get_devicePixelRatio", null },
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
            .{ "origin", "get_origin", null },
            .{ "isSecureContext", "get_isSecureContext", null },
            .{ "crossOriginIsolated", "get_crossOriginIsolated", null },
            .{ "indexedDB", "get_indexedDB", null },
            .{ "trustedTypes", "get_trustedTypes", null },
            .{ "performance", "get_performance", null },
            .{ "caches", "get_caches", null },
            .{ "scheduler", "get_scheduler", null },
            .{ "crypto", "get_crypto", null },
            .{ "sessionStorage", "get_sessionStorage", null },
            .{ "localStorage", "get_localStorage", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "close", "call_close", 0 },
            .{ "stop", "call_stop", 0 },
            .{ "focus", "call_focus", 0 },
            .{ "blur", "call_blur", 0 },
            .{ "open", "call_open", 0 },
            .{ "alert", "call_alert", 0 },
            .{ "alert", "call_alert", 1 },
            .{ "confirm", "call_confirm", 0 },
            .{ "prompt", "call_prompt", 0 },
            .{ "print", "call_print", 0 },
            .{ "postMessage", "call_postMessage", 2 },
            .{ "postMessage", "call_postMessage", 1 },
            .{ "navigate", "call_navigate", 1 },
            .{ "showOpenFilePicker", "call_showOpenFilePicker", 0 },
            .{ "showSaveFilePicker", "call_showSaveFilePicker", 0 },
            .{ "showDirectoryPicker", "call_showDirectoryPicker", 0 },
            .{ "getDigitalGoodsService", "call_getDigitalGoodsService", 1 },
            .{ "getSelection", "call_getSelection", 0 },
            .{ "getScreenDetails", "call_getScreenDetails", 0 },
            .{ "getComputedStyle", "call_getComputedStyle", 1 },
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
            .{ "scroll", "call_scroll", 2 },
            .{ "scrollTo", "call_scrollTo", 0 },
            .{ "scrollTo", "call_scrollTo", 2 },
            .{ "scrollBy", "call_scrollBy", 0 },
            .{ "scrollBy", "call_scrollBy", 2 },
            .{ "queryLocalFonts", "call_queryLocalFonts", 0 },
            .{ "reportError", "call_reportError", 1 },
            .{ "btoa", "call_btoa", 1 },
            .{ "atob", "call_atob", 1 },
            .{ "setTimeout", "call_setTimeout", 2 },
            .{ "clearTimeout", "call_clearTimeout", 0 },
            .{ "setInterval", "call_setInterval", 2 },
            .{ "clearInterval", "call_clearInterval", 0 },
            .{ "queueMicrotask", "call_queueMicrotask", 1 },
            .{ "createImageBitmap", "call_createImageBitmap", 1 },
            .{ "createImageBitmap", "call_createImageBitmap", 5 },
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
            "alert",
            "confirm",
            "prompt",
            "print",
            "postMessage",
            "postMessage",
            "navigate",
            "showOpenFilePicker",
            "showSaveFilePicker",
            "showDirectoryPicker",
            "getDigitalGoodsService",
            "getSelection",
            "getScreenDetails",
            "getComputedStyle",
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
            "scroll",
            "scrollTo",
            "scrollTo",
            "scrollBy",
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
            .{ "self", "get_self", null },
            .{ "document", "get_document", null },
            .{ "name", "get_name", "set_name" },
            .{ "location", "get_location", null },
            .{ "history", "get_history", null },
            .{ "navigation", "get_navigation", null },
            .{ "customElements", "get_customElements", null },
            .{ "locationbar", "get_locationbar", null },
            .{ "menubar", "get_menubar", null },
            .{ "personalbar", "get_personalbar", null },
            .{ "scrollbars", "get_scrollbars", null },
            .{ "statusbar", "get_statusbar", null },
            .{ "toolbar", "get_toolbar", null },
            .{ "status", "get_status", "set_status" },
            .{ "closed", "get_closed", null },
            .{ "frames", "get_frames", null },
            .{ "length", "get_length", null },
            .{ "top", "get_top", null },
            .{ "opener", "get_opener", "set_opener" },
            .{ "parent", "get_parent", null },
            .{ "frameElement", "get_frameElement", null },
            .{ "navigator", "get_navigator", null },
            .{ "clientInformation", "get_clientInformation", null },
            .{ "originAgentCluster", "get_originAgentCluster", null },
            .{ "ondeviceorientation", "get_ondeviceorientation", "set_ondeviceorientation" },
            .{ "ondeviceorientationabsolute", "get_ondeviceorientationabsolute", "set_ondeviceorientationabsolute" },
            .{ "ondevicemotion", "get_ondevicemotion", "set_ondevicemotion" },
            .{ "viewport", "get_viewport", null },
            .{ "cookieStore", "get_cookieStore", null },
            .{ "credentialless", "get_credentialless", null },
            .{ "speechSynthesis", "get_speechSynthesis", null },
            .{ "fence", "get_fence", null },
            .{ "documentPictureInPicture", "get_documentPictureInPicture", null },
            .{ "event", "get_event", null },
            .{ "orientation", "get_orientation", null },
            .{ "onorientationchange", "get_onorientationchange", "set_onorientationchange" },
            .{ "sharedStorage", "get_sharedStorage", null },
            .{ "onappinstalled", "get_onappinstalled", "set_onappinstalled" },
            .{ "onbeforeinstallprompt", "get_onbeforeinstallprompt", "set_onbeforeinstallprompt" },
            .{ "external", "get_external", null },
            .{ "screen", "get_screen", null },
            .{ "visualViewport", "get_visualViewport", null },
            .{ "innerWidth", "get_innerWidth", null },
            .{ "innerHeight", "get_innerHeight", null },
            .{ "scrollX", "get_scrollX", null },
            .{ "pageXOffset", "get_pageXOffset", null },
            .{ "scrollY", "get_scrollY", null },
            .{ "pageYOffset", "get_pageYOffset", null },
            .{ "screenX", "get_screenX", null },
            .{ "screenLeft", "get_screenLeft", null },
            .{ "screenY", "get_screenY", null },
            .{ "screenTop", "get_screenTop", null },
            .{ "outerWidth", "get_outerWidth", null },
            .{ "outerHeight", "get_outerHeight", null },
            .{ "devicePixelRatio", "get_devicePixelRatio", null },
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
            .{ "origin", "get_origin", null },
            .{ "isSecureContext", "get_isSecureContext", null },
            .{ "crossOriginIsolated", "get_crossOriginIsolated", null },
            .{ "indexedDB", "get_indexedDB", null },
            .{ "trustedTypes", "get_trustedTypes", null },
            .{ "performance", "get_performance", null },
            .{ "caches", "get_caches", null },
            .{ "scheduler", "get_scheduler", null },
            .{ "crypto", "get_crypto", null },
            .{ "sessionStorage", "get_sessionStorage", null },
            .{ "localStorage", "get_localStorage", null },
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
            window: WindowProxy = undefined,
            self: WindowProxy = undefined,
            document: *runtime.Instance = undefined,
            name: runtime.DOMString = undefined,
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
            status: runtime.DOMString = undefined,
            closed: bool = undefined,
            frames: WindowProxy = undefined,
            length: u32 = undefined,
            top: ?WindowProxy = null,
            opener: *const anyopaque = undefined,
            parent: ?WindowProxy = null,
            frameElement: ?*runtime.Instance = null,
            navigator: *runtime.Instance = undefined,
            clientInformation: *runtime.Instance = undefined,
            originAgentCluster: bool = undefined,
            ondeviceorientation: EventHandler = undefined,
            ondeviceorientationabsolute: EventHandler = undefined,
            ondevicemotion: EventHandler = undefined,
            viewport: *runtime.Instance = undefined,
            cookieStore: *runtime.Instance = undefined,
            credentialless: bool = undefined,
            speechSynthesis: *runtime.Instance = undefined,
            fence: ?*runtime.Instance = null,
            documentPictureInPicture: *runtime.Instance = undefined,
            event: union(enum) {
                Event: Event,
                @"undefined": void,
            } = undefined,
            orientation: i16 = undefined,
            onorientationchange: EventHandler = undefined,
            sharedStorage: ?*runtime.Instance = null,
            onappinstalled: EventHandler = undefined,
            onbeforeinstallprompt: EventHandler = undefined,
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
            onabort: EventHandler = undefined,
            onauxclick: EventHandler = undefined,
            onbeforeinput: EventHandler = undefined,
            onbeforematch: EventHandler = undefined,
            onbeforetoggle: EventHandler = undefined,
            onblur: EventHandler = undefined,
            oncancel: EventHandler = undefined,
            oncanplay: EventHandler = undefined,
            oncanplaythrough: EventHandler = undefined,
            onchange: EventHandler = undefined,
            onclick: EventHandler = undefined,
            onclose: EventHandler = undefined,
            oncommand: EventHandler = undefined,
            oncontextlost: EventHandler = undefined,
            oncontextmenu: EventHandler = undefined,
            oncontextrestored: EventHandler = undefined,
            oncopy: EventHandler = undefined,
            oncuechange: EventHandler = undefined,
            oncut: EventHandler = undefined,
            ondblclick: EventHandler = undefined,
            ondrag: EventHandler = undefined,
            ondragend: EventHandler = undefined,
            ondragenter: EventHandler = undefined,
            ondragleave: EventHandler = undefined,
            ondragover: EventHandler = undefined,
            ondragstart: EventHandler = undefined,
            ondrop: EventHandler = undefined,
            ondurationchange: EventHandler = undefined,
            onemptied: EventHandler = undefined,
            onended: EventHandler = undefined,
            onerror: OnErrorEventHandler = undefined,
            onfocus: EventHandler = undefined,
            onformdata: EventHandler = undefined,
            oninput: EventHandler = undefined,
            oninvalid: EventHandler = undefined,
            onkeydown: EventHandler = undefined,
            onkeypress: EventHandler = undefined,
            onkeyup: EventHandler = undefined,
            onload: EventHandler = undefined,
            onloadeddata: EventHandler = undefined,
            onloadedmetadata: EventHandler = undefined,
            onloadstart: EventHandler = undefined,
            onmousedown: EventHandler = undefined,
            onmouseenter: EventHandler = undefined,
            onmouseleave: EventHandler = undefined,
            onmousemove: EventHandler = undefined,
            onmouseout: EventHandler = undefined,
            onmouseover: EventHandler = undefined,
            onmouseup: EventHandler = undefined,
            onpaste: EventHandler = undefined,
            onpause: EventHandler = undefined,
            onplay: EventHandler = undefined,
            onplaying: EventHandler = undefined,
            onprogress: EventHandler = undefined,
            onratechange: EventHandler = undefined,
            onreset: EventHandler = undefined,
            onresize: EventHandler = undefined,
            onscroll: EventHandler = undefined,
            onscrollend: EventHandler = undefined,
            onsecuritypolicyviolation: EventHandler = undefined,
            onseeked: EventHandler = undefined,
            onseeking: EventHandler = undefined,
            onselect: EventHandler = undefined,
            onslotchange: EventHandler = undefined,
            onstalled: EventHandler = undefined,
            onsubmit: EventHandler = undefined,
            onsuspend: EventHandler = undefined,
            ontimeupdate: EventHandler = undefined,
            ontoggle: EventHandler = undefined,
            onvolumechange: EventHandler = undefined,
            onwaiting: EventHandler = undefined,
            onwebkitanimationend: EventHandler = undefined,
            onwebkitanimationiteration: EventHandler = undefined,
            onwebkitanimationstart: EventHandler = undefined,
            onwebkittransitionend: EventHandler = undefined,
            onwheel: EventHandler = undefined,
            onselectstart: EventHandler = undefined,
            onselectionchange: EventHandler = undefined,
            onanimationstart: EventHandler = undefined,
            onanimationiteration: EventHandler = undefined,
            onanimationend: EventHandler = undefined,
            onanimationcancel: EventHandler = undefined,
            ontransitionrun: EventHandler = undefined,
            ontransitionstart: EventHandler = undefined,
            ontransitionend: EventHandler = undefined,
            ontransitioncancel: EventHandler = undefined,
            onbeforexrselect: EventHandler = undefined,
            onpointerover: EventHandler = undefined,
            onpointerenter: EventHandler = undefined,
            onpointerdown: EventHandler = undefined,
            onpointermove: EventHandler = undefined,
            onpointerrawupdate: EventHandler = undefined,
            onpointerup: EventHandler = undefined,
            onpointercancel: EventHandler = undefined,
            onpointerout: EventHandler = undefined,
            onpointerleave: EventHandler = undefined,
            ongotpointercapture: EventHandler = undefined,
            onlostpointercapture: EventHandler = undefined,
            ontouchstart: EventHandler = undefined,
            ontouchend: EventHandler = undefined,
            ontouchmove: EventHandler = undefined,
            ontouchcancel: EventHandler = undefined,
            onfencedtreeclick: EventHandler = undefined,
            onsnapchanged: EventHandler = undefined,
            onsnapchanging: EventHandler = undefined,
            onafterprint: EventHandler = undefined,
            onbeforeprint: EventHandler = undefined,
            onbeforeunload: OnBeforeUnloadEventHandler = undefined,
            onhashchange: EventHandler = undefined,
            onlanguagechange: EventHandler = undefined,
            onmessage: EventHandler = undefined,
            onmessageerror: EventHandler = undefined,
            onoffline: EventHandler = undefined,
            ononline: EventHandler = undefined,
            onpagehide: EventHandler = undefined,
            onpagereveal: EventHandler = undefined,
            onpageshow: EventHandler = undefined,
            onpageswap: EventHandler = undefined,
            onpopstate: EventHandler = undefined,
            onrejectionhandled: EventHandler = undefined,
            onstorage: EventHandler = undefined,
            onunhandledrejection: EventHandler = undefined,
            onunload: EventHandler = undefined,
            ongamepadconnected: EventHandler = undefined,
            ongamepaddisconnected: EventHandler = undefined,
            onportalactivate: EventHandler = undefined,
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

        .set_name = &set_name,
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
        .set_status = &set_status,

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
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return WindowImpl.init(allocator, State, &vtable, ctx);
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

    pub fn get_history(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WindowImpl.get_history(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_navigation(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WindowImpl.get_navigation(instance);
    }

    pub fn get_customElements(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WindowImpl.get_customElements(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_locationbar(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WindowImpl.get_locationbar(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_menubar(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WindowImpl.get_menubar(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_personalbar(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WindowImpl.get_personalbar(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_scrollbars(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WindowImpl.get_scrollbars(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_statusbar(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WindowImpl.get_statusbar(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_toolbar(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WindowImpl.get_toolbar(instance);
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
    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try WindowImpl.get_length(instance);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_top(instance: *runtime.Instance) anyerror!WindowProxy {
        return try WindowImpl.get_top(instance);
    }

    pub fn get_opener(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try WindowImpl.get_opener(instance);
    }

    pub fn set_opener(instance: *runtime.Instance, value: *const anyopaque) anyerror!void {
        try WindowImpl.set_opener(instance, value);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_parent(instance: *runtime.Instance) anyerror!WindowProxy {
        return try WindowImpl.get_parent(instance);
    }

    pub fn get_frameElement(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WindowImpl.get_frameElement(instance);
    }

    pub fn get_navigator(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WindowImpl.get_navigator(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_clientInformation(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WindowImpl.get_clientInformation(instance);
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

    pub fn get_fence(instance: *runtime.Instance) anyerror!*runtime.Instance {
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
    pub fn get_event(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try WindowImpl.get_event(instance);
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
    pub fn get_sharedStorage(instance: *runtime.Instance) anyerror!*runtime.Instance {
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
    pub fn get_visualViewport(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_visualViewport) |cached| {
            return cached;
        }
        const value = try WindowImpl.get_visualViewport(instance);
        state.own.cached_visualViewport = value;
        return value;
    }

    /// Extended attributes: [Replaceable]
    pub fn get_innerWidth(instance: *runtime.Instance) anyerror!i32 {
        return try WindowImpl.get_innerWidth(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_innerHeight(instance: *runtime.Instance) anyerror!i32 {
        return try WindowImpl.get_innerHeight(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_scrollX(instance: *runtime.Instance) anyerror!f64 {
        return try WindowImpl.get_scrollX(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_pageXOffset(instance: *runtime.Instance) anyerror!f64 {
        return try WindowImpl.get_pageXOffset(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_scrollY(instance: *runtime.Instance) anyerror!f64 {
        return try WindowImpl.get_scrollY(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_pageYOffset(instance: *runtime.Instance) anyerror!f64 {
        return try WindowImpl.get_pageYOffset(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_screenX(instance: *runtime.Instance) anyerror!i32 {
        return try WindowImpl.get_screenX(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_screenLeft(instance: *runtime.Instance) anyerror!i32 {
        return try WindowImpl.get_screenLeft(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_screenY(instance: *runtime.Instance) anyerror!i32 {
        return try WindowImpl.get_screenY(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_screenTop(instance: *runtime.Instance) anyerror!i32 {
        return try WindowImpl.get_screenTop(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_outerWidth(instance: *runtime.Instance) anyerror!i32 {
        return try WindowImpl.get_outerWidth(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_outerHeight(instance: *runtime.Instance) anyerror!i32 {
        return try WindowImpl.get_outerHeight(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_devicePixelRatio(instance: *runtime.Instance) anyerror!f64 {
        return try WindowImpl.get_devicePixelRatio(instance);
    }

    pub fn get_launchQueue(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WindowImpl.get_launchQueue(instance);
    }

    pub fn get_portalHost(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WindowImpl.get_portalHost(instance);
    }

    pub fn get_pushManager(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WindowImpl.get_pushManager(instance);
    }

    pub fn get_onabort(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onabort(instance);
    }

    pub fn set_onabort(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onabort(instance, value);
    }

    pub fn get_onauxclick(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onauxclick(instance);
    }

    pub fn set_onauxclick(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onauxclick(instance, value);
    }

    pub fn get_onbeforeinput(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onbeforeinput(instance);
    }

    pub fn set_onbeforeinput(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onbeforeinput(instance, value);
    }

    pub fn get_onbeforematch(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onbeforematch(instance);
    }

    pub fn set_onbeforematch(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onbeforematch(instance, value);
    }

    pub fn get_onbeforetoggle(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onbeforetoggle(instance);
    }

    pub fn set_onbeforetoggle(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onbeforetoggle(instance, value);
    }

    pub fn get_onblur(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onblur(instance);
    }

    pub fn set_onblur(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onblur(instance, value);
    }

    pub fn get_oncancel(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_oncancel(instance);
    }

    pub fn set_oncancel(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_oncancel(instance, value);
    }

    pub fn get_oncanplay(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_oncanplay(instance);
    }

    pub fn set_oncanplay(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_oncanplay(instance, value);
    }

    pub fn get_oncanplaythrough(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_oncanplaythrough(instance);
    }

    pub fn set_oncanplaythrough(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_oncanplaythrough(instance, value);
    }

    pub fn get_onchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onchange(instance);
    }

    pub fn set_onchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onchange(instance, value);
    }

    pub fn get_onclick(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onclick(instance);
    }

    pub fn set_onclick(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onclick(instance, value);
    }

    pub fn get_onclose(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onclose(instance);
    }

    pub fn set_onclose(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onclose(instance, value);
    }

    pub fn get_oncommand(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_oncommand(instance);
    }

    pub fn set_oncommand(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_oncommand(instance, value);
    }

    pub fn get_oncontextlost(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_oncontextlost(instance);
    }

    pub fn set_oncontextlost(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_oncontextlost(instance, value);
    }

    pub fn get_oncontextmenu(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_oncontextmenu(instance);
    }

    pub fn set_oncontextmenu(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_oncontextmenu(instance, value);
    }

    pub fn get_oncontextrestored(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_oncontextrestored(instance);
    }

    pub fn set_oncontextrestored(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_oncontextrestored(instance, value);
    }

    pub fn get_oncopy(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_oncopy(instance);
    }

    pub fn set_oncopy(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_oncopy(instance, value);
    }

    pub fn get_oncuechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_oncuechange(instance);
    }

    pub fn set_oncuechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_oncuechange(instance, value);
    }

    pub fn get_oncut(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_oncut(instance);
    }

    pub fn set_oncut(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_oncut(instance, value);
    }

    pub fn get_ondblclick(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_ondblclick(instance);
    }

    pub fn set_ondblclick(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_ondblclick(instance, value);
    }

    pub fn get_ondrag(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_ondrag(instance);
    }

    pub fn set_ondrag(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_ondrag(instance, value);
    }

    pub fn get_ondragend(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_ondragend(instance);
    }

    pub fn set_ondragend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_ondragend(instance, value);
    }

    pub fn get_ondragenter(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_ondragenter(instance);
    }

    pub fn set_ondragenter(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_ondragenter(instance, value);
    }

    pub fn get_ondragleave(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_ondragleave(instance);
    }

    pub fn set_ondragleave(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_ondragleave(instance, value);
    }

    pub fn get_ondragover(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_ondragover(instance);
    }

    pub fn set_ondragover(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_ondragover(instance, value);
    }

    pub fn get_ondragstart(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_ondragstart(instance);
    }

    pub fn set_ondragstart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_ondragstart(instance, value);
    }

    pub fn get_ondrop(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_ondrop(instance);
    }

    pub fn set_ondrop(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_ondrop(instance, value);
    }

    pub fn get_ondurationchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_ondurationchange(instance);
    }

    pub fn set_ondurationchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_ondurationchange(instance, value);
    }

    pub fn get_onemptied(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onemptied(instance);
    }

    pub fn set_onemptied(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onemptied(instance, value);
    }

    pub fn get_onended(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onended(instance);
    }

    pub fn set_onended(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onended(instance, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!OnErrorEventHandler {
        return try WindowImpl.get_onerror(instance);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: OnErrorEventHandler) anyerror!void {
        try WindowImpl.set_onerror(instance, value);
    }

    pub fn get_onfocus(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onfocus(instance);
    }

    pub fn set_onfocus(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onfocus(instance, value);
    }

    pub fn get_onformdata(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onformdata(instance);
    }

    pub fn set_onformdata(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onformdata(instance, value);
    }

    pub fn get_oninput(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_oninput(instance);
    }

    pub fn set_oninput(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_oninput(instance, value);
    }

    pub fn get_oninvalid(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_oninvalid(instance);
    }

    pub fn set_oninvalid(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_oninvalid(instance, value);
    }

    pub fn get_onkeydown(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onkeydown(instance);
    }

    pub fn set_onkeydown(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onkeydown(instance, value);
    }

    pub fn get_onkeypress(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onkeypress(instance);
    }

    pub fn set_onkeypress(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onkeypress(instance, value);
    }

    pub fn get_onkeyup(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onkeyup(instance);
    }

    pub fn set_onkeyup(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onkeyup(instance, value);
    }

    pub fn get_onload(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onload(instance);
    }

    pub fn set_onload(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onload(instance, value);
    }

    pub fn get_onloadeddata(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onloadeddata(instance);
    }

    pub fn set_onloadeddata(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onloadeddata(instance, value);
    }

    pub fn get_onloadedmetadata(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onloadedmetadata(instance);
    }

    pub fn set_onloadedmetadata(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onloadedmetadata(instance, value);
    }

    pub fn get_onloadstart(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onloadstart(instance);
    }

    pub fn set_onloadstart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onloadstart(instance, value);
    }

    pub fn get_onmousedown(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onmousedown(instance);
    }

    pub fn set_onmousedown(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onmousedown(instance, value);
    }

    /// Extended attributes: [LegacyLenientThis]
    pub fn get_onmouseenter(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onmouseenter(instance);
    }

    /// Extended attributes: [LegacyLenientThis]
    pub fn set_onmouseenter(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onmouseenter(instance, value);
    }

    /// Extended attributes: [LegacyLenientThis]
    pub fn get_onmouseleave(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onmouseleave(instance);
    }

    /// Extended attributes: [LegacyLenientThis]
    pub fn set_onmouseleave(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onmouseleave(instance, value);
    }

    pub fn get_onmousemove(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onmousemove(instance);
    }

    pub fn set_onmousemove(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onmousemove(instance, value);
    }

    pub fn get_onmouseout(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onmouseout(instance);
    }

    pub fn set_onmouseout(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onmouseout(instance, value);
    }

    pub fn get_onmouseover(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onmouseover(instance);
    }

    pub fn set_onmouseover(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onmouseover(instance, value);
    }

    pub fn get_onmouseup(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onmouseup(instance);
    }

    pub fn set_onmouseup(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onmouseup(instance, value);
    }

    pub fn get_onpaste(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onpaste(instance);
    }

    pub fn set_onpaste(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onpaste(instance, value);
    }

    pub fn get_onpause(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onpause(instance);
    }

    pub fn set_onpause(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onpause(instance, value);
    }

    pub fn get_onplay(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onplay(instance);
    }

    pub fn set_onplay(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onplay(instance, value);
    }

    pub fn get_onplaying(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onplaying(instance);
    }

    pub fn set_onplaying(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onplaying(instance, value);
    }

    pub fn get_onprogress(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onprogress(instance);
    }

    pub fn set_onprogress(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onprogress(instance, value);
    }

    pub fn get_onratechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onratechange(instance);
    }

    pub fn set_onratechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onratechange(instance, value);
    }

    pub fn get_onreset(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onreset(instance);
    }

    pub fn set_onreset(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onreset(instance, value);
    }

    pub fn get_onresize(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onresize(instance);
    }

    pub fn set_onresize(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onresize(instance, value);
    }

    pub fn get_onscroll(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onscroll(instance);
    }

    pub fn set_onscroll(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onscroll(instance, value);
    }

    pub fn get_onscrollend(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onscrollend(instance);
    }

    pub fn set_onscrollend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onscrollend(instance, value);
    }

    pub fn get_onsecuritypolicyviolation(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onsecuritypolicyviolation(instance);
    }

    pub fn set_onsecuritypolicyviolation(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onsecuritypolicyviolation(instance, value);
    }

    pub fn get_onseeked(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onseeked(instance);
    }

    pub fn set_onseeked(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onseeked(instance, value);
    }

    pub fn get_onseeking(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onseeking(instance);
    }

    pub fn set_onseeking(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onseeking(instance, value);
    }

    pub fn get_onselect(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onselect(instance);
    }

    pub fn set_onselect(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onselect(instance, value);
    }

    pub fn get_onslotchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onslotchange(instance);
    }

    pub fn set_onslotchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onslotchange(instance, value);
    }

    pub fn get_onstalled(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onstalled(instance);
    }

    pub fn set_onstalled(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onstalled(instance, value);
    }

    pub fn get_onsubmit(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onsubmit(instance);
    }

    pub fn set_onsubmit(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onsubmit(instance, value);
    }

    pub fn get_onsuspend(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onsuspend(instance);
    }

    pub fn set_onsuspend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onsuspend(instance, value);
    }

    pub fn get_ontimeupdate(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_ontimeupdate(instance);
    }

    pub fn set_ontimeupdate(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_ontimeupdate(instance, value);
    }

    pub fn get_ontoggle(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_ontoggle(instance);
    }

    pub fn set_ontoggle(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_ontoggle(instance, value);
    }

    pub fn get_onvolumechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onvolumechange(instance);
    }

    pub fn set_onvolumechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onvolumechange(instance, value);
    }

    pub fn get_onwaiting(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onwaiting(instance);
    }

    pub fn set_onwaiting(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onwaiting(instance, value);
    }

    pub fn get_onwebkitanimationend(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onwebkitanimationend(instance);
    }

    pub fn set_onwebkitanimationend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onwebkitanimationend(instance, value);
    }

    pub fn get_onwebkitanimationiteration(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onwebkitanimationiteration(instance);
    }

    pub fn set_onwebkitanimationiteration(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onwebkitanimationiteration(instance, value);
    }

    pub fn get_onwebkitanimationstart(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onwebkitanimationstart(instance);
    }

    pub fn set_onwebkitanimationstart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onwebkitanimationstart(instance, value);
    }

    pub fn get_onwebkittransitionend(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onwebkittransitionend(instance);
    }

    pub fn set_onwebkittransitionend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onwebkittransitionend(instance, value);
    }

    pub fn get_onwheel(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onwheel(instance);
    }

    pub fn set_onwheel(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onwheel(instance, value);
    }

    pub fn get_onselectstart(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onselectstart(instance);
    }

    pub fn set_onselectstart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onselectstart(instance, value);
    }

    pub fn get_onselectionchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onselectionchange(instance);
    }

    pub fn set_onselectionchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onselectionchange(instance, value);
    }

    pub fn get_onanimationstart(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onanimationstart(instance);
    }

    pub fn set_onanimationstart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onanimationstart(instance, value);
    }

    pub fn get_onanimationiteration(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onanimationiteration(instance);
    }

    pub fn set_onanimationiteration(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onanimationiteration(instance, value);
    }

    pub fn get_onanimationend(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onanimationend(instance);
    }

    pub fn set_onanimationend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onanimationend(instance, value);
    }

    pub fn get_onanimationcancel(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onanimationcancel(instance);
    }

    pub fn set_onanimationcancel(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onanimationcancel(instance, value);
    }

    pub fn get_ontransitionrun(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_ontransitionrun(instance);
    }

    pub fn set_ontransitionrun(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_ontransitionrun(instance, value);
    }

    pub fn get_ontransitionstart(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_ontransitionstart(instance);
    }

    pub fn set_ontransitionstart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_ontransitionstart(instance, value);
    }

    pub fn get_ontransitionend(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_ontransitionend(instance);
    }

    pub fn set_ontransitionend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_ontransitionend(instance, value);
    }

    pub fn get_ontransitioncancel(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_ontransitioncancel(instance);
    }

    pub fn set_ontransitioncancel(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_ontransitioncancel(instance, value);
    }

    pub fn get_onbeforexrselect(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onbeforexrselect(instance);
    }

    pub fn set_onbeforexrselect(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onbeforexrselect(instance, value);
    }

    pub fn get_onpointerover(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onpointerover(instance);
    }

    pub fn set_onpointerover(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onpointerover(instance, value);
    }

    pub fn get_onpointerenter(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onpointerenter(instance);
    }

    pub fn set_onpointerenter(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onpointerenter(instance, value);
    }

    pub fn get_onpointerdown(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onpointerdown(instance);
    }

    pub fn set_onpointerdown(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onpointerdown(instance, value);
    }

    pub fn get_onpointermove(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onpointermove(instance);
    }

    pub fn set_onpointermove(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onpointermove(instance, value);
    }

    /// Extended attributes: [SecureContext]
    pub fn get_onpointerrawupdate(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onpointerrawupdate(instance);
    }

    /// Extended attributes: [SecureContext]
    pub fn set_onpointerrawupdate(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onpointerrawupdate(instance, value);
    }

    pub fn get_onpointerup(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onpointerup(instance);
    }

    pub fn set_onpointerup(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onpointerup(instance, value);
    }

    pub fn get_onpointercancel(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onpointercancel(instance);
    }

    pub fn set_onpointercancel(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onpointercancel(instance, value);
    }

    pub fn get_onpointerout(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onpointerout(instance);
    }

    pub fn set_onpointerout(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onpointerout(instance, value);
    }

    pub fn get_onpointerleave(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onpointerleave(instance);
    }

    pub fn set_onpointerleave(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onpointerleave(instance, value);
    }

    pub fn get_ongotpointercapture(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_ongotpointercapture(instance);
    }

    pub fn set_ongotpointercapture(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_ongotpointercapture(instance, value);
    }

    pub fn get_onlostpointercapture(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onlostpointercapture(instance);
    }

    pub fn set_onlostpointercapture(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onlostpointercapture(instance, value);
    }

    pub fn get_ontouchstart(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_ontouchstart(instance);
    }

    pub fn set_ontouchstart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_ontouchstart(instance, value);
    }

    pub fn get_ontouchend(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_ontouchend(instance);
    }

    pub fn set_ontouchend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_ontouchend(instance, value);
    }

    pub fn get_ontouchmove(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_ontouchmove(instance);
    }

    pub fn set_ontouchmove(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_ontouchmove(instance, value);
    }

    pub fn get_ontouchcancel(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_ontouchcancel(instance);
    }

    pub fn set_ontouchcancel(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_ontouchcancel(instance, value);
    }

    pub fn get_onfencedtreeclick(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onfencedtreeclick(instance);
    }

    pub fn set_onfencedtreeclick(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onfencedtreeclick(instance, value);
    }

    pub fn get_onsnapchanged(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onsnapchanged(instance);
    }

    pub fn set_onsnapchanged(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onsnapchanged(instance, value);
    }

    pub fn get_onsnapchanging(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onsnapchanging(instance);
    }

    pub fn set_onsnapchanging(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onsnapchanging(instance, value);
    }

    pub fn get_onafterprint(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onafterprint(instance);
    }

    pub fn set_onafterprint(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onafterprint(instance, value);
    }

    pub fn get_onbeforeprint(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onbeforeprint(instance);
    }

    pub fn set_onbeforeprint(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onbeforeprint(instance, value);
    }

    pub fn get_onbeforeunload(instance: *runtime.Instance) anyerror!OnBeforeUnloadEventHandler {
        return try WindowImpl.get_onbeforeunload(instance);
    }

    pub fn set_onbeforeunload(instance: *runtime.Instance, value: OnBeforeUnloadEventHandler) anyerror!void {
        try WindowImpl.set_onbeforeunload(instance, value);
    }

    pub fn get_onhashchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onhashchange(instance);
    }

    pub fn set_onhashchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onhashchange(instance, value);
    }

    pub fn get_onlanguagechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onlanguagechange(instance);
    }

    pub fn set_onlanguagechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onlanguagechange(instance, value);
    }

    pub fn get_onmessage(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onmessage(instance);
    }

    pub fn set_onmessage(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onmessage(instance, value);
    }

    pub fn get_onmessageerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onmessageerror(instance);
    }

    pub fn set_onmessageerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onmessageerror(instance, value);
    }

    pub fn get_onoffline(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onoffline(instance);
    }

    pub fn set_onoffline(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onoffline(instance, value);
    }

    pub fn get_ononline(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_ononline(instance);
    }

    pub fn set_ononline(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_ononline(instance, value);
    }

    pub fn get_onpagehide(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onpagehide(instance);
    }

    pub fn set_onpagehide(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onpagehide(instance, value);
    }

    pub fn get_onpagereveal(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onpagereveal(instance);
    }

    pub fn set_onpagereveal(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onpagereveal(instance, value);
    }

    pub fn get_onpageshow(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onpageshow(instance);
    }

    pub fn set_onpageshow(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onpageshow(instance, value);
    }

    pub fn get_onpageswap(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onpageswap(instance);
    }

    pub fn set_onpageswap(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onpageswap(instance, value);
    }

    pub fn get_onpopstate(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onpopstate(instance);
    }

    pub fn set_onpopstate(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onpopstate(instance, value);
    }

    pub fn get_onrejectionhandled(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onrejectionhandled(instance);
    }

    pub fn set_onrejectionhandled(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onrejectionhandled(instance, value);
    }

    pub fn get_onstorage(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onstorage(instance);
    }

    pub fn set_onstorage(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onstorage(instance, value);
    }

    pub fn get_onunhandledrejection(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onunhandledrejection(instance);
    }

    pub fn set_onunhandledrejection(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onunhandledrejection(instance, value);
    }

    pub fn get_onunload(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onunload(instance);
    }

    pub fn set_onunload(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onunload(instance, value);
    }

    pub fn get_ongamepadconnected(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_ongamepadconnected(instance);
    }

    pub fn set_ongamepadconnected(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_ongamepadconnected(instance, value);
    }

    pub fn get_ongamepaddisconnected(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_ongamepaddisconnected(instance);
    }

    pub fn set_ongamepaddisconnected(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_ongamepaddisconnected(instance, value);
    }

    pub fn get_onportalactivate(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowImpl.get_onportalactivate(instance);
    }

    pub fn set_onportalactivate(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowImpl.set_onportalactivate(instance, value);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_origin(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try WindowImpl.get_origin(instance);
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

    pub fn call_print(instance: *runtime.Instance) anyerror!void {
        return try WindowImpl.call_print(instance);
    }

    pub fn call_confirm(instance: *runtime.Instance, message: DOMString) anyerror!bool {
        
        return try WindowImpl.call_confirm(instance, message);
    }

    pub fn call_postMessage(instance: *runtime.Instance, message: *const anyopaque, targetOrigin: runtime.USVString, transfer: *const anyopaque) anyerror!void {
        
        return try WindowImpl.call_postMessage(instance, message, targetOrigin, transfer);
    }

    pub fn call_showDirectoryPicker(instance: *runtime.Instance, options: DirectoryPickerOptions) anyerror!*const anyopaque {
        
        return try WindowImpl.call_showDirectoryPicker(instance, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_matchMedia(instance: *runtime.Instance, query: CSSOMString) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try WindowImpl.call_matchMedia(instance, query);
    }

    pub fn call_scroll(instance: *runtime.Instance, options: ScrollToOptions) anyerror!*const anyopaque {
        
        return try WindowImpl.call_scroll(instance, options);
    }

    pub fn call_resizeTo(instance: *runtime.Instance, width: i32, height: i32) anyerror!void {
        
        return try WindowImpl.call_resizeTo(instance, width, height);
    }

    pub fn call_showSaveFilePicker(instance: *runtime.Instance, options: SaveFilePickerOptions) anyerror!*const anyopaque {
        
        return try WindowImpl.call_showSaveFilePicker(instance, options);
    }

    pub fn call_setTimeout(instance: *runtime.Instance, handler: TimerHandler, timeout: i32, arguments: *const anyopaque) anyerror!i32 {
        
        return try WindowImpl.call_setTimeout(instance, handler, timeout, arguments);
    }

    pub fn call_clearInterval(instance: *runtime.Instance, id: i32) anyerror!void {
        
        return try WindowImpl.call_clearInterval(instance, id);
    }

    /// Extended attributes: [NewObject]
    pub fn call_fetch(instance: *runtime.Instance, input: RequestInfo, init_data: RequestInit) anyerror!*const anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try WindowImpl.call_fetch(instance, input, init_data);
    }

    pub fn call_blur(instance: *runtime.Instance) anyerror!void {
        return try WindowImpl.call_blur(instance);
    }

    pub fn call_showOpenFilePicker(instance: *runtime.Instance, options: OpenFilePickerOptions) anyerror!*const anyopaque {
        
        return try WindowImpl.call_showOpenFilePicker(instance, options);
    }

    pub fn call_scrollBy(instance: *runtime.Instance, options: ScrollToOptions) anyerror!*const anyopaque {
        
        return try WindowImpl.call_scrollBy(instance, options);
    }

    pub fn call_releaseEvents(instance: *runtime.Instance) anyerror!void {
        return try WindowImpl.call_releaseEvents(instance);
    }

    pub fn call_atob(instance: *runtime.Instance, data: DOMString) anyerror!runtime.ByteString {
        
        return try WindowImpl.call_atob(instance, data);
    }

    pub fn call_alert(instance: *runtime.Instance) anyerror!void {
        return try WindowImpl.call_alert(instance);
    }

    pub fn call_btoa(instance: *runtime.Instance, data: DOMString) anyerror!DOMString {
        
        return try WindowImpl.call_btoa(instance, data);
    }

    pub fn call_focus(instance: *runtime.Instance) anyerror!void {
        return try WindowImpl.call_focus(instance);
    }

    pub fn call_requestIdleCallback(instance: *runtime.Instance, callback: IdleRequestCallback, options: IdleRequestOptions) anyerror!u32 {
        
        return try WindowImpl.call_requestIdleCallback(instance, callback, options);
    }

    pub fn call_queueMicrotask(instance: *runtime.Instance, callback: VoidFunction) anyerror!void {
        
        return try WindowImpl.call_queueMicrotask(instance, callback);
    }

    pub fn call_structuredClone(instance: *runtime.Instance, value: *const anyopaque, options: StructuredSerializeOptions) anyerror!*const anyopaque {
        
        return try WindowImpl.call_structuredClone(instance, value, options);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try WindowImpl.call_close(instance);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_getDigitalGoodsService(instance: *runtime.Instance, serviceProvider: DOMString) anyerror!*const anyopaque {
        
        return try WindowImpl.call_getDigitalGoodsService(instance, serviceProvider);
    }

    pub fn call_moveBy(instance: *runtime.Instance, x: i32, y: i32) anyerror!void {
        
        return try WindowImpl.call_moveBy(instance, x, y);
    }

    pub fn call_getSelection(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WindowImpl.call_getSelection(instance);
    }

    pub fn call_stop(instance: *runtime.Instance) anyerror!void {
        return try WindowImpl.call_stop(instance);
    }

    pub fn call_resizeBy(instance: *runtime.Instance, x: i32, y: i32) anyerror!void {
        
        return try WindowImpl.call_resizeBy(instance, x, y);
    }

    pub fn call_open(instance: *runtime.Instance, url: runtime.USVString, target: DOMString, features: DOMString) anyerror!WindowProxy {
        
        return try WindowImpl.call_open(instance, url, target, features);
    }

    pub fn call_moveTo(instance: *runtime.Instance, x: i32, y: i32) anyerror!void {
        
        return try WindowImpl.call_moveTo(instance, x, y);
    }

    pub fn call_scrollTo(instance: *runtime.Instance, options: ScrollToOptions) anyerror!*const anyopaque {
        
        return try WindowImpl.call_scrollTo(instance, options);
    }

    pub fn call_prompt(instance: *runtime.Instance, message: DOMString, default: DOMString) anyerror!DOMString {
        
        return try WindowImpl.call_prompt(instance, message, default);
    }

    pub fn call_reportError(instance: *runtime.Instance, e: *const anyopaque) anyerror!void {
        
        return try WindowImpl.call_reportError(instance, e);
    }

    pub fn call_clearTimeout(instance: *runtime.Instance, id: i32) anyerror!void {
        
        return try WindowImpl.call_clearTimeout(instance, id);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getComputedStyle(instance: *runtime.Instance, elt: *runtime.Instance, pseudoElt: CSSOMString) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try WindowImpl.call_getComputedStyle(instance, elt, pseudoElt);
    }

    pub fn call_setInterval(instance: *runtime.Instance, handler: TimerHandler, timeout: i32, arguments: *const anyopaque) anyerror!i32 {
        
        return try WindowImpl.call_setInterval(instance, handler, timeout, arguments);
    }

    pub fn call_cancelAnimationFrame(instance: *runtime.Instance, handle: u32) anyerror!void {
        
        return try WindowImpl.call_cancelAnimationFrame(instance, handle);
    }

    /// Extended attributes: [NewObject], [SecureContext]
    pub fn call_fetchLater(instance: *runtime.Instance, input: RequestInfo, init_data: DeferredRequestInit) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try WindowImpl.call_fetchLater(instance, input, init_data);
    }

    pub fn call_requestAnimationFrame(instance: *runtime.Instance, callback: FrameRequestCallback) anyerror!u32 {
        
        return try WindowImpl.call_requestAnimationFrame(instance, callback);
    }

    pub fn call_createImageBitmap(instance: *runtime.Instance, image: ImageBitmapSource, options: ImageBitmapOptions) anyerror!*const anyopaque {
        
        return try WindowImpl.call_createImageBitmap(instance, image, options);
    }

    pub fn call_cancelIdleCallback(instance: *runtime.Instance, handle: u32) anyerror!void {
        
        return try WindowImpl.call_cancelIdleCallback(instance, handle);
    }

    pub fn call_captureEvents(instance: *runtime.Instance) anyerror!void {
        return try WindowImpl.call_captureEvents(instance);
    }

    pub fn call_queryLocalFonts(instance: *runtime.Instance, options: QueryOptions) anyerror!*const anyopaque {
        
        return try WindowImpl.call_queryLocalFonts(instance, options);
    }

    pub fn call_navigate(instance: *runtime.Instance, dir: SpatialNavigationDirection) anyerror!void {
        
        return try WindowImpl.call_navigate(instance, dir);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_getScreenDetails(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try WindowImpl.call_getScreenDetails(instance);
    }

};
