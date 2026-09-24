//! Generated from: dom.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const DocumentImpl = @import("impls").Document;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Node = @import("interfaces").Node;
const FontFaceSource = @import("mixins").FontFaceSource;
const NonElementParentNode = @import("mixins").NonElementParentNode;
const DocumentOrShadowRoot = @import("mixins").DocumentOrShadowRoot;
const ParentNode = @import("mixins").ParentNode;
const XPathEvaluatorBase = @import("mixins").XPathEvaluatorBase;
const GlobalEventHandlers = @import("mixins").GlobalEventHandlers;
const GeometryUtils = @import("mixins").GeometryUtils;
const HTMLOrSVGScriptElement = @import("typedefs").HTMLOrSVGScriptElement;
const HTMLCollection = @import("interfaces").HTMLCollection;
const HTMLHeadElement = @import("interfaces").HTMLHeadElement;
const FontMetrics = @import("interfaces").FontMetrics;
const NodeIterator = @import("interfaces").NodeIterator;
const DOMPointInit = @import("dictionaries").DOMPointInit;
const Text = @import("interfaces").Text;
const GeometryNode = @import("typedefs").GeometryNode;
const USVString = @import("typedefs").USVString;
const Element = @import("interfaces").Element;
const XPathExpression = @import("interfaces").XPathExpression;
const BoxQuadOptions = @import("dictionaries").BoxQuadOptions;
const XPathResult = @import("interfaces").XPathResult;
const Location = @import("interfaces").Location;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const StyleSheetList = @import("interfaces").StyleSheetList;
const FragmentDirective = @import("interfaces").FragmentDirective;
const Comment = @import("interfaces").Comment;
const NamedFlowMap = @import("interfaces").NamedFlowMap;
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;
const ViewTransitionUpdateCallback = @import("callbacks").ViewTransitionUpdateCallback;
const StorageAccessHandle = @import("interfaces").StorageAccessHandle;
const ImportNodeOptions = @import("dictionaries").ImportNodeOptions;
const DOMImplementation = @import("interfaces").DOMImplementation;
const CustomElementRegistry = @import("interfaces").CustomElementRegistry;
const Range = @import("interfaces").Range;
const Animation = @import("interfaces").Animation;
const Event = @import("interfaces").Event;
const PermissionsPolicy = @import("interfaces").PermissionsPolicy;
const XPathNSResolver = @import("interfaces").XPathNSResolver;
const DocumentType = @import("interfaces").DocumentType;
const HTMLAllCollection = @import("interfaces").HTMLAllCollection;
const DOMString = @import("typedefs").DOMString;
const DocumentFragment = @import("interfaces").DocumentFragment;
const OnErrorEventHandler = @import("typedefs").OnErrorEventHandler;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const FontFaceSet = @import("interfaces").FontFaceSet;
const BrowsingTopicsOptions = @import("dictionaries").BrowsingTopicsOptions;
const DOMQuad = @import("interfaces").DOMQuad;
const DOMRectReadOnly = @import("interfaces").DOMRectReadOnly;
const StartViewTransitionOptions = @import("dictionaries").StartViewTransitionOptions;
const StylePropertyMapReadOnly = @import("interfaces").StylePropertyMapReadOnly;
const CDATASection = @import("interfaces").CDATASection;
const DocumentTimeline = @import("interfaces").DocumentTimeline;
const ViewTransition = @import("interfaces").ViewTransition;
const TreeWalker = @import("interfaces").TreeWalker;
const EventHandler = @import("typedefs").EventHandler;
const DocumentReadyState = @import("enums").DocumentReadyState;
const ConvertCoordinateOptions = @import("dictionaries").ConvertCoordinateOptions;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const HTMLElement = @import("interfaces").HTMLElement;
const StorageAccessTypes = @import("dictionaries").StorageAccessTypes;
const Attr = @import("interfaces").Attr;
const TrustedHTML = @import("interfaces").TrustedHTML;
const WindowProxy = @import("typedefs").WindowProxy;
const NodeList = @import("interfaces").NodeList;
const DOMQuadInit = @import("dictionaries").DOMQuadInit;
const ElementCreationOptions = @import("dictionaries").ElementCreationOptions;
const DOMPoint = @import("interfaces").DOMPoint;
const Observable = @import("interfaces").Observable;
const CaretPosition = @import("interfaces").CaretPosition;
const CaretPositionFromPointOptions = @import("dictionaries").CaretPositionFromPointOptions;
const ProcessingInstruction = @import("interfaces").ProcessingInstruction;
const SVGSVGElement = @import("interfaces").SVGSVGElement;
const GetRootNodeOptions = @import("dictionaries").GetRootNodeOptions;
const Selection = @import("interfaces").Selection;
const NodeFilter = @import("interfaces").NodeFilter;
const DocumentVisibilityState = @import("enums").DocumentVisibilityState;

