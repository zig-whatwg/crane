//! Generated from: mathml-core.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MathMLElementImpl = @import("impls").MathMLElement;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Element = @import("interfaces").Element;
const ElementCSSInlineStyle = @import("interfaces").ElementCSSInlineStyle;
const GlobalEventHandlers = @import("mixins").GlobalEventHandlers;
const CSSOMString = @import("typedefs").CSSOMString;
const HTMLCollection = @import("interfaces").HTMLCollection;
const DOMPointInit = @import("dictionaries").DOMPointInit;
const GeometryNode = @import("typedefs").GeometryNode;
const CSSStyleDeclaration = @import("interfaces").CSSStyleDeclaration;
const NamedNodeMap = @import("interfaces").NamedNodeMap;
const USVString = @import("typedefs").USVString;
const TrustedType = @import("typedefs").TrustedType;
const CheckVisibilityOptions = @import("dictionaries").CheckVisibilityOptions;
const ScrollIntoViewOptions = @import("dictionaries").ScrollIntoViewOptions;
const BoxQuadOptions = @import("dictionaries").BoxQuadOptions;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const FocusableAreasOption = @import("dictionaries").FocusableAreasOption;
const EventListener = @import("interfaces").EventListener;
const CSSStyleProperties = @import("interfaces").CSSStyleProperties;
const CSSPseudoElement = @import("interfaces").CSSPseudoElement;
const ViewTransitionUpdateCallback = @import("callbacks").ViewTransitionUpdateCallback;
const Node = @import("interfaces").Node;
const CustomElementRegistry = @import("interfaces").CustomElementRegistry;
const Animation = @import("interfaces").Animation;
const Range = @import("interfaces").Range;
const Event = @import("interfaces").Event;
const DOMRectList = @import("interfaces").DOMRectList;
const DOMString = @import("typedefs").DOMString;
const Document = @import("interfaces").Document;
const OnErrorEventHandler = @import("typedefs").OnErrorEventHandler;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const GetHTMLOptions = @import("dictionaries").GetHTMLOptions;
const ScrollToOptions = @import("dictionaries").ScrollToOptions;
const HTMLSlotElement = @import("interfaces").HTMLSlotElement;
const DOMQuad = @import("interfaces").DOMQuad;
const DOMRectReadOnly = @import("interfaces").DOMRectReadOnly;
const KeyframeAnimationOptions = @import("dictionaries").KeyframeAnimationOptions;
const StylePropertyMapReadOnly = @import("interfaces").StylePropertyMapReadOnly;
const DOMTokenList = @import("interfaces").DOMTokenList;
const StartViewTransitionOptions = @import("dictionaries").StartViewTransitionOptions;
const DOMRect = @import("interfaces").DOMRect;
const ViewTransition = @import("interfaces").ViewTransition;
const SpatialNavigationSearchOptions = @import("dictionaries").SpatialNavigationSearchOptions;
const GetAnimationsOptions = @import("dictionaries").GetAnimationsOptions;
const EventHandler = @import("typedefs").EventHandler;
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
const Observable = @import("interfaces").Observable;
const DOMPoint = @import("interfaces").DOMPoint;
const PointerLockOptions = @import("dictionaries").PointerLockOptions;
const GetRootNodeOptions = @import("dictionaries").GetRootNodeOptions;
const ShadowRootInit = @import("dictionaries").ShadowRootInit;

pub const MathMLElement = struct {
    pub const Meta = struct {
        pub const name = "MathMLElement";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Element.State;
        pub const ParentInterface = Element;
        pub const MixinTypes = &.{
            ElementCSSInlineStyle,
            GlobalEventHandlers,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "style", "get_style", "set_style" },
            .{ "attributeStyleMap", "get_attributeStyleMap", null },
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
            .{ "style", "cssText" },
        };

        /// [LegacyLenientThis] attributes: do NOT throw TypeError on invalid this
        /// Getters return undefined, setters silently return
        pub const lenient_this_attributes = .{
            "onmouseenter",
            "onmouseleave",
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
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "style", "get_style", "set_style" },
            .{ "attributeStyleMap", "get_attributeStyleMap", null },
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
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            style: *runtime.Instance = undefined,
            attributeStyleMap: *runtime.Instance = undefined,
            onerror: typedefs.OnErrorEventHandler = undefined,
            cached_style: ?*runtime.Instance = null,
            cached_attributeStyleMap: ?*runtime.Instance = null,
            _internal: ?*MathMLElementImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_attributeStyleMap = &get_attributeStyleMap,
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
        .get_onpointermove = &get_onpointermove,
        .get_onpointerout = &get_onpointerout,
        .get_onpointerover = &get_onpointerover,
        .get_onpointerrawupdate = &get_onpointerrawupdate,
        .get_onpointerup = &get_onpointerup,
        .get_onprogress = &get_onprogress,
        .get_onratechange = &get_onratechange,
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
        .get_onvolumechange = &get_onvolumechange,
        .get_onwaiting = &get_onwaiting,
        .get_onwebkitanimationend = &get_onwebkitanimationend,
        .get_onwebkitanimationiteration = &get_onwebkitanimationiteration,
        .get_onwebkitanimationstart = &get_onwebkitanimationstart,
        .get_onwebkittransitionend = &get_onwebkittransitionend,
        .get_onwheel = &get_onwheel,
        .get_style = &get_style,

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
        .set_onpointermove = &set_onpointermove,
        .set_onpointerout = &set_onpointerout,
        .set_onpointerover = &set_onpointerover,
        .set_onpointerrawupdate = &set_onpointerrawupdate,
        .set_onpointerup = &set_onpointerup,
        .set_onprogress = &set_onprogress,
        .set_onratechange = &set_onratechange,
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
        .set_onvolumechange = &set_onvolumechange,
        .set_onwaiting = &set_onwaiting,
        .set_onwebkitanimationend = &set_onwebkitanimationend,
        .set_onwebkitanimationiteration = &set_onwebkitanimationiteration,
        .set_onwebkitanimationstart = &set_onwebkitanimationstart,
        .set_onwebkittransitionend = &set_onwebkittransitionend,
        .set_onwheel = &set_onwheel,
        .set_style = &set_style,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates, Meta.name, State);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return MathMLElementImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return MathMLElementImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MathMLElementImpl.deinit(instance);
    }

    /// Extended attributes: [SameObject], [PutForwards=cssText]
    pub fn get_style(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_style) |cached| {
            return cached;
        }
        const value = try MathMLElementImpl.get_style(instance);
        state.own.cached_style = value;
        return value;
    }

    /// Extended attributes: [SameObject], [PutForwards=cssText]
    pub fn set_style(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [PutForwards] - Get target object and set the forwarded property
        // Per WebIDL spec: setting 'style' forwards to 'cssText' on the attribute's value
        const target = try get_style(instance);

        // Use JavaScript [[Set]] semantics to set the forwarded property
        // This respects prototype chain and user-defined setters
        try runtime.setPropertyOnInstance(target, "cssText", value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_attributeStyleMap(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_attributeStyleMap) |cached| {
            return cached;
        }
        const value = try MathMLElementImpl.get_attributeStyleMap(instance);
        state.own.cached_attributeStyleMap = value;
        return value;
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
};
