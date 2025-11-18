//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WindowImpl = @import("../impls/Window.zig");
const EventTarget = @import("EventTarget.zig");
const PushManagerAttribute = @import("PushManagerAttribute.zig");
const GlobalEventHandlers = @import("GlobalEventHandlers.zig");
const WindowEventHandlers = @import("WindowEventHandlers.zig");
const WindowOrWorkerGlobalScope = @import("WindowOrWorkerGlobalScope.zig");
const AnimationFrameProvider = @import("AnimationFrameProvider.zig");
const WindowSessionStorage = @import("WindowSessionStorage.zig");
const WindowLocalStorage = @import("WindowLocalStorage.zig");

pub const Window = struct {
    pub const Meta = struct {
        pub const name = "Window";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{
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
        
        /// Properties that cannot be shadowed or deleted (configurable: false)
        pub const legacy_unforgeable_properties = .{
            "window",
            "document",
            "location",
            "top",
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            window: WindowProxy = undefined,
            self: WindowProxy = undefined,
            document: Document = undefined,
            name: runtime.DOMString = undefined,
            location: Location = undefined,
            history: History = undefined,
            navigation: Navigation = undefined,
            customElements: CustomElementRegistry = undefined,
            locationbar: BarProp = undefined,
            menubar: BarProp = undefined,
            personalbar: BarProp = undefined,
            scrollbars: BarProp = undefined,
            statusbar: BarProp = undefined,
            toolbar: BarProp = undefined,
            status: runtime.DOMString = undefined,
            closed: bool = undefined,
            frames: WindowProxy = undefined,
            length: u32 = undefined,
            top: ?WindowProxy = null,
            opener: anyopaque = undefined,
            parent: ?WindowProxy = null,
            frameElement: ?Element = null,
            navigator: Navigator = undefined,
            clientInformation: Navigator = undefined,
            originAgentCluster: bool = undefined,
            ondeviceorientation: EventHandler = undefined,
            ondeviceorientationabsolute: EventHandler = undefined,
            ondevicemotion: EventHandler = undefined,
            viewport: Viewport = undefined,
            cookieStore: CookieStore = undefined,
            credentialless: bool = undefined,
            speechSynthesis: SpeechSynthesis = undefined,
            fence: ?Fence = null,
            documentPictureInPicture: DocumentPictureInPicture = undefined,
            event: (Event or undefined) = undefined,
            orientation: i16 = undefined,
            onorientationchange: EventHandler = undefined,
            sharedStorage: ?SharedStorage = null,
            onappinstalled: EventHandler = undefined,
            onbeforeinstallprompt: EventHandler = undefined,
            external: External = undefined,
            screen: Screen = undefined,
            visualViewport: ?VisualViewport = null,
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
            launchQueue: LaunchQueue = undefined,
            portalHost: ?PortalHost = null,
            pushManager: PushManager = undefined,
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
            indexedDB: IDBFactory = undefined,
            trustedTypes: TrustedTypePolicyFactory = undefined,
            performance: Performance = undefined,
            caches: CacheStorage = undefined,
            scheduler: Scheduler = undefined,
            crypto: Crypto = undefined,
            sessionStorage: Storage = undefined,
            localStorage: Storage = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Window, .{
        .deinit_fn = &deinit_wrapper,

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

        .call_addEventListener = &call_addEventListener,
        .call_alert = &call_alert,
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
        .call_createImageBitmap = &call_createImageBitmap,
        .call_dispatchEvent = &call_dispatchEvent,
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
        .call_postMessage = &call_postMessage,
        .call_print = &call_print,
        .call_prompt = &call_prompt,
        .call_queryLocalFonts = &call_queryLocalFonts,
        .call_queueMicrotask = &call_queueMicrotask,
        .call_releaseEvents = &call_releaseEvents,
        .call_removeEventListener = &call_removeEventListener,
        .call_reportError = &call_reportError,
        .call_requestAnimationFrame = &call_requestAnimationFrame,
        .call_requestIdleCallback = &call_requestIdleCallback,
        .call_resizeBy = &call_resizeBy,
        .call_resizeTo = &call_resizeTo,
        .call_scroll = &call_scroll,
        .call_scroll = &call_scroll,
        .call_scrollBy = &call_scrollBy,
        .call_scrollBy = &call_scrollBy,
        .call_scrollTo = &call_scrollTo,
        .call_scrollTo = &call_scrollTo,
        .call_setInterval = &call_setInterval,
        .call_setTimeout = &call_setTimeout,
        .call_showDirectoryPicker = &call_showDirectoryPicker,
        .call_showOpenFilePicker = &call_showOpenFilePicker,
        .call_showSaveFilePicker = &call_showSaveFilePicker,
        .call_stop = &call_stop,
        .call_structuredClone = &call_structuredClone,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        WindowImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        WindowImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_window(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_window(state);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_self(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_self(state);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_document(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_document(state);
    }

    pub fn get_name(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return WindowImpl.get_name(state);
    }

    pub fn set_name(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        WindowImpl.set_name(state, value);
    }

    /// Extended attributes: [PutForwards=href], [LegacyUnforgeable]
    pub fn get_location(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_location(state);
    }

    pub fn get_history(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_history(state);
    }

    pub fn get_navigation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_navigation(state);
    }

    pub fn get_customElements(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_customElements(state);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_locationbar(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_locationbar(state);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_menubar(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_menubar(state);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_personalbar(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_personalbar(state);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_scrollbars(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_scrollbars(state);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_statusbar(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_statusbar(state);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_toolbar(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_toolbar(state);
    }

    pub fn get_status(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return WindowImpl.get_status(state);
    }

    pub fn set_status(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        WindowImpl.set_status(state, value);
    }

    pub fn get_closed(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return WindowImpl.get_closed(state);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_frames(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_frames(state);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_length(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return WindowImpl.get_length(state);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_top(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_top(state);
    }

    pub fn get_opener(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_opener(state);
    }

    pub fn set_opener(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_opener(state, value);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_parent(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_parent(state);
    }

    pub fn get_frameElement(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_frameElement(state);
    }

    pub fn get_navigator(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_navigator(state);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_clientInformation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_clientInformation(state);
    }

    pub fn get_originAgentCluster(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return WindowImpl.get_originAgentCluster(state);
    }

    /// Extended attributes: [SecureContext]
    pub fn get_ondeviceorientation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_ondeviceorientation(state);
    }

    /// Extended attributes: [SecureContext]
    pub fn set_ondeviceorientation(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_ondeviceorientation(state, value);
    }

    /// Extended attributes: [SecureContext]
    pub fn get_ondeviceorientationabsolute(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_ondeviceorientationabsolute(state);
    }

    /// Extended attributes: [SecureContext]
    pub fn set_ondeviceorientationabsolute(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_ondeviceorientationabsolute(state, value);
    }

    /// Extended attributes: [SecureContext]
    pub fn get_ondevicemotion(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_ondevicemotion(state);
    }

    /// Extended attributes: [SecureContext]
    pub fn set_ondevicemotion(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_ondevicemotion(state, value);
    }

    /// Extended attributes: [SameObject], [Replaceable]
    pub fn get_viewport(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_viewport) |cached| {
            return cached;
        }
        const value = WindowImpl.get_viewport(state);
        state.cached_viewport = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_cookieStore(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_cookieStore) |cached| {
            return cached;
        }
        const value = WindowImpl.get_cookieStore(state);
        state.cached_cookieStore = value;
        return value;
    }

    pub fn get_credentialless(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return WindowImpl.get_credentialless(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_speechSynthesis(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_speechSynthesis) |cached| {
            return cached;
        }
        const value = WindowImpl.get_speechSynthesis(state);
        state.cached_speechSynthesis = value;
        return value;
    }

    pub fn get_fence(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_fence(state);
    }

    /// Extended attributes: [SameObject], [SecureContext]
    pub fn get_documentPictureInPicture(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_documentPictureInPicture) |cached| {
            return cached;
        }
        const value = WindowImpl.get_documentPictureInPicture(state);
        state.cached_documentPictureInPicture = value;
        return value;
    }

    /// Extended attributes: [Replaceable]
    pub fn get_event(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_event(state);
    }

    pub fn get_orientation(instance: *runtime.Instance) i16 {
        const state = instance.getState(State);
        return WindowImpl.get_orientation(state);
    }

    pub fn get_onorientationchange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onorientationchange(state);
    }

    pub fn set_onorientationchange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onorientationchange(state, value);
    }

    /// Extended attributes: [SecureContext]
    pub fn get_sharedStorage(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_sharedStorage(state);
    }

    pub fn get_onappinstalled(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onappinstalled(state);
    }

    pub fn set_onappinstalled(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onappinstalled(state, value);
    }

    pub fn get_onbeforeinstallprompt(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onbeforeinstallprompt(state);
    }

    pub fn set_onbeforeinstallprompt(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onbeforeinstallprompt(state, value);
    }

    /// Extended attributes: [Replaceable], [SameObject]
    pub fn get_external(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_external) |cached| {
            return cached;
        }
        const value = WindowImpl.get_external(state);
        state.cached_external = value;
        return value;
    }

    /// Extended attributes: [SameObject], [Replaceable]
    pub fn get_screen(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_screen) |cached| {
            return cached;
        }
        const value = WindowImpl.get_screen(state);
        state.cached_screen = value;
        return value;
    }

    /// Extended attributes: [SameObject], [Replaceable]
    pub fn get_visualViewport(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_visualViewport) |cached| {
            return cached;
        }
        const value = WindowImpl.get_visualViewport(state);
        state.cached_visualViewport = value;
        return value;
    }

    /// Extended attributes: [Replaceable]
    pub fn get_innerWidth(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return WindowImpl.get_innerWidth(state);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_innerHeight(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return WindowImpl.get_innerHeight(state);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_scrollX(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return WindowImpl.get_scrollX(state);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_pageXOffset(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return WindowImpl.get_pageXOffset(state);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_scrollY(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return WindowImpl.get_scrollY(state);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_pageYOffset(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return WindowImpl.get_pageYOffset(state);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_screenX(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return WindowImpl.get_screenX(state);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_screenLeft(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return WindowImpl.get_screenLeft(state);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_screenY(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return WindowImpl.get_screenY(state);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_screenTop(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return WindowImpl.get_screenTop(state);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_outerWidth(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return WindowImpl.get_outerWidth(state);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_outerHeight(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return WindowImpl.get_outerHeight(state);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_devicePixelRatio(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return WindowImpl.get_devicePixelRatio(state);
    }

    pub fn get_launchQueue(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_launchQueue(state);
    }

    pub fn get_portalHost(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_portalHost(state);
    }

    pub fn get_pushManager(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_pushManager(state);
    }

    pub fn get_onabort(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onabort(state);
    }

    pub fn set_onabort(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onabort(state, value);
    }

    pub fn get_onauxclick(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onauxclick(state);
    }

    pub fn set_onauxclick(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onauxclick(state, value);
    }

    pub fn get_onbeforeinput(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onbeforeinput(state);
    }

    pub fn set_onbeforeinput(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onbeforeinput(state, value);
    }

    pub fn get_onbeforematch(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onbeforematch(state);
    }

    pub fn set_onbeforematch(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onbeforematch(state, value);
    }

    pub fn get_onbeforetoggle(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onbeforetoggle(state);
    }

    pub fn set_onbeforetoggle(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onbeforetoggle(state, value);
    }

    pub fn get_onblur(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onblur(state);
    }

    pub fn set_onblur(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onblur(state, value);
    }

    pub fn get_oncancel(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_oncancel(state);
    }

    pub fn set_oncancel(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_oncancel(state, value);
    }

    pub fn get_oncanplay(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_oncanplay(state);
    }

    pub fn set_oncanplay(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_oncanplay(state, value);
    }

    pub fn get_oncanplaythrough(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_oncanplaythrough(state);
    }

    pub fn set_oncanplaythrough(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_oncanplaythrough(state, value);
    }

    pub fn get_onchange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onchange(state);
    }

    pub fn set_onchange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onchange(state, value);
    }

    pub fn get_onclick(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onclick(state);
    }

    pub fn set_onclick(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onclick(state, value);
    }

    pub fn get_onclose(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onclose(state);
    }

    pub fn set_onclose(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onclose(state, value);
    }

    pub fn get_oncommand(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_oncommand(state);
    }

    pub fn set_oncommand(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_oncommand(state, value);
    }

    pub fn get_oncontextlost(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_oncontextlost(state);
    }

    pub fn set_oncontextlost(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_oncontextlost(state, value);
    }

    pub fn get_oncontextmenu(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_oncontextmenu(state);
    }

    pub fn set_oncontextmenu(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_oncontextmenu(state, value);
    }

    pub fn get_oncontextrestored(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_oncontextrestored(state);
    }

    pub fn set_oncontextrestored(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_oncontextrestored(state, value);
    }

    pub fn get_oncopy(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_oncopy(state);
    }

    pub fn set_oncopy(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_oncopy(state, value);
    }

    pub fn get_oncuechange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_oncuechange(state);
    }

    pub fn set_oncuechange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_oncuechange(state, value);
    }

    pub fn get_oncut(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_oncut(state);
    }

    pub fn set_oncut(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_oncut(state, value);
    }

    pub fn get_ondblclick(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_ondblclick(state);
    }

    pub fn set_ondblclick(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_ondblclick(state, value);
    }

    pub fn get_ondrag(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_ondrag(state);
    }

    pub fn set_ondrag(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_ondrag(state, value);
    }

    pub fn get_ondragend(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_ondragend(state);
    }

    pub fn set_ondragend(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_ondragend(state, value);
    }

    pub fn get_ondragenter(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_ondragenter(state);
    }

    pub fn set_ondragenter(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_ondragenter(state, value);
    }

    pub fn get_ondragleave(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_ondragleave(state);
    }

    pub fn set_ondragleave(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_ondragleave(state, value);
    }

    pub fn get_ondragover(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_ondragover(state);
    }

    pub fn set_ondragover(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_ondragover(state, value);
    }

    pub fn get_ondragstart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_ondragstart(state);
    }

    pub fn set_ondragstart(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_ondragstart(state, value);
    }

    pub fn get_ondrop(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_ondrop(state);
    }

    pub fn set_ondrop(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_ondrop(state, value);
    }

    pub fn get_ondurationchange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_ondurationchange(state);
    }

    pub fn set_ondurationchange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_ondurationchange(state, value);
    }

    pub fn get_onemptied(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onemptied(state);
    }

    pub fn set_onemptied(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onemptied(state, value);
    }

    pub fn get_onended(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onended(state);
    }

    pub fn set_onended(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onended(state, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onerror(state);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onerror(state, value);
    }

    pub fn get_onfocus(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onfocus(state);
    }

    pub fn set_onfocus(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onfocus(state, value);
    }

    pub fn get_onformdata(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onformdata(state);
    }

    pub fn set_onformdata(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onformdata(state, value);
    }

    pub fn get_oninput(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_oninput(state);
    }

    pub fn set_oninput(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_oninput(state, value);
    }

    pub fn get_oninvalid(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_oninvalid(state);
    }

    pub fn set_oninvalid(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_oninvalid(state, value);
    }

    pub fn get_onkeydown(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onkeydown(state);
    }

    pub fn set_onkeydown(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onkeydown(state, value);
    }

    pub fn get_onkeypress(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onkeypress(state);
    }

    pub fn set_onkeypress(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onkeypress(state, value);
    }

    pub fn get_onkeyup(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onkeyup(state);
    }

    pub fn set_onkeyup(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onkeyup(state, value);
    }

    pub fn get_onload(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onload(state);
    }

    pub fn set_onload(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onload(state, value);
    }

    pub fn get_onloadeddata(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onloadeddata(state);
    }

    pub fn set_onloadeddata(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onloadeddata(state, value);
    }

    pub fn get_onloadedmetadata(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onloadedmetadata(state);
    }

    pub fn set_onloadedmetadata(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onloadedmetadata(state, value);
    }

    pub fn get_onloadstart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onloadstart(state);
    }

    pub fn set_onloadstart(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onloadstart(state, value);
    }

    pub fn get_onmousedown(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onmousedown(state);
    }

    pub fn set_onmousedown(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onmousedown(state, value);
    }

    /// Extended attributes: [LegacyLenientThis]
    pub fn get_onmouseenter(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onmouseenter(state);
    }

    /// Extended attributes: [LegacyLenientThis]
    pub fn set_onmouseenter(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onmouseenter(state, value);
    }

    /// Extended attributes: [LegacyLenientThis]
    pub fn get_onmouseleave(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onmouseleave(state);
    }

    /// Extended attributes: [LegacyLenientThis]
    pub fn set_onmouseleave(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onmouseleave(state, value);
    }

    pub fn get_onmousemove(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onmousemove(state);
    }

    pub fn set_onmousemove(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onmousemove(state, value);
    }

    pub fn get_onmouseout(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onmouseout(state);
    }

    pub fn set_onmouseout(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onmouseout(state, value);
    }

    pub fn get_onmouseover(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onmouseover(state);
    }

    pub fn set_onmouseover(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onmouseover(state, value);
    }

    pub fn get_onmouseup(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onmouseup(state);
    }

    pub fn set_onmouseup(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onmouseup(state, value);
    }

    pub fn get_onpaste(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onpaste(state);
    }

    pub fn set_onpaste(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onpaste(state, value);
    }

    pub fn get_onpause(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onpause(state);
    }

    pub fn set_onpause(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onpause(state, value);
    }

    pub fn get_onplay(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onplay(state);
    }

    pub fn set_onplay(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onplay(state, value);
    }

    pub fn get_onplaying(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onplaying(state);
    }

    pub fn set_onplaying(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onplaying(state, value);
    }

    pub fn get_onprogress(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onprogress(state);
    }

    pub fn set_onprogress(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onprogress(state, value);
    }

    pub fn get_onratechange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onratechange(state);
    }

    pub fn set_onratechange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onratechange(state, value);
    }

    pub fn get_onreset(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onreset(state);
    }

    pub fn set_onreset(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onreset(state, value);
    }

    pub fn get_onresize(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onresize(state);
    }

    pub fn set_onresize(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onresize(state, value);
    }

    pub fn get_onscroll(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onscroll(state);
    }

    pub fn set_onscroll(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onscroll(state, value);
    }

    pub fn get_onscrollend(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onscrollend(state);
    }

    pub fn set_onscrollend(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onscrollend(state, value);
    }

    pub fn get_onsecuritypolicyviolation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onsecuritypolicyviolation(state);
    }

    pub fn set_onsecuritypolicyviolation(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onsecuritypolicyviolation(state, value);
    }

    pub fn get_onseeked(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onseeked(state);
    }

    pub fn set_onseeked(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onseeked(state, value);
    }

    pub fn get_onseeking(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onseeking(state);
    }

    pub fn set_onseeking(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onseeking(state, value);
    }

    pub fn get_onselect(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onselect(state);
    }

    pub fn set_onselect(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onselect(state, value);
    }

    pub fn get_onslotchange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onslotchange(state);
    }

    pub fn set_onslotchange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onslotchange(state, value);
    }

    pub fn get_onstalled(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onstalled(state);
    }

    pub fn set_onstalled(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onstalled(state, value);
    }

    pub fn get_onsubmit(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onsubmit(state);
    }

    pub fn set_onsubmit(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onsubmit(state, value);
    }

    pub fn get_onsuspend(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onsuspend(state);
    }

    pub fn set_onsuspend(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onsuspend(state, value);
    }

    pub fn get_ontimeupdate(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_ontimeupdate(state);
    }

    pub fn set_ontimeupdate(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_ontimeupdate(state, value);
    }

    pub fn get_ontoggle(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_ontoggle(state);
    }

    pub fn set_ontoggle(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_ontoggle(state, value);
    }

    pub fn get_onvolumechange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onvolumechange(state);
    }

    pub fn set_onvolumechange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onvolumechange(state, value);
    }

    pub fn get_onwaiting(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onwaiting(state);
    }

    pub fn set_onwaiting(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onwaiting(state, value);
    }

    pub fn get_onwebkitanimationend(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onwebkitanimationend(state);
    }

    pub fn set_onwebkitanimationend(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onwebkitanimationend(state, value);
    }

    pub fn get_onwebkitanimationiteration(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onwebkitanimationiteration(state);
    }

    pub fn set_onwebkitanimationiteration(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onwebkitanimationiteration(state, value);
    }

    pub fn get_onwebkitanimationstart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onwebkitanimationstart(state);
    }

    pub fn set_onwebkitanimationstart(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onwebkitanimationstart(state, value);
    }

    pub fn get_onwebkittransitionend(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onwebkittransitionend(state);
    }

    pub fn set_onwebkittransitionend(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onwebkittransitionend(state, value);
    }

    pub fn get_onwheel(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onwheel(state);
    }

    pub fn set_onwheel(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onwheel(state, value);
    }

    pub fn get_onselectstart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onselectstart(state);
    }

    pub fn set_onselectstart(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onselectstart(state, value);
    }

    pub fn get_onselectionchange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onselectionchange(state);
    }

    pub fn set_onselectionchange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onselectionchange(state, value);
    }

    pub fn get_onanimationstart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onanimationstart(state);
    }

    pub fn set_onanimationstart(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onanimationstart(state, value);
    }

    pub fn get_onanimationiteration(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onanimationiteration(state);
    }

    pub fn set_onanimationiteration(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onanimationiteration(state, value);
    }

    pub fn get_onanimationend(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onanimationend(state);
    }

    pub fn set_onanimationend(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onanimationend(state, value);
    }

    pub fn get_onanimationcancel(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onanimationcancel(state);
    }

    pub fn set_onanimationcancel(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onanimationcancel(state, value);
    }

    pub fn get_ontransitionrun(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_ontransitionrun(state);
    }

    pub fn set_ontransitionrun(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_ontransitionrun(state, value);
    }

    pub fn get_ontransitionstart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_ontransitionstart(state);
    }

    pub fn set_ontransitionstart(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_ontransitionstart(state, value);
    }

    pub fn get_ontransitionend(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_ontransitionend(state);
    }

    pub fn set_ontransitionend(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_ontransitionend(state, value);
    }

    pub fn get_ontransitioncancel(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_ontransitioncancel(state);
    }

    pub fn set_ontransitioncancel(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_ontransitioncancel(state, value);
    }

    pub fn get_onbeforexrselect(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onbeforexrselect(state);
    }

    pub fn set_onbeforexrselect(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onbeforexrselect(state, value);
    }

    pub fn get_onpointerover(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onpointerover(state);
    }

    pub fn set_onpointerover(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onpointerover(state, value);
    }

    pub fn get_onpointerenter(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onpointerenter(state);
    }

    pub fn set_onpointerenter(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onpointerenter(state, value);
    }

    pub fn get_onpointerdown(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onpointerdown(state);
    }

    pub fn set_onpointerdown(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onpointerdown(state, value);
    }

    pub fn get_onpointermove(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onpointermove(state);
    }

    pub fn set_onpointermove(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onpointermove(state, value);
    }

    /// Extended attributes: [SecureContext]
    pub fn get_onpointerrawupdate(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onpointerrawupdate(state);
    }

    /// Extended attributes: [SecureContext]
    pub fn set_onpointerrawupdate(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onpointerrawupdate(state, value);
    }

    pub fn get_onpointerup(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onpointerup(state);
    }

    pub fn set_onpointerup(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onpointerup(state, value);
    }

    pub fn get_onpointercancel(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onpointercancel(state);
    }

    pub fn set_onpointercancel(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onpointercancel(state, value);
    }

    pub fn get_onpointerout(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onpointerout(state);
    }

    pub fn set_onpointerout(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onpointerout(state, value);
    }

    pub fn get_onpointerleave(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onpointerleave(state);
    }

    pub fn set_onpointerleave(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onpointerleave(state, value);
    }

    pub fn get_ongotpointercapture(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_ongotpointercapture(state);
    }

    pub fn set_ongotpointercapture(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_ongotpointercapture(state, value);
    }

    pub fn get_onlostpointercapture(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onlostpointercapture(state);
    }

    pub fn set_onlostpointercapture(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onlostpointercapture(state, value);
    }

    pub fn get_ontouchstart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_ontouchstart(state);
    }

    pub fn set_ontouchstart(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_ontouchstart(state, value);
    }

    pub fn get_ontouchend(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_ontouchend(state);
    }

    pub fn set_ontouchend(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_ontouchend(state, value);
    }

    pub fn get_ontouchmove(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_ontouchmove(state);
    }

    pub fn set_ontouchmove(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_ontouchmove(state, value);
    }

    pub fn get_ontouchcancel(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_ontouchcancel(state);
    }

    pub fn set_ontouchcancel(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_ontouchcancel(state, value);
    }

    pub fn get_onfencedtreeclick(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onfencedtreeclick(state);
    }

    pub fn set_onfencedtreeclick(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onfencedtreeclick(state, value);
    }

    pub fn get_onsnapchanged(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onsnapchanged(state);
    }

    pub fn set_onsnapchanged(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onsnapchanged(state, value);
    }

    pub fn get_onsnapchanging(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onsnapchanging(state);
    }

    pub fn set_onsnapchanging(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onsnapchanging(state, value);
    }

    pub fn get_onafterprint(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onafterprint(state);
    }

    pub fn set_onafterprint(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onafterprint(state, value);
    }

    pub fn get_onbeforeprint(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onbeforeprint(state);
    }

    pub fn set_onbeforeprint(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onbeforeprint(state, value);
    }

    pub fn get_onbeforeunload(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onbeforeunload(state);
    }

    pub fn set_onbeforeunload(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onbeforeunload(state, value);
    }

    pub fn get_onhashchange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onhashchange(state);
    }

    pub fn set_onhashchange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onhashchange(state, value);
    }

    pub fn get_onlanguagechange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onlanguagechange(state);
    }

    pub fn set_onlanguagechange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onlanguagechange(state, value);
    }

    pub fn get_onmessage(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onmessage(state);
    }

    pub fn set_onmessage(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onmessage(state, value);
    }

    pub fn get_onmessageerror(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onmessageerror(state);
    }

    pub fn set_onmessageerror(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onmessageerror(state, value);
    }

    pub fn get_onoffline(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onoffline(state);
    }

    pub fn set_onoffline(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onoffline(state, value);
    }

    pub fn get_ononline(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_ononline(state);
    }

    pub fn set_ononline(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_ononline(state, value);
    }

    pub fn get_onpagehide(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onpagehide(state);
    }

    pub fn set_onpagehide(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onpagehide(state, value);
    }

    pub fn get_onpagereveal(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onpagereveal(state);
    }

    pub fn set_onpagereveal(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onpagereveal(state, value);
    }

    pub fn get_onpageshow(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onpageshow(state);
    }

    pub fn set_onpageshow(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onpageshow(state, value);
    }

    pub fn get_onpageswap(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onpageswap(state);
    }

    pub fn set_onpageswap(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onpageswap(state, value);
    }

    pub fn get_onpopstate(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onpopstate(state);
    }

    pub fn set_onpopstate(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onpopstate(state, value);
    }

    pub fn get_onrejectionhandled(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onrejectionhandled(state);
    }

    pub fn set_onrejectionhandled(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onrejectionhandled(state, value);
    }

    pub fn get_onstorage(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onstorage(state);
    }

    pub fn set_onstorage(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onstorage(state, value);
    }

    pub fn get_onunhandledrejection(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onunhandledrejection(state);
    }

    pub fn set_onunhandledrejection(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onunhandledrejection(state, value);
    }

    pub fn get_onunload(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onunload(state);
    }

    pub fn set_onunload(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onunload(state, value);
    }

    pub fn get_ongamepadconnected(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_ongamepadconnected(state);
    }

    pub fn set_ongamepadconnected(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_ongamepadconnected(state, value);
    }

    pub fn get_ongamepaddisconnected(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_ongamepaddisconnected(state);
    }

    pub fn set_ongamepaddisconnected(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_ongamepaddisconnected(state, value);
    }

    pub fn get_onportalactivate(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_onportalactivate(state);
    }

    pub fn set_onportalactivate(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowImpl.set_onportalactivate(state, value);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_origin(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return WindowImpl.get_origin(state);
    }

    pub fn get_isSecureContext(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return WindowImpl.get_isSecureContext(state);
    }

    pub fn get_crossOriginIsolated(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return WindowImpl.get_crossOriginIsolated(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_indexedDB(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_indexedDB) |cached| {
            return cached;
        }
        const value = WindowImpl.get_indexedDB(state);
        state.cached_indexedDB = value;
        return value;
    }

    pub fn get_trustedTypes(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_trustedTypes(state);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_performance(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_performance(state);
    }

    /// Extended attributes: [SecureContext], [SameObject]
    pub fn get_caches(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_caches) |cached| {
            return cached;
        }
        const value = WindowImpl.get_caches(state);
        state.cached_caches = value;
        return value;
    }

    /// Extended attributes: [Replaceable]
    pub fn get_scheduler(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_scheduler(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_crypto(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_crypto) |cached| {
            return cached;
        }
        const value = WindowImpl.get_crypto(state);
        state.cached_crypto = value;
        return value;
    }

    pub fn get_sessionStorage(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_sessionStorage(state);
    }

    pub fn get_localStorage(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.get_localStorage(state);
    }

    pub fn call_print(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.call_print(state);
    }

    pub fn call_confirm(instance: *runtime.Instance, message: runtime.DOMString) bool {
        const state = instance.getState(State);
        
        return WindowImpl.call_confirm(state, message);
    }

    /// Arguments for postMessage (WebIDL overloading)
    pub const PostMessageArgs = union(enum) {
        /// postMessage(message, targetOrigin, transfer)
        any_USVString_sequence: struct {
            message: anyopaque,
            targetOrigin: runtime.USVString,
            transfer: anyopaque,
        },
        /// postMessage(message, options)
        any_WindowPostMessageOptions: struct {
            message: anyopaque,
            options: anyopaque,
        },
    };

    pub fn call_postMessage(instance: *runtime.Instance, args: PostMessageArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .any_USVString_sequence => |a| return WindowImpl.any_USVString_sequence(state, a.message, a.targetOrigin, a.transfer),
            .any_WindowPostMessageOptions => |a| return WindowImpl.any_WindowPostMessageOptions(state, a.message, a.options),
        }
    }

    pub fn call_showDirectoryPicker(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WindowImpl.call_showDirectoryPicker(state, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_matchMedia(instance: *runtime.Instance, query: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return WindowImpl.call_matchMedia(state, query);
    }

    /// Arguments for scroll (WebIDL overloading)
    pub const ScrollArgs = union(enum) {
        /// scroll(options)
        ScrollToOptions: anyopaque,
        /// scroll(x, y)
        unrestricted double_unrestricted double: struct {
            x: f64,
            y: f64,
        },
    };

    pub fn call_scroll(instance: *runtime.Instance, args: ScrollArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .ScrollToOptions => |arg| return WindowImpl.ScrollToOptions(state, arg),
            .unrestricted double_unrestricted double => |a| return WindowImpl.unrestricted double_unrestricted double(state, a.x, a.y),
        }
    }

    pub fn call_resizeTo(instance: *runtime.Instance, width: i32, height: i32) anyopaque {
        const state = instance.getState(State);
        
        return WindowImpl.call_resizeTo(state, width, height);
    }

    pub fn call_showSaveFilePicker(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WindowImpl.call_showSaveFilePicker(state, options);
    }

    pub fn call_setTimeout(instance: *runtime.Instance, handler: anyopaque, timeout: i32, arguments: anyopaque) i32 {
        const state = instance.getState(State);
        
        return WindowImpl.call_setTimeout(state, handler, timeout, arguments);
    }

    pub fn call_clearInterval(instance: *runtime.Instance, id: i32) anyopaque {
        const state = instance.getState(State);
        
        return WindowImpl.call_clearInterval(state, id);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WindowImpl.call_removeEventListener(state, type_, callback, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_fetch(instance: *runtime.Instance, input: anyopaque, init: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return WindowImpl.call_fetch(state, input, init);
    }

    pub fn call_blur(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.call_blur(state);
    }

    pub fn call_showOpenFilePicker(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WindowImpl.call_showOpenFilePicker(state, options);
    }

    /// Arguments for scrollBy (WebIDL overloading)
    pub const ScrollByArgs = union(enum) {
        /// scrollBy(options)
        ScrollToOptions: anyopaque,
        /// scrollBy(x, y)
        unrestricted double_unrestricted double: struct {
            x: f64,
            y: f64,
        },
    };

    pub fn call_scrollBy(instance: *runtime.Instance, args: ScrollByArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .ScrollToOptions => |arg| return WindowImpl.ScrollToOptions(state, arg),
            .unrestricted double_unrestricted double => |a| return WindowImpl.unrestricted double_unrestricted double(state, a.x, a.y),
        }
    }

    pub fn call_releaseEvents(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.call_releaseEvents(state);
    }

    pub fn call_atob(instance: *runtime.Instance, data: runtime.DOMString) runtime.ByteString {
        const state = instance.getState(State);
        
        return WindowImpl.call_atob(state, data);
    }

    /// Arguments for alert (WebIDL overloading)
    pub const AlertArgs = union(enum) {
        /// alert()
        no_params: void,
        /// alert(message)
        string: runtime.DOMString,
    };

    pub fn call_alert(instance: *runtime.Instance, args: AlertArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .no_params => return WindowImpl.no_params(state),
            .string => |arg| return WindowImpl.string(state, arg),
        }
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return WindowImpl.call_dispatchEvent(state, event);
    }

    pub fn call_btoa(instance: *runtime.Instance, data: runtime.DOMString) runtime.DOMString {
        const state = instance.getState(State);
        
        return WindowImpl.call_btoa(state, data);
    }

    pub fn call_focus(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.call_focus(state);
    }

    pub fn call_requestIdleCallback(instance: *runtime.Instance, callback: anyopaque, options: anyopaque) u32 {
        const state = instance.getState(State);
        
        return WindowImpl.call_requestIdleCallback(state, callback, options);
    }

    pub fn call_queueMicrotask(instance: *runtime.Instance, callback: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WindowImpl.call_queueMicrotask(state, callback);
    }

    pub fn call_structuredClone(instance: *runtime.Instance, value: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WindowImpl.call_structuredClone(state, value, options);
    }

    pub fn call_close(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.call_close(state);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_getDigitalGoodsService(instance: *runtime.Instance, serviceProvider: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return WindowImpl.call_getDigitalGoodsService(state, serviceProvider);
    }

    pub fn call_moveBy(instance: *runtime.Instance, x: i32, y: i32) anyopaque {
        const state = instance.getState(State);
        
        return WindowImpl.call_moveBy(state, x, y);
    }

    pub fn call_getSelection(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.call_getSelection(state);
    }

    pub fn call_stop(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.call_stop(state);
    }

    pub fn call_resizeBy(instance: *runtime.Instance, x: i32, y: i32) anyopaque {
        const state = instance.getState(State);
        
        return WindowImpl.call_resizeBy(state, x, y);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WindowImpl.call_when(state, type_, options);
    }

    pub fn call_open(instance: *runtime.Instance, url: runtime.USVString, target: runtime.DOMString, features: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return WindowImpl.call_open(state, url, target, features);
    }

    pub fn call_moveTo(instance: *runtime.Instance, x: i32, y: i32) anyopaque {
        const state = instance.getState(State);
        
        return WindowImpl.call_moveTo(state, x, y);
    }

    pub fn call_prompt(instance: *runtime.Instance, message: runtime.DOMString, default: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return WindowImpl.call_prompt(state, message, default);
    }

    /// Arguments for scrollTo (WebIDL overloading)
    pub const ScrollToArgs = union(enum) {
        /// scrollTo(options)
        ScrollToOptions: anyopaque,
        /// scrollTo(x, y)
        unrestricted double_unrestricted double: struct {
            x: f64,
            y: f64,
        },
    };

    pub fn call_scrollTo(instance: *runtime.Instance, args: ScrollToArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .ScrollToOptions => |arg| return WindowImpl.ScrollToOptions(state, arg),
            .unrestricted double_unrestricted double => |a| return WindowImpl.unrestricted double_unrestricted double(state, a.x, a.y),
        }
    }

    pub fn call_reportError(instance: *runtime.Instance, e: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WindowImpl.call_reportError(state, e);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getComputedStyle(instance: *runtime.Instance, elt: anyopaque, pseudoElt: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return WindowImpl.call_getComputedStyle(state, elt, pseudoElt);
    }

    pub fn call_clearTimeout(instance: *runtime.Instance, id: i32) anyopaque {
        const state = instance.getState(State);
        
        return WindowImpl.call_clearTimeout(state, id);
    }

    pub fn call_setInterval(instance: *runtime.Instance, handler: anyopaque, timeout: i32, arguments: anyopaque) i32 {
        const state = instance.getState(State);
        
        return WindowImpl.call_setInterval(state, handler, timeout, arguments);
    }

    pub fn call_cancelAnimationFrame(instance: *runtime.Instance, handle: u32) anyopaque {
        const state = instance.getState(State);
        
        return WindowImpl.call_cancelAnimationFrame(state, handle);
    }

    /// Extended attributes: [NewObject], [SecureContext]
    pub fn call_fetchLater(instance: *runtime.Instance, input: anyopaque, init: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return WindowImpl.call_fetchLater(state, input, init);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WindowImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_requestAnimationFrame(instance: *runtime.Instance, callback: anyopaque) u32 {
        const state = instance.getState(State);
        
        return WindowImpl.call_requestAnimationFrame(state, callback);
    }

    /// Arguments for createImageBitmap (WebIDL overloading)
    pub const CreateImageBitmapArgs = union(enum) {
        /// createImageBitmap(image, options)
        ImageBitmapSource_ImageBitmapOptions: struct {
            image: anyopaque,
            options: anyopaque,
        },
        /// createImageBitmap(image, sx, sy, sw, sh, options)
        ImageBitmapSource_long_long_long_long_ImageBitmapOptions: struct {
            image: anyopaque,
            sx: i32,
            sy: i32,
            sw: i32,
            sh: i32,
            options: anyopaque,
        },
    };

    pub fn call_createImageBitmap(instance: *runtime.Instance, args: CreateImageBitmapArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .ImageBitmapSource_ImageBitmapOptions => |a| return WindowImpl.ImageBitmapSource_ImageBitmapOptions(state, a.image, a.options),
            .ImageBitmapSource_long_long_long_long_ImageBitmapOptions => |a| return WindowImpl.ImageBitmapSource_long_long_long_long_ImageBitmapOptions(state, a.image, a.sx, a.sy, a.sw, a.sh, a.options),
        }
    }

    pub fn call_cancelIdleCallback(instance: *runtime.Instance, handle: u32) anyopaque {
        const state = instance.getState(State);
        
        return WindowImpl.call_cancelIdleCallback(state, handle);
    }

    pub fn call_captureEvents(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.call_captureEvents(state);
    }

    pub fn call_queryLocalFonts(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WindowImpl.call_queryLocalFonts(state, options);
    }

    pub fn call_navigate(instance: *runtime.Instance, dir: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WindowImpl.call_navigate(state, dir);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_getScreenDetails(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowImpl.call_getScreenDetails(state);
    }

};
