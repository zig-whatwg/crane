//! Generated from: dom.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XMLDocumentImpl = @import("../impls/XMLDocument.zig");
const Document = @import("Document.zig");

pub const XMLDocument = struct {
    pub const Meta = struct {
        pub const name = "XMLDocument";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Document;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Properties that cannot be shadowed or deleted (configurable: false)
        pub const legacy_unforgeable_properties = .{
            "location",
        };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(XMLDocument, .{
        .deinit_fn = &deinit_wrapper,

        .get_ATTRIBUTE_NODE = &Document.get_ATTRIBUTE_NODE,
        .get_CDATA_SECTION_NODE = &Document.get_CDATA_SECTION_NODE,
        .get_COMMENT_NODE = &Document.get_COMMENT_NODE,
        .get_DOCUMENT_FRAGMENT_NODE = &Document.get_DOCUMENT_FRAGMENT_NODE,
        .get_DOCUMENT_NODE = &Document.get_DOCUMENT_NODE,
        .get_DOCUMENT_POSITION_CONTAINED_BY = &Document.get_DOCUMENT_POSITION_CONTAINED_BY,
        .get_DOCUMENT_POSITION_CONTAINS = &Document.get_DOCUMENT_POSITION_CONTAINS,
        .get_DOCUMENT_POSITION_DISCONNECTED = &Document.get_DOCUMENT_POSITION_DISCONNECTED,
        .get_DOCUMENT_POSITION_FOLLOWING = &Document.get_DOCUMENT_POSITION_FOLLOWING,
        .get_DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC = &Document.get_DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC,
        .get_DOCUMENT_POSITION_PRECEDING = &Document.get_DOCUMENT_POSITION_PRECEDING,
        .get_DOCUMENT_TYPE_NODE = &Document.get_DOCUMENT_TYPE_NODE,
        .get_ELEMENT_NODE = &Document.get_ELEMENT_NODE,
        .get_ENTITY_NODE = &Document.get_ENTITY_NODE,
        .get_ENTITY_REFERENCE_NODE = &Document.get_ENTITY_REFERENCE_NODE,
        .get_NOTATION_NODE = &Document.get_NOTATION_NODE,
        .get_PROCESSING_INSTRUCTION_NODE = &Document.get_PROCESSING_INSTRUCTION_NODE,
        .get_TEXT_NODE = &Document.get_TEXT_NODE,
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
        
        // Initialize the state (Impl receives full hierarchy)
        XMLDocumentImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        XMLDocumentImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_nodeType(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_nodeType(state);
    }

    pub fn get_nodeName(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_nodeName(state);
    }

    pub fn get_baseURI(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_baseURI(state);
    }

    pub fn get_isConnected(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_isConnected(state);
    }

    pub fn get_ownerDocument(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_ownerDocument(state);
    }

    pub fn get_parentNode(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_parentNode(state);
    }

    pub fn get_parentElement(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_parentElement(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_childNodes(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_childNodes) |cached| {
            return cached;
        }
        const value = XMLDocumentImpl.get_childNodes(state);
        state.cached_childNodes = value;
        return value;
    }

    pub fn get_firstChild(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_firstChild(state);
    }

    pub fn get_lastChild(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_lastChild(state);
    }

    pub fn get_previousSibling(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_previousSibling(state);
    }

    pub fn get_nextSibling(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_nextSibling(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_nodeValue(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_nodeValue(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_nodeValue(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        XMLDocumentImpl.set_nodeValue(state, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_textContent(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_textContent(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_textContent(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        XMLDocumentImpl.set_textContent(state, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_implementation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_implementation) |cached| {
            return cached;
        }
        const value = XMLDocumentImpl.get_implementation(state);
        state.cached_implementation = value;
        return value;
    }

    pub fn get_URL(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_URL(state);
    }

    pub fn get_documentURI(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_documentURI(state);
    }

    pub fn get_compatMode(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_compatMode(state);
    }

    pub fn get_characterSet(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_characterSet(state);
    }

    pub fn get_charset(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_charset(state);
    }

    pub fn get_inputEncoding(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_inputEncoding(state);
    }

    pub fn get_contentType(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_contentType(state);
    }

    pub fn get_doctype(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_doctype(state);
    }

    pub fn get_documentElement(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_documentElement(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_fragmentDirective(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_fragmentDirective) |cached| {
            return cached;
        }
        const value = XMLDocumentImpl.get_fragmentDirective(state);
        state.cached_fragmentDirective = value;
        return value;
    }

    pub fn get_prerendering(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_prerendering(state);
    }

    pub fn get_onprerenderingchange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onprerenderingchange(state);
    }

    pub fn set_onprerenderingchange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onprerenderingchange(state, value);
    }

    /// Extended attributes: [LegacyLenientSetter]
    pub fn get_fullscreenEnabled(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_fullscreenEnabled(state);
    }

    /// Extended attributes: [LegacyLenientSetter], [Unscopable]
    pub fn get_fullscreen(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_fullscreen(state);
    }

    pub fn get_onfullscreenchange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onfullscreenchange(state);
    }

    pub fn set_onfullscreenchange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onfullscreenchange(state, value);
    }

    pub fn get_onfullscreenerror(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onfullscreenerror(state);
    }

    pub fn set_onfullscreenerror(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onfullscreenerror(state, value);
    }

    pub fn get_timeline(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_timeline(state);
    }

    pub fn get_pictureInPictureEnabled(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_pictureInPictureEnabled(state);
    }

    pub fn get_onpointerlockchange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onpointerlockchange(state);
    }

    pub fn set_onpointerlockchange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onpointerlockchange(state, value);
    }

    pub fn get_onpointerlockerror(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onpointerlockerror(state);
    }

    pub fn set_onpointerlockerror(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onpointerlockerror(state, value);
    }

    pub fn get_onfreeze(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onfreeze(state);
    }

    pub fn set_onfreeze(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onfreeze(state, value);
    }

    pub fn get_onresume(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onresume(state);
    }

    pub fn set_onresume(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onresume(state, value);
    }

    pub fn get_wasDiscarded(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_wasDiscarded(state);
    }

    pub fn get_namedFlows(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_namedFlows(state);
    }

    pub fn get_rootElement(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_rootElement(state);
    }

    pub fn get_activeViewTransition(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_activeViewTransition(state);
    }

    /// Extended attributes: [PutForwards=href], [LegacyUnforgeable]
    pub fn get_location(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_location(state);
    }

    pub fn get_domain(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_domain(state);
    }

    pub fn set_domain(instance: *runtime.Instance, value: runtime.USVString) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_domain(state, value);
    }

    pub fn get_referrer(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_referrer(state);
    }

    pub fn get_cookie(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_cookie(state);
    }

    pub fn set_cookie(instance: *runtime.Instance, value: runtime.USVString) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_cookie(state, value);
    }

    pub fn get_lastModified(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_lastModified(state);
    }

    pub fn get_readyState(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_readyState(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_title(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_title(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_title(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        XMLDocumentImpl.set_title(state, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_dir(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_dir(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_dir(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        XMLDocumentImpl.set_dir(state, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_body(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_body(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_body(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        XMLDocumentImpl.set_body(state, value);
    }

    pub fn get_head(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_head(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_images(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_images) |cached| {
            return cached;
        }
        const value = XMLDocumentImpl.get_images(state);
        state.cached_images = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_embeds(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_embeds) |cached| {
            return cached;
        }
        const value = XMLDocumentImpl.get_embeds(state);
        state.cached_embeds = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_plugins(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_plugins) |cached| {
            return cached;
        }
        const value = XMLDocumentImpl.get_plugins(state);
        state.cached_plugins = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_links(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_links) |cached| {
            return cached;
        }
        const value = XMLDocumentImpl.get_links(state);
        state.cached_links = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_forms(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_forms) |cached| {
            return cached;
        }
        const value = XMLDocumentImpl.get_forms(state);
        state.cached_forms = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_scripts(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_scripts) |cached| {
            return cached;
        }
        const value = XMLDocumentImpl.get_scripts(state);
        state.cached_scripts = value;
        return value;
    }

    pub fn get_currentScript(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_currentScript(state);
    }

    pub fn get_defaultView(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_defaultView(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_designMode(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_designMode(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_designMode(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        XMLDocumentImpl.set_designMode(state, value);
    }

    pub fn get_hidden(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_hidden(state);
    }

    pub fn get_visibilityState(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_visibilityState(state);
    }

    /// Extended attributes: [LegacyLenientThis]
    pub fn get_onreadystatechange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onreadystatechange(state);
    }

    /// Extended attributes: [LegacyLenientThis]
    pub fn set_onreadystatechange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onreadystatechange(state, value);
    }

    pub fn get_onvisibilitychange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onvisibilitychange(state);
    }

    pub fn set_onvisibilitychange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onvisibilitychange(state, value);
    }

    /// Extended attributes: [CEReactions], [LegacyNullToEmptyString]
    pub fn get_fgColor(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_fgColor(state);
    }

    /// Extended attributes: [CEReactions], [LegacyNullToEmptyString]
    pub fn set_fgColor(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        XMLDocumentImpl.set_fgColor(state, value);
    }

    /// Extended attributes: [CEReactions], [LegacyNullToEmptyString]
    pub fn get_linkColor(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_linkColor(state);
    }

    /// Extended attributes: [CEReactions], [LegacyNullToEmptyString]
    pub fn set_linkColor(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        XMLDocumentImpl.set_linkColor(state, value);
    }

    /// Extended attributes: [CEReactions], [LegacyNullToEmptyString]
    pub fn get_vlinkColor(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_vlinkColor(state);
    }

    /// Extended attributes: [CEReactions], [LegacyNullToEmptyString]
    pub fn set_vlinkColor(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        XMLDocumentImpl.set_vlinkColor(state, value);
    }

    /// Extended attributes: [CEReactions], [LegacyNullToEmptyString]
    pub fn get_alinkColor(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_alinkColor(state);
    }

    /// Extended attributes: [CEReactions], [LegacyNullToEmptyString]
    pub fn set_alinkColor(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        XMLDocumentImpl.set_alinkColor(state, value);
    }

    /// Extended attributes: [CEReactions], [LegacyNullToEmptyString]
    pub fn get_bgColor(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_bgColor(state);
    }

    /// Extended attributes: [CEReactions], [LegacyNullToEmptyString]
    pub fn set_bgColor(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        XMLDocumentImpl.set_bgColor(state, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_anchors(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_anchors) |cached| {
            return cached;
        }
        const value = XMLDocumentImpl.get_anchors(state);
        state.cached_anchors = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_applets(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_applets) |cached| {
            return cached;
        }
        const value = XMLDocumentImpl.get_applets(state);
        state.cached_applets = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_all(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_all) |cached| {
            return cached;
        }
        const value = XMLDocumentImpl.get_all(state);
        state.cached_all = value;
        return value;
    }

    pub fn get_scrollingElement(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_scrollingElement(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_permissionsPolicy(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_permissionsPolicy) |cached| {
            return cached;
        }
        const value = XMLDocumentImpl.get_permissionsPolicy(state);
        state.cached_permissionsPolicy = value;
        return value;
    }

    pub fn get_fonts(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_fonts(state);
    }

    pub fn get_customElementRegistry(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_customElementRegistry(state);
    }

    /// Extended attributes: [LegacyLenientSetter]
    pub fn get_fullscreenElement(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_fullscreenElement(state);
    }

    pub fn get_pictureInPictureElement(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_pictureInPictureElement(state);
    }

    pub fn get_pointerLockElement(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_pointerLockElement(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_styleSheets(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_styleSheets) |cached| {
            return cached;
        }
        const value = XMLDocumentImpl.get_styleSheets(state);
        state.cached_styleSheets = value;
        return value;
    }

    pub fn get_adoptedStyleSheets(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_adoptedStyleSheets(state);
    }

    pub fn set_adoptedStyleSheets(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_adoptedStyleSheets(state, value);
    }

    pub fn get_activeElement(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_activeElement(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_children(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_children) |cached| {
            return cached;
        }
        const value = XMLDocumentImpl.get_children(state);
        state.cached_children = value;
        return value;
    }

    pub fn get_firstElementChild(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_firstElementChild(state);
    }

    pub fn get_lastElementChild(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_lastElementChild(state);
    }

    pub fn get_childElementCount(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_childElementCount(state);
    }

    pub fn get_onabort(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onabort(state);
    }

    pub fn set_onabort(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onabort(state, value);
    }

    pub fn get_onauxclick(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onauxclick(state);
    }

    pub fn set_onauxclick(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onauxclick(state, value);
    }

    pub fn get_onbeforeinput(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onbeforeinput(state);
    }

    pub fn set_onbeforeinput(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onbeforeinput(state, value);
    }

    pub fn get_onbeforematch(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onbeforematch(state);
    }

    pub fn set_onbeforematch(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onbeforematch(state, value);
    }

    pub fn get_onbeforetoggle(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onbeforetoggle(state);
    }

    pub fn set_onbeforetoggle(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onbeforetoggle(state, value);
    }

    pub fn get_onblur(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onblur(state);
    }

    pub fn set_onblur(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onblur(state, value);
    }

    pub fn get_oncancel(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_oncancel(state);
    }

    pub fn set_oncancel(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_oncancel(state, value);
    }

    pub fn get_oncanplay(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_oncanplay(state);
    }

    pub fn set_oncanplay(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_oncanplay(state, value);
    }

    pub fn get_oncanplaythrough(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_oncanplaythrough(state);
    }

    pub fn set_oncanplaythrough(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_oncanplaythrough(state, value);
    }

    pub fn get_onchange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onchange(state);
    }

    pub fn set_onchange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onchange(state, value);
    }

    pub fn get_onclick(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onclick(state);
    }

    pub fn set_onclick(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onclick(state, value);
    }

    pub fn get_onclose(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onclose(state);
    }

    pub fn set_onclose(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onclose(state, value);
    }

    pub fn get_oncommand(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_oncommand(state);
    }

    pub fn set_oncommand(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_oncommand(state, value);
    }

    pub fn get_oncontextlost(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_oncontextlost(state);
    }

    pub fn set_oncontextlost(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_oncontextlost(state, value);
    }

    pub fn get_oncontextmenu(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_oncontextmenu(state);
    }

    pub fn set_oncontextmenu(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_oncontextmenu(state, value);
    }

    pub fn get_oncontextrestored(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_oncontextrestored(state);
    }

    pub fn set_oncontextrestored(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_oncontextrestored(state, value);
    }

    pub fn get_oncopy(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_oncopy(state);
    }

    pub fn set_oncopy(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_oncopy(state, value);
    }

    pub fn get_oncuechange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_oncuechange(state);
    }

    pub fn set_oncuechange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_oncuechange(state, value);
    }

    pub fn get_oncut(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_oncut(state);
    }

    pub fn set_oncut(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_oncut(state, value);
    }

    pub fn get_ondblclick(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_ondblclick(state);
    }

    pub fn set_ondblclick(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_ondblclick(state, value);
    }

    pub fn get_ondrag(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_ondrag(state);
    }

    pub fn set_ondrag(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_ondrag(state, value);
    }

    pub fn get_ondragend(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_ondragend(state);
    }

    pub fn set_ondragend(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_ondragend(state, value);
    }

    pub fn get_ondragenter(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_ondragenter(state);
    }

    pub fn set_ondragenter(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_ondragenter(state, value);
    }

    pub fn get_ondragleave(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_ondragleave(state);
    }

    pub fn set_ondragleave(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_ondragleave(state, value);
    }

    pub fn get_ondragover(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_ondragover(state);
    }

    pub fn set_ondragover(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_ondragover(state, value);
    }

    pub fn get_ondragstart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_ondragstart(state);
    }

    pub fn set_ondragstart(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_ondragstart(state, value);
    }

    pub fn get_ondrop(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_ondrop(state);
    }

    pub fn set_ondrop(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_ondrop(state, value);
    }

    pub fn get_ondurationchange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_ondurationchange(state);
    }

    pub fn set_ondurationchange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_ondurationchange(state, value);
    }

    pub fn get_onemptied(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onemptied(state);
    }

    pub fn set_onemptied(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onemptied(state, value);
    }

    pub fn get_onended(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onended(state);
    }

    pub fn set_onended(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onended(state, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onerror(state);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onerror(state, value);
    }

    pub fn get_onfocus(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onfocus(state);
    }

    pub fn set_onfocus(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onfocus(state, value);
    }

    pub fn get_onformdata(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onformdata(state);
    }

    pub fn set_onformdata(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onformdata(state, value);
    }

    pub fn get_oninput(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_oninput(state);
    }

    pub fn set_oninput(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_oninput(state, value);
    }

    pub fn get_oninvalid(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_oninvalid(state);
    }

    pub fn set_oninvalid(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_oninvalid(state, value);
    }

    pub fn get_onkeydown(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onkeydown(state);
    }

    pub fn set_onkeydown(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onkeydown(state, value);
    }

    pub fn get_onkeypress(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onkeypress(state);
    }

    pub fn set_onkeypress(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onkeypress(state, value);
    }

    pub fn get_onkeyup(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onkeyup(state);
    }

    pub fn set_onkeyup(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onkeyup(state, value);
    }

    pub fn get_onload(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onload(state);
    }

    pub fn set_onload(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onload(state, value);
    }

    pub fn get_onloadeddata(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onloadeddata(state);
    }

    pub fn set_onloadeddata(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onloadeddata(state, value);
    }

    pub fn get_onloadedmetadata(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onloadedmetadata(state);
    }

    pub fn set_onloadedmetadata(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onloadedmetadata(state, value);
    }

    pub fn get_onloadstart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onloadstart(state);
    }

    pub fn set_onloadstart(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onloadstart(state, value);
    }

    pub fn get_onmousedown(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onmousedown(state);
    }

    pub fn set_onmousedown(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onmousedown(state, value);
    }

    /// Extended attributes: [LegacyLenientThis]
    pub fn get_onmouseenter(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onmouseenter(state);
    }

    /// Extended attributes: [LegacyLenientThis]
    pub fn set_onmouseenter(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onmouseenter(state, value);
    }

    /// Extended attributes: [LegacyLenientThis]
    pub fn get_onmouseleave(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onmouseleave(state);
    }

    /// Extended attributes: [LegacyLenientThis]
    pub fn set_onmouseleave(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onmouseleave(state, value);
    }

    pub fn get_onmousemove(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onmousemove(state);
    }

    pub fn set_onmousemove(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onmousemove(state, value);
    }

    pub fn get_onmouseout(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onmouseout(state);
    }

    pub fn set_onmouseout(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onmouseout(state, value);
    }

    pub fn get_onmouseover(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onmouseover(state);
    }

    pub fn set_onmouseover(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onmouseover(state, value);
    }

    pub fn get_onmouseup(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onmouseup(state);
    }

    pub fn set_onmouseup(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onmouseup(state, value);
    }

    pub fn get_onpaste(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onpaste(state);
    }

    pub fn set_onpaste(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onpaste(state, value);
    }

    pub fn get_onpause(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onpause(state);
    }

    pub fn set_onpause(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onpause(state, value);
    }

    pub fn get_onplay(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onplay(state);
    }

    pub fn set_onplay(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onplay(state, value);
    }

    pub fn get_onplaying(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onplaying(state);
    }

    pub fn set_onplaying(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onplaying(state, value);
    }

    pub fn get_onprogress(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onprogress(state);
    }

    pub fn set_onprogress(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onprogress(state, value);
    }

    pub fn get_onratechange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onratechange(state);
    }

    pub fn set_onratechange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onratechange(state, value);
    }

    pub fn get_onreset(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onreset(state);
    }

    pub fn set_onreset(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onreset(state, value);
    }

    pub fn get_onresize(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onresize(state);
    }

    pub fn set_onresize(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onresize(state, value);
    }

    pub fn get_onscroll(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onscroll(state);
    }

    pub fn set_onscroll(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onscroll(state, value);
    }

    pub fn get_onscrollend(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onscrollend(state);
    }

    pub fn set_onscrollend(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onscrollend(state, value);
    }

    pub fn get_onsecuritypolicyviolation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onsecuritypolicyviolation(state);
    }

    pub fn set_onsecuritypolicyviolation(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onsecuritypolicyviolation(state, value);
    }

    pub fn get_onseeked(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onseeked(state);
    }

    pub fn set_onseeked(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onseeked(state, value);
    }

    pub fn get_onseeking(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onseeking(state);
    }

    pub fn set_onseeking(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onseeking(state, value);
    }

    pub fn get_onselect(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onselect(state);
    }

    pub fn set_onselect(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onselect(state, value);
    }

    pub fn get_onslotchange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onslotchange(state);
    }

    pub fn set_onslotchange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onslotchange(state, value);
    }

    pub fn get_onstalled(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onstalled(state);
    }

    pub fn set_onstalled(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onstalled(state, value);
    }

    pub fn get_onsubmit(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onsubmit(state);
    }

    pub fn set_onsubmit(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onsubmit(state, value);
    }

    pub fn get_onsuspend(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onsuspend(state);
    }

    pub fn set_onsuspend(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onsuspend(state, value);
    }

    pub fn get_ontimeupdate(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_ontimeupdate(state);
    }

    pub fn set_ontimeupdate(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_ontimeupdate(state, value);
    }

    pub fn get_ontoggle(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_ontoggle(state);
    }

    pub fn set_ontoggle(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_ontoggle(state, value);
    }

    pub fn get_onvolumechange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onvolumechange(state);
    }

    pub fn set_onvolumechange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onvolumechange(state, value);
    }

    pub fn get_onwaiting(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onwaiting(state);
    }

    pub fn set_onwaiting(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onwaiting(state, value);
    }

    pub fn get_onwebkitanimationend(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onwebkitanimationend(state);
    }

    pub fn set_onwebkitanimationend(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onwebkitanimationend(state, value);
    }

    pub fn get_onwebkitanimationiteration(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onwebkitanimationiteration(state);
    }

    pub fn set_onwebkitanimationiteration(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onwebkitanimationiteration(state, value);
    }

    pub fn get_onwebkitanimationstart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onwebkitanimationstart(state);
    }

    pub fn set_onwebkitanimationstart(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onwebkitanimationstart(state, value);
    }

    pub fn get_onwebkittransitionend(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onwebkittransitionend(state);
    }

    pub fn set_onwebkittransitionend(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onwebkittransitionend(state, value);
    }

    pub fn get_onwheel(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onwheel(state);
    }

    pub fn set_onwheel(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onwheel(state, value);
    }

    pub fn get_onselectstart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onselectstart(state);
    }

    pub fn set_onselectstart(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onselectstart(state, value);
    }

    pub fn get_onselectionchange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onselectionchange(state);
    }

    pub fn set_onselectionchange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onselectionchange(state, value);
    }

    pub fn get_onanimationstart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onanimationstart(state);
    }

    pub fn set_onanimationstart(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onanimationstart(state, value);
    }

    pub fn get_onanimationiteration(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onanimationiteration(state);
    }

    pub fn set_onanimationiteration(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onanimationiteration(state, value);
    }

    pub fn get_onanimationend(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onanimationend(state);
    }

    pub fn set_onanimationend(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onanimationend(state, value);
    }

    pub fn get_onanimationcancel(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onanimationcancel(state);
    }

    pub fn set_onanimationcancel(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onanimationcancel(state, value);
    }

    pub fn get_ontransitionrun(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_ontransitionrun(state);
    }

    pub fn set_ontransitionrun(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_ontransitionrun(state, value);
    }

    pub fn get_ontransitionstart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_ontransitionstart(state);
    }

    pub fn set_ontransitionstart(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_ontransitionstart(state, value);
    }

    pub fn get_ontransitionend(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_ontransitionend(state);
    }

    pub fn set_ontransitionend(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_ontransitionend(state, value);
    }

    pub fn get_ontransitioncancel(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_ontransitioncancel(state);
    }

    pub fn set_ontransitioncancel(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_ontransitioncancel(state, value);
    }

    pub fn get_onbeforexrselect(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onbeforexrselect(state);
    }

    pub fn set_onbeforexrselect(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onbeforexrselect(state, value);
    }

    pub fn get_onpointerover(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onpointerover(state);
    }

    pub fn set_onpointerover(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onpointerover(state, value);
    }

    pub fn get_onpointerenter(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onpointerenter(state);
    }

    pub fn set_onpointerenter(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onpointerenter(state, value);
    }

    pub fn get_onpointerdown(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onpointerdown(state);
    }

    pub fn set_onpointerdown(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onpointerdown(state, value);
    }

    pub fn get_onpointermove(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onpointermove(state);
    }

    pub fn set_onpointermove(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onpointermove(state, value);
    }

    /// Extended attributes: [SecureContext]
    pub fn get_onpointerrawupdate(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onpointerrawupdate(state);
    }

    /// Extended attributes: [SecureContext]
    pub fn set_onpointerrawupdate(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onpointerrawupdate(state, value);
    }

    pub fn get_onpointerup(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onpointerup(state);
    }

    pub fn set_onpointerup(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onpointerup(state, value);
    }

    pub fn get_onpointercancel(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onpointercancel(state);
    }

    pub fn set_onpointercancel(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onpointercancel(state, value);
    }

    pub fn get_onpointerout(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onpointerout(state);
    }

    pub fn set_onpointerout(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onpointerout(state, value);
    }

    pub fn get_onpointerleave(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onpointerleave(state);
    }

    pub fn set_onpointerleave(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onpointerleave(state, value);
    }

    pub fn get_ongotpointercapture(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_ongotpointercapture(state);
    }

    pub fn set_ongotpointercapture(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_ongotpointercapture(state, value);
    }

    pub fn get_onlostpointercapture(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onlostpointercapture(state);
    }

    pub fn set_onlostpointercapture(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onlostpointercapture(state, value);
    }

    pub fn get_ontouchstart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_ontouchstart(state);
    }

    pub fn set_ontouchstart(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_ontouchstart(state, value);
    }

    pub fn get_ontouchend(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_ontouchend(state);
    }

    pub fn set_ontouchend(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_ontouchend(state, value);
    }

    pub fn get_ontouchmove(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_ontouchmove(state);
    }

    pub fn set_ontouchmove(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_ontouchmove(state, value);
    }

    pub fn get_ontouchcancel(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_ontouchcancel(state);
    }

    pub fn set_ontouchcancel(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_ontouchcancel(state, value);
    }

    pub fn get_onfencedtreeclick(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onfencedtreeclick(state);
    }

    pub fn set_onfencedtreeclick(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onfencedtreeclick(state, value);
    }

    pub fn get_onsnapchanged(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onsnapchanged(state);
    }

    pub fn set_onsnapchanged(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onsnapchanged(state, value);
    }

    pub fn get_onsnapchanging(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.get_onsnapchanging(state);
    }

    pub fn set_onsnapchanging(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLDocumentImpl.set_onsnapchanging(state, value);
    }

    pub fn call_isDefaultNamespace(instance: *runtime.Instance, namespace: anyopaque) bool {
        const state = instance.getState(State);
        
        return XMLDocumentImpl.call_isDefaultNamespace(state, namespace);
    }

    pub fn call_exitPointerLock(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.call_exitPointerLock(state);
    }

    pub fn call_queryCommandState(instance: *runtime.Instance, commandId: runtime.DOMString) bool {
        const state = instance.getState(State);
        
        return XMLDocumentImpl.call_queryCommandState(state, commandId);
    }

    pub fn call_parseHTMLUnsafe(instance: *runtime.Instance, html: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XMLDocumentImpl.call_parseHTMLUnsafe(state, html);
    }

    pub fn call_contains(instance: *runtime.Instance, other: anyopaque) bool {
        const state = instance.getState(State);
        
        return XMLDocumentImpl.call_contains(state, other);
    }

    /// Extended attributes: [NewObject]
    pub fn call_exitPictureInPicture(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return XMLDocumentImpl.call_exitPictureInPicture(state);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createExpression(instance: *runtime.Instance, expression: runtime.DOMString, resolver: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return XMLDocumentImpl.call_createExpression(state, expression, resolver);
    }

    pub fn call_elementFromPoint(instance: *runtime.Instance, x: f64, y: f64) anyopaque {
        const state = instance.getState(State);
        
        return XMLDocumentImpl.call_elementFromPoint(state, x, y);
    }

    pub fn call_getRootNode(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XMLDocumentImpl.call_getRootNode(state, options);
    }

    /// Extended attributes: [CEReactions], [NewObject]
    pub fn call_createElement(instance: *runtime.Instance, localName: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        // [NewObject] - Caller owns the returned object
        
        return XMLDocumentImpl.call_createElement(state, localName, options);
    }

    pub fn call_releaseEvents(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.call_releaseEvents(state);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_prepend(instance: *runtime.Instance, nodes: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return XMLDocumentImpl.call_prepend(state, nodes);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return XMLDocumentImpl.call_dispatchEvent(state, event);
    }

    pub fn call_convertQuadFromNode(instance: *runtime.Instance, quad: anyopaque, from: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XMLDocumentImpl.call_convertQuadFromNode(state, quad, from, options);
    }

    pub fn call_queryCommandSupported(instance: *runtime.Instance, commandId: runtime.DOMString) bool {
        const state = instance.getState(State);
        
        return XMLDocumentImpl.call_queryCommandSupported(state, commandId);
    }

    pub fn call_hasPrivateToken(instance: *runtime.Instance, issuer: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return XMLDocumentImpl.call_hasPrivateToken(state, issuer);
    }

    pub fn call_requestStorageAccessFor(instance: *runtime.Instance, requestedOrigin: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return XMLDocumentImpl.call_requestStorageAccessFor(state, requestedOrigin);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XMLDocumentImpl.call_when(state, type_, options);
    }

    /// Arguments for open (WebIDL overloading)
    pub const OpenArgs = union(enum) {
        /// open(unused1, unused2)
        string_string: struct {
            unused1: runtime.DOMString,
            unused2: runtime.DOMString,
        },
        /// open(url, name, features)
        USVString_string_string: struct {
            url: runtime.USVString,
            name: runtime.DOMString,
            features: runtime.DOMString,
        },
    };

    pub fn call_open(instance: *runtime.Instance, args: OpenArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .string_string => |a| return XMLDocumentImpl.string_string(state, a.unused1, a.unused2),
            .USVString_string_string => |a| return XMLDocumentImpl.USVString_string_string(state, a.url, a.name, a.features),
        }
    }

    pub fn call_hasUnpartitionedCookieAccess(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.call_hasUnpartitionedCookieAccess(state);
    }

    pub fn call_hasRedemptionRecord(instance: *runtime.Instance, issuer: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return XMLDocumentImpl.call_hasRedemptionRecord(state, issuer);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_insertBefore(instance: *runtime.Instance, node: anyopaque, child: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return XMLDocumentImpl.call_insertBefore(state, node, child);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_execCommand(instance: *runtime.Instance, commandId: runtime.DOMString, showUI: bool, value: runtime.DOMString) bool {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return XMLDocumentImpl.call_execCommand(state, commandId, showUI, value);
    }

    pub fn call_measureElement(instance: *runtime.Instance, element: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XMLDocumentImpl.call_measureElement(state, element);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_write(instance: *runtime.Instance, text: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return XMLDocumentImpl.call_write(state, text);
    }

    pub fn call_lookupNamespaceURI(instance: *runtime.Instance, prefix: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XMLDocumentImpl.call_lookupNamespaceURI(state, prefix);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createAttribute(instance: *runtime.Instance, localName: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return XMLDocumentImpl.call_createAttribute(state, localName);
    }

    pub fn call_queryCommandIndeterm(instance: *runtime.Instance, commandId: runtime.DOMString) bool {
        const state = instance.getState(State);
        
        return XMLDocumentImpl.call_queryCommandIndeterm(state, commandId);
    }

    pub fn call_getElementsByTagNameNS(instance: *runtime.Instance, namespace: anyopaque, localName: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return XMLDocumentImpl.call_getElementsByTagNameNS(state, namespace, localName);
    }

    pub fn call_clear(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.call_clear(state);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createProcessingInstruction(instance: *runtime.Instance, target: runtime.DOMString, data: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return XMLDocumentImpl.call_createProcessingInstruction(state, target, data);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createEvent(instance: *runtime.Instance, interface: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return XMLDocumentImpl.call_createEvent(state, interface);
    }

    pub fn call_elementsFromPoint(instance: *runtime.Instance, x: f64, y: f64) anyopaque {
        const state = instance.getState(State);
        
        return XMLDocumentImpl.call_elementsFromPoint(state, x, y);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_removeChild(instance: *runtime.Instance, child: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return XMLDocumentImpl.call_removeChild(state, child);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_replaceChildren(instance: *runtime.Instance, nodes: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return XMLDocumentImpl.call_replaceChildren(state, nodes);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_normalize(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        return XMLDocumentImpl.call_normalize(state);
    }

    pub fn call_isEqualNode(instance: *runtime.Instance, otherNode: anyopaque) bool {
        const state = instance.getState(State);
        
        return XMLDocumentImpl.call_isEqualNode(state, otherNode);
    }

    pub fn call_getBoxQuads(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XMLDocumentImpl.call_getBoxQuads(state, options);
    }

    pub fn call_convertPointFromNode(instance: *runtime.Instance, point: anyopaque, from: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XMLDocumentImpl.call_convertPointFromNode(state, point, from, options);
    }

    pub fn call_getAnimations(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.call_getAnimations(state);
    }

    pub fn call_getElementsByClassName(instance: *runtime.Instance, classNames: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return XMLDocumentImpl.call_getElementsByClassName(state, classNames);
    }

    pub fn call_getElementsByTagName(instance: *runtime.Instance, qualifiedName: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return XMLDocumentImpl.call_getElementsByTagName(state, qualifiedName);
    }

    pub fn call_evaluate(instance: *runtime.Instance, expression: runtime.DOMString, contextNode: anyopaque, resolver: anyopaque, type_: u16, result: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XMLDocumentImpl.call_evaluate(state, expression, contextNode, resolver, type_, result);
    }

    pub fn call_querySelector(instance: *runtime.Instance, selectors: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return XMLDocumentImpl.call_querySelector(state, selectors);
    }

    pub fn call_hasStorageAccess(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.call_hasStorageAccess(state);
    }

    pub fn call_compareDocumentPosition(instance: *runtime.Instance, other: anyopaque) u16 {
        const state = instance.getState(State);
        
        return XMLDocumentImpl.call_compareDocumentPosition(state, other);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createCDATASection(instance: *runtime.Instance, data: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return XMLDocumentImpl.call_createCDATASection(state, data);
    }

    /// Extended attributes: [CEReactions], [NewObject]
    pub fn call_importNode(instance: *runtime.Instance, node: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        // [NewObject] - Caller owns the returned object
        
        return XMLDocumentImpl.call_importNode(state, node, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createRange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return XMLDocumentImpl.call_createRange(state);
    }

    pub fn call_queryCommandEnabled(instance: *runtime.Instance, commandId: runtime.DOMString) bool {
        const state = instance.getState(State);
        
        return XMLDocumentImpl.call_queryCommandEnabled(state, commandId);
    }

    pub fn call_getElementById(instance: *runtime.Instance, elementId: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return XMLDocumentImpl.call_getElementById(state, elementId);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createAttributeNS(instance: *runtime.Instance, namespace: anyopaque, qualifiedName: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return XMLDocumentImpl.call_createAttributeNS(state, namespace, qualifiedName);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XMLDocumentImpl.call_removeEventListener(state, type_, callback, options);
    }

    pub fn call_exitFullscreen(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.call_exitFullscreen(state);
    }

    /// Extended attributes: [CEReactions], [NewObject]
    pub fn call_cloneNode(instance: *runtime.Instance, subtree: bool) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        // [NewObject] - Caller owns the returned object
        
        return XMLDocumentImpl.call_cloneNode(state, subtree);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createTextNode(instance: *runtime.Instance, data: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return XMLDocumentImpl.call_createTextNode(state, data);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_adoptNode(instance: *runtime.Instance, node: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return XMLDocumentImpl.call_adoptNode(state, node);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createTreeWalker(instance: *runtime.Instance, root: anyopaque, whatToShow: u32, filter: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return XMLDocumentImpl.call_createTreeWalker(state, root, whatToShow, filter);
    }

    pub fn call_getElementsByName(instance: *runtime.Instance, elementName: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return XMLDocumentImpl.call_getElementsByName(state, elementName);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_writeln(instance: *runtime.Instance, text: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return XMLDocumentImpl.call_writeln(state, text);
    }

    pub fn call_hasFocus(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return XMLDocumentImpl.call_hasFocus(state);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_append(instance: *runtime.Instance, nodes: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return XMLDocumentImpl.call_append(state, nodes);
    }

    pub fn call_queryCommandValue(instance: *runtime.Instance, commandId: runtime.DOMString) runtime.DOMString {
        const state = instance.getState(State);
        
        return XMLDocumentImpl.call_queryCommandValue(state, commandId);
    }

    pub fn call_caretPositionFromPoint(instance: *runtime.Instance, x: f64, y: f64, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XMLDocumentImpl.call_caretPositionFromPoint(state, x, y, options);
    }

    pub fn call_isSameNode(instance: *runtime.Instance, otherNode: anyopaque) bool {
        const state = instance.getState(State);
        
        return XMLDocumentImpl.call_isSameNode(state, otherNode);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_moveBefore(instance: *runtime.Instance, node: anyopaque, child: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return XMLDocumentImpl.call_moveBefore(state, node, child);
    }

    pub fn call_convertRectFromNode(instance: *runtime.Instance, rect: anyopaque, from: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XMLDocumentImpl.call_convertRectFromNode(state, rect, from, options);
    }

    pub fn call_startViewTransition(instance: *runtime.Instance, callbackOptions: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XMLDocumentImpl.call_startViewTransition(state, callbackOptions);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createComment(instance: *runtime.Instance, data: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return XMLDocumentImpl.call_createComment(state, data);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createDocumentFragment(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return XMLDocumentImpl.call_createDocumentFragment(state);
    }

    pub fn call_lookupPrefix(instance: *runtime.Instance, namespace: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XMLDocumentImpl.call_lookupPrefix(state, namespace);
    }

    pub fn call_getSelection(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.call_getSelection(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_close(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        return XMLDocumentImpl.call_close(state);
    }

    /// Arguments for requestStorageAccess (WebIDL overloading)
    pub const RequestStorageAccessArgs = union(enum) {
        /// requestStorageAccess()
        no_params: void,
        /// requestStorageAccess(types)
        StorageAccessTypes: anyopaque,
    };

    pub fn call_requestStorageAccess(instance: *runtime.Instance, args: RequestStorageAccessArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .no_params => return XMLDocumentImpl.no_params(state),
            .StorageAccessTypes => |arg| return XMLDocumentImpl.StorageAccessTypes(state, arg),
        }
    }

    /// Extended attributes: [CEReactions]
    pub fn call_appendChild(instance: *runtime.Instance, node: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return XMLDocumentImpl.call_appendChild(state, node);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XMLDocumentImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_hasChildNodes(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return XMLDocumentImpl.call_hasChildNodes(state);
    }

    /// Extended attributes: [CEReactions], [NewObject]
    pub fn call_createElementNS(instance: *runtime.Instance, namespace: anyopaque, qualifiedName: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        // [NewObject] - Caller owns the returned object
        
        return XMLDocumentImpl.call_createElementNS(state, namespace, qualifiedName, options);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_replaceChild(instance: *runtime.Instance, node: anyopaque, child: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return XMLDocumentImpl.call_replaceChild(state, node, child);
    }

    pub fn call_captureEvents(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLDocumentImpl.call_captureEvents(state);
    }

    /// Extended attributes: [NewObject]
    pub fn call_querySelectorAll(instance: *runtime.Instance, selectors: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return XMLDocumentImpl.call_querySelectorAll(state, selectors);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_browsingTopics(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XMLDocumentImpl.call_browsingTopics(state, options);
    }

    pub fn call_createNSResolver(instance: *runtime.Instance, nodeResolver: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XMLDocumentImpl.call_createNSResolver(state, nodeResolver);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createNodeIterator(instance: *runtime.Instance, root: anyopaque, whatToShow: u32, filter: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return XMLDocumentImpl.call_createNodeIterator(state, root, whatToShow, filter);
    }

    pub fn call_measureText(instance: *runtime.Instance, text: runtime.DOMString, styleMap: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XMLDocumentImpl.call_measureText(state, text, styleMap);
    }

};
