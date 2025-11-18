//! Generated from: dom.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DocumentImpl = @import("impls").Document;
const Node = @import("interfaces").Node;
const FontFaceSource = @import("interfaces").FontFaceSource;
const NonElementParentNode = @import("interfaces").NonElementParentNode;
const DocumentOrShadowRoot = @import("interfaces").DocumentOrShadowRoot;
const ParentNode = @import("interfaces").ParentNode;
const XPathEvaluatorBase = @import("interfaces").XPathEvaluatorBase;
const GlobalEventHandlers = @import("interfaces").GlobalEventHandlers;
const GeometryUtils = @import("interfaces").GeometryUtils;
const HTMLOrSVGScriptElement = @import("typedefs").HTMLOrSVGScriptElement;
const HTMLCollection = @import("interfaces").HTMLCollection;
const HTMLHeadElement = @import("interfaces").HTMLHeadElement;
const NodeIterator = @import("interfaces").NodeIterator;
const FontMetrics = @import("interfaces").FontMetrics;
const DOMPointInit = @import("dictionaries").DOMPointInit;
const Text = @import("interfaces").Text;
const GeometryNode = @import("typedefs").GeometryNode;
const Element = @import("interfaces").Element;
const Promise<boolean> = @import("interfaces").Promise<boolean>;
const XPathExpression = @import("interfaces").XPathExpression;
const BoxQuadOptions = @import("dictionaries").BoxQuadOptions;
const XPathResult = @import("interfaces").XPathResult;
const Location = @import("interfaces").Location;
const StyleSheetList = @import("interfaces").StyleSheetList;
const FragmentDirective = @import("interfaces").FragmentDirective;
const Comment = @import("interfaces").Comment;
const (boolean or ImportNodeOptions) = @import("interfaces").(boolean or ImportNodeOptions);
const (ViewTransitionUpdateCallback or StartViewTransitionOptions) = @import("interfaces").(ViewTransitionUpdateCallback or StartViewTransitionOptions);
const NamedFlowMap = @import("interfaces").NamedFlowMap;
const Promise<StorageAccessHandle> = @import("interfaces").Promise<StorageAccessHandle>;
const DOMImplementation = @import("interfaces").DOMImplementation;
const CustomElementRegistry = @import("interfaces").CustomElementRegistry;
const Range = @import("interfaces").Range;
const Event = @import("interfaces").Event;
const PermissionsPolicy = @import("interfaces").PermissionsPolicy;
const (DOMString or ElementCreationOptions) = @import("interfaces").(DOMString or ElementCreationOptions);
const Promise<sequence<BrowsingTopic>> = @import("interfaces").Promise<sequence<BrowsingTopic>>;
const DocumentType = @import("interfaces").DocumentType;
const XPathNSResolver = @import("interfaces").XPathNSResolver;
const DOMString = @import("typedefs").DOMString;
const (TrustedHTML or DOMString) = @import("interfaces").(TrustedHTML or DOMString);
const DocumentFragment = @import("interfaces").DocumentFragment;
const HTMLAllCollection = @import("interfaces").HTMLAllCollection;
const OnErrorEventHandler = @import("typedefs").OnErrorEventHandler;
const FontFaceSet = @import("interfaces").FontFaceSet;
const BrowsingTopicsOptions = @import("dictionaries").BrowsingTopicsOptions;
const DOMQuad = @import("interfaces").DOMQuad;
const DOMRectReadOnly = @import("interfaces").DOMRectReadOnly;
const StylePropertyMapReadOnly = @import("interfaces").StylePropertyMapReadOnly;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const ObservableArray<CSSStyleSheet> = @import("interfaces").ObservableArray<CSSStyleSheet>;
const CDATASection = @import("interfaces").CDATASection;
const DocumentTimeline = @import("interfaces").DocumentTimeline;
const ViewTransition = @import("interfaces").ViewTransition;
const TreeWalker = @import("interfaces").TreeWalker;
const EventHandler = @import("typedefs").EventHandler;
const DocumentReadyState = @import("enums").DocumentReadyState;
const ConvertCoordinateOptions = @import("dictionaries").ConvertCoordinateOptions;
const HTMLElement = @import("interfaces").HTMLElement;
const StorageAccessTypes = @import("dictionaries").StorageAccessTypes;
const Attr = @import("interfaces").Attr;
const WindowProxy = @import("interfaces").WindowProxy;
const DOMQuadInit = @import("dictionaries").DOMQuadInit;
const NodeList = @import("interfaces").NodeList;
const (Node or DOMString) = @import("interfaces").(Node or DOMString);
const DOMPoint = @import("interfaces").DOMPoint;
const CaretPosition = @import("interfaces").CaretPosition;
const CaretPositionFromPointOptions = @import("dictionaries").CaretPositionFromPointOptions;
const ProcessingInstruction = @import("interfaces").ProcessingInstruction;
const SVGSVGElement = @import("interfaces").SVGSVGElement;
const Selection = @import("interfaces").Selection;
const NodeFilter = @import("interfaces").NodeFilter;
const DocumentVisibilityState = @import("enums").DocumentVisibilityState;