pub const Document = struct {
    pub const Meta = struct {
        pub const name = "Document";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Node.State;
        pub const ParentInterface = Node;
        pub const MixinTypes = &.{
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

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "implementation", "get_implementation", null },
            .{ "URL", "get_URL", null },
            .{ "documentURI", "get_documentURI", null },
            .{ "compatMode", "get_compatMode", null },
            .{ "characterSet", "get_characterSet", null },
            .{ "charset", "get_charset", null },
            .{ "inputEncoding", "get_inputEncoding", null },
            .{ "contentType", "get_contentType", null },
            .{ "doctype", "get_doctype", null },
            .{ "documentElement", "get_documentElement", null },
            .{ "fragmentDirective", "get_fragmentDirective", null },
            .{ "prerendering", "get_prerendering", null },
            .{ "onprerenderingchange", "get_onprerenderingchange", "set_onprerenderingchange" },
            .{ "fullscreenEnabled", "get_fullscreenEnabled", "set_fullscreenEnabled" },
            .{ "fullscreen", "get_fullscreen", "set_fullscreen" },
            .{ "onfullscreenchange", "get_onfullscreenchange", "set_onfullscreenchange" },
            .{ "onfullscreenerror", "get_onfullscreenerror", "set_onfullscreenerror" },
            .{ "timeline", "get_timeline", null },
            .{ "pictureInPictureEnabled", "get_pictureInPictureEnabled", null },
            .{ "onpointerlockchange", "get_onpointerlockchange", "set_onpointerlockchange" },
            .{ "onpointerlockerror", "get_onpointerlockerror", "set_onpointerlockerror" },
            .{ "onfreeze", "get_onfreeze", "set_onfreeze" },
            .{ "onresume", "get_onresume", "set_onresume" },
            .{ "wasDiscarded", "get_wasDiscarded", null },
            .{ "namedFlows", "get_namedFlows", null },
            .{ "rootElement", "get_rootElement", null },
            .{ "activeViewTransition", "get_activeViewTransition", null },
            .{ "location", "get_location", "set_location" },
            .{ "domain", "get_domain", "set_domain" },
            .{ "referrer", "get_referrer", null },
            .{ "cookie", "get_cookie", "set_cookie" },
            .{ "lastModified", "get_lastModified", null },
            .{ "readyState", "get_readyState", null },
            .{ "title", "get_title", "set_title" },
            .{ "dir", "get_dir", "set_dir" },
            .{ "body", "get_body", "set_body" },
            .{ "head", "get_head", null },
            .{ "images", "get_images", null },
            .{ "embeds", "get_embeds", null },
            .{ "plugins", "get_plugins", null },
            .{ "links", "get_links", null },
            .{ "forms", "get_forms", null },
            .{ "scripts", "get_scripts", null },
            .{ "currentScript", "get_currentScript", null },
            .{ "defaultView", "get_defaultView", null },
            .{ "designMode", "get_designMode", "set_designMode" },
            .{ "hidden", "get_hidden", null },
            .{ "visibilityState", "get_visibilityState", null },
            .{ "onreadystatechange", "get_onreadystatechange", "set_onreadystatechange" },
            .{ "onvisibilitychange", "get_onvisibilitychange", "set_onvisibilitychange" },
            .{ "fgColor", "get_fgColor", "set_fgColor" },
            .{ "linkColor", "get_linkColor", "set_linkColor" },
            .{ "vlinkColor", "get_vlinkColor", "set_vlinkColor" },
            .{ "alinkColor", "get_alinkColor", "set_alinkColor" },
            .{ "bgColor", "get_bgColor", "set_bgColor" },
            .{ "anchors", "get_anchors", null },
            .{ "applets", "get_applets", null },
            .{ "all", "get_all", null },
            .{ "scrollingElement", "get_scrollingElement", null },
            .{ "permissionsPolicy", "get_permissionsPolicy", null },
            .{ "fonts", "get_fonts", null },
            .{ "customElementRegistry", "get_customElementRegistry", null },
            .{ "fullscreenElement", "get_fullscreenElement", "set_fullscreenElement" },
            .{ "pictureInPictureElement", "get_pictureInPictureElement", null },
            .{ "pointerLockElement", "get_pointerLockElement", null },
            .{ "styleSheets", "get_styleSheets", null },
            .{ "adoptedStyleSheets", "get_adoptedStyleSheets", "set_adoptedStyleSheets" },
            .{ "activeElement", "get_activeElement", null },
            .{ "children", "get_children", null },
            .{ "firstElementChild", "get_firstElementChild", null },
            .{ "lastElementChild", "get_lastElementChild", null },
            .{ "childElementCount", "get_childElementCount", null },
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
        };

        /// [PutForwards] attributes: setting the attribute forwards to a property on the value
        /// Format: { "attrName", "forwardedProperty" }
        pub const put_forwards_attributes = .{
            .{ "location", "href" },
        };

        /// [LegacyLenientThis] attributes: do NOT throw TypeError on invalid this
        /// Getters return undefined, setters silently return
        pub const lenient_this_attributes = .{
            "onreadystatechange",
            "onmouseenter",
            "onmouseleave",
        };

        /// [LegacyLenientSetter] attributes: readonly with no-op setters
        /// Setters silently do nothing (don't throw, don't modify)
        pub const lenient_setter_attributes = .{
            "fullscreenEnabled",
            "fullscreen",
            "fullscreenElement",
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getElementsByTagName", "call_getElementsByTagName", 1 },
            .{ "getElementsByTagNameNS", "call_getElementsByTagNameNS", 2 },
            .{ "getElementsByClassName", "call_getElementsByClassName", 1 },
            .{ "createElement", "call_createElement", 1 },
            .{ "createElementNS", "call_createElementNS", 2 },
            .{ "createDocumentFragment", "call_createDocumentFragment", 0 },
            .{ "createTextNode", "call_createTextNode", 1 },
            .{ "createCDATASection", "call_createCDATASection", 1 },
            .{ "createComment", "call_createComment", 1 },
            .{ "createProcessingInstruction", "call_createProcessingInstruction", 2 },
            .{ "importNode", "call_importNode", 1 },
            .{ "adoptNode", "call_adoptNode", 1 },
            .{ "createAttribute", "call_createAttribute", 1 },
            .{ "createAttributeNS", "call_createAttributeNS", 2 },
            .{ "createEvent", "call_createEvent", 1 },
            .{ "createRange", "call_createRange", 0 },
            .{ "createNodeIterator", "call_createNodeIterator", 1 },
            .{ "createTreeWalker", "call_createTreeWalker", 1 },
            .{ "exitFullscreen", "call_exitFullscreen", 0 },
            .{ "getSelection", "call_getSelection", 0 },
            .{ "exitPictureInPicture", "call_exitPictureInPicture", 0 },
            .{ "browsingTopics", "call_browsingTopics", 0 },
            .{ "exitPointerLock", "call_exitPointerLock", 0 },
            .{ "requestStorageAccessFor", "call_requestStorageAccessFor", 1 },
            .{ "hasStorageAccess", "call_hasStorageAccess", 0 },
            .{ "requestStorageAccess", "call_requestStorageAccess", 0 },
            .{ "startViewTransition", "call_startViewTransition", 0 },
            .{ "measureElement", "call_measureElement", 1 },
            .{ "measureText", "call_measureText", 2 },
            .{ "hasUnpartitionedCookieAccess", "call_hasUnpartitionedCookieAccess", 0 },
            .{ "getElementsByName", "call_getElementsByName", 1 },
            .{ "open", "call_open", 0 },
            .{ "close", "call_close", 0 },
            .{ "write", "call_write", 0 },
            .{ "writeln", "call_writeln", 0 },
            .{ "hasFocus", "call_hasFocus", 0 },
            .{ "execCommand", "call_execCommand", 1 },
            .{ "queryCommandEnabled", "call_queryCommandEnabled", 1 },
            .{ "queryCommandIndeterm", "call_queryCommandIndeterm", 1 },
            .{ "queryCommandState", "call_queryCommandState", 1 },
            .{ "queryCommandSupported", "call_queryCommandSupported", 1 },
            .{ "queryCommandValue", "call_queryCommandValue", 1 },
            .{ "clear", "call_clear", 0 },
            .{ "captureEvents", "call_captureEvents", 0 },
            .{ "releaseEvents", "call_releaseEvents", 0 },
            .{ "hasPrivateToken", "call_hasPrivateToken", 1 },
            .{ "hasRedemptionRecord", "call_hasRedemptionRecord", 1 },
            .{ "elementFromPoint", "call_elementFromPoint", 2 },
            .{ "elementsFromPoint", "call_elementsFromPoint", 2 },
            .{ "caretPositionFromPoint", "call_caretPositionFromPoint", 2 },
            .{ "getElementById", "call_getElementById", 1 },
            .{ "getAnimations", "call_getAnimations", 0 },
            .{ "prepend", "call_prepend", 0 },
            .{ "append", "call_append", 0 },
            .{ "replaceChildren", "call_replaceChildren", 0 },
            .{ "moveBefore", "call_moveBefore", 2 },
            .{ "querySelector", "call_querySelector", 1 },
            .{ "querySelectorAll", "call_querySelectorAll", 1 },
            .{ "createExpression", "call_createExpression", 1 },
            .{ "createNSResolver", "call_createNSResolver", 1 },
            .{ "evaluate", "call_evaluate", 2 },
            .{ "getBoxQuads", "call_getBoxQuads", 0 },
            .{ "convertQuadFromNode", "call_convertQuadFromNode", 2 },
            .{ "convertRectFromNode", "call_convertRectFromNode", 2 },
            .{ "convertPointFromNode", "call_convertPointFromNode", 2 },
        };

        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "parseHTMLUnsafe", "call_static_parseHTMLUnsafe", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getElementsByTagName",
            "getElementsByTagNameNS",
            "getElementsByClassName",
            "createElement",
            "createElementNS",
            "createDocumentFragment",
            "createTextNode",
            "createCDATASection",
            "createComment",
            "createProcessingInstruction",
            "importNode",
            "adoptNode",
            "createAttribute",
            "createAttributeNS",
            "createEvent",
            "createRange",
            "createNodeIterator",
            "createTreeWalker",
            "exitFullscreen",
            "getSelection",
            "exitPictureInPicture",
            "browsingTopics",
            "exitPointerLock",
            "requestStorageAccessFor",
            "hasStorageAccess",
            "requestStorageAccess",
            "startViewTransition",
            "measureElement",
            "measureText",
            "hasUnpartitionedCookieAccess",
            "parseHTMLUnsafe",
            "getElementsByName",
            "open",
            "close",
            "write",
            "writeln",
            "hasFocus",
            "execCommand",
            "queryCommandEnabled",
            "queryCommandIndeterm",
            "queryCommandState",
            "queryCommandSupported",
            "queryCommandValue",
            "clear",
            "captureEvents",
            "releaseEvents",
            "hasPrivateToken",
            "hasRedemptionRecord",
            "elementFromPoint",
            "elementsFromPoint",
            "caretPositionFromPoint",
            "getElementById",
            "getAnimations",
            "prepend",
            "append",
            "replaceChildren",
            "moveBefore",
            "querySelector",
            "querySelectorAll",
            "createExpression",
            "createNSResolver",
            "evaluate",
            "getBoxQuads",
            "convertQuadFromNode",
            "convertRectFromNode",
            "convertPointFromNode",
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
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "implementation", "get_implementation", null },
            .{ "URL", "get_URL", null },
            .{ "documentURI", "get_documentURI", null },
            .{ "compatMode", "get_compatMode", null },
            .{ "characterSet", "get_characterSet", null },
            .{ "charset", "get_charset", null },
            .{ "inputEncoding", "get_inputEncoding", null },
            .{ "contentType", "get_contentType", null },
            .{ "doctype", "get_doctype", null },
            .{ "documentElement", "get_documentElement", null },
            .{ "fragmentDirective", "get_fragmentDirective", null },
            .{ "prerendering", "get_prerendering", null },
            .{ "onprerenderingchange", "get_onprerenderingchange", "set_onprerenderingchange" },
            .{ "fullscreenEnabled", "get_fullscreenEnabled", "set_fullscreenEnabled" },
            .{ "fullscreen", "get_fullscreen", "set_fullscreen" },
            .{ "onfullscreenchange", "get_onfullscreenchange", "set_onfullscreenchange" },
            .{ "onfullscreenerror", "get_onfullscreenerror", "set_onfullscreenerror" },
            .{ "timeline", "get_timeline", null },
            .{ "pictureInPictureEnabled", "get_pictureInPictureEnabled", null },
            .{ "onpointerlockchange", "get_onpointerlockchange", "set_onpointerlockchange" },
            .{ "onpointerlockerror", "get_onpointerlockerror", "set_onpointerlockerror" },
            .{ "onfreeze", "get_onfreeze", "set_onfreeze" },
            .{ "onresume", "get_onresume", "set_onresume" },
            .{ "wasDiscarded", "get_wasDiscarded", null },
            .{ "namedFlows", "get_namedFlows", null },
            .{ "rootElement", "get_rootElement", null },
            .{ "activeViewTransition", "get_activeViewTransition", null },
            .{ "location", "get_location", "set_location" },
            .{ "domain", "get_domain", "set_domain" },
            .{ "referrer", "get_referrer", null },
            .{ "cookie", "get_cookie", "set_cookie" },
            .{ "lastModified", "get_lastModified", null },
            .{ "readyState", "get_readyState", null },
            .{ "title", "get_title", "set_title" },
            .{ "body", "get_body", "set_body" },
            .{ "head", "get_head", null },
            .{ "images", "get_images", null },
            .{ "embeds", "get_embeds", null },
            .{ "plugins", "get_plugins", null },
            .{ "links", "get_links", null },
            .{ "forms", "get_forms", null },
            .{ "scripts", "get_scripts", null },
            .{ "currentScript", "get_currentScript", null },
            .{ "defaultView", "get_defaultView", null },
            .{ "designMode", "get_designMode", "set_designMode" },
            .{ "visibilityState", "get_visibilityState", null },
            .{ "onreadystatechange", "get_onreadystatechange", "set_onreadystatechange" },
            .{ "onvisibilitychange", "get_onvisibilitychange", "set_onvisibilitychange" },
            .{ "fgColor", "get_fgColor", "set_fgColor" },
            .{ "linkColor", "get_linkColor", "set_linkColor" },
            .{ "vlinkColor", "get_vlinkColor", "set_vlinkColor" },
            .{ "alinkColor", "get_alinkColor", "set_alinkColor" },
            .{ "bgColor", "get_bgColor", "set_bgColor" },
            .{ "anchors", "get_anchors", null },
            .{ "applets", "get_applets", null },
            .{ "all", "get_all", null },
            .{ "scrollingElement", "get_scrollingElement", null },
            .{ "permissionsPolicy", "get_permissionsPolicy", null },
            .{ "fonts", "get_fonts", null },
            .{ "customElementRegistry", "get_customElementRegistry", null },
            .{ "fullscreenElement", "get_fullscreenElement", "set_fullscreenElement" },
            .{ "pictureInPictureElement", "get_pictureInPictureElement", null },
            .{ "pointerLockElement", "get_pointerLockElement", null },
            .{ "styleSheets", "get_styleSheets", null },
            .{ "adoptedStyleSheets", "get_adoptedStyleSheets", "set_adoptedStyleSheets" },
            .{ "activeElement", "get_activeElement", null },
            .{ "children", "get_children", null },
            .{ "firstElementChild", "get_firstElementChild", null },
            .{ "lastElementChild", "get_lastElementChild", null },
            .{ "childElementCount", "get_childElementCount", null },
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
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
            .{ "dir", "get_dir", "set_dir" },
            .{ "hidden", "get_hidden", null },
        };

        pub const has_constructor = true;

        /// Members marked with [Unscopable] extended attribute
        pub const unscopables = .{
            "fullscreen",
            "prepend",
            "append",
            "replaceChildren",
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            implementation: *runtime.Instance = undefined,
            URL: runtime.USVString = undefined,
            documentURI: runtime.USVString = undefined,
            compatMode: typedefs.DOMString = undefined,
            characterSet: typedefs.DOMString = undefined,
            charset: typedefs.DOMString = undefined,
            inputEncoding: typedefs.DOMString = undefined,
            contentType: typedefs.DOMString = undefined,
            doctype: ?*runtime.Instance = null,
            documentElement: ?*runtime.Instance = null,
            fragmentDirective: *runtime.Instance = undefined,
            prerendering: bool = undefined,
            fullscreenEnabled: bool = undefined,
            fullscreen: bool = undefined,
            timeline: *runtime.Instance = undefined,
            pictureInPictureEnabled: bool = undefined,
            wasDiscarded: bool = undefined,
            namedFlows: *runtime.Instance = undefined,
            rootElement: ?*runtime.Instance = null,
            activeViewTransition: ?*runtime.Instance = null,
            location: ?*runtime.Instance = null,
            domain: runtime.USVString = undefined,
            referrer: runtime.USVString = undefined,
            cookie: runtime.USVString = undefined,
            lastModified: typedefs.DOMString = undefined,
            readyState: enums.DocumentReadyState = undefined,
            title: typedefs.DOMString = undefined,
            dir: typedefs.DOMString = undefined,
            body: ?*runtime.Instance = null,
            head: ?*runtime.Instance = null,
            images: *runtime.Instance = undefined,
            embeds: *runtime.Instance = undefined,
            plugins: *runtime.Instance = undefined,
            links: *runtime.Instance = undefined,
            forms: *runtime.Instance = undefined,
            scripts: *runtime.Instance = undefined,
            currentScript: ?typedefs.HTMLOrSVGScriptElement = null,
            defaultView: ?typedefs.WindowProxy = null,
            designMode: typedefs.DOMString = undefined,
            hidden: bool = undefined,
            visibilityState: enums.DocumentVisibilityState = undefined,
            fgColor: typedefs.DOMString = undefined,
            linkColor: typedefs.DOMString = undefined,
            vlinkColor: typedefs.DOMString = undefined,
            alinkColor: typedefs.DOMString = undefined,
            bgColor: typedefs.DOMString = undefined,
            anchors: *runtime.Instance = undefined,
            applets: *runtime.Instance = undefined,
            all: *runtime.Instance = undefined,
            scrollingElement: ?*runtime.Instance = null,
            permissionsPolicy: *runtime.Instance = undefined,
            fonts: *runtime.Instance = undefined,
            customElementRegistry: ?*runtime.Instance = null,
            fullscreenElement: ?*runtime.Instance = null,
            pictureInPictureElement: ?*runtime.Instance = null,
            pointerLockElement: ?*runtime.Instance = null,
            styleSheets: *runtime.Instance = undefined,
            adoptedStyleSheets: runtime.JSValue = undefined,
            activeElement: ?*runtime.Instance = null,
            children: *runtime.Instance = undefined,
            firstElementChild: ?*runtime.Instance = null,
            lastElementChild: ?*runtime.Instance = null,
            childElementCount: u32 = undefined,
            onerror: typedefs.OnErrorEventHandler = undefined,
            cached_implementation: ?*runtime.Instance = null,
            cached_fragmentDirective: ?*runtime.Instance = null,
            cached_images: ?*runtime.Instance = null,
            cached_embeds: ?*runtime.Instance = null,
            cached_plugins: ?*runtime.Instance = null,
            cached_links: ?*runtime.Instance = null,
            cached_forms: ?*runtime.Instance = null,
            cached_scripts: ?*runtime.Instance = null,
            cached_anchors: ?*runtime.Instance = null,
            cached_applets: ?*runtime.Instance = null,
            cached_all: ?*runtime.Instance = null,
            cached_permissionsPolicy: ?*runtime.Instance = null,
            cached_styleSheets: ?*runtime.Instance = null,
            cached_children: ?*runtime.Instance = null,
            _internal: ?*DocumentImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_URL = &get_URL,
        .get_activeElement = &get_activeElement,
        .get_activeViewTransition = &get_activeViewTransition,
        .get_adoptedStyleSheets = &get_adoptedStyleSheets,
        .get_alinkColor = &get_alinkColor,
        .get_all = &get_all,
        .get_anchors = &get_anchors,
        .get_applets = &get_applets,
        .get_bgColor = &get_bgColor,
        .get_body = &get_body,
        .get_characterSet = &get_characterSet,
        .get_charset = &get_charset,
        .get_childElementCount = &get_childElementCount,
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
        .get_lastElementChild = &get_lastElementChild,
        .get_lastModified = &get_lastModified,
        .get_linkColor = &get_linkColor,
        .get_links = &get_links,
        .get_location = &get_location,
        .get_namedFlows = &get_namedFlows,
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
        .get_permissionsPolicy = &get_permissionsPolicy,
        .get_pictureInPictureElement = &get_pictureInPictureElement,
        .get_pictureInPictureEnabled = &get_pictureInPictureEnabled,
        .get_plugins = &get_plugins,
        .get_pointerLockElement = &get_pointerLockElement,
        .get_prerendering = &get_prerendering,
        .get_readyState = &get_readyState,
        .get_referrer = &get_referrer,
        .get_rootElement = &get_rootElement,
        .get_scripts = &get_scripts,
        .get_scrollingElement = &get_scrollingElement,
        .get_styleSheets = &get_styleSheets,
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
        .set_fullscreen = &set_fullscreen,
        .set_fullscreenElement = &set_fullscreenElement,
        .set_fullscreenEnabled = &set_fullscreenEnabled,
        .set_linkColor = &set_linkColor,
        .set_location = &set_location,
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
        .set_title = &set_title,
        .set_vlinkColor = &set_vlinkColor,

        .call_adoptNode = &call_adoptNode,
        .call_append = &call_append,
        .call_browsingTopics = &call_browsingTopics,
        .call_captureEvents = &call_captureEvents,
        .call_caretPositionFromPoint = &call_caretPositionFromPoint,
        .call_clear = &call_clear,
        .call_close = &call_close,
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
        .call_getSelection = &call_getSelection,
        .call_hasFocus = &call_hasFocus,
        .call_hasPrivateToken = &call_hasPrivateToken,
        .call_hasRedemptionRecord = &call_hasRedemptionRecord,
        .call_hasStorageAccess = &call_hasStorageAccess,
        .call_hasUnpartitionedCookieAccess = &call_hasUnpartitionedCookieAccess,
        .call_importNode = &call_importNode,
        .call_measureElement = &call_measureElement,
        .call_measureText = &call_measureText,
        .call_moveBefore = &call_moveBefore,
        .call_open = &call_open,
        .call_prepend = &call_prepend,
        .call_queryCommandEnabled = &call_queryCommandEnabled,
        .call_queryCommandIndeterm = &call_queryCommandIndeterm,
        .call_queryCommandState = &call_queryCommandState,
        .call_queryCommandSupported = &call_queryCommandSupported,
        .call_queryCommandValue = &call_queryCommandValue,
        .call_querySelector = &call_querySelector,
        .call_querySelectorAll = &call_querySelectorAll,
        .call_releaseEvents = &call_releaseEvents,
        .call_replaceChildren = &call_replaceChildren,
        .call_requestStorageAccess = &call_requestStorageAccess,
        .call_requestStorageAccessFor = &call_requestStorageAccessFor,
        .call_startViewTransition = &call_startViewTransition,
        .call_write = &call_write,
        .call_writeln = &call_writeln,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates, Meta.name, State);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return DocumentImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return DocumentImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DocumentImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try DocumentImpl.call_constructor(ctx);
    }

    /// Extended attributes: [SameObject]
    pub fn get_implementation(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_implementation) |cached| {
            return cached;
        }
        const value = try DocumentImpl.get_implementation(instance);
        state.own.cached_implementation = value;
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

    pub fn get_doctype(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try DocumentImpl.get_doctype(instance);
    }

    pub fn get_documentElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try DocumentImpl.get_documentElement(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_fragmentDirective(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_fragmentDirective) |cached| {
            return cached;
        }
        const value = try DocumentImpl.get_fragmentDirective(instance);
        state.own.cached_fragmentDirective = value;
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

    /// Extended attributes: [LegacyLenientSetter]
    pub fn set_fullscreenEnabled(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        // [LegacyLenientSetter] - Silently do nothing (no-op setter)
        // Per WebIDL §4.3.10: The setter steps are to return.
        _ = instance;
        _ = value;
    }

    /// Extended attributes: [LegacyLenientSetter], [Unscopable]
    pub fn get_fullscreen(instance: *runtime.Instance) anyerror!bool {
        return try DocumentImpl.get_fullscreen(instance);
    }

    /// Extended attributes: [LegacyLenientSetter], [Unscopable]
    pub fn set_fullscreen(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        // [LegacyLenientSetter] - Silently do nothing (no-op setter)
        // Per WebIDL §4.3.10: The setter steps are to return.
        _ = instance;
        _ = value;
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

    pub fn get_timeline(instance: *runtime.Instance) anyerror!*runtime.Instance {
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

    pub fn get_namedFlows(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try DocumentImpl.get_namedFlows(instance);
    }

    pub fn get_rootElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try DocumentImpl.get_rootElement(instance);
    }

    pub fn get_activeViewTransition(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try DocumentImpl.get_activeViewTransition(instance);
    }

    /// Extended attributes: [PutForwards=href], [LegacyUnforgeable]
    pub fn get_location(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try DocumentImpl.get_location(instance);
    }

    /// Extended attributes: [PutForwards=href], [LegacyUnforgeable]
    pub fn set_location(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [PutForwards] - Get target object and set the forwarded property
        // Per WebIDL spec: setting 'location' forwards to 'href' on the attribute's value
        const target_opt = try get_location(instance);
        // Per WebIDL spec: if the target is null, throw TypeError
        const target = target_opt orelse return error.TypeError;

        // Use JavaScript [[Set]] semantics to set the forwarded property
        // This respects prototype chain and user-defined setters
        try runtime.setPropertyOnInstance(target, "href", value);
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
    pub fn get_body(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try DocumentImpl.get_body(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_body(instance: *runtime.Instance, value: ?*runtime.Instance) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();

        try DocumentImpl.set_body(instance, value);
    }

    pub fn get_head(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try DocumentImpl.get_head(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_images(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_images) |cached| {
            return cached;
        }
        const value = try DocumentImpl.get_images(instance);
        state.own.cached_images = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_embeds(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_embeds) |cached| {
            return cached;
        }
        const value = try DocumentImpl.get_embeds(instance);
        state.own.cached_embeds = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_plugins(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_plugins) |cached| {
            return cached;
        }
        const value = try DocumentImpl.get_plugins(instance);
        state.own.cached_plugins = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_links(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_links) |cached| {
            return cached;
        }
        const value = try DocumentImpl.get_links(instance);
        state.own.cached_links = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_forms(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_forms) |cached| {
            return cached;
        }
        const value = try DocumentImpl.get_forms(instance);
        state.own.cached_forms = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_scripts(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_scripts) |cached| {
            return cached;
        }
        const value = try DocumentImpl.get_scripts(instance);
        state.own.cached_scripts = value;
        return value;
    }

    pub fn get_currentScript(instance: *runtime.Instance) anyerror!?HTMLOrSVGScriptElement {
        return try DocumentImpl.get_currentScript(instance);
    }

    pub fn get_defaultView(instance: *runtime.Instance) anyerror!?WindowProxy {
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
    pub fn get_anchors(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_anchors) |cached| {
            return cached;
        }
        const value = try DocumentImpl.get_anchors(instance);
        state.own.cached_anchors = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_applets(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_applets) |cached| {
            return cached;
        }
        const value = try DocumentImpl.get_applets(instance);
        state.own.cached_applets = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_all(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_all) |cached| {
            return cached;
        }
        const value = try DocumentImpl.get_all(instance);
        state.own.cached_all = value;
        return value;
    }

    pub fn get_scrollingElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try DocumentImpl.get_scrollingElement(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_permissionsPolicy(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_permissionsPolicy) |cached| {
            return cached;
        }
        const value = try DocumentImpl.get_permissionsPolicy(instance);
        state.own.cached_permissionsPolicy = value;
        return value;
    }

    pub fn get_fonts(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try DocumentImpl.get_fonts(instance);
    }

    pub fn get_customElementRegistry(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try DocumentImpl.get_customElementRegistry(instance);
    }

    /// Extended attributes: [LegacyLenientSetter]
    pub fn get_fullscreenElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try DocumentImpl.get_fullscreenElement(instance);
    }

    /// Extended attributes: [LegacyLenientSetter]
    pub fn set_fullscreenElement(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        // [LegacyLenientSetter] - Silently do nothing (no-op setter)
        // Per WebIDL §4.3.10: The setter steps are to return.
        _ = instance;
        _ = value;
    }

    pub fn get_pictureInPictureElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try DocumentImpl.get_pictureInPictureElement(instance);
    }

    pub fn get_pointerLockElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try DocumentImpl.get_pointerLockElement(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_styleSheets(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_styleSheets) |cached| {
            return cached;
        }
        const value = try DocumentImpl.get_styleSheets(instance);
        state.own.cached_styleSheets = value;
        return value;
    }

    pub fn get_adoptedStyleSheets(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try DocumentImpl.get_adoptedStyleSheets(instance);
    }

    pub fn set_adoptedStyleSheets(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        try DocumentImpl.set_adoptedStyleSheets(instance, value);
    }

    pub fn get_activeElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try DocumentImpl.get_activeElement(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_children(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_children) |cached| {
            return cached;
        }
        const value = try mixins.ParentNode.get_children(instance);
        state.own.cached_children = value;
        return value;
    }

    pub const get_firstElementChild = mixins.ParentNode.get_firstElementChild;

    pub const get_lastElementChild = mixins.ParentNode.get_lastElementChild;

    pub const get_childElementCount = mixins.ParentNode.get_childElementCount;

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

    pub fn call_clear(instance: *runtime.Instance) anyerror!void {
        return try DocumentImpl.call_clear(instance);
    }

    pub const call_getElementById = mixins.NonElementParentNode.call_getElementById;

    /// Extended attributes: [SecureContext]
    pub fn call_browsingTopics(instance: *runtime.Instance, options: webidl.Opt(BrowsingTopicsOptions)) anyerror!runtime.JSValue {
        return try DocumentImpl.call_browsingTopics(instance, options);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_open(instance: *runtime.Instance, unused1: webidl.Opt(DOMString), unused2: webidl.Opt(DOMString)) anyerror!*runtime.Instance {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();

        return try DocumentImpl.call_open(instance, unused1, unused2);
    }

    pub fn call_elementsFromPoint(instance: *runtime.Instance, x: f64, y: f64) anyerror!runtime.JSValue {
        return try DocumentImpl.call_elementsFromPoint(instance, x, y);
    }

    pub fn call_static_parseHTMLUnsafe(instance: *runtime.Instance, html: DOMString) anyerror!*runtime.Instance {
        return try DocumentImpl.call_static_parseHTMLUnsafe(instance, html);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_writeln(instance: *runtime.Instance, text: []const DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();

        return try DocumentImpl.call_writeln(instance, text);
    }

    pub fn call_exitPointerLock(instance: *runtime.Instance) anyerror!void {
        return try DocumentImpl.call_exitPointerLock(instance);
    }

    pub fn call_hasFocus(instance: *runtime.Instance) anyerror!bool {
        return try DocumentImpl.call_hasFocus(instance);
    }

    pub const call_append = mixins.ParentNode.call_append;

    pub fn call_queryCommandSupported(instance: *runtime.Instance, commandId: DOMString) anyerror!bool {
        return try DocumentImpl.call_queryCommandSupported(instance, commandId);
    }

    pub fn call_getBoxQuads(instance: *runtime.Instance, options: webidl.Opt(BoxQuadOptions)) anyerror!runtime.JSValue {
        return try DocumentImpl.call_getBoxQuads(instance, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createTreeWalker(instance: *runtime.Instance, root: *runtime.Instance, whatToShow: webidl.Opt(u32), filter: webidl.Opt(??*runtime.CallbackWrapper)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object

        return try DocumentImpl.call_createTreeWalker(instance, root, whatToShow, filter);
    }

    pub fn call_createNSResolver(instance: *runtime.Instance, nodeResolver: *runtime.Instance) anyerror!*runtime.Instance {
        return try DocumentImpl.call_createNSResolver(instance, nodeResolver);
    }

    /// Extended attributes: [CEReactions], [NewObject]
    pub fn call_createElementNS(instance: *runtime.Instance, namespace: ?DOMString, qualifiedName: DOMString, options: webidl.Opt(runtime.JSValue)) anyerror!*runtime.Instance {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();

        // [NewObject] - Caller owns the returned object

        return try DocumentImpl.call_createElementNS(instance, namespace, qualifiedName, options);
    }

    pub fn call_measureElement(instance: *runtime.Instance, element: *runtime.Instance) anyerror!*runtime.Instance {
        return try DocumentImpl.call_measureElement(instance, element);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();

        return try DocumentImpl.call_close(instance);
    }

    pub fn call_getElementsByClassName(instance: *runtime.Instance, classNames: DOMString) anyerror!*runtime.Instance {
        return try DocumentImpl.call_getElementsByClassName(instance, classNames);
    }

    pub fn call_convertQuadFromNode(instance: *runtime.Instance, quad: DOMQuadInit, from: GeometryNode, options: webidl.Opt(ConvertCoordinateOptions)) anyerror!*runtime.Instance {
        return try DocumentImpl.call_convertQuadFromNode(instance, quad, from, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createEvent(instance: *runtime.Instance, interface: DOMString) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object

        return try DocumentImpl.call_createEvent(instance, interface);
    }

    /// Extended attributes: [NewObject]
    pub fn call_exitPictureInPicture(instance: *runtime.Instance) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object
        return try DocumentImpl.call_exitPictureInPicture(instance);
    }

    /// Extended attributes: [CEReactions], [NewObject]
    pub fn call_createElement(instance: *runtime.Instance, localName: DOMString, options: webidl.Opt(runtime.JSValue)) anyerror!*runtime.Instance {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();

        // [NewObject] - Caller owns the returned object

        return try DocumentImpl.call_createElement(instance, localName, options);
    }

    pub fn call_hasRedemptionRecord(instance: *runtime.Instance, issuer: runtime.USVString) anyerror!runtime.JSValue {
        return try DocumentImpl.call_hasRedemptionRecord(instance, issuer);
    }

    pub fn call_startViewTransition(instance: *runtime.Instance, callbackOptions: webidl.Opt(runtime.JSValue)) anyerror!*runtime.Instance {
        return try DocumentImpl.call_startViewTransition(instance, callbackOptions);
    }

    pub const call_querySelector = mixins.ParentNode.call_querySelector;

    pub fn call_getElementsByTagName(instance: *runtime.Instance, qualifiedName: DOMString) anyerror!*runtime.Instance {
        return try DocumentImpl.call_getElementsByTagName(instance, qualifiedName);
    }

    pub fn call_measureText(instance: *runtime.Instance, text: DOMString, styleMap: *runtime.Instance) anyerror!*runtime.Instance {
        return try DocumentImpl.call_measureText(instance, text, styleMap);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createAttribute(instance: *runtime.Instance, localName: DOMString) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object

        return try DocumentImpl.call_createAttribute(instance, localName);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createComment(instance: *runtime.Instance, data: DOMString) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object

        return try DocumentImpl.call_createComment(instance, data);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createTextNode(instance: *runtime.Instance, data: DOMString) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object

        return try DocumentImpl.call_createTextNode(instance, data);
    }

    pub const call_querySelectorAll = mixins.ParentNode.call_querySelectorAll;

    pub fn call_queryCommandState(instance: *runtime.Instance, commandId: DOMString) anyerror!bool {
        return try DocumentImpl.call_queryCommandState(instance, commandId);
    }

    pub fn call_elementFromPoint(instance: *runtime.Instance, x: f64, y: f64) anyerror!?*runtime.Instance {
        return try DocumentImpl.call_elementFromPoint(instance, x, y);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createRange(instance: *runtime.Instance) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        return try DocumentImpl.call_createRange(instance);
    }

    pub fn call_queryCommandEnabled(instance: *runtime.Instance, commandId: DOMString) anyerror!bool {
        return try DocumentImpl.call_queryCommandEnabled(instance, commandId);
    }

    pub fn call_getter(instance: *runtime.Instance, name: DOMString) anyerror!runtime.JSValue {
        return try DocumentImpl.call_getter(instance, name);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createAttributeNS(instance: *runtime.Instance, namespace: ?DOMString, qualifiedName: DOMString) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object

        return try DocumentImpl.call_createAttributeNS(instance, namespace, qualifiedName);
    }

    pub fn call_requestStorageAccessFor(instance: *runtime.Instance, requestedOrigin: runtime.USVString) anyerror!runtime.JSValue {
        return try DocumentImpl.call_requestStorageAccessFor(instance, requestedOrigin);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_adoptNode(instance: *runtime.Instance, node: *runtime.Instance) anyerror!*runtime.Instance {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();

        return try DocumentImpl.call_adoptNode(instance, node);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_write(instance: *runtime.Instance, text: []const DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();

        return try DocumentImpl.call_write(instance, text);
    }

    pub fn call_hasStorageAccess(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try DocumentImpl.call_hasStorageAccess(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_execCommand(instance: *runtime.Instance, commandId: DOMString, showUI: webidl.Opt(bool), value: webidl.Opt(DOMString)) anyerror!bool {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();

        return try DocumentImpl.call_execCommand(instance, commandId, showUI, value);
    }

    pub fn call_captureEvents(instance: *runtime.Instance) anyerror!void {
        return try DocumentImpl.call_captureEvents(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createNodeIterator(instance: *runtime.Instance, root: *runtime.Instance, whatToShow: webidl.Opt(u32), filter: webidl.Opt(??*runtime.CallbackWrapper)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object

        return try DocumentImpl.call_createNodeIterator(instance, root, whatToShow, filter);
    }

    pub fn call_hasPrivateToken(instance: *runtime.Instance, issuer: runtime.USVString) anyerror!runtime.JSValue {
        return try DocumentImpl.call_hasPrivateToken(instance, issuer);
    }

    pub fn call_requestStorageAccess(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try DocumentImpl.call_requestStorageAccess(instance);
    }

    pub fn call_releaseEvents(instance: *runtime.Instance) anyerror!void {
        return try DocumentImpl.call_releaseEvents(instance);
    }

    pub fn call_exitFullscreen(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try DocumentImpl.call_exitFullscreen(instance);
    }

    pub fn call_getElementsByTagNameNS(instance: *runtime.Instance, namespace: ?DOMString, localName: DOMString) anyerror!*runtime.Instance {
        return try DocumentImpl.call_getElementsByTagNameNS(instance, namespace, localName);
    }

    pub fn call_getElementsByName(instance: *runtime.Instance, elementName: DOMString) anyerror!*runtime.Instance {
        return try DocumentImpl.call_getElementsByName(instance, elementName);
    }

    pub fn call_caretPositionFromPoint(instance: *runtime.Instance, x: f64, y: f64, options: webidl.Opt(CaretPositionFromPointOptions)) anyerror!?*runtime.Instance {
        return try DocumentImpl.call_caretPositionFromPoint(instance, x, y, options);
    }

    pub fn call_convertRectFromNode(instance: *runtime.Instance, rect: *runtime.Instance, from: GeometryNode, options: webidl.Opt(ConvertCoordinateOptions)) anyerror!*runtime.Instance {
        return try DocumentImpl.call_convertRectFromNode(instance, rect, from, options);
    }

    pub fn call_hasUnpartitionedCookieAccess(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try DocumentImpl.call_hasUnpartitionedCookieAccess(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createCDATASection(instance: *runtime.Instance, data: DOMString) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object

        return try DocumentImpl.call_createCDATASection(instance, data);
    }

    pub fn call_queryCommandIndeterm(instance: *runtime.Instance, commandId: DOMString) anyerror!bool {
        return try DocumentImpl.call_queryCommandIndeterm(instance, commandId);
    }

    pub const call_replaceChildren = mixins.ParentNode.call_replaceChildren;

    /// Extended attributes: [CEReactions], [NewObject]
    pub fn call_importNode(instance: *runtime.Instance, node: *runtime.Instance, options: webidl.Opt(runtime.JSValue)) anyerror!*runtime.Instance {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();

        // [NewObject] - Caller owns the returned object

        return try DocumentImpl.call_importNode(instance, node, options);
    }

    pub fn call_convertPointFromNode(instance: *runtime.Instance, point: DOMPointInit, from: GeometryNode, options: webidl.Opt(ConvertCoordinateOptions)) anyerror!*runtime.Instance {
        return try DocumentImpl.call_convertPointFromNode(instance, point, from, options);
    }

    pub fn call_getSelection(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try DocumentImpl.call_getSelection(instance);
    }

    pub fn call_queryCommandValue(instance: *runtime.Instance, commandId: DOMString) anyerror!DOMString {
        return try DocumentImpl.call_queryCommandValue(instance, commandId);
    }

    pub fn call_evaluate(instance: *runtime.Instance, expression: DOMString, contextNode: *runtime.Instance, resolver: webidl.Opt(??*runtime.CallbackWrapper), @"type": webidl.Opt(u16), result: webidl.Opt(?*runtime.Instance)) anyerror!*runtime.Instance {
        return try DocumentImpl.call_evaluate(instance, expression, contextNode, resolver, @"type", result);
    }

    pub const call_prepend = mixins.ParentNode.call_prepend;

    pub fn call_getAnimations(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try DocumentImpl.call_getAnimations(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createDocumentFragment(instance: *runtime.Instance) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        return try DocumentImpl.call_createDocumentFragment(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createProcessingInstruction(instance: *runtime.Instance, target: DOMString, data: DOMString) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object

        return try DocumentImpl.call_createProcessingInstruction(instance, target, data);
    }

    pub const call_moveBefore = mixins.ParentNode.call_moveBefore;

    /// Extended attributes: [NewObject]
    pub fn call_createExpression(instance: *runtime.Instance, expression: DOMString, resolver: webidl.Opt(??*runtime.CallbackWrapper)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object

        return try DocumentImpl.call_createExpression(instance, expression, resolver);
    }

    pub fn call_open__1(instance: *runtime.Instance, url: runtime.USVString, name: DOMString, features: DOMString) anyerror!?WindowProxy {
        if (comptime @hasDecl(DocumentImpl, "call_open__1")) {
            return try DocumentImpl.call_open__1(instance, url, name, features);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn call_requestStorageAccess__1(instance: *runtime.Instance, types: webidl.Opt(StorageAccessTypes)) anyerror!runtime.JSValue {
        if (comptime @hasDecl(DocumentImpl, "call_requestStorageAccess__1")) {
            return try DocumentImpl.call_requestStorageAccess__1(instance, types);
        } else {
            return error.NotImplemented;
        }
    }

    /// WebIDL overload sets: every overload of each overloaded operation,
    /// in IDL order, for the overload resolution algorithm
    /// (webidl.overload_resolution). The binding is installed for the first
    /// overload and forwards to the one the arguments select.
    pub const overloads = .{
        .{ "open", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_open", .args = &.{ .{ .kinds = &.{.string}, .optionality = .optional }, .{ .kinds = &.{.string}, .optionality = .optional } } },
            .{ .function = "call_open__1", .implemented = @hasDecl(DocumentImpl, "call_open__1"), .args = &.{ .{ .kinds = &.{.string} }, .{ .kinds = &.{.string} }, .{ .kinds = &.{.string} } } },
        } },
        .{ "requestStorageAccess", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_requestStorageAccess", .args = &.{} },
            .{ .function = "call_requestStorageAccess__1", .implemented = @hasDecl(DocumentImpl, "call_requestStorageAccess__1"), .args = &.{.{ .kinds = &.{.dictionary}, .optionality = .optional }} },
        } },
    };

    /// WebIDL [LegacyNullToEmptyString]: the values null converts to "" for
    /// (bit i = argument i; an attribute setter's value is bit 0).
    pub const legacy_null_to_empty = .{
        .{ "set_fgColor", 0b1 },
        .{ "set_linkColor", 0b1 },
        .{ "set_vlinkColor", 0b1 },
        .{ "set_alinkColor", 0b1 },
        .{ "set_bgColor", 0b1 },
    };

    /// Get supported property names for named property enumeration (Reflect.ownKeys, etc.)
    /// Per WebIDL spec §3.9.3, returns names in list order for proper enumeration
    pub fn getSupportedPropertyNames(instance: *runtime.Instance, allocator: std.mem.Allocator) ![]runtime.DOMString {
        return DocumentImpl.getSupportedPropertyNames(instance, allocator);
    }
};