pub const Document = struct {
    pub const Meta = struct {
        pub const name = "Document";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Node;
        pub const MixinTypes = .{
            FontFaceSource,
            NonElementParentNode,
            DocumentOrShadowRoot,
            ParentNode,
            XPathEvaluatorBase,
            GlobalEventHandlers,
            GeometryUtils,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "LegacyOverrideBuiltIns" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Properties that cannot be shadowed or deleted (configurable: false)
        pub const legacy_unforgeable_properties = .{
            "location",
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            implementation: DOMImplementation = undefined,
            URL: runtime.USVString = undefined,
            documentURI: runtime.USVString = undefined,
            compatMode: runtime.DOMString = undefined,
            characterSet: runtime.DOMString = undefined,
            charset: runtime.DOMString = undefined,
            inputEncoding: runtime.DOMString = undefined,
            contentType: runtime.DOMString = undefined,
            doctype: ?DocumentType = null,
            documentElement: ?Element = null,
            fragmentDirective: FragmentDirective = undefined,
            prerendering: bool = undefined,
            onprerenderingchange: EventHandler = undefined,
            fullscreenEnabled: bool = undefined,
            fullscreen: bool = undefined,
            onfullscreenchange: EventHandler = undefined,
            onfullscreenerror: EventHandler = undefined,
            timeline: DocumentTimeline = undefined,
            pictureInPictureEnabled: bool = undefined,
            onpointerlockchange: EventHandler = undefined,
            onpointerlockerror: EventHandler = undefined,
            onfreeze: EventHandler = undefined,
            onresume: EventHandler = undefined,
            wasDiscarded: bool = undefined,
            namedFlows: NamedFlowMap = undefined,
            rootElement: ?SVGSVGElement = null,
            activeViewTransition: ?ViewTransition = null,
            location: ?Location = null,
            domain: runtime.USVString = undefined,
            referrer: runtime.USVString = undefined,
            cookie: runtime.USVString = undefined,
            lastModified: runtime.DOMString = undefined,
            readyState: DocumentReadyState = undefined,
            title: runtime.DOMString = undefined,
            dir: runtime.DOMString = undefined,
            body: ?HTMLElement = null,
            head: ?HTMLHeadElement = null,
            images: HTMLCollection = undefined,
            embeds: HTMLCollection = undefined,
            plugins: HTMLCollection = undefined,
            links: HTMLCollection = undefined,
            forms: HTMLCollection = undefined,
            scripts: HTMLCollection = undefined,
            currentScript: ?HTMLOrSVGScriptElement = null,
            defaultView: ?WindowProxy = null,
            designMode: runtime.DOMString = undefined,
            hidden: bool = undefined,
            visibilityState: DocumentVisibilityState = undefined,
            onreadystatechange: EventHandler = undefined,
            onvisibilitychange: EventHandler = undefined,
            fgColor: runtime.DOMString = undefined,
            linkColor: runtime.DOMString = undefined,
            vlinkColor: runtime.DOMString = undefined,
            alinkColor: runtime.DOMString = undefined,
            bgColor: runtime.DOMString = undefined,
            anchors: HTMLCollection = undefined,
            applets: HTMLCollection = undefined,
            all: HTMLAllCollection = undefined,
            scrollingElement: ?Element = null,
            permissionsPolicy: PermissionsPolicy = undefined,
            fonts: FontFaceSet = undefined,
            customElementRegistry: ?CustomElementRegistry = null,
            fullscreenElement: ?Element = null,
            pictureInPictureElement: ?Element = null,
            pointerLockElement: ?Element = null,
            styleSheets: StyleSheetList = undefined,
            adoptedStyleSheets: ObservableArray<CSSStyleSheet> = undefined,
            activeElement: ?Element = null,
            children: HTMLCollection = undefined,
            firstElementChild: ?Element = null,
            lastElementChild: ?Element = null,
            childElementCount: u32 = undefined,
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
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Document, .{
        .deinit_fn = &deinit_wrapper,

        .get_ATTRIBUTE_NODE = &Node.get_ATTRIBUTE_NODE,
        .get_CDATA_SECTION_NODE = &Node.get_CDATA_SECTION_NODE,
        .get_COMMENT_NODE = &Node.get_COMMENT_NODE,
        .get_DOCUMENT_FRAGMENT_NODE = &Node.get_DOCUMENT_FRAGMENT_NODE,
        .get_DOCUMENT_NODE = &Node.get_DOCUMENT_NODE,
        .get_DOCUMENT_POSITION_CONTAINED_BY = &Node.get_DOCUMENT_POSITION_CONTAINED_BY,
        .get_DOCUMENT_POSITION_CONTAINS = &Node.get_DOCUMENT_POSITION_CONTAINS,
        .get_DOCUMENT_POSITION_DISCONNECTED = &Node.get_DOCUMENT_POSITION_DISCONNECTED,
        .get_DOCUMENT_POSITION_FOLLOWING = &Node.get_DOCUMENT_POSITION_FOLLOWING,
        .get_DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC = &Node.get_DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC,
        .get_DOCUMENT_POSITION_PRECEDING = &Node.get_DOCUMENT_POSITION_PRECEDING,
        .get_DOCUMENT_TYPE_NODE = &Node.get_DOCUMENT_TYPE_NODE,
        .get_ELEMENT_NODE = &Node.get_ELEMENT_NODE,
        .get_ENTITY_NODE = &Node.get_ENTITY_NODE,
        .get_ENTITY_REFERENCE_NODE = &Node.get_ENTITY_REFERENCE_NODE,
        .get_NOTATION_NODE = &Node.get_NOTATION_NODE,
        .get_PROCESSING_INSTRUCTION_NODE = &Node.get_PROCESSING_INSTRUCTION_NODE,
        .get_TEXT_NODE = &Node.get_TEXT_NODE,
        .get_URL = &get_URL,
        .get_activeElement = &get_activeElement,
        .get_activeViewTransition = &get_activeViewTransition,
        .get_adoptedStyleSheets = &get_adoptedStyleSheets,
        .get_alinkColor = &get_alinkColor,
        .get_all = &get_all,
        .get_anchors = &get_anchors,
        .get_applets = &get_applets,
        .get_baseURI = &get_baseURI,
        .get_bgColor = &get_bgColor,
        .get_body = &get_body,
        .get_characterSet = &get_characterSet,
        .get_charset = &get_charset,
        .get_childElementCount = &get_childElementCount,
        .get_childNodes = &get_childNodes,
        .get_children = &get_children,
        .get_compatMode = &get_compatMode,
        .get_contentType = &get_contentType,
        .get_cookie = &get_cookie,
        .get_currentScript = &get_currentScript,
        .get_customElementRegistry = &get_customElementRegistry,
        .get_defaultView = &get_defaultView,
        .get_designMode = &get_designMode,
        .get_dir = &get_dir,
        .get_doctype = &get_doctype,
        .get_documentElement = &get_documentElement,
        .get_documentURI = &get_documentURI,
        .get_domain = &get_domain,
        .get_embeds = &get_embeds,
        .get_fgColor = &get_fgColor,
        .get_firstChild = &get_firstChild,
        .get_firstElementChild = &get_firstElementChild,
        .get_fonts = &get_fonts,
        .get_forms = &get_forms,
        .get_fragmentDirective = &get_fragmentDirective,
        .get_fullscreen = &get_fullscreen,
        .get_fullscreenElement = &get_fullscreenElement,
        .get_fullscreenEnabled = &get_fullscreenEnabled,
        .get_head = &get_head,
        .get_hidden = &get_hidden,
        .get_images = &get_images,
        .get_implementation = &get_implementation,
        .get_inputEncoding = &get_inputEncoding,
        .get_isConnected = &get_isConnected,
        .get_lastChild = &get_lastChild,
        .get_lastElementChild = &get_lastElementChild,
        .get_lastModified = &get_lastModified,
        .get_linkColor = &get_linkColor,
        .get_links = &get_links,
        .get_location = &get_location,
        .get_namedFlows = &get_namedFlows,
        .get_nextSibling = &get_nextSibling,
        .get_nodeName = &get_nodeName,
        .get_nodeType = &get_nodeType,
        .get_nodeValue = &get_nodeValue,
        .get_onabort = &get_onabort,
        .get_onanimationcancel = &get_onanimationcancel,
        .get_onanimationend = &get_onanimationend,
        .get_onanimationiteration = &get_onanimationiteration,
        .get_onanimationstart = &get_onanimationstart,
        .get_onauxclick = &get_onauxclick,
        .get_onbeforeinput = &get_onbeforeinput,
        .get_onbeforematch = &get_onbeforematch,
        .get_onbeforetoggle = &get_onbeforetoggle,
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
        .get_onfreeze = &get_onfreeze,
        .get_onfullscreenchange = &get_onfullscreenchange,
        .get_onfullscreenerror = &get_onfullscreenerror,
        .get_ongotpointercapture = &get_ongotpointercapture,
        .get_oninput = &get_oninput,
        .get_oninvalid = &get_oninvalid,
        .get_onkeydown = &get_onkeydown,
        .get_onkeypress = &get_onkeypress,
        .get_onkeyup = &get_onkeyup,
        .get_onload = &get_onload,
        .get_onloadeddata = &get_onloadeddata,
        .get_onloadedmetadata = &get_onloadedmetadata,
        .get_onloadstart = &get_onloadstart,
        .get_onlostpointercapture = &get_onlostpointercapture,
        .get_onmousedown = &get_onmousedown,
        .get_onmouseenter = &get_onmouseenter,
        .get_onmouseleave = &get_onmouseleave,
        .get_onmousemove = &get_onmousemove,
        .get_onmouseout = &get_onmouseout,
        .get_onmouseover = &get_onmouseover,
        .get_onmouseup = &get_onmouseup,
        .get_onpaste = &get_onpaste,
        .get_onpause = &get_onpause,
        .get_onplay = &get_onplay,
        .get_onplaying = &get_onplaying,
        .get_onpointercancel = &get_onpointercancel,
        .get_onpointerdown = &get_onpointerdown,
        .get_onpointerenter = &get_onpointerenter,
        .get_onpointerleave = &get_onpointerleave,
        .get_onpointerlockchange = &get_onpointerlockchange,
        .get_onpointerlockerror = &get_onpointerlockerror,
        .get_onpointermove = &get_onpointermove,
        .get_onpointerout = &get_onpointerout,
        .get_onpointerover = &get_onpointerover,
        .get_onpointerrawupdate = &get_onpointerrawupdate,
        .get_onpointerup = &get_onpointerup,
        .get_onprerenderingchange = &get_onprerenderingchange,
        .get_onprogress = &get_onprogress,
        .get_onratechange = &get_onratechange,
        .get_onreadystatechange = &get_onreadystatechange,
        .get_onreset = &get_onreset,
        .get_onresize = &get_onresize,
        .get_onresume = &get_onresume,
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
        .get_onvisibilitychange = &get_onvisibilitychange,
        .get_onvolumechange = &get_onvolumechange,
        .get_onwaiting = &get_onwaiting,
        .get_onwebkitanimationend = &get_onwebkitanimationend,
        .get_onwebkitanimationiteration = &get_onwebkitanimationiteration,
        .get_onwebkitanimationstart = &get_onwebkitanimationstart,
        .get_onwebkittransitionend = &get_onwebkittransitionend,
        .get_onwheel = &get_onwheel,
        .get_ownerDocument = &get_ownerDocument,
        .get_parentElement = &get_parentElement,
        .get_parentNode = &get_parentNode,
        .get_permissionsPolicy = &get_permissionsPolicy,
        .get_pictureInPictureElement = &get_pictureInPictureElement,
        .get_pictureInPictureEnabled = &get_pictureInPictureEnabled,
        .get_plugins = &get_plugins,
        .get_pointerLockElement = &get_pointerLockElement,
        .get_prerendering = &get_prerendering,
        .get_previousSibling = &get_previousSibling,
        .get_readyState = &get_readyState,
        .get_referrer = &get_referrer,
        .get_rootElement = &get_rootElement,
        .get_scripts = &get_scripts,
        .get_scrollingElement = &get_scrollingElement,
        .get_styleSheets = &get_styleSheets,
        .get_textContent = &get_textContent,
        .get_timeline = &get_timeline,
        .get_title = &get_title,
        .get_visibilityState = &get_visibilityState,
        .get_vlinkColor = &get_vlinkColor,
        .get_wasDiscarded = &get_wasDiscarded,

        .set_adoptedStyleSheets = &set_adoptedStyleSheets,
        .set_alinkColor = &set_alinkColor,
        .set_bgColor = &set_bgColor,
        .set_body = &set_body,
        .set_cookie = &set_cookie,
        .set_designMode = &set_designMode,
        .set_dir = &set_dir,
        .set_domain = &set_domain,
        .set_fgColor = &set_fgColor,
        .set_linkColor = &set_linkColor,
        .set_nodeValue = &set_nodeValue,
        .set_onabort = &set_onabort,
        .set_onanimationcancel = &set_onanimationcancel,
        .set_onanimationend = &set_onanimationend,
        .set_onanimationiteration = &set_onanimationiteration,
        .set_onanimationstart = &set_onanimationstart,
        .set_onauxclick = &set_onauxclick,
        .set_onbeforeinput = &set_onbeforeinput,
        .set_onbeforematch = &set_onbeforematch,
        .set_onbeforetoggle = &set_onbeforetoggle,
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
        .set_onfreeze = &set_onfreeze,
        .set_onfullscreenchange = &set_onfullscreenchange,
        .set_onfullscreenerror = &set_onfullscreenerror,
        .set_ongotpointercapture = &set_ongotpointercapture,
        .set_oninput = &set_oninput,
        .set_oninvalid = &set_oninvalid,
        .set_onkeydown = &set_onkeydown,
        .set_onkeypress = &set_onkeypress,
        .set_onkeyup = &set_onkeyup,
        .set_onload = &set_onload,
        .set_onloadeddata = &set_onloadeddata,
        .set_onloadedmetadata = &set_onloadedmetadata,
        .set_onloadstart = &set_onloadstart,
        .set_onlostpointercapture = &set_onlostpointercapture,
        .set_onmousedown = &set_onmousedown,
        .set_onmouseenter = &set_onmouseenter,
        .set_onmouseleave = &set_onmouseleave,
        .set_onmousemove = &set_onmousemove,
        .set_onmouseout = &set_onmouseout,
        .set_onmouseover = &set_onmouseover,
        .set_onmouseup = &set_onmouseup,
        .set_onpaste = &set_onpaste,
        .set_onpause = &set_onpause,
        .set_onplay = &set_onplay,
        .set_onplaying = &set_onplaying,
        .set_onpointercancel = &set_onpointercancel,
        .set_onpointerdown = &set_onpointerdown,
        .set_onpointerenter = &set_onpointerenter,
        .set_onpointerleave = &set_onpointerleave,
        .set_onpointerlockchange = &set_onpointerlockchange,
        .set_onpointerlockerror = &set_onpointerlockerror,
        .set_onpointermove = &set_onpointermove,
        .set_onpointerout = &set_onpointerout,
        .set_onpointerover = &set_onpointerover,
        .set_onpointerrawupdate = &set_onpointerrawupdate,
        .set_onpointerup = &set_onpointerup,
        .set_onprerenderingchange = &set_onprerenderingchange,
        .set_onprogress = &set_onprogress,
        .set_onratechange = &set_onratechange,
        .set_onreadystatechange = &set_onreadystatechange,
        .set_onreset = &set_onreset,
        .set_onresize = &set_onresize,
        .set_onresume = &set_onresume,
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
        .set_onvisibilitychange = &set_onvisibilitychange,
        .set_onvolumechange = &set_onvolumechange,
        .set_onwaiting = &set_onwaiting,
        .set_onwebkitanimationend = &set_onwebkitanimationend,
        .set_onwebkitanimationiteration = &set_onwebkitanimationiteration,
        .set_onwebkitanimationstart = &set_onwebkitanimationstart,
        .set_onwebkittransitionend = &set_onwebkittransitionend,
        .set_onwheel = &set_onwheel,
        .set_textContent = &set_textContent,
        .set_title = &set_title,
        .set_vlinkColor = &set_vlinkColor,

        .call_addEventListener = &call_addEventListener,
        .call_adoptNode = &call_adoptNode,
        .call_append = &call_append,
        .call_appendChild = &call_appendChild,
        .call_browsingTopics = &call_browsingTopics,
        .call_captureEvents = &call_captureEvents,
        .call_caretPositionFromPoint = &call_caretPositionFromPoint,
        .call_clear = &call_clear,
        .call_cloneNode = &call_cloneNode,
        .call_close = &call_close,
        .call_compareDocumentPosition = &call_compareDocumentPosition,
        .call_contains = &call_contains,
        .call_convertPointFromNode = &call_convertPointFromNode,
        .call_convertQuadFromNode = &call_convertQuadFromNode,
        .call_convertRectFromNode = &call_convertRectFromNode,
        .call_createAttribute = &call_createAttribute,
        .call_createAttributeNS = &call_createAttributeNS,
        .call_createCDATASection = &call_createCDATASection,
        .call_createComment = &call_createComment,
        .call_createDocumentFragment = &call_createDocumentFragment,
        .call_createElement = &call_createElement,
        .call_createElementNS = &call_createElementNS,
        .call_createEvent = &call_createEvent,
        .call_createExpression = &call_createExpression,
        .call_createNSResolver = &call_createNSResolver,
        .call_createNodeIterator = &call_createNodeIterator,
        .call_createProcessingInstruction = &call_createProcessingInstruction,
        .call_createRange = &call_createRange,
        .call_createTextNode = &call_createTextNode,
        .call_createTreeWalker = &call_createTreeWalker,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_elementFromPoint = &call_elementFromPoint,
        .call_elementsFromPoint = &call_elementsFromPoint,
        .call_evaluate = &call_evaluate,
        .call_execCommand = &call_execCommand,
        .call_exitFullscreen = &call_exitFullscreen,
        .call_exitPictureInPicture = &call_exitPictureInPicture,
        .call_exitPointerLock = &call_exitPointerLock,
        .call_getAnimations = &call_getAnimations,
        .call_getBoxQuads = &call_getBoxQuads,
        .call_getElementById = &call_getElementById,
        .call_getElementsByClassName = &call_getElementsByClassName,
        .call_getElementsByName = &call_getElementsByName,
        .call_getElementsByTagName = &call_getElementsByTagName,
        .call_getElementsByTagNameNS = &call_getElementsByTagNameNS,
        .call_getRootNode = &call_getRootNode,
        .call_getSelection = &call_getSelection,
        .call_hasChildNodes = &call_hasChildNodes,
        .call_hasFocus = &call_hasFocus,
        .call_hasPrivateToken = &call_hasPrivateToken,
        .call_hasRedemptionRecord = &call_hasRedemptionRecord,
        .call_hasStorageAccess = &call_hasStorageAccess,
        .call_hasUnpartitionedCookieAccess = &call_hasUnpartitionedCookieAccess,
        .call_importNode = &call_importNode,
        .call_insertBefore = &call_insertBefore,
        .call_isDefaultNamespace = &call_isDefaultNamespace,
        .call_isEqualNode = &call_isEqualNode,
        .call_isSameNode = &call_isSameNode,
        .call_lookupNamespaceURI = &call_lookupNamespaceURI,
        .call_lookupPrefix = &call_lookupPrefix,
        .call_measureElement = &call_measureElement,
        .call_measureText = &call_measureText,
        .call_moveBefore = &call_moveBefore,
        .call_normalize = &call_normalize,
        .call_open = &call_open,
        .call_parseHTMLUnsafe = &call_parseHTMLUnsafe,
        .call_prepend = &call_prepend,
        .call_queryCommandEnabled = &call_queryCommandEnabled,
        .call_queryCommandIndeterm = &call_queryCommandIndeterm,
        .call_queryCommandState = &call_queryCommandState,
        .call_queryCommandSupported = &call_queryCommandSupported,
        .call_queryCommandValue = &call_queryCommandValue,
        .call_querySelector = &call_querySelector,
        .call_querySelectorAll = &call_querySelectorAll,
        .call_releaseEvents = &call_releaseEvents,
        .call_removeChild = &call_removeChild,
        .call_removeEventListener = &call_removeEventListener,
        .call_replaceChild = &call_replaceChild,
        .call_replaceChildren = &call_replaceChildren,
        .call_requestStorageAccess = &call_requestStorageAccess,
        .call_requestStorageAccessFor = &call_requestStorageAccessFor,
        .call_startViewTransition = &call_startViewTransition,
        .call_when = &call_when,
        .call_write = &call_write,
        .call_writeln = &call_writeln,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        DocumentImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DocumentImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try DocumentImpl.constructor(instance);
        
        return instance;
    }

    pub fn get_nodeType(instance: *runtime.Instance) anyerror!u16 {
        return try DocumentImpl.get_nodeType(instance);
    }

    pub fn get_nodeName(instance: *runtime.Instance) anyerror!DOMString {
        return try DocumentImpl.get_nodeName(instance);
    }

    pub fn get_baseURI(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try DocumentImpl.get_baseURI(instance);
    }

    pub fn get_isConnected(instance: *runtime.Instance) anyerror!bool {
        return try DocumentImpl.get_isConnected(instance);
    }

    pub fn get_ownerDocument(instance: *runtime.Instance) anyerror!anyopaque {
        return try DocumentImpl.get_ownerDocument(instance);
    }

    pub fn get_parentNode(instance: *runtime.Instance) anyerror!anyopaque {
        return try DocumentImpl.get_parentNode(instance);
    }

    pub fn get_parentElement(instance: *runtime.Instance) anyerror!anyopaque {
        return try DocumentImpl.get_parentElement(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_childNodes(instance: *runtime.Instance) anyerror!NodeList {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_childNodes) |cached| {
            return cached;
        }
        const value = try DocumentImpl.get_childNodes(instance);
        state.cached_childNodes = value;
        return value;
    }

    pub fn get_firstChild(instance: *runtime.Instance) anyerror!anyopaque {
        return try DocumentImpl.get_firstChild(instance);
    }

    pub fn get_lastChild(instance: *runtime.Instance) anyerror!anyopaque {
        return try DocumentImpl.get_lastChild(instance);
    }

    pub fn get_previousSibling(instance: *runtime.Instance) anyerror!anyopaque {
        return try DocumentImpl.get_previousSibling(instance);
    }

    pub fn get_nextSibling(instance: *runtime.Instance) anyerror!anyopaque {
        return try DocumentImpl.get_nextSibling(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_nodeValue(instance: *runtime.Instance) anyerror!anyopaque {
        return try DocumentImpl.get_nodeValue(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_nodeValue(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try DocumentImpl.set_nodeValue(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_textContent(instance: *runtime.Instance) anyerror!anyopaque {
        return try DocumentImpl.get_textContent(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_textContent(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try DocumentImpl.set_textContent(instance, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_implementation(instance: *runtime.Instance) anyerror!DOMImplementation {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_implementation) |cached| {
            return cached;
        }
        const value = try DocumentImpl.get_implementation(instance);
        state.cached_implementation = value;
        return value;
    }

    pub fn get_URL(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try DocumentImpl.get_URL(instance);
    }

    pub fn get_documentURI(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try DocumentImpl.get_documentURI(instance);
    }

    pub fn get_compatMode(instance: *runtime.Instance) anyerror!DOMString {
        return try DocumentImpl.get_compatMode(instance);
    }

    pub fn get_characterSet(instance: *runtime.Instance) anyerror!DOMString {
        return try DocumentImpl.get_characterSet(instance);
    }

    pub fn get_charset(instance: *runtime.Instance) anyerror!DOMString {
        return try DocumentImpl.get_charset(instance);
    }

    pub fn get_inputEncoding(instance: *runtime.Instance) anyerror!DOMString {
        return try DocumentImpl.get_inputEncoding(instance);
    }

    pub fn get_contentType(instance: *runtime.Instance) anyerror!DOMString {
        return try DocumentImpl.get_contentType(instance);
    }

    pub fn get_doctype(instance: *runtime.Instance) anyerror!anyopaque {
        return try DocumentImpl.get_doctype(instance);
    }

    pub fn get_documentElement(instance: *runtime.Instance) anyerror!anyopaque {
        return try DocumentImpl.get_documentElement(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_fragmentDirective(instance: *runtime.Instance) anyerror!FragmentDirective {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_fragmentDirective) |cached| {
            return cached;
        }
        const value = try DocumentImpl.get_fragmentDirective(instance);
        state.cached_fragmentDirective = value;
        return value;
    }

    pub fn get_prerendering(instance: *runtime.Instance) anyerror!bool {
        return try DocumentImpl.get_prerendering(instance);
    }

    pub fn get_onprerenderingchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onprerenderingchange(instance);
    }

    pub fn set_onprerenderingchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onprerenderingchange(instance, value);
    }

    /// Extended attributes: [LegacyLenientSetter]
    pub fn get_fullscreenEnabled(instance: *runtime.Instance) anyerror!bool {
        return try DocumentImpl.get_fullscreenEnabled(instance);
    }

    /// Extended attributes: [LegacyLenientSetter], [Unscopable]
    pub fn get_fullscreen(instance: *runtime.Instance) anyerror!bool {
        return try DocumentImpl.get_fullscreen(instance);
    }

    pub fn get_onfullscreenchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onfullscreenchange(instance);
    }

    pub fn set_onfullscreenchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onfullscreenchange(instance, value);
    }

    pub fn get_onfullscreenerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onfullscreenerror(instance);
    }

    pub fn set_onfullscreenerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onfullscreenerror(instance, value);
    }

    pub fn get_timeline(instance: *runtime.Instance) anyerror!DocumentTimeline {
        return try DocumentImpl.get_timeline(instance);
    }

    pub fn get_pictureInPictureEnabled(instance: *runtime.Instance) anyerror!bool {
        return try DocumentImpl.get_pictureInPictureEnabled(instance);
    }

    pub fn get_onpointerlockchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onpointerlockchange(instance);
    }

    pub fn set_onpointerlockchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onpointerlockchange(instance, value);
    }

    pub fn get_onpointerlockerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onpointerlockerror(instance);
    }

    pub fn set_onpointerlockerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onpointerlockerror(instance, value);
    }

    pub fn get_onfreeze(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onfreeze(instance);
    }

    pub fn set_onfreeze(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onfreeze(instance, value);
    }

    pub fn get_onresume(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onresume(instance);
    }

    pub fn set_onresume(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onresume(instance, value);
    }

    pub fn get_wasDiscarded(instance: *runtime.Instance) anyerror!bool {
        return try DocumentImpl.get_wasDiscarded(instance);
    }

    pub fn get_namedFlows(instance: *runtime.Instance) anyerror!NamedFlowMap {
        return try DocumentImpl.get_namedFlows(instance);
    }

    pub fn get_rootElement(instance: *runtime.Instance) anyerror!anyopaque {
        return try DocumentImpl.get_rootElement(instance);
    }

    pub fn get_activeViewTransition(instance: *runtime.Instance) anyerror!anyopaque {
        return try DocumentImpl.get_activeViewTransition(instance);
    }

    /// Extended attributes: [PutForwards=href], [LegacyUnforgeable]
    pub fn get_location(instance: *runtime.Instance) anyerror!anyopaque {
        return try DocumentImpl.get_location(instance);
    }

    pub fn get_domain(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try DocumentImpl.get_domain(instance);
    }

    pub fn set_domain(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try DocumentImpl.set_domain(instance, value);
    }

    pub fn get_referrer(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try DocumentImpl.get_referrer(instance);
    }

    pub fn get_cookie(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try DocumentImpl.get_cookie(instance);
    }

    pub fn set_cookie(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try DocumentImpl.set_cookie(instance, value);
    }

    pub fn get_lastModified(instance: *runtime.Instance) anyerror!DOMString {
        return try DocumentImpl.get_lastModified(instance);
    }

    pub fn get_readyState(instance: *runtime.Instance) anyerror!DocumentReadyState {
        return try DocumentImpl.get_readyState(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_title(instance: *runtime.Instance) anyerror!DOMString {
        return try DocumentImpl.get_title(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_title(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try DocumentImpl.set_title(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_dir(instance: *runtime.Instance) anyerror!DOMString {
        return try DocumentImpl.get_dir(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_dir(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try DocumentImpl.set_dir(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_body(instance: *runtime.Instance) anyerror!anyopaque {
        return try DocumentImpl.get_body(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_body(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try DocumentImpl.set_body(instance, value);
    }

    pub fn get_head(instance: *runtime.Instance) anyerror!anyopaque {
        return try DocumentImpl.get_head(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_images(instance: *runtime.Instance) anyerror!HTMLCollection {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_images) |cached| {
            return cached;
        }
        const value = try DocumentImpl.get_images(instance);
        state.cached_images = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_embeds(instance: *runtime.Instance) anyerror!HTMLCollection {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_embeds) |cached| {
            return cached;
        }
        const value = try DocumentImpl.get_embeds(instance);
        state.cached_embeds = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_plugins(instance: *runtime.Instance) anyerror!HTMLCollection {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_plugins) |cached| {
            return cached;
        }
        const value = try DocumentImpl.get_plugins(instance);
        state.cached_plugins = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_links(instance: *runtime.Instance) anyerror!HTMLCollection {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_links) |cached| {
            return cached;
        }
        const value = try DocumentImpl.get_links(instance);
        state.cached_links = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_forms(instance: *runtime.Instance) anyerror!HTMLCollection {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_forms) |cached| {
            return cached;
        }
        const value = try DocumentImpl.get_forms(instance);
        state.cached_forms = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_scripts(instance: *runtime.Instance) anyerror!HTMLCollection {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_scripts) |cached| {
            return cached;
        }
        const value = try DocumentImpl.get_scripts(instance);
        state.cached_scripts = value;
        return value;
    }

    pub fn get_currentScript(instance: *runtime.Instance) anyerror!anyopaque {
        return try DocumentImpl.get_currentScript(instance);
    }

    pub fn get_defaultView(instance: *runtime.Instance) anyerror!anyopaque {
        return try DocumentImpl.get_defaultView(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_designMode(instance: *runtime.Instance) anyerror!DOMString {
        return try DocumentImpl.get_designMode(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_designMode(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try DocumentImpl.set_designMode(instance, value);
    }

    pub fn get_hidden(instance: *runtime.Instance) anyerror!bool {
        return try DocumentImpl.get_hidden(instance);
    }

    pub fn get_visibilityState(instance: *runtime.Instance) anyerror!DocumentVisibilityState {
        return try DocumentImpl.get_visibilityState(instance);
    }

    /// Extended attributes: [LegacyLenientThis]
    pub fn get_onreadystatechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onreadystatechange(instance);
    }

    /// Extended attributes: [LegacyLenientThis]
    pub fn set_onreadystatechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onreadystatechange(instance, value);
    }

    pub fn get_onvisibilitychange(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onvisibilitychange(instance);
    }

    pub fn set_onvisibilitychange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onvisibilitychange(instance, value);
    }

    /// Extended attributes: [CEReactions], [LegacyNullToEmptyString]
    pub fn get_fgColor(instance: *runtime.Instance) anyerror!DOMString {
        return try DocumentImpl.get_fgColor(instance);
    }

    /// Extended attributes: [CEReactions], [LegacyNullToEmptyString]
    pub fn set_fgColor(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try DocumentImpl.set_fgColor(instance, value);
    }

    /// Extended attributes: [CEReactions], [LegacyNullToEmptyString]
    pub fn get_linkColor(instance: *runtime.Instance) anyerror!DOMString {
        return try DocumentImpl.get_linkColor(instance);
    }

    /// Extended attributes: [CEReactions], [LegacyNullToEmptyString]
    pub fn set_linkColor(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try DocumentImpl.set_linkColor(instance, value);
    }

    /// Extended attributes: [CEReactions], [LegacyNullToEmptyString]
    pub fn get_vlinkColor(instance: *runtime.Instance) anyerror!DOMString {
        return try DocumentImpl.get_vlinkColor(instance);
    }

    /// Extended attributes: [CEReactions], [LegacyNullToEmptyString]
    pub fn set_vlinkColor(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try DocumentImpl.set_vlinkColor(instance, value);
    }

    /// Extended attributes: [CEReactions], [LegacyNullToEmptyString]
    pub fn get_alinkColor(instance: *runtime.Instance) anyerror!DOMString {
        return try DocumentImpl.get_alinkColor(instance);
    }

    /// Extended attributes: [CEReactions], [LegacyNullToEmptyString]
    pub fn set_alinkColor(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try DocumentImpl.set_alinkColor(instance, value);
    }

    /// Extended attributes: [CEReactions], [LegacyNullToEmptyString]
    pub fn get_bgColor(instance: *runtime.Instance) anyerror!DOMString {
        return try DocumentImpl.get_bgColor(instance);
    }

    /// Extended attributes: [CEReactions], [LegacyNullToEmptyString]
    pub fn set_bgColor(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try DocumentImpl.set_bgColor(instance, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_anchors(instance: *runtime.Instance) anyerror!HTMLCollection {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_anchors) |cached| {
            return cached;
        }
        const value = try DocumentImpl.get_anchors(instance);
        state.cached_anchors = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_applets(instance: *runtime.Instance) anyerror!HTMLCollection {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_applets) |cached| {
            return cached;
        }
        const value = try DocumentImpl.get_applets(instance);
        state.cached_applets = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_all(instance: *runtime.Instance) anyerror!HTMLAllCollection {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_all) |cached| {
            return cached;
        }
        const value = try DocumentImpl.get_all(instance);
        state.cached_all = value;
        return value;
    }

    pub fn get_scrollingElement(instance: *runtime.Instance) anyerror!anyopaque {
        return try DocumentImpl.get_scrollingElement(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_permissionsPolicy(instance: *runtime.Instance) anyerror!PermissionsPolicy {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_permissionsPolicy) |cached| {
            return cached;
        }
        const value = try DocumentImpl.get_permissionsPolicy(instance);
        state.cached_permissionsPolicy = value;
        return value;
    }

    pub fn get_fonts(instance: *runtime.Instance) anyerror!FontFaceSet {
        return try DocumentImpl.get_fonts(instance);
    }

    pub fn get_customElementRegistry(instance: *runtime.Instance) anyerror!anyopaque {
        return try DocumentImpl.get_customElementRegistry(instance);
    }

    /// Extended attributes: [LegacyLenientSetter]
    pub fn get_fullscreenElement(instance: *runtime.Instance) anyerror!anyopaque {
        return try DocumentImpl.get_fullscreenElement(instance);
    }

    pub fn get_pictureInPictureElement(instance: *runtime.Instance) anyerror!anyopaque {
        return try DocumentImpl.get_pictureInPictureElement(instance);
    }

    pub fn get_pointerLockElement(instance: *runtime.Instance) anyerror!anyopaque {
        return try DocumentImpl.get_pointerLockElement(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_styleSheets(instance: *runtime.Instance) anyerror!StyleSheetList {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_styleSheets) |cached| {
            return cached;
        }
        const value = try DocumentImpl.get_styleSheets(instance);
        state.cached_styleSheets = value;
        return value;
    }

    pub fn get_adoptedStyleSheets(instance: *runtime.Instance) anyerror!anyopaque {
        return try DocumentImpl.get_adoptedStyleSheets(instance);
    }

    pub fn set_adoptedStyleSheets(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try DocumentImpl.set_adoptedStyleSheets(instance, value);
    }

    pub fn get_activeElement(instance: *runtime.Instance) anyerror!anyopaque {
        return try DocumentImpl.get_activeElement(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_children(instance: *runtime.Instance) anyerror!HTMLCollection {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_children) |cached| {
            return cached;
        }
        const value = try DocumentImpl.get_children(instance);
        state.cached_children = value;
        return value;
    }

    pub fn get_firstElementChild(instance: *runtime.Instance) anyerror!anyopaque {
        return try DocumentImpl.get_firstElementChild(instance);
    }

    pub fn get_lastElementChild(instance: *runtime.Instance) anyerror!anyopaque {
        return try DocumentImpl.get_lastElementChild(instance);
    }

    pub fn get_childElementCount(instance: *runtime.Instance) anyerror!u32 {
        return try DocumentImpl.get_childElementCount(instance);
    }

    pub fn get_onabort(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onabort(instance);
    }

    pub fn set_onabort(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onabort(instance, value);
    }

    pub fn get_onauxclick(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onauxclick(instance);
    }

    pub fn set_onauxclick(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onauxclick(instance, value);
    }

    pub fn get_onbeforeinput(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onbeforeinput(instance);
    }

    pub fn set_onbeforeinput(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onbeforeinput(instance, value);
    }

    pub fn get_onbeforematch(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onbeforematch(instance);
    }

    pub fn set_onbeforematch(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onbeforematch(instance, value);
    }

    pub fn get_onbeforetoggle(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onbeforetoggle(instance);
    }

    pub fn set_onbeforetoggle(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onbeforetoggle(instance, value);
    }

    pub fn get_onblur(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onblur(instance);
    }

    pub fn set_onblur(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onblur(instance, value);
    }

    pub fn get_oncancel(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_oncancel(instance);
    }

    pub fn set_oncancel(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_oncancel(instance, value);
    }

    pub fn get_oncanplay(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_oncanplay(instance);
    }

    pub fn set_oncanplay(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_oncanplay(instance, value);
    }

    pub fn get_oncanplaythrough(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_oncanplaythrough(instance);
    }

    pub fn set_oncanplaythrough(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_oncanplaythrough(instance, value);
    }

    pub fn get_onchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onchange(instance);
    }

    pub fn set_onchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onchange(instance, value);
    }

    pub fn get_onclick(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onclick(instance);
    }

    pub fn set_onclick(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onclick(instance, value);
    }

    pub fn get_onclose(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onclose(instance);
    }

    pub fn set_onclose(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onclose(instance, value);
    }

    pub fn get_oncommand(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_oncommand(instance);
    }

    pub fn set_oncommand(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_oncommand(instance, value);
    }

    pub fn get_oncontextlost(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_oncontextlost(instance);
    }

    pub fn set_oncontextlost(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_oncontextlost(instance, value);
    }

    pub fn get_oncontextmenu(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_oncontextmenu(instance);
    }

    pub fn set_oncontextmenu(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_oncontextmenu(instance, value);
    }

    pub fn get_oncontextrestored(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_oncontextrestored(instance);
    }

    pub fn set_oncontextrestored(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_oncontextrestored(instance, value);
    }

    pub fn get_oncopy(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_oncopy(instance);
    }

    pub fn set_oncopy(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_oncopy(instance, value);
    }

    pub fn get_oncuechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_oncuechange(instance);
    }

    pub fn set_oncuechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_oncuechange(instance, value);
    }

    pub fn get_oncut(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_oncut(instance);
    }

    pub fn set_oncut(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_oncut(instance, value);
    }

    pub fn get_ondblclick(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_ondblclick(instance);
    }

    pub fn set_ondblclick(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_ondblclick(instance, value);
    }

    pub fn get_ondrag(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_ondrag(instance);
    }

    pub fn set_ondrag(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_ondrag(instance, value);
    }

    pub fn get_ondragend(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_ondragend(instance);
    }

    pub fn set_ondragend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_ondragend(instance, value);
    }

    pub fn get_ondragenter(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_ondragenter(instance);
    }

    pub fn set_ondragenter(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_ondragenter(instance, value);
    }

    pub fn get_ondragleave(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_ondragleave(instance);
    }

    pub fn set_ondragleave(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_ondragleave(instance, value);
    }

    pub fn get_ondragover(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_ondragover(instance);
    }

    pub fn set_ondragover(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_ondragover(instance, value);
    }

    pub fn get_ondragstart(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_ondragstart(instance);
    }

    pub fn set_ondragstart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_ondragstart(instance, value);
    }

    pub fn get_ondrop(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_ondrop(instance);
    }

    pub fn set_ondrop(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_ondrop(instance, value);
    }

    pub fn get_ondurationchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_ondurationchange(instance);
    }

    pub fn set_ondurationchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_ondurationchange(instance, value);
    }

    pub fn get_onemptied(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onemptied(instance);
    }

    pub fn set_onemptied(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onemptied(instance, value);
    }

    pub fn get_onended(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onended(instance);
    }

    pub fn set_onended(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onended(instance, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!OnErrorEventHandler {
        return try DocumentImpl.get_onerror(instance);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: OnErrorEventHandler) anyerror!void {
        try DocumentImpl.set_onerror(instance, value);
    }

    pub fn get_onfocus(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onfocus(instance);
    }

    pub fn set_onfocus(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onfocus(instance, value);
    }

    pub fn get_onformdata(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onformdata(instance);
    }

    pub fn set_onformdata(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onformdata(instance, value);
    }

    pub fn get_oninput(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_oninput(instance);
    }

    pub fn set_oninput(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_oninput(instance, value);
    }

    pub fn get_oninvalid(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_oninvalid(instance);
    }

    pub fn set_oninvalid(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_oninvalid(instance, value);
    }

    pub fn get_onkeydown(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onkeydown(instance);
    }

    pub fn set_onkeydown(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onkeydown(instance, value);
    }

    pub fn get_onkeypress(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onkeypress(instance);
    }

    pub fn set_onkeypress(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onkeypress(instance, value);
    }

    pub fn get_onkeyup(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onkeyup(instance);
    }

    pub fn set_onkeyup(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onkeyup(instance, value);
    }

    pub fn get_onload(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onload(instance);
    }

    pub fn set_onload(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onload(instance, value);
    }

    pub fn get_onloadeddata(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onloadeddata(instance);
    }

    pub fn set_onloadeddata(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onloadeddata(instance, value);
    }

    pub fn get_onloadedmetadata(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onloadedmetadata(instance);
    }

    pub fn set_onloadedmetadata(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onloadedmetadata(instance, value);
    }

    pub fn get_onloadstart(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onloadstart(instance);
    }

    pub fn set_onloadstart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onloadstart(instance, value);
    }

    pub fn get_onmousedown(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onmousedown(instance);
    }

    pub fn set_onmousedown(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onmousedown(instance, value);
    }

    /// Extended attributes: [LegacyLenientThis]
    pub fn get_onmouseenter(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onmouseenter(instance);
    }

    /// Extended attributes: [LegacyLenientThis]
    pub fn set_onmouseenter(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onmouseenter(instance, value);
    }

    /// Extended attributes: [LegacyLenientThis]
    pub fn get_onmouseleave(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onmouseleave(instance);
    }

    /// Extended attributes: [LegacyLenientThis]
    pub fn set_onmouseleave(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onmouseleave(instance, value);
    }

    pub fn get_onmousemove(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onmousemove(instance);
    }

    pub fn set_onmousemove(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onmousemove(instance, value);
    }

    pub fn get_onmouseout(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onmouseout(instance);
    }

    pub fn set_onmouseout(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onmouseout(instance, value);
    }

    pub fn get_onmouseover(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onmouseover(instance);
    }

    pub fn set_onmouseover(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onmouseover(instance, value);
    }

    pub fn get_onmouseup(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onmouseup(instance);
    }

    pub fn set_onmouseup(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onmouseup(instance, value);
    }

    pub fn get_onpaste(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onpaste(instance);
    }

    pub fn set_onpaste(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onpaste(instance, value);
    }

    pub fn get_onpause(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onpause(instance);
    }

    pub fn set_onpause(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onpause(instance, value);
    }

    pub fn get_onplay(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onplay(instance);
    }

    pub fn set_onplay(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onplay(instance, value);
    }

    pub fn get_onplaying(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onplaying(instance);
    }

    pub fn set_onplaying(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onplaying(instance, value);
    }

    pub fn get_onprogress(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onprogress(instance);
    }

    pub fn set_onprogress(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onprogress(instance, value);
    }

    pub fn get_onratechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onratechange(instance);
    }

    pub fn set_onratechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onratechange(instance, value);
    }

    pub fn get_onreset(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onreset(instance);
    }

    pub fn set_onreset(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onreset(instance, value);
    }

    pub fn get_onresize(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onresize(instance);
    }

    pub fn set_onresize(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onresize(instance, value);
    }

    pub fn get_onscroll(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onscroll(instance);
    }

    pub fn set_onscroll(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onscroll(instance, value);
    }

    pub fn get_onscrollend(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onscrollend(instance);
    }

    pub fn set_onscrollend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onscrollend(instance, value);
    }

    pub fn get_onsecuritypolicyviolation(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onsecuritypolicyviolation(instance);
    }

    pub fn set_onsecuritypolicyviolation(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onsecuritypolicyviolation(instance, value);
    }

    pub fn get_onseeked(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onseeked(instance);
    }

    pub fn set_onseeked(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onseeked(instance, value);
    }

    pub fn get_onseeking(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onseeking(instance);
    }

    pub fn set_onseeking(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onseeking(instance, value);
    }

    pub fn get_onselect(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onselect(instance);
    }

    pub fn set_onselect(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onselect(instance, value);
    }

    pub fn get_onslotchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onslotchange(instance);
    }

    pub fn set_onslotchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onslotchange(instance, value);
    }

    pub fn get_onstalled(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onstalled(instance);
    }

    pub fn set_onstalled(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onstalled(instance, value);
    }

    pub fn get_onsubmit(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onsubmit(instance);
    }

    pub fn set_onsubmit(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onsubmit(instance, value);
    }

    pub fn get_onsuspend(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onsuspend(instance);
    }

    pub fn set_onsuspend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onsuspend(instance, value);
    }

    pub fn get_ontimeupdate(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_ontimeupdate(instance);
    }

    pub fn set_ontimeupdate(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_ontimeupdate(instance, value);
    }

    pub fn get_ontoggle(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_ontoggle(instance);
    }

    pub fn set_ontoggle(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_ontoggle(instance, value);
    }

    pub fn get_onvolumechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onvolumechange(instance);
    }

    pub fn set_onvolumechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onvolumechange(instance, value);
    }

    pub fn get_onwaiting(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onwaiting(instance);
    }

    pub fn set_onwaiting(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onwaiting(instance, value);
    }

    pub fn get_onwebkitanimationend(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onwebkitanimationend(instance);
    }

    pub fn set_onwebkitanimationend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onwebkitanimationend(instance, value);
    }

    pub fn get_onwebkitanimationiteration(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onwebkitanimationiteration(instance);
    }

    pub fn set_onwebkitanimationiteration(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onwebkitanimationiteration(instance, value);
    }

    pub fn get_onwebkitanimationstart(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onwebkitanimationstart(instance);
    }

    pub fn set_onwebkitanimationstart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onwebkitanimationstart(instance, value);
    }

    pub fn get_onwebkittransitionend(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onwebkittransitionend(instance);
    }

    pub fn set_onwebkittransitionend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onwebkittransitionend(instance, value);
    }

    pub fn get_onwheel(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onwheel(instance);
    }

    pub fn set_onwheel(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onwheel(instance, value);
    }

    pub fn get_onselectstart(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onselectstart(instance);
    }

    pub fn set_onselectstart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onselectstart(instance, value);
    }

    pub fn get_onselectionchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onselectionchange(instance);
    }

    pub fn set_onselectionchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onselectionchange(instance, value);
    }

    pub fn get_onanimationstart(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onanimationstart(instance);
    }

    pub fn set_onanimationstart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onanimationstart(instance, value);
    }

    pub fn get_onanimationiteration(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onanimationiteration(instance);
    }

    pub fn set_onanimationiteration(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onanimationiteration(instance, value);
    }

    pub fn get_onanimationend(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onanimationend(instance);
    }

    pub fn set_onanimationend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onanimationend(instance, value);
    }

    pub fn get_onanimationcancel(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onanimationcancel(instance);
    }

    pub fn set_onanimationcancel(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onanimationcancel(instance, value);
    }

    pub fn get_ontransitionrun(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_ontransitionrun(instance);
    }

    pub fn set_ontransitionrun(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_ontransitionrun(instance, value);
    }

    pub fn get_ontransitionstart(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_ontransitionstart(instance);
    }

    pub fn set_ontransitionstart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_ontransitionstart(instance, value);
    }

    pub fn get_ontransitionend(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_ontransitionend(instance);
    }

    pub fn set_ontransitionend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_ontransitionend(instance, value);
    }

    pub fn get_ontransitioncancel(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_ontransitioncancel(instance);
    }

    pub fn set_ontransitioncancel(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_ontransitioncancel(instance, value);
    }

    pub fn get_onbeforexrselect(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onbeforexrselect(instance);
    }

    pub fn set_onbeforexrselect(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onbeforexrselect(instance, value);
    }

    pub fn get_onpointerover(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onpointerover(instance);
    }

    pub fn set_onpointerover(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onpointerover(instance, value);
    }

    pub fn get_onpointerenter(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onpointerenter(instance);
    }

    pub fn set_onpointerenter(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onpointerenter(instance, value);
    }

    pub fn get_onpointerdown(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onpointerdown(instance);
    }

    pub fn set_onpointerdown(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onpointerdown(instance, value);
    }

    pub fn get_onpointermove(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onpointermove(instance);
    }

    pub fn set_onpointermove(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onpointermove(instance, value);
    }

    /// Extended attributes: [SecureContext]
    pub fn get_onpointerrawupdate(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onpointerrawupdate(instance);
    }

    /// Extended attributes: [SecureContext]
    pub fn set_onpointerrawupdate(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onpointerrawupdate(instance, value);
    }

    pub fn get_onpointerup(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onpointerup(instance);
    }

    pub fn set_onpointerup(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onpointerup(instance, value);
    }

    pub fn get_onpointercancel(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onpointercancel(instance);
    }

    pub fn set_onpointercancel(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onpointercancel(instance, value);
    }

    pub fn get_onpointerout(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onpointerout(instance);
    }

    pub fn set_onpointerout(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onpointerout(instance, value);
    }

    pub fn get_onpointerleave(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onpointerleave(instance);
    }

    pub fn set_onpointerleave(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onpointerleave(instance, value);
    }

    pub fn get_ongotpointercapture(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_ongotpointercapture(instance);
    }

    pub fn set_ongotpointercapture(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_ongotpointercapture(instance, value);
    }

    pub fn get_onlostpointercapture(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onlostpointercapture(instance);
    }

    pub fn set_onlostpointercapture(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onlostpointercapture(instance, value);
    }

    pub fn get_ontouchstart(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_ontouchstart(instance);
    }

    pub fn set_ontouchstart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_ontouchstart(instance, value);
    }

    pub fn get_ontouchend(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_ontouchend(instance);
    }

    pub fn set_ontouchend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_ontouchend(instance, value);
    }

    pub fn get_ontouchmove(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_ontouchmove(instance);
    }

    pub fn set_ontouchmove(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_ontouchmove(instance, value);
    }

    pub fn get_ontouchcancel(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_ontouchcancel(instance);
    }

    pub fn set_ontouchcancel(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_ontouchcancel(instance, value);
    }

    pub fn get_onfencedtreeclick(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onfencedtreeclick(instance);
    }

    pub fn set_onfencedtreeclick(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onfencedtreeclick(instance, value);
    }

    pub fn get_onsnapchanged(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onsnapchanged(instance);
    }

    pub fn set_onsnapchanged(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onsnapchanged(instance, value);
    }

    pub fn get_onsnapchanging(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentImpl.get_onsnapchanging(instance);
    }

    pub fn set_onsnapchanging(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentImpl.set_onsnapchanging(instance, value);
    }

    pub fn call_isDefaultNamespace(instance: *runtime.Instance, namespace: anyopaque) anyerror!bool {
        
        return try DocumentImpl.call_isDefaultNamespace(instance, namespace);
    }

    pub fn call_exitPointerLock(instance: *runtime.Instance) anyerror!void {
        return try DocumentImpl.call_exitPointerLock(instance);
    }

    pub fn call_queryCommandState(instance: *runtime.Instance, commandId: DOMString) anyerror!bool {
        
        return try DocumentImpl.call_queryCommandState(instance, commandId);
    }

    pub fn call_parseHTMLUnsafe(instance: *runtime.Instance, html: anyopaque) anyerror!Document {
        
        return try DocumentImpl.call_parseHTMLUnsafe(instance, html);
    }

    pub fn call_contains(instance: *runtime.Instance, other: anyopaque) anyerror!bool {
        
        return try DocumentImpl.call_contains(instance, other);
    }

    /// Extended attributes: [NewObject]
    pub fn call_exitPictureInPicture(instance: *runtime.Instance) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        return try DocumentImpl.call_exitPictureInPicture(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createExpression(instance: *runtime.Instance, expression: DOMString, resolver: anyopaque) anyerror!XPathExpression {
        // [NewObject] - Caller owns the returned object
        
        return try DocumentImpl.call_createExpression(instance, expression, resolver);
    }

    pub fn call_elementFromPoint(instance: *runtime.Instance, x: f64, y: f64) anyerror!anyopaque {
        
        return try DocumentImpl.call_elementFromPoint(instance, x, y);
    }

    pub fn call_getRootNode(instance: *runtime.Instance, options: GetRootNodeOptions) anyerror!Node {
        
        return try DocumentImpl.call_getRootNode(instance, options);
    }

    /// Extended attributes: [CEReactions], [NewObject]
    pub fn call_createElement(instance: *runtime.Instance, localName: DOMString, options: anyopaque) anyerror!Element {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        // [NewObject] - Caller owns the returned object
        
        return try DocumentImpl.call_createElement(instance, localName, options);
    }

    pub fn call_releaseEvents(instance: *runtime.Instance) anyerror!void {
        return try DocumentImpl.call_releaseEvents(instance);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_prepend(instance: *runtime.Instance, nodes: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try DocumentImpl.call_prepend(instance, nodes);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try DocumentImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_convertQuadFromNode(instance: *runtime.Instance, quad: DOMQuadInit, from: GeometryNode, options: ConvertCoordinateOptions) anyerror!DOMQuad {
        
        return try DocumentImpl.call_convertQuadFromNode(instance, quad, from, options);
    }

    pub fn call_queryCommandSupported(instance: *runtime.Instance, commandId: DOMString) anyerror!bool {
        
        return try DocumentImpl.call_queryCommandSupported(instance, commandId);
    }

    pub fn call_hasPrivateToken(instance: *runtime.Instance, issuer: runtime.USVString) anyerror!anyopaque {
        
        return try DocumentImpl.call_hasPrivateToken(instance, issuer);
    }

    pub fn call_requestStorageAccessFor(instance: *runtime.Instance, requestedOrigin: runtime.USVString) anyerror!anyopaque {
        
        return try DocumentImpl.call_requestStorageAccessFor(instance, requestedOrigin);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try DocumentImpl.call_when(instance, type_, options);
    }

    /// Arguments for open (WebIDL overloading)
    pub const OpenArgs = union(enum) {
        /// open(unused1, unused2)
        string_string: struct {
            unused1: DOMString,
            unused2: DOMString,
        },
        /// open(url, name, features)
        USVString_string_string: struct {
            url: runtime.USVString,
            name: DOMString,
            features: DOMString,
        },
    };

    pub fn call_open(instance: *runtime.Instance, args: OpenArgs) anyerror!Document {
        switch (args) {
            .string_string => |a| return try DocumentImpl.string_string(instance, a.unused1, a.unused2),
            .USVString_string_string => |a| return try DocumentImpl.USVString_string_string(instance, a.url, a.name, a.features),
        }
    }

    pub fn call_hasUnpartitionedCookieAccess(instance: *runtime.Instance) anyerror!anyopaque {
        return try DocumentImpl.call_hasUnpartitionedCookieAccess(instance);
    }

    pub fn call_hasRedemptionRecord(instance: *runtime.Instance, issuer: runtime.USVString) anyerror!anyopaque {
        
        return try DocumentImpl.call_hasRedemptionRecord(instance, issuer);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_insertBefore(instance: *runtime.Instance, node: Node, child: anyopaque) anyerror!Node {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try DocumentImpl.call_insertBefore(instance, node, child);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_execCommand(instance: *runtime.Instance, commandId: DOMString, showUI: bool, value: DOMString) anyerror!bool {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try DocumentImpl.call_execCommand(instance, commandId, showUI, value);
    }

    pub fn call_measureElement(instance: *runtime.Instance, element: Element) anyerror!FontMetrics {
        
        return try DocumentImpl.call_measureElement(instance, element);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_write(instance: *runtime.Instance, text: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try DocumentImpl.call_write(instance, text);
    }

    pub fn call_lookupNamespaceURI(instance: *runtime.Instance, prefix: anyopaque) anyerror!anyopaque {
        
        return try DocumentImpl.call_lookupNamespaceURI(instance, prefix);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createAttribute(instance: *runtime.Instance, localName: DOMString) anyerror!Attr {
        // [NewObject] - Caller owns the returned object
        
        return try DocumentImpl.call_createAttribute(instance, localName);
    }

    pub fn call_queryCommandIndeterm(instance: *runtime.Instance, commandId: DOMString) anyerror!bool {
        
        return try DocumentImpl.call_queryCommandIndeterm(instance, commandId);
    }

    pub fn call_getElementsByTagNameNS(instance: *runtime.Instance, namespace: anyopaque, localName: DOMString) anyerror!HTMLCollection {
        
        return try DocumentImpl.call_getElementsByTagNameNS(instance, namespace, localName);
    }

    pub fn call_clear(instance: *runtime.Instance) anyerror!void {
        return try DocumentImpl.call_clear(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createProcessingInstruction(instance: *runtime.Instance, target: DOMString, data: DOMString) anyerror!ProcessingInstruction {
        // [NewObject] - Caller owns the returned object
        
        return try DocumentImpl.call_createProcessingInstruction(instance, target, data);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createEvent(instance: *runtime.Instance, interface: DOMString) anyerror!Event {
        // [NewObject] - Caller owns the returned object
        
        return try DocumentImpl.call_createEvent(instance, interface);
    }

    pub fn call_elementsFromPoint(instance: *runtime.Instance, x: f64, y: f64) anyerror!anyopaque {
        
        return try DocumentImpl.call_elementsFromPoint(instance, x, y);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_removeChild(instance: *runtime.Instance, child: Node) anyerror!Node {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try DocumentImpl.call_removeChild(instance, child);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_replaceChildren(instance: *runtime.Instance, nodes: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try DocumentImpl.call_replaceChildren(instance, nodes);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_normalize(instance: *runtime.Instance) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        return try DocumentImpl.call_normalize(instance);
    }

    pub fn call_isEqualNode(instance: *runtime.Instance, otherNode: anyopaque) anyerror!bool {
        
        return try DocumentImpl.call_isEqualNode(instance, otherNode);
    }

    pub fn call_getBoxQuads(instance: *runtime.Instance, options: BoxQuadOptions) anyerror!anyopaque {
        
        return try DocumentImpl.call_getBoxQuads(instance, options);
    }

    pub fn call_convertPointFromNode(instance: *runtime.Instance, point: DOMPointInit, from: GeometryNode, options: ConvertCoordinateOptions) anyerror!DOMPoint {
        
        return try DocumentImpl.call_convertPointFromNode(instance, point, from, options);
    }

    pub fn call_getAnimations(instance: *runtime.Instance) anyerror!anyopaque {
        return try DocumentImpl.call_getAnimations(instance);
    }

    pub fn call_getElementsByClassName(instance: *runtime.Instance, classNames: DOMString) anyerror!HTMLCollection {
        
        return try DocumentImpl.call_getElementsByClassName(instance, classNames);
    }

    pub fn call_getElementsByTagName(instance: *runtime.Instance, qualifiedName: DOMString) anyerror!HTMLCollection {
        
        return try DocumentImpl.call_getElementsByTagName(instance, qualifiedName);
    }

    pub fn call_evaluate(instance: *runtime.Instance, expression: DOMString, contextNode: Node, resolver: anyopaque, type_: u16, result: anyopaque) anyerror!XPathResult {
        
        return try DocumentImpl.call_evaluate(instance, expression, contextNode, resolver, type_, result);
    }

    pub fn call_querySelector(instance: *runtime.Instance, selectors: DOMString) anyerror!anyopaque {
        
        return try DocumentImpl.call_querySelector(instance, selectors);
    }

    pub fn call_hasStorageAccess(instance: *runtime.Instance) anyerror!anyopaque {
        return try DocumentImpl.call_hasStorageAccess(instance);
    }

    pub fn call_compareDocumentPosition(instance: *runtime.Instance, other: Node) anyerror!u16 {
        
        return try DocumentImpl.call_compareDocumentPosition(instance, other);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createCDATASection(instance: *runtime.Instance, data: DOMString) anyerror!CDATASection {
        // [NewObject] - Caller owns the returned object
        
        return try DocumentImpl.call_createCDATASection(instance, data);
    }

    /// Extended attributes: [CEReactions], [NewObject]
    pub fn call_importNode(instance: *runtime.Instance, node: Node, options: anyopaque) anyerror!Node {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        // [NewObject] - Caller owns the returned object
        
        return try DocumentImpl.call_importNode(instance, node, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createRange(instance: *runtime.Instance) anyerror!Range {
        // [NewObject] - Caller owns the returned object
        return try DocumentImpl.call_createRange(instance);
    }

    pub fn call_queryCommandEnabled(instance: *runtime.Instance, commandId: DOMString) anyerror!bool {
        
        return try DocumentImpl.call_queryCommandEnabled(instance, commandId);
    }

    pub fn call_getElementById(instance: *runtime.Instance, elementId: DOMString) anyerror!anyopaque {
        
        return try DocumentImpl.call_getElementById(instance, elementId);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createAttributeNS(instance: *runtime.Instance, namespace: anyopaque, qualifiedName: DOMString) anyerror!Attr {
        // [NewObject] - Caller owns the returned object
        
        return try DocumentImpl.call_createAttributeNS(instance, namespace, qualifiedName);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try DocumentImpl.call_removeEventListener(instance, type_, callback, options);
    }

    pub fn call_exitFullscreen(instance: *runtime.Instance) anyerror!anyopaque {
        return try DocumentImpl.call_exitFullscreen(instance);
    }

    /// Extended attributes: [CEReactions], [NewObject]
    pub fn call_cloneNode(instance: *runtime.Instance, subtree: bool) anyerror!Node {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        // [NewObject] - Caller owns the returned object
        
        return try DocumentImpl.call_cloneNode(instance, subtree);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createTextNode(instance: *runtime.Instance, data: DOMString) anyerror!Text {
        // [NewObject] - Caller owns the returned object
        
        return try DocumentImpl.call_createTextNode(instance, data);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_adoptNode(instance: *runtime.Instance, node: Node) anyerror!Node {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try DocumentImpl.call_adoptNode(instance, node);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createTreeWalker(instance: *runtime.Instance, root: Node, whatToShow: u32, filter: anyopaque) anyerror!TreeWalker {
        // [NewObject] - Caller owns the returned object
        
        return try DocumentImpl.call_createTreeWalker(instance, root, whatToShow, filter);
    }

    pub fn call_getElementsByName(instance: *runtime.Instance, elementName: DOMString) anyerror!NodeList {
        
        return try DocumentImpl.call_getElementsByName(instance, elementName);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_writeln(instance: *runtime.Instance, text: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try DocumentImpl.call_writeln(instance, text);
    }

    pub fn call_hasFocus(instance: *runtime.Instance) anyerror!bool {
        return try DocumentImpl.call_hasFocus(instance);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_append(instance: *runtime.Instance, nodes: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try DocumentImpl.call_append(instance, nodes);
    }

    pub fn call_queryCommandValue(instance: *runtime.Instance, commandId: DOMString) anyerror!DOMString {
        
        return try DocumentImpl.call_queryCommandValue(instance, commandId);
    }

    pub fn call_caretPositionFromPoint(instance: *runtime.Instance, x: f64, y: f64, options: CaretPositionFromPointOptions) anyerror!anyopaque {
        
        return try DocumentImpl.call_caretPositionFromPoint(instance, x, y, options);
    }

    pub fn call_isSameNode(instance: *runtime.Instance, otherNode: anyopaque) anyerror!bool {
        
        return try DocumentImpl.call_isSameNode(instance, otherNode);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_moveBefore(instance: *runtime.Instance, node: Node, child: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try DocumentImpl.call_moveBefore(instance, node, child);
    }

    pub fn call_convertRectFromNode(instance: *runtime.Instance, rect: DOMRectReadOnly, from: GeometryNode, options: ConvertCoordinateOptions) anyerror!DOMQuad {
        
        return try DocumentImpl.call_convertRectFromNode(instance, rect, from, options);
    }

    pub fn call_startViewTransition(instance: *runtime.Instance, callbackOptions: anyopaque) anyerror!ViewTransition {
        
        return try DocumentImpl.call_startViewTransition(instance, callbackOptions);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createComment(instance: *runtime.Instance, data: DOMString) anyerror!Comment {
        // [NewObject] - Caller owns the returned object
        
        return try DocumentImpl.call_createComment(instance, data);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createDocumentFragment(instance: *runtime.Instance) anyerror!DocumentFragment {
        // [NewObject] - Caller owns the returned object
        return try DocumentImpl.call_createDocumentFragment(instance);
    }

    pub fn call_lookupPrefix(instance: *runtime.Instance, namespace: anyopaque) anyerror!anyopaque {
        
        return try DocumentImpl.call_lookupPrefix(instance, namespace);
    }

    pub fn call_getSelection(instance: *runtime.Instance) anyerror!anyopaque {
        return try DocumentImpl.call_getSelection(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        return try DocumentImpl.call_close(instance);
    }

    /// Arguments for requestStorageAccess (WebIDL overloading)
    pub const RequestStorageAccessArgs = union(enum) {
        /// requestStorageAccess()
        no_params: void,
        /// requestStorageAccess(types)
        StorageAccessTypes: StorageAccessTypes,
    };

    pub fn call_requestStorageAccess(instance: *runtime.Instance, args: RequestStorageAccessArgs) anyerror!anyopaque {
        switch (args) {
            .no_params => return try DocumentImpl.no_params(instance),
            .StorageAccessTypes => |arg| return try DocumentImpl.StorageAccessTypes(instance, arg),
        }
    }

    /// Extended attributes: [CEReactions]
    pub fn call_appendChild(instance: *runtime.Instance, node: Node) anyerror!Node {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try DocumentImpl.call_appendChild(instance, node);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try DocumentImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_hasChildNodes(instance: *runtime.Instance) anyerror!bool {
        return try DocumentImpl.call_hasChildNodes(instance);
    }

    /// Extended attributes: [CEReactions], [NewObject]
    pub fn call_createElementNS(instance: *runtime.Instance, namespace: anyopaque, qualifiedName: DOMString, options: anyopaque) anyerror!Element {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        // [NewObject] - Caller owns the returned object
        
        return try DocumentImpl.call_createElementNS(instance, namespace, qualifiedName, options);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_replaceChild(instance: *runtime.Instance, node: Node, child: Node) anyerror!Node {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try DocumentImpl.call_replaceChild(instance, node, child);
    }

    pub fn call_captureEvents(instance: *runtime.Instance) anyerror!void {
        return try DocumentImpl.call_captureEvents(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_querySelectorAll(instance: *runtime.Instance, selectors: DOMString) anyerror!NodeList {
        // [NewObject] - Caller owns the returned object
        
        return try DocumentImpl.call_querySelectorAll(instance, selectors);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_browsingTopics(instance: *runtime.Instance, options: BrowsingTopicsOptions) anyerror!anyopaque {
        
        return try DocumentImpl.call_browsingTopics(instance, options);
    }

    pub fn call_createNSResolver(instance: *runtime.Instance, nodeResolver: Node) anyerror!Node {
        
        return try DocumentImpl.call_createNSResolver(instance, nodeResolver);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createNodeIterator(instance: *runtime.Instance, root: Node, whatToShow: u32, filter: anyopaque) anyerror!NodeIterator {
        // [NewObject] - Caller owns the returned object
        
        return try DocumentImpl.call_createNodeIterator(instance, root, whatToShow, filter);
    }

    pub fn call_measureText(instance: *runtime.Instance, text: DOMString, styleMap: StylePropertyMapReadOnly) anyerror!FontMetrics {
        
        return try DocumentImpl.call_measureText(instance, text, styleMap);
    }

};
