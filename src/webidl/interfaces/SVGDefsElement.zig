//! Generated from: SVG.idl
//! Generated at: 2025-11-18T18:28:13Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SVGDefsElementImpl = @import("impls").SVGDefsElement;
const SVGGraphicsElement = @import("interfaces").SVGGraphicsElement;

pub const SVGDefsElement = struct {
    pub const Meta = struct {
        pub const name = "SVGDefsElement";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *SVGGraphicsElement;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(SVGDefsElement, .{
        .deinit_fn = &deinit_wrapper,

        .get_ATTRIBUTE_NODE = &SVGGraphicsElement.get_ATTRIBUTE_NODE,
        .get_CDATA_SECTION_NODE = &SVGGraphicsElement.get_CDATA_SECTION_NODE,
        .get_COMMENT_NODE = &SVGGraphicsElement.get_COMMENT_NODE,
        .get_DOCUMENT_FRAGMENT_NODE = &SVGGraphicsElement.get_DOCUMENT_FRAGMENT_NODE,
        .get_DOCUMENT_NODE = &SVGGraphicsElement.get_DOCUMENT_NODE,
        .get_DOCUMENT_POSITION_CONTAINED_BY = &SVGGraphicsElement.get_DOCUMENT_POSITION_CONTAINED_BY,
        .get_DOCUMENT_POSITION_CONTAINS = &SVGGraphicsElement.get_DOCUMENT_POSITION_CONTAINS,
        .get_DOCUMENT_POSITION_DISCONNECTED = &SVGGraphicsElement.get_DOCUMENT_POSITION_DISCONNECTED,
        .get_DOCUMENT_POSITION_FOLLOWING = &SVGGraphicsElement.get_DOCUMENT_POSITION_FOLLOWING,
        .get_DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC = &SVGGraphicsElement.get_DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC,
        .get_DOCUMENT_POSITION_PRECEDING = &SVGGraphicsElement.get_DOCUMENT_POSITION_PRECEDING,
        .get_DOCUMENT_TYPE_NODE = &SVGGraphicsElement.get_DOCUMENT_TYPE_NODE,
        .get_ELEMENT_NODE = &SVGGraphicsElement.get_ELEMENT_NODE,
        .get_ENTITY_NODE = &SVGGraphicsElement.get_ENTITY_NODE,
        .get_ENTITY_REFERENCE_NODE = &SVGGraphicsElement.get_ENTITY_REFERENCE_NODE,
        .get_NOTATION_NODE = &SVGGraphicsElement.get_NOTATION_NODE,
        .get_PROCESSING_INSTRUCTION_NODE = &SVGGraphicsElement.get_PROCESSING_INSTRUCTION_NODE,
        .get_TEXT_NODE = &SVGGraphicsElement.get_TEXT_NODE,
        .get_activeViewTransition = &get_activeViewTransition,
        .get_ariaActiveDescendantElement = &get_ariaActiveDescendantElement,
        .get_ariaAtomic = &get_ariaAtomic,
        .get_ariaAutoComplete = &get_ariaAutoComplete,
        .get_ariaBrailleLabel = &get_ariaBrailleLabel,
        .get_ariaBrailleRoleDescription = &get_ariaBrailleRoleDescription,
        .get_ariaBusy = &get_ariaBusy,
        .get_ariaChecked = &get_ariaChecked,
        .get_ariaColCount = &get_ariaColCount,
        .get_ariaColIndex = &get_ariaColIndex,
        .get_ariaColIndexText = &get_ariaColIndexText,
        .get_ariaColSpan = &get_ariaColSpan,
        .get_ariaControlsElements = &get_ariaControlsElements,
        .get_ariaCurrent = &get_ariaCurrent,
        .get_ariaDescribedByElements = &get_ariaDescribedByElements,
        .get_ariaDescription = &get_ariaDescription,
        .get_ariaDetailsElements = &get_ariaDetailsElements,
        .get_ariaDisabled = &get_ariaDisabled,
        .get_ariaErrorMessageElements = &get_ariaErrorMessageElements,
        .get_ariaExpanded = &get_ariaExpanded,
        .get_ariaFlowToElements = &get_ariaFlowToElements,
        .get_ariaHasPopup = &get_ariaHasPopup,
        .get_ariaHidden = &get_ariaHidden,
        .get_ariaInvalid = &get_ariaInvalid,
        .get_ariaKeyShortcuts = &get_ariaKeyShortcuts,
        .get_ariaLabel = &get_ariaLabel,
        .get_ariaLabelledByElements = &get_ariaLabelledByElements,
        .get_ariaLevel = &get_ariaLevel,
        .get_ariaLive = &get_ariaLive,
        .get_ariaModal = &get_ariaModal,
        .get_ariaMultiLine = &get_ariaMultiLine,
        .get_ariaMultiSelectable = &get_ariaMultiSelectable,
        .get_ariaOrientation = &get_ariaOrientation,
        .get_ariaOwnsElements = &get_ariaOwnsElements,
        .get_ariaPlaceholder = &get_ariaPlaceholder,
        .get_ariaPosInSet = &get_ariaPosInSet,
        .get_ariaPressed = &get_ariaPressed,
        .get_ariaReadOnly = &get_ariaReadOnly,
        .get_ariaRelevant = &get_ariaRelevant,
        .get_ariaRequired = &get_ariaRequired,
        .get_ariaRoleDescription = &get_ariaRoleDescription,
        .get_ariaRowCount = &get_ariaRowCount,
        .get_ariaRowIndex = &get_ariaRowIndex,
        .get_ariaRowIndexText = &get_ariaRowIndexText,
        .get_ariaRowSpan = &get_ariaRowSpan,
        .get_ariaSelected = &get_ariaSelected,
        .get_ariaSetSize = &get_ariaSetSize,
        .get_ariaSort = &get_ariaSort,
        .get_ariaValueMax = &get_ariaValueMax,
        .get_ariaValueMin = &get_ariaValueMin,
        .get_ariaValueNow = &get_ariaValueNow,
        .get_ariaValueText = &get_ariaValueText,
        .get_assignedSlot = &get_assignedSlot,
        .get_attributeStyleMap = &get_attributeStyleMap,
        .get_attributes = &get_attributes,
        .get_autofocus = &get_autofocus,
        .get_baseURI = &get_baseURI,
        .get_childElementCount = &get_childElementCount,
        .get_childNodes = &get_childNodes,
        .get_children = &get_children,
        .get_classList = &get_classList,
        .get_className = &get_className,
        .get_className = &get_className,
        .get_clientHeight = &get_clientHeight,
        .get_clientLeft = &get_clientLeft,
        .get_clientTop = &get_clientTop,
        .get_clientWidth = &get_clientWidth,
        .get_correspondingElement = &get_correspondingElement,
        .get_correspondingUseElement = &get_correspondingUseElement,
        .get_currentCSSZoom = &get_currentCSSZoom,
        .get_customElementRegistry = &get_customElementRegistry,
        .get_dataset = &get_dataset,
        .get_elementTiming = &get_elementTiming,
        .get_firstChild = &get_firstChild,
        .get_firstElementChild = &get_firstElementChild,
        .get_id = &get_id,
        .get_innerHTML = &get_innerHTML,
        .get_isConnected = &get_isConnected,
        .get_lastChild = &get_lastChild,
        .get_lastElementChild = &get_lastElementChild,
        .get_localName = &get_localName,
        .get_namespaceURI = &get_namespaceURI,
        .get_nextElementSibling = &get_nextElementSibling,
        .get_nextSibling = &get_nextSibling,
        .get_nodeName = &get_nodeName,
        .get_nodeType = &get_nodeType,
        .get_nodeValue = &get_nodeValue,
        .get_nonce = &get_nonce,
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
        .get_outerHTML = &get_outerHTML,
        .get_ownerDocument = &get_ownerDocument,
        .get_ownerSVGElement = &get_ownerSVGElement,
        .get_parentElement = &get_parentElement,
        .get_parentNode = &get_parentNode,
        .get_part = &get_part,
        .get_prefix = &get_prefix,
        .get_previousElementSibling = &get_previousElementSibling,
        .get_previousSibling = &get_previousSibling,
        .get_regionOverset = &get_regionOverset,
        .get_requiredExtensions = &get_requiredExtensions,
        .get_role = &get_role,
        .get_scrollHeight = &get_scrollHeight,
        .get_scrollLeft = &get_scrollLeft,
        .get_scrollTop = &get_scrollTop,
        .get_scrollWidth = &get_scrollWidth,
        .get_shadowRoot = &get_shadowRoot,
        .get_slot = &get_slot,
        .get_style = &get_style,
        .get_style = &get_style,
        .get_systemLanguage = &get_systemLanguage,
        .get_tabIndex = &get_tabIndex,
        .get_tagName = &get_tagName,
        .get_textContent = &get_textContent,
        .get_transform = &get_transform,
        .get_viewportElement = &get_viewportElement,

        .set_ariaActiveDescendantElement = &set_ariaActiveDescendantElement,
        .set_ariaAtomic = &set_ariaAtomic,
        .set_ariaAutoComplete = &set_ariaAutoComplete,
        .set_ariaBrailleLabel = &set_ariaBrailleLabel,
        .set_ariaBrailleRoleDescription = &set_ariaBrailleRoleDescription,
        .set_ariaBusy = &set_ariaBusy,
        .set_ariaChecked = &set_ariaChecked,
        .set_ariaColCount = &set_ariaColCount,
        .set_ariaColIndex = &set_ariaColIndex,
        .set_ariaColIndexText = &set_ariaColIndexText,
        .set_ariaColSpan = &set_ariaColSpan,
        .set_ariaControlsElements = &set_ariaControlsElements,
        .set_ariaCurrent = &set_ariaCurrent,
        .set_ariaDescribedByElements = &set_ariaDescribedByElements,
        .set_ariaDescription = &set_ariaDescription,
        .set_ariaDetailsElements = &set_ariaDetailsElements,
        .set_ariaDisabled = &set_ariaDisabled,
        .set_ariaErrorMessageElements = &set_ariaErrorMessageElements,
        .set_ariaExpanded = &set_ariaExpanded,
        .set_ariaFlowToElements = &set_ariaFlowToElements,
        .set_ariaHasPopup = &set_ariaHasPopup,
        .set_ariaHidden = &set_ariaHidden,
        .set_ariaInvalid = &set_ariaInvalid,
        .set_ariaKeyShortcuts = &set_ariaKeyShortcuts,
        .set_ariaLabel = &set_ariaLabel,
        .set_ariaLabelledByElements = &set_ariaLabelledByElements,
        .set_ariaLevel = &set_ariaLevel,
        .set_ariaLive = &set_ariaLive,
        .set_ariaModal = &set_ariaModal,
        .set_ariaMultiLine = &set_ariaMultiLine,
        .set_ariaMultiSelectable = &set_ariaMultiSelectable,
        .set_ariaOrientation = &set_ariaOrientation,
        .set_ariaOwnsElements = &set_ariaOwnsElements,
        .set_ariaPlaceholder = &set_ariaPlaceholder,
        .set_ariaPosInSet = &set_ariaPosInSet,
        .set_ariaPressed = &set_ariaPressed,
        .set_ariaReadOnly = &set_ariaReadOnly,
        .set_ariaRelevant = &set_ariaRelevant,
        .set_ariaRequired = &set_ariaRequired,
        .set_ariaRoleDescription = &set_ariaRoleDescription,
        .set_ariaRowCount = &set_ariaRowCount,
        .set_ariaRowIndex = &set_ariaRowIndex,
        .set_ariaRowIndexText = &set_ariaRowIndexText,
        .set_ariaRowSpan = &set_ariaRowSpan,
        .set_ariaSelected = &set_ariaSelected,
        .set_ariaSetSize = &set_ariaSetSize,
        .set_ariaSort = &set_ariaSort,
        .set_ariaValueMax = &set_ariaValueMax,
        .set_ariaValueMin = &set_ariaValueMin,
        .set_ariaValueNow = &set_ariaValueNow,
        .set_ariaValueText = &set_ariaValueText,
        .set_autofocus = &set_autofocus,
        .set_className = &set_className,
        .set_elementTiming = &set_elementTiming,
        .set_id = &set_id,
        .set_innerHTML = &set_innerHTML,
        .set_nodeValue = &set_nodeValue,
        .set_nonce = &set_nonce,
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
        .set_outerHTML = &set_outerHTML,
        .set_role = &set_role,
        .set_scrollLeft = &set_scrollLeft,
        .set_scrollTop = &set_scrollTop,
        .set_slot = &set_slot,
        .set_tabIndex = &set_tabIndex,
        .set_textContent = &set_textContent,

        .call_addEventListener = &call_addEventListener,
        .call_after = &call_after,
        .call_animate = &call_animate,
        .call_append = &call_append,
        .call_appendChild = &call_appendChild,
        .call_attachShadow = &call_attachShadow,
        .call_before = &call_before,
        .call_blur = &call_blur,
        .call_checkVisibility = &call_checkVisibility,
        .call_cloneNode = &call_cloneNode,
        .call_closest = &call_closest,
        .call_compareDocumentPosition = &call_compareDocumentPosition,
        .call_computedStyleMap = &call_computedStyleMap,
        .call_contains = &call_contains,
        .call_convertPointFromNode = &call_convertPointFromNode,
        .call_convertQuadFromNode = &call_convertQuadFromNode,
        .call_convertRectFromNode = &call_convertRectFromNode,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_focus = &call_focus,
        .call_focusableAreas = &call_focusableAreas,
        .call_getAnimations = &call_getAnimations,
        .call_getAttribute = &call_getAttribute,
        .call_getAttributeNS = &call_getAttributeNS,
        .call_getAttributeNames = &call_getAttributeNames,
        .call_getAttributeNode = &call_getAttributeNode,
        .call_getAttributeNodeNS = &call_getAttributeNodeNS,
        .call_getBBox = &call_getBBox,
        .call_getBoundingClientRect = &call_getBoundingClientRect,
        .call_getBoxQuads = &call_getBoxQuads,
        .call_getCTM = &call_getCTM,
        .call_getClientRects = &call_getClientRects,
        .call_getElementsByClassName = &call_getElementsByClassName,
        .call_getElementsByTagName = &call_getElementsByTagName,
        .call_getElementsByTagNameNS = &call_getElementsByTagNameNS,
        .call_getHTML = &call_getHTML,
        .call_getRegionFlowRanges = &call_getRegionFlowRanges,
        .call_getRootNode = &call_getRootNode,
        .call_getScreenCTM = &call_getScreenCTM,
        .call_getSpatialNavigationContainer = &call_getSpatialNavigationContainer,
        .call_hasAttribute = &call_hasAttribute,
        .call_hasAttributeNS = &call_hasAttributeNS,
        .call_hasAttributes = &call_hasAttributes,
        .call_hasChildNodes = &call_hasChildNodes,
        .call_hasPointerCapture = &call_hasPointerCapture,
        .call_insertAdjacentElement = &call_insertAdjacentElement,
        .call_insertAdjacentHTML = &call_insertAdjacentHTML,
        .call_insertAdjacentText = &call_insertAdjacentText,
        .call_insertBefore = &call_insertBefore,
        .call_isDefaultNamespace = &call_isDefaultNamespace,
        .call_isEqualNode = &call_isEqualNode,
        .call_isSameNode = &call_isSameNode,
        .call_lookupNamespaceURI = &call_lookupNamespaceURI,
        .call_lookupPrefix = &call_lookupPrefix,
        .call_matches = &call_matches,
        .call_moveBefore = &call_moveBefore,
        .call_normalize = &call_normalize,
        .call_prepend = &call_prepend,
        .call_pseudo = &call_pseudo,
        .call_querySelector = &call_querySelector,
        .call_querySelectorAll = &call_querySelectorAll,
        .call_releasePointerCapture = &call_releasePointerCapture,
        .call_remove = &call_remove,
        .call_removeAttribute = &call_removeAttribute,
        .call_removeAttributeNS = &call_removeAttributeNS,
        .call_removeAttributeNode = &call_removeAttributeNode,
        .call_removeChild = &call_removeChild,
        .call_removeEventListener = &call_removeEventListener,
        .call_replaceChild = &call_replaceChild,
        .call_replaceChildren = &call_replaceChildren,
        .call_replaceWith = &call_replaceWith,
        .call_requestFullscreen = &call_requestFullscreen,
        .call_requestPointerLock = &call_requestPointerLock,
        .call_scroll = &call_scroll,
        .call_scrollBy = &call_scrollBy,
        .call_scrollIntoView = &call_scrollIntoView,
        .call_scrollTo = &call_scrollTo,
        .call_setAttribute = &call_setAttribute,
        .call_setAttributeNS = &call_setAttributeNS,
        .call_setAttributeNode = &call_setAttributeNode,
        .call_setAttributeNodeNS = &call_setAttributeNodeNS,
        .call_setHTMLUnsafe = &call_setHTMLUnsafe,
        .call_setPointerCapture = &call_setPointerCapture,
        .call_spatialNavigationSearch = &call_spatialNavigationSearch,
        .call_startViewTransition = &call_startViewTransition,
        .call_toggleAttribute = &call_toggleAttribute,
        .call_webkitMatchesSelector = &call_webkitMatchesSelector,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        SVGDefsElementImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SVGDefsElementImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_nodeType(instance: *runtime.Instance) anyerror!u16 {
        return try SVGDefsElementImpl.get_nodeType(instance);
    }

    pub fn get_nodeName(instance: *runtime.Instance) anyerror!DOMString {
        return try SVGDefsElementImpl.get_nodeName(instance);
    }

    pub fn get_baseURI(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try SVGDefsElementImpl.get_baseURI(instance);
    }

    pub fn get_isConnected(instance: *runtime.Instance) anyerror!bool {
        return try SVGDefsElementImpl.get_isConnected(instance);
    }

    pub fn get_ownerDocument(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ownerDocument(instance);
    }

    pub fn get_parentNode(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_parentNode(instance);
    }

    pub fn get_parentElement(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_parentElement(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_childNodes(instance: *runtime.Instance) anyerror!NodeList {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_childNodes) |cached| {
            return cached;
        }
        const value = try SVGDefsElementImpl.get_childNodes(instance);
        state.cached_childNodes = value;
        return value;
    }

    pub fn get_firstChild(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_firstChild(instance);
    }

    pub fn get_lastChild(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_lastChild(instance);
    }

    pub fn get_previousSibling(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_previousSibling(instance);
    }

    pub fn get_nextSibling(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_nextSibling(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_nodeValue(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_nodeValue(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_nodeValue(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_nodeValue(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_textContent(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_textContent(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_textContent(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_textContent(instance, value);
    }

    pub fn get_namespaceURI(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_namespaceURI(instance);
    }

    pub fn get_prefix(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_prefix(instance);
    }

    pub fn get_localName(instance: *runtime.Instance) anyerror!DOMString {
        return try SVGDefsElementImpl.get_localName(instance);
    }

    pub fn get_tagName(instance: *runtime.Instance) anyerror!DOMString {
        return try SVGDefsElementImpl.get_tagName(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_id(instance: *runtime.Instance) anyerror!DOMString {
        return try SVGDefsElementImpl.get_id(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_id(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_id(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_className(instance: *runtime.Instance) anyerror!DOMString {
        return try SVGDefsElementImpl.get_className(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_className(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_className(instance, value);
    }

    /// Extended attributes: [SameObject], [PutForwards=value]
    pub fn get_classList(instance: *runtime.Instance) anyerror!DOMTokenList {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_classList) |cached| {
            return cached;
        }
        const value = try SVGDefsElementImpl.get_classList(instance);
        state.cached_classList = value;
        return value;
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn get_slot(instance: *runtime.Instance) anyerror!DOMString {
        return try SVGDefsElementImpl.get_slot(instance);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn set_slot(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_slot(instance, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_attributes(instance: *runtime.Instance) anyerror!NamedNodeMap {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_attributes) |cached| {
            return cached;
        }
        const value = try SVGDefsElementImpl.get_attributes(instance);
        state.cached_attributes = value;
        return value;
    }

    pub fn get_shadowRoot(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_shadowRoot(instance);
    }

    pub fn get_customElementRegistry(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_customElementRegistry(instance);
    }

    pub fn get_onfullscreenchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onfullscreenchange(instance);
    }

    pub fn set_onfullscreenchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onfullscreenchange(instance, value);
    }

    pub fn get_onfullscreenerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onfullscreenerror(instance);
    }

    pub fn set_onfullscreenerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onfullscreenerror(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_elementTiming(instance: *runtime.Instance) anyerror!DOMString {
        return try SVGDefsElementImpl.get_elementTiming(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_elementTiming(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_elementTiming(instance, value);
    }

    /// Extended attributes: [SameObject], [PutForwards=value]
    pub fn get_part(instance: *runtime.Instance) anyerror!DOMTokenList {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_part) |cached| {
            return cached;
        }
        const value = try SVGDefsElementImpl.get_part(instance);
        state.cached_part = value;
        return value;
    }

    pub fn get_activeViewTransition(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_activeViewTransition(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_innerHTML(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_innerHTML(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_innerHTML(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_innerHTML(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_outerHTML(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_outerHTML(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_outerHTML(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_outerHTML(instance, value);
    }

    pub fn get_scrollTop(instance: *runtime.Instance) anyerror!f64 {
        return try SVGDefsElementImpl.get_scrollTop(instance);
    }

    pub fn set_scrollTop(instance: *runtime.Instance, value: f64) anyerror!void {
        try SVGDefsElementImpl.set_scrollTop(instance, value);
    }

    pub fn get_scrollLeft(instance: *runtime.Instance) anyerror!f64 {
        return try SVGDefsElementImpl.get_scrollLeft(instance);
    }

    pub fn set_scrollLeft(instance: *runtime.Instance, value: f64) anyerror!void {
        try SVGDefsElementImpl.set_scrollLeft(instance, value);
    }

    pub fn get_scrollWidth(instance: *runtime.Instance) anyerror!i32 {
        return try SVGDefsElementImpl.get_scrollWidth(instance);
    }

    pub fn get_scrollHeight(instance: *runtime.Instance) anyerror!i32 {
        return try SVGDefsElementImpl.get_scrollHeight(instance);
    }

    pub fn get_clientTop(instance: *runtime.Instance) anyerror!i32 {
        return try SVGDefsElementImpl.get_clientTop(instance);
    }

    pub fn get_clientLeft(instance: *runtime.Instance) anyerror!i32 {
        return try SVGDefsElementImpl.get_clientLeft(instance);
    }

    pub fn get_clientWidth(instance: *runtime.Instance) anyerror!i32 {
        return try SVGDefsElementImpl.get_clientWidth(instance);
    }

    pub fn get_clientHeight(instance: *runtime.Instance) anyerror!i32 {
        return try SVGDefsElementImpl.get_clientHeight(instance);
    }

    pub fn get_currentCSSZoom(instance: *runtime.Instance) anyerror!f64 {
        return try SVGDefsElementImpl.get_currentCSSZoom(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_role(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_role(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_role(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_role(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-activedescendant"]
    pub fn get_ariaActiveDescendantElement(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaActiveDescendantElement(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-activedescendant"]
    pub fn set_ariaActiveDescendantElement(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaActiveDescendantElement(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-atomic"]
    pub fn get_ariaAtomic(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaAtomic(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-atomic"]
    pub fn set_ariaAtomic(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaAtomic(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-autocomplete"]
    pub fn get_ariaAutoComplete(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaAutoComplete(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-autocomplete"]
    pub fn set_ariaAutoComplete(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaAutoComplete(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-braillelabel"]
    pub fn get_ariaBrailleLabel(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaBrailleLabel(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-braillelabel"]
    pub fn set_ariaBrailleLabel(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaBrailleLabel(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-brailleroledescription"]
    pub fn get_ariaBrailleRoleDescription(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaBrailleRoleDescription(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-brailleroledescription"]
    pub fn set_ariaBrailleRoleDescription(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaBrailleRoleDescription(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-busy"]
    pub fn get_ariaBusy(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaBusy(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-busy"]
    pub fn set_ariaBusy(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaBusy(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-checked"]
    pub fn get_ariaChecked(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaChecked(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-checked"]
    pub fn set_ariaChecked(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaChecked(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-colcount"]
    pub fn get_ariaColCount(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaColCount(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-colcount"]
    pub fn set_ariaColCount(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaColCount(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-colindex"]
    pub fn get_ariaColIndex(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaColIndex(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-colindex"]
    pub fn set_ariaColIndex(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaColIndex(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-colindextext"]
    pub fn get_ariaColIndexText(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaColIndexText(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-colindextext"]
    pub fn set_ariaColIndexText(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaColIndexText(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-colspan"]
    pub fn get_ariaColSpan(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaColSpan(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-colspan"]
    pub fn set_ariaColSpan(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaColSpan(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-controls"]
    pub fn get_ariaControlsElements(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaControlsElements(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-controls"]
    pub fn set_ariaControlsElements(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaControlsElements(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-current"]
    pub fn get_ariaCurrent(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaCurrent(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-current"]
    pub fn set_ariaCurrent(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaCurrent(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-describedby"]
    pub fn get_ariaDescribedByElements(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaDescribedByElements(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-describedby"]
    pub fn set_ariaDescribedByElements(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaDescribedByElements(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-description"]
    pub fn get_ariaDescription(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaDescription(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-description"]
    pub fn set_ariaDescription(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaDescription(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-details"]
    pub fn get_ariaDetailsElements(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaDetailsElements(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-details"]
    pub fn set_ariaDetailsElements(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaDetailsElements(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-disabled"]
    pub fn get_ariaDisabled(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaDisabled(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-disabled"]
    pub fn set_ariaDisabled(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaDisabled(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-errormessage"]
    pub fn get_ariaErrorMessageElements(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaErrorMessageElements(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-errormessage"]
    pub fn set_ariaErrorMessageElements(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaErrorMessageElements(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-expanded"]
    pub fn get_ariaExpanded(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaExpanded(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-expanded"]
    pub fn set_ariaExpanded(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaExpanded(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-flowto"]
    pub fn get_ariaFlowToElements(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaFlowToElements(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-flowto"]
    pub fn set_ariaFlowToElements(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaFlowToElements(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-haspopup"]
    pub fn get_ariaHasPopup(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaHasPopup(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-haspopup"]
    pub fn set_ariaHasPopup(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaHasPopup(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-hidden"]
    pub fn get_ariaHidden(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaHidden(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-hidden"]
    pub fn set_ariaHidden(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaHidden(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-invalid"]
    pub fn get_ariaInvalid(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaInvalid(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-invalid"]
    pub fn set_ariaInvalid(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaInvalid(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-keyshortcuts"]
    pub fn get_ariaKeyShortcuts(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaKeyShortcuts(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-keyshortcuts"]
    pub fn set_ariaKeyShortcuts(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaKeyShortcuts(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-label"]
    pub fn get_ariaLabel(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaLabel(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-label"]
    pub fn set_ariaLabel(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaLabel(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-labelledby"]
    pub fn get_ariaLabelledByElements(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaLabelledByElements(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-labelledby"]
    pub fn set_ariaLabelledByElements(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaLabelledByElements(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-level"]
    pub fn get_ariaLevel(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaLevel(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-level"]
    pub fn set_ariaLevel(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaLevel(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-live"]
    pub fn get_ariaLive(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaLive(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-live"]
    pub fn set_ariaLive(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaLive(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-modal"]
    pub fn get_ariaModal(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaModal(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-modal"]
    pub fn set_ariaModal(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaModal(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-multiline"]
    pub fn get_ariaMultiLine(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaMultiLine(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-multiline"]
    pub fn set_ariaMultiLine(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaMultiLine(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-multiselectable"]
    pub fn get_ariaMultiSelectable(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaMultiSelectable(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-multiselectable"]
    pub fn set_ariaMultiSelectable(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaMultiSelectable(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-orientation"]
    pub fn get_ariaOrientation(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaOrientation(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-orientation"]
    pub fn set_ariaOrientation(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaOrientation(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-owns"]
    pub fn get_ariaOwnsElements(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaOwnsElements(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-owns"]
    pub fn set_ariaOwnsElements(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaOwnsElements(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-placeholder"]
    pub fn get_ariaPlaceholder(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaPlaceholder(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-placeholder"]
    pub fn set_ariaPlaceholder(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaPlaceholder(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-posinset"]
    pub fn get_ariaPosInSet(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaPosInSet(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-posinset"]
    pub fn set_ariaPosInSet(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaPosInSet(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-pressed"]
    pub fn get_ariaPressed(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaPressed(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-pressed"]
    pub fn set_ariaPressed(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaPressed(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-readonly"]
    pub fn get_ariaReadOnly(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaReadOnly(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-readonly"]
    pub fn set_ariaReadOnly(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaReadOnly(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-relevant"]
    pub fn get_ariaRelevant(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaRelevant(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-relevant"]
    pub fn set_ariaRelevant(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaRelevant(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-required"]
    pub fn get_ariaRequired(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaRequired(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-required"]
    pub fn set_ariaRequired(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaRequired(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-roledescription"]
    pub fn get_ariaRoleDescription(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaRoleDescription(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-roledescription"]
    pub fn set_ariaRoleDescription(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaRoleDescription(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-rowcount"]
    pub fn get_ariaRowCount(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaRowCount(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-rowcount"]
    pub fn set_ariaRowCount(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaRowCount(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-rowindex"]
    pub fn get_ariaRowIndex(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaRowIndex(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-rowindex"]
    pub fn set_ariaRowIndex(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaRowIndex(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-rowindextext"]
    pub fn get_ariaRowIndexText(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaRowIndexText(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-rowindextext"]
    pub fn set_ariaRowIndexText(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaRowIndexText(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-rowspan"]
    pub fn get_ariaRowSpan(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaRowSpan(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-rowspan"]
    pub fn set_ariaRowSpan(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaRowSpan(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-selected"]
    pub fn get_ariaSelected(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaSelected(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-selected"]
    pub fn set_ariaSelected(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaSelected(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-setsize"]
    pub fn get_ariaSetSize(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaSetSize(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-setsize"]
    pub fn set_ariaSetSize(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaSetSize(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-sort"]
    pub fn get_ariaSort(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaSort(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-sort"]
    pub fn set_ariaSort(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaSort(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-valuemax"]
    pub fn get_ariaValueMax(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaValueMax(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-valuemax"]
    pub fn set_ariaValueMax(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaValueMax(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-valuemin"]
    pub fn get_ariaValueMin(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaValueMin(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-valuemin"]
    pub fn set_ariaValueMin(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaValueMin(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-valuenow"]
    pub fn get_ariaValueNow(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaValueNow(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-valuenow"]
    pub fn set_ariaValueNow(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaValueNow(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-valuetext"]
    pub fn get_ariaValueText(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ariaValueText(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-valuetext"]
    pub fn set_ariaValueText(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_ariaValueText(instance, value);
    }

    pub fn get_regionOverset(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_regionOverset(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_children(instance: *runtime.Instance) anyerror!HTMLCollection {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_children) |cached| {
            return cached;
        }
        const value = try SVGDefsElementImpl.get_children(instance);
        state.cached_children = value;
        return value;
    }

    pub fn get_firstElementChild(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_firstElementChild(instance);
    }

    pub fn get_lastElementChild(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_lastElementChild(instance);
    }

    pub fn get_childElementCount(instance: *runtime.Instance) anyerror!u32 {
        return try SVGDefsElementImpl.get_childElementCount(instance);
    }

    pub fn get_previousElementSibling(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_previousElementSibling(instance);
    }

    pub fn get_nextElementSibling(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_nextElementSibling(instance);
    }

    pub fn get_assignedSlot(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_assignedSlot(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_className(instance: *runtime.Instance) anyerror!SVGAnimatedString {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_className) |cached| {
            return cached;
        }
        const value = try SVGDefsElementImpl.get_className(instance);
        state.cached_className = value;
        return value;
    }

    pub fn get_ownerSVGElement(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_ownerSVGElement(instance);
    }

    pub fn get_viewportElement(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.get_viewportElement(instance);
    }

    /// Extended attributes: [SameObject], [PutForwards=cssText]
    pub fn get_style(instance: *runtime.Instance) anyerror!CSSStyleProperties {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_style) |cached| {
            return cached;
        }
        const value = try SVGDefsElementImpl.get_style(instance);
        state.cached_style = value;
        return value;
    }

    pub fn get_style(instance: *runtime.Instance) anyerror!CSSStyleDeclaration {
        return try SVGDefsElementImpl.get_style(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_attributeStyleMap(instance: *runtime.Instance) anyerror!StylePropertyMap {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_attributeStyleMap) |cached| {
            return cached;
        }
        const value = try SVGDefsElementImpl.get_attributeStyleMap(instance);
        state.cached_attributeStyleMap = value;
        return value;
    }

    pub fn get_onabort(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onabort(instance);
    }

    pub fn set_onabort(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onabort(instance, value);
    }

    pub fn get_onauxclick(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onauxclick(instance);
    }

    pub fn set_onauxclick(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onauxclick(instance, value);
    }

    pub fn get_onbeforeinput(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onbeforeinput(instance);
    }

    pub fn set_onbeforeinput(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onbeforeinput(instance, value);
    }

    pub fn get_onbeforematch(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onbeforematch(instance);
    }

    pub fn set_onbeforematch(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onbeforematch(instance, value);
    }

    pub fn get_onbeforetoggle(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onbeforetoggle(instance);
    }

    pub fn set_onbeforetoggle(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onbeforetoggle(instance, value);
    }

    pub fn get_onblur(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onblur(instance);
    }

    pub fn set_onblur(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onblur(instance, value);
    }

    pub fn get_oncancel(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_oncancel(instance);
    }

    pub fn set_oncancel(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_oncancel(instance, value);
    }

    pub fn get_oncanplay(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_oncanplay(instance);
    }

    pub fn set_oncanplay(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_oncanplay(instance, value);
    }

    pub fn get_oncanplaythrough(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_oncanplaythrough(instance);
    }

    pub fn set_oncanplaythrough(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_oncanplaythrough(instance, value);
    }

    pub fn get_onchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onchange(instance);
    }

    pub fn set_onchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onchange(instance, value);
    }

    pub fn get_onclick(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onclick(instance);
    }

    pub fn set_onclick(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onclick(instance, value);
    }

    pub fn get_onclose(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onclose(instance);
    }

    pub fn set_onclose(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onclose(instance, value);
    }

    pub fn get_oncommand(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_oncommand(instance);
    }

    pub fn set_oncommand(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_oncommand(instance, value);
    }

    pub fn get_oncontextlost(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_oncontextlost(instance);
    }

    pub fn set_oncontextlost(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_oncontextlost(instance, value);
    }

    pub fn get_oncontextmenu(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_oncontextmenu(instance);
    }

    pub fn set_oncontextmenu(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_oncontextmenu(instance, value);
    }

    pub fn get_oncontextrestored(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_oncontextrestored(instance);
    }

    pub fn set_oncontextrestored(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_oncontextrestored(instance, value);
    }

    pub fn get_oncopy(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_oncopy(instance);
    }

    pub fn set_oncopy(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_oncopy(instance, value);
    }

    pub fn get_oncuechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_oncuechange(instance);
    }

    pub fn set_oncuechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_oncuechange(instance, value);
    }

    pub fn get_oncut(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_oncut(instance);
    }

    pub fn set_oncut(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_oncut(instance, value);
    }

    pub fn get_ondblclick(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_ondblclick(instance);
    }

    pub fn set_ondblclick(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_ondblclick(instance, value);
    }

    pub fn get_ondrag(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_ondrag(instance);
    }

    pub fn set_ondrag(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_ondrag(instance, value);
    }

    pub fn get_ondragend(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_ondragend(instance);
    }

    pub fn set_ondragend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_ondragend(instance, value);
    }

    pub fn get_ondragenter(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_ondragenter(instance);
    }

    pub fn set_ondragenter(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_ondragenter(instance, value);
    }

    pub fn get_ondragleave(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_ondragleave(instance);
    }

    pub fn set_ondragleave(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_ondragleave(instance, value);
    }

    pub fn get_ondragover(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_ondragover(instance);
    }

    pub fn set_ondragover(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_ondragover(instance, value);
    }

    pub fn get_ondragstart(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_ondragstart(instance);
    }

    pub fn set_ondragstart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_ondragstart(instance, value);
    }

    pub fn get_ondrop(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_ondrop(instance);
    }

    pub fn set_ondrop(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_ondrop(instance, value);
    }

    pub fn get_ondurationchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_ondurationchange(instance);
    }

    pub fn set_ondurationchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_ondurationchange(instance, value);
    }

    pub fn get_onemptied(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onemptied(instance);
    }

    pub fn set_onemptied(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onemptied(instance, value);
    }

    pub fn get_onended(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onended(instance);
    }

    pub fn set_onended(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onended(instance, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!OnErrorEventHandler {
        return try SVGDefsElementImpl.get_onerror(instance);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: OnErrorEventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onerror(instance, value);
    }

    pub fn get_onfocus(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onfocus(instance);
    }

    pub fn set_onfocus(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onfocus(instance, value);
    }

    pub fn get_onformdata(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onformdata(instance);
    }

    pub fn set_onformdata(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onformdata(instance, value);
    }

    pub fn get_oninput(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_oninput(instance);
    }

    pub fn set_oninput(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_oninput(instance, value);
    }

    pub fn get_oninvalid(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_oninvalid(instance);
    }

    pub fn set_oninvalid(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_oninvalid(instance, value);
    }

    pub fn get_onkeydown(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onkeydown(instance);
    }

    pub fn set_onkeydown(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onkeydown(instance, value);
    }

    pub fn get_onkeypress(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onkeypress(instance);
    }

    pub fn set_onkeypress(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onkeypress(instance, value);
    }

    pub fn get_onkeyup(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onkeyup(instance);
    }

    pub fn set_onkeyup(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onkeyup(instance, value);
    }

    pub fn get_onload(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onload(instance);
    }

    pub fn set_onload(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onload(instance, value);
    }

    pub fn get_onloadeddata(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onloadeddata(instance);
    }

    pub fn set_onloadeddata(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onloadeddata(instance, value);
    }

    pub fn get_onloadedmetadata(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onloadedmetadata(instance);
    }

    pub fn set_onloadedmetadata(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onloadedmetadata(instance, value);
    }

    pub fn get_onloadstart(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onloadstart(instance);
    }

    pub fn set_onloadstart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onloadstart(instance, value);
    }

    pub fn get_onmousedown(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onmousedown(instance);
    }

    pub fn set_onmousedown(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onmousedown(instance, value);
    }

    /// Extended attributes: [LegacyLenientThis]
    pub fn get_onmouseenter(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onmouseenter(instance);
    }

    /// Extended attributes: [LegacyLenientThis]
    pub fn set_onmouseenter(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onmouseenter(instance, value);
    }

    /// Extended attributes: [LegacyLenientThis]
    pub fn get_onmouseleave(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onmouseleave(instance);
    }

    /// Extended attributes: [LegacyLenientThis]
    pub fn set_onmouseleave(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onmouseleave(instance, value);
    }

    pub fn get_onmousemove(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onmousemove(instance);
    }

    pub fn set_onmousemove(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onmousemove(instance, value);
    }

    pub fn get_onmouseout(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onmouseout(instance);
    }

    pub fn set_onmouseout(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onmouseout(instance, value);
    }

    pub fn get_onmouseover(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onmouseover(instance);
    }

    pub fn set_onmouseover(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onmouseover(instance, value);
    }

    pub fn get_onmouseup(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onmouseup(instance);
    }

    pub fn set_onmouseup(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onmouseup(instance, value);
    }

    pub fn get_onpaste(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onpaste(instance);
    }

    pub fn set_onpaste(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onpaste(instance, value);
    }

    pub fn get_onpause(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onpause(instance);
    }

    pub fn set_onpause(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onpause(instance, value);
    }

    pub fn get_onplay(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onplay(instance);
    }

    pub fn set_onplay(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onplay(instance, value);
    }

    pub fn get_onplaying(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onplaying(instance);
    }

    pub fn set_onplaying(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onplaying(instance, value);
    }

    pub fn get_onprogress(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onprogress(instance);
    }

    pub fn set_onprogress(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onprogress(instance, value);
    }

    pub fn get_onratechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onratechange(instance);
    }

    pub fn set_onratechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onratechange(instance, value);
    }

    pub fn get_onreset(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onreset(instance);
    }

    pub fn set_onreset(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onreset(instance, value);
    }

    pub fn get_onresize(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onresize(instance);
    }

    pub fn set_onresize(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onresize(instance, value);
    }

    pub fn get_onscroll(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onscroll(instance);
    }

    pub fn set_onscroll(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onscroll(instance, value);
    }

    pub fn get_onscrollend(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onscrollend(instance);
    }

    pub fn set_onscrollend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onscrollend(instance, value);
    }

    pub fn get_onsecuritypolicyviolation(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onsecuritypolicyviolation(instance);
    }

    pub fn set_onsecuritypolicyviolation(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onsecuritypolicyviolation(instance, value);
    }

    pub fn get_onseeked(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onseeked(instance);
    }

    pub fn set_onseeked(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onseeked(instance, value);
    }

    pub fn get_onseeking(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onseeking(instance);
    }

    pub fn set_onseeking(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onseeking(instance, value);
    }

    pub fn get_onselect(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onselect(instance);
    }

    pub fn set_onselect(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onselect(instance, value);
    }

    pub fn get_onslotchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onslotchange(instance);
    }

    pub fn set_onslotchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onslotchange(instance, value);
    }

    pub fn get_onstalled(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onstalled(instance);
    }

    pub fn set_onstalled(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onstalled(instance, value);
    }

    pub fn get_onsubmit(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onsubmit(instance);
    }

    pub fn set_onsubmit(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onsubmit(instance, value);
    }

    pub fn get_onsuspend(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onsuspend(instance);
    }

    pub fn set_onsuspend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onsuspend(instance, value);
    }

    pub fn get_ontimeupdate(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_ontimeupdate(instance);
    }

    pub fn set_ontimeupdate(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_ontimeupdate(instance, value);
    }

    pub fn get_ontoggle(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_ontoggle(instance);
    }

    pub fn set_ontoggle(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_ontoggle(instance, value);
    }

    pub fn get_onvolumechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onvolumechange(instance);
    }

    pub fn set_onvolumechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onvolumechange(instance, value);
    }

    pub fn get_onwaiting(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onwaiting(instance);
    }

    pub fn set_onwaiting(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onwaiting(instance, value);
    }

    pub fn get_onwebkitanimationend(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onwebkitanimationend(instance);
    }

    pub fn set_onwebkitanimationend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onwebkitanimationend(instance, value);
    }

    pub fn get_onwebkitanimationiteration(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onwebkitanimationiteration(instance);
    }

    pub fn set_onwebkitanimationiteration(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onwebkitanimationiteration(instance, value);
    }

    pub fn get_onwebkitanimationstart(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onwebkitanimationstart(instance);
    }

    pub fn set_onwebkitanimationstart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onwebkitanimationstart(instance, value);
    }

    pub fn get_onwebkittransitionend(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onwebkittransitionend(instance);
    }

    pub fn set_onwebkittransitionend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onwebkittransitionend(instance, value);
    }

    pub fn get_onwheel(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onwheel(instance);
    }

    pub fn set_onwheel(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onwheel(instance, value);
    }

    pub fn get_onselectstart(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onselectstart(instance);
    }

    pub fn set_onselectstart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onselectstart(instance, value);
    }

    pub fn get_onselectionchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onselectionchange(instance);
    }

    pub fn set_onselectionchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onselectionchange(instance, value);
    }

    pub fn get_onanimationstart(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onanimationstart(instance);
    }

    pub fn set_onanimationstart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onanimationstart(instance, value);
    }

    pub fn get_onanimationiteration(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onanimationiteration(instance);
    }

    pub fn set_onanimationiteration(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onanimationiteration(instance, value);
    }

    pub fn get_onanimationend(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onanimationend(instance);
    }

    pub fn set_onanimationend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onanimationend(instance, value);
    }

    pub fn get_onanimationcancel(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onanimationcancel(instance);
    }

    pub fn set_onanimationcancel(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onanimationcancel(instance, value);
    }

    pub fn get_ontransitionrun(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_ontransitionrun(instance);
    }

    pub fn set_ontransitionrun(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_ontransitionrun(instance, value);
    }

    pub fn get_ontransitionstart(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_ontransitionstart(instance);
    }

    pub fn set_ontransitionstart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_ontransitionstart(instance, value);
    }

    pub fn get_ontransitionend(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_ontransitionend(instance);
    }

    pub fn set_ontransitionend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_ontransitionend(instance, value);
    }

    pub fn get_ontransitioncancel(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_ontransitioncancel(instance);
    }

    pub fn set_ontransitioncancel(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_ontransitioncancel(instance, value);
    }

    pub fn get_onbeforexrselect(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onbeforexrselect(instance);
    }

    pub fn set_onbeforexrselect(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onbeforexrselect(instance, value);
    }

    pub fn get_onpointerover(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onpointerover(instance);
    }

    pub fn set_onpointerover(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onpointerover(instance, value);
    }

    pub fn get_onpointerenter(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onpointerenter(instance);
    }

    pub fn set_onpointerenter(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onpointerenter(instance, value);
    }

    pub fn get_onpointerdown(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onpointerdown(instance);
    }

    pub fn set_onpointerdown(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onpointerdown(instance, value);
    }

    pub fn get_onpointermove(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onpointermove(instance);
    }

    pub fn set_onpointermove(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onpointermove(instance, value);
    }

    /// Extended attributes: [SecureContext]
    pub fn get_onpointerrawupdate(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onpointerrawupdate(instance);
    }

    /// Extended attributes: [SecureContext]
    pub fn set_onpointerrawupdate(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onpointerrawupdate(instance, value);
    }

    pub fn get_onpointerup(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onpointerup(instance);
    }

    pub fn set_onpointerup(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onpointerup(instance, value);
    }

    pub fn get_onpointercancel(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onpointercancel(instance);
    }

    pub fn set_onpointercancel(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onpointercancel(instance, value);
    }

    pub fn get_onpointerout(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onpointerout(instance);
    }

    pub fn set_onpointerout(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onpointerout(instance, value);
    }

    pub fn get_onpointerleave(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onpointerleave(instance);
    }

    pub fn set_onpointerleave(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onpointerleave(instance, value);
    }

    pub fn get_ongotpointercapture(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_ongotpointercapture(instance);
    }

    pub fn set_ongotpointercapture(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_ongotpointercapture(instance, value);
    }

    pub fn get_onlostpointercapture(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onlostpointercapture(instance);
    }

    pub fn set_onlostpointercapture(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onlostpointercapture(instance, value);
    }

    pub fn get_ontouchstart(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_ontouchstart(instance);
    }

    pub fn set_ontouchstart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_ontouchstart(instance, value);
    }

    pub fn get_ontouchend(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_ontouchend(instance);
    }

    pub fn set_ontouchend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_ontouchend(instance, value);
    }

    pub fn get_ontouchmove(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_ontouchmove(instance);
    }

    pub fn set_ontouchmove(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_ontouchmove(instance, value);
    }

    pub fn get_ontouchcancel(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_ontouchcancel(instance);
    }

    pub fn set_ontouchcancel(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_ontouchcancel(instance, value);
    }

    pub fn get_onfencedtreeclick(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onfencedtreeclick(instance);
    }

    pub fn set_onfencedtreeclick(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onfencedtreeclick(instance, value);
    }

    pub fn get_onsnapchanged(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onsnapchanged(instance);
    }

    pub fn set_onsnapchanged(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onsnapchanged(instance, value);
    }

    pub fn get_onsnapchanging(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGDefsElementImpl.get_onsnapchanging(instance);
    }

    pub fn set_onsnapchanging(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGDefsElementImpl.set_onsnapchanging(instance, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_correspondingElement(instance: *runtime.Instance) anyerror!anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_correspondingElement) |cached| {
            return cached;
        }
        const value = try SVGDefsElementImpl.get_correspondingElement(instance);
        state.cached_correspondingElement = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_correspondingUseElement(instance: *runtime.Instance) anyerror!anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_correspondingUseElement) |cached| {
            return cached;
        }
        const value = try SVGDefsElementImpl.get_correspondingUseElement(instance);
        state.cached_correspondingUseElement = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_dataset(instance: *runtime.Instance) anyerror!DOMStringMap {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_dataset) |cached| {
            return cached;
        }
        const value = try SVGDefsElementImpl.get_dataset(instance);
        state.cached_dataset = value;
        return value;
    }

    pub fn get_nonce(instance: *runtime.Instance) anyerror!DOMString {
        return try SVGDefsElementImpl.get_nonce(instance);
    }

    pub fn set_nonce(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try SVGDefsElementImpl.set_nonce(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_autofocus(instance: *runtime.Instance) anyerror!bool {
        return try SVGDefsElementImpl.get_autofocus(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_autofocus(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_autofocus(instance, value);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn get_tabIndex(instance: *runtime.Instance) anyerror!i32 {
        return try SVGDefsElementImpl.get_tabIndex(instance);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn set_tabIndex(instance: *runtime.Instance, value: i32) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGDefsElementImpl.set_tabIndex(instance, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_transform(instance: *runtime.Instance) anyerror!SVGAnimatedTransformList {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_transform) |cached| {
            return cached;
        }
        const value = try SVGDefsElementImpl.get_transform(instance);
        state.cached_transform = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_requiredExtensions(instance: *runtime.Instance) anyerror!SVGStringList {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_requiredExtensions) |cached| {
            return cached;
        }
        const value = try SVGDefsElementImpl.get_requiredExtensions(instance);
        state.cached_requiredExtensions = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_systemLanguage(instance: *runtime.Instance) anyerror!SVGStringList {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_systemLanguage) |cached| {
            return cached;
        }
        const value = try SVGDefsElementImpl.get_systemLanguage(instance);
        state.cached_systemLanguage = value;
        return value;
    }

    pub fn call_isDefaultNamespace(instance: *runtime.Instance, namespace: anyopaque) anyerror!bool {
        
        return try SVGDefsElementImpl.call_isDefaultNamespace(instance, namespace);
    }

    pub fn call_getAttributeNS(instance: *runtime.Instance, namespace: anyopaque, localName: DOMString) anyerror!anyopaque {
        
        return try SVGDefsElementImpl.call_getAttributeNS(instance, namespace, localName);
    }

    pub fn call_getAttribute(instance: *runtime.Instance, qualifiedName: DOMString) anyerror!anyopaque {
        
        return try SVGDefsElementImpl.call_getAttribute(instance, qualifiedName);
    }

    pub fn call_hasAttribute(instance: *runtime.Instance, qualifiedName: DOMString) anyerror!bool {
        
        return try SVGDefsElementImpl.call_hasAttribute(instance, qualifiedName);
    }

    pub fn call_contains(instance: *runtime.Instance, other: anyopaque) anyerror!bool {
        
        return try SVGDefsElementImpl.call_contains(instance, other);
    }

    pub fn call_matches(instance: *runtime.Instance, selectors: DOMString) anyerror!bool {
        
        return try SVGDefsElementImpl.call_matches(instance, selectors);
    }

    pub fn call_releasePointerCapture(instance: *runtime.Instance, pointerId: i32) anyerror!void {
        
        return try SVGDefsElementImpl.call_releasePointerCapture(instance, pointerId);
    }

    /// Extended attributes: [SameObject]
    pub fn call_computedStyleMap(instance: *runtime.Instance) anyerror!StylePropertyMapReadOnly {
        return try SVGDefsElementImpl.call_computedStyleMap(instance);
    }

    /// Arguments for scroll (WebIDL overloading)
    pub const ScrollArgs = union(enum) {
        /// scroll(options)
        ScrollToOptions: ScrollToOptions,
        /// scroll(x, y)
        unrestricted double_unrestricted double: struct {
            x: f64,
            y: f64,
        },
    };

    pub fn call_scroll(instance: *runtime.Instance, args: ScrollArgs) anyerror!anyopaque {
        switch (args) {
            .ScrollToOptions => |arg| return try SVGDefsElementImpl.ScrollToOptions(instance, arg),
            .unrestricted double_unrestricted double => |a| return try SVGDefsElementImpl.unrestricted double_unrestricted double(instance, a.x, a.y),
        }
    }

    pub fn call_getClientRects(instance: *runtime.Instance) anyerror!DOMRectList {
        return try SVGDefsElementImpl.call_getClientRects(instance);
    }

    pub fn call_getRootNode(instance: *runtime.Instance, options: GetRootNodeOptions) anyerror!Node {
        
        return try SVGDefsElementImpl.call_getRootNode(instance, options);
    }

    /// Arguments for scrollBy (WebIDL overloading)
    pub const ScrollByArgs = union(enum) {
        /// scrollBy(options)
        ScrollToOptions: ScrollToOptions,
        /// scrollBy(x, y)
        unrestricted double_unrestricted double: struct {
            x: f64,
            y: f64,
        },
    };

    pub fn call_scrollBy(instance: *runtime.Instance, args: ScrollByArgs) anyerror!anyopaque {
        switch (args) {
            .ScrollToOptions => |arg| return try SVGDefsElementImpl.ScrollToOptions(instance, arg),
            .unrestricted double_unrestricted double => |a| return try SVGDefsElementImpl.unrestricted double_unrestricted double(instance, a.x, a.y),
        }
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_prepend(instance: *runtime.Instance, nodes: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try SVGDefsElementImpl.call_prepend(instance, nodes);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try SVGDefsElementImpl.call_dispatchEvent(instance, event);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_replaceWith(instance: *runtime.Instance, nodes: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try SVGDefsElementImpl.call_replaceWith(instance, nodes);
    }

    pub fn call_convertQuadFromNode(instance: *runtime.Instance, quad: DOMQuadInit, from: GeometryNode, options: ConvertCoordinateOptions) anyerror!DOMQuad {
        
        return try SVGDefsElementImpl.call_convertQuadFromNode(instance, quad, from, options);
    }

    pub fn call_focus(instance: *runtime.Instance, options: FocusOptions) anyerror!void {
        
        return try SVGDefsElementImpl.call_focus(instance, options);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_setAttributeNodeNS(instance: *runtime.Instance, attr: Attr) anyerror!anyopaque {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try SVGDefsElementImpl.call_setAttributeNodeNS(instance, attr);
    }

    pub fn call_getAttributeNodeNS(instance: *runtime.Instance, namespace: anyopaque, localName: DOMString) anyerror!anyopaque {
        
        return try SVGDefsElementImpl.call_getAttributeNodeNS(instance, namespace, localName);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_setAttributeNS(instance: *runtime.Instance, namespace: anyopaque, qualifiedName: DOMString, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try SVGDefsElementImpl.call_setAttributeNS(instance, namespace, qualifiedName, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_setAttributeNode(instance: *runtime.Instance, attr: Attr) anyerror!anyopaque {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try SVGDefsElementImpl.call_setAttributeNode(instance, attr);
    }

    pub fn call_getScreenCTM(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.call_getScreenCTM(instance);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try SVGDefsElementImpl.call_when(instance, type_, options);
    }

    /// Arguments for scrollTo (WebIDL overloading)
    pub const ScrollToArgs = union(enum) {
        /// scrollTo(options)
        ScrollToOptions: ScrollToOptions,
        /// scrollTo(x, y)
        unrestricted double_unrestricted double: struct {
            x: f64,
            y: f64,
        },
    };

    pub fn call_scrollTo(instance: *runtime.Instance, args: ScrollToArgs) anyerror!anyopaque {
        switch (args) {
            .ScrollToOptions => |arg| return try SVGDefsElementImpl.ScrollToOptions(instance, arg),
            .unrestricted double_unrestricted double => |a| return try SVGDefsElementImpl.unrestricted double_unrestricted double(instance, a.x, a.y),
        }
    }

    /// Extended attributes: [CEReactions]
    pub fn call_insertBefore(instance: *runtime.Instance, node: Node, child: anyopaque) anyerror!Node {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try SVGDefsElementImpl.call_insertBefore(instance, node, child);
    }

    pub fn call_lookupNamespaceURI(instance: *runtime.Instance, prefix: anyopaque) anyerror!anyopaque {
        
        return try SVGDefsElementImpl.call_lookupNamespaceURI(instance, prefix);
    }

    pub fn call_getElementsByTagNameNS(instance: *runtime.Instance, namespace: anyopaque, localName: DOMString) anyerror!HTMLCollection {
        
        return try SVGDefsElementImpl.call_getElementsByTagNameNS(instance, namespace, localName);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_replaceChildren(instance: *runtime.Instance, nodes: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try SVGDefsElementImpl.call_replaceChildren(instance, nodes);
    }

    pub fn call_getRegionFlowRanges(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.call_getRegionFlowRanges(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_removeChild(instance: *runtime.Instance, child: Node) anyerror!Node {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try SVGDefsElementImpl.call_removeChild(instance, child);
    }

    pub fn call_focusableAreas(instance: *runtime.Instance, option: FocusableAreasOption) anyerror!anyopaque {
        
        return try SVGDefsElementImpl.call_focusableAreas(instance, option);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_normalize(instance: *runtime.Instance) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        return try SVGDefsElementImpl.call_normalize(instance);
    }

    pub fn call_isEqualNode(instance: *runtime.Instance, otherNode: anyopaque) anyerror!bool {
        
        return try SVGDefsElementImpl.call_isEqualNode(instance, otherNode);
    }

    pub fn call_getBoxQuads(instance: *runtime.Instance, options: BoxQuadOptions) anyerror!anyopaque {
        
        return try SVGDefsElementImpl.call_getBoxQuads(instance, options);
    }

    pub fn call_convertPointFromNode(instance: *runtime.Instance, point: DOMPointInit, from: GeometryNode, options: ConvertCoordinateOptions) anyerror!DOMPoint {
        
        return try SVGDefsElementImpl.call_convertPointFromNode(instance, point, from, options);
    }

    pub fn call_getBBox(instance: *runtime.Instance, options: SVGBoundingBoxOptions) anyerror!DOMRect {
        
        return try SVGDefsElementImpl.call_getBBox(instance, options);
    }

    pub fn call_getAnimations(instance: *runtime.Instance, options: GetAnimationsOptions) anyerror!anyopaque {
        
        return try SVGDefsElementImpl.call_getAnimations(instance, options);
    }

    pub fn call_getElementsByClassName(instance: *runtime.Instance, classNames: DOMString) anyerror!HTMLCollection {
        
        return try SVGDefsElementImpl.call_getElementsByClassName(instance, classNames);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_insertAdjacentElement(instance: *runtime.Instance, where: DOMString, element: Element) anyerror!anyopaque {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try SVGDefsElementImpl.call_insertAdjacentElement(instance, where, element);
    }

    pub fn call_webkitMatchesSelector(instance: *runtime.Instance, selectors: DOMString) anyerror!bool {
        
        return try SVGDefsElementImpl.call_webkitMatchesSelector(instance, selectors);
    }

    pub fn call_spatialNavigationSearch(instance: *runtime.Instance, dir: SpatialNavigationDirection, options: SpatialNavigationSearchOptions) anyerror!anyopaque {
        
        return try SVGDefsElementImpl.call_spatialNavigationSearch(instance, dir, options);
    }

    pub fn call_getElementsByTagName(instance: *runtime.Instance, qualifiedName: DOMString) anyerror!HTMLCollection {
        
        return try SVGDefsElementImpl.call_getElementsByTagName(instance, qualifiedName);
    }

    pub fn call_querySelector(instance: *runtime.Instance, selectors: DOMString) anyerror!anyopaque {
        
        return try SVGDefsElementImpl.call_querySelector(instance, selectors);
    }

    pub fn call_compareDocumentPosition(instance: *runtime.Instance, other: Node) anyerror!u16 {
        
        return try SVGDefsElementImpl.call_compareDocumentPosition(instance, other);
    }

    pub fn call_closest(instance: *runtime.Instance, selectors: DOMString) anyerror!anyopaque {
        
        return try SVGDefsElementImpl.call_closest(instance, selectors);
    }

    pub fn call_getSpatialNavigationContainer(instance: *runtime.Instance) anyerror!Node {
        return try SVGDefsElementImpl.call_getSpatialNavigationContainer(instance);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_remove(instance: *runtime.Instance) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        return try SVGDefsElementImpl.call_remove(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_removeAttribute(instance: *runtime.Instance, qualifiedName: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try SVGDefsElementImpl.call_removeAttribute(instance, qualifiedName);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try SVGDefsElementImpl.call_removeEventListener(instance, type_, callback, options);
    }

    pub fn call_convertRectFromNode(instance: *runtime.Instance, rect: DOMRectReadOnly, from: GeometryNode, options: ConvertCoordinateOptions) anyerror!DOMQuad {
        
        return try SVGDefsElementImpl.call_convertRectFromNode(instance, rect, from, options);
    }

    /// Extended attributes: [CEReactions], [NewObject]
    pub fn call_cloneNode(instance: *runtime.Instance, subtree: bool) anyerror!Node {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        // [NewObject] - Caller owns the returned object
        
        return try SVGDefsElementImpl.call_cloneNode(instance, subtree);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_removeAttributeNode(instance: *runtime.Instance, attr: Attr) anyerror!Attr {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try SVGDefsElementImpl.call_removeAttributeNode(instance, attr);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_removeAttributeNS(instance: *runtime.Instance, namespace: anyopaque, localName: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try SVGDefsElementImpl.call_removeAttributeNS(instance, namespace, localName);
    }

    pub fn call_insertAdjacentText(instance: *runtime.Instance, where: DOMString, data: DOMString) anyerror!void {
        
        return try SVGDefsElementImpl.call_insertAdjacentText(instance, where, data);
    }

    pub fn call_requestFullscreen(instance: *runtime.Instance, options: FullscreenOptions) anyerror!anyopaque {
        
        return try SVGDefsElementImpl.call_requestFullscreen(instance, options);
    }

    pub fn call_animate(instance: *runtime.Instance, keyframes: anyopaque, options: anyopaque) anyerror!Animation {
        
        return try SVGDefsElementImpl.call_animate(instance, keyframes, options);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_append(instance: *runtime.Instance, nodes: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try SVGDefsElementImpl.call_append(instance, nodes);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_moveBefore(instance: *runtime.Instance, node: Node, child: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try SVGDefsElementImpl.call_moveBefore(instance, node, child);
    }

    pub fn call_getHTML(instance: *runtime.Instance, options: GetHTMLOptions) anyerror!DOMString {
        
        return try SVGDefsElementImpl.call_getHTML(instance, options);
    }

    pub fn call_getAttributeNode(instance: *runtime.Instance, qualifiedName: DOMString) anyerror!anyopaque {
        
        return try SVGDefsElementImpl.call_getAttributeNode(instance, qualifiedName);
    }

    pub fn call_isSameNode(instance: *runtime.Instance, otherNode: anyopaque) anyerror!bool {
        
        return try SVGDefsElementImpl.call_isSameNode(instance, otherNode);
    }

    pub fn call_blur(instance: *runtime.Instance) anyerror!void {
        return try SVGDefsElementImpl.call_blur(instance);
    }

    pub fn call_startViewTransition(instance: *runtime.Instance, callbackOptions: anyopaque) anyerror!ViewTransition {
        
        return try SVGDefsElementImpl.call_startViewTransition(instance, callbackOptions);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_setHTMLUnsafe(instance: *runtime.Instance, html: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try SVGDefsElementImpl.call_setHTMLUnsafe(instance, html);
    }

    pub fn call_lookupPrefix(instance: *runtime.Instance, namespace: anyopaque) anyerror!anyopaque {
        
        return try SVGDefsElementImpl.call_lookupPrefix(instance, namespace);
    }

    pub fn call_scrollIntoView(instance: *runtime.Instance, arg: anyopaque) anyerror!anyopaque {
        
        return try SVGDefsElementImpl.call_scrollIntoView(instance, arg);
    }

    pub fn call_hasAttributes(instance: *runtime.Instance) anyerror!bool {
        return try SVGDefsElementImpl.call_hasAttributes(instance);
    }

    pub fn call_hasPointerCapture(instance: *runtime.Instance, pointerId: i32) anyerror!bool {
        
        return try SVGDefsElementImpl.call_hasPointerCapture(instance, pointerId);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_toggleAttribute(instance: *runtime.Instance, qualifiedName: DOMString, force: bool) anyerror!bool {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try SVGDefsElementImpl.call_toggleAttribute(instance, qualifiedName, force);
    }

    pub fn call_pseudo(instance: *runtime.Instance, type_: anyopaque) anyerror!anyopaque {
        
        return try SVGDefsElementImpl.call_pseudo(instance, type_);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_before(instance: *runtime.Instance, nodes: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try SVGDefsElementImpl.call_before(instance, nodes);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_after(instance: *runtime.Instance, nodes: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try SVGDefsElementImpl.call_after(instance, nodes);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_setAttribute(instance: *runtime.Instance, qualifiedName: DOMString, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try SVGDefsElementImpl.call_setAttribute(instance, qualifiedName, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_appendChild(instance: *runtime.Instance, node: Node) anyerror!Node {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try SVGDefsElementImpl.call_appendChild(instance, node);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try SVGDefsElementImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_getAttributeNames(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.call_getAttributeNames(instance);
    }

    pub fn call_hasChildNodes(instance: *runtime.Instance) anyerror!bool {
        return try SVGDefsElementImpl.call_hasChildNodes(instance);
    }

    pub fn call_attachShadow(instance: *runtime.Instance, init: ShadowRootInit) anyerror!ShadowRoot {
        
        return try SVGDefsElementImpl.call_attachShadow(instance, init);
    }

    pub fn call_requestPointerLock(instance: *runtime.Instance, options: PointerLockOptions) anyerror!anyopaque {
        
        return try SVGDefsElementImpl.call_requestPointerLock(instance, options);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_insertAdjacentHTML(instance: *runtime.Instance, position: DOMString, string: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try SVGDefsElementImpl.call_insertAdjacentHTML(instance, position, string);
    }

    pub fn call_hasAttributeNS(instance: *runtime.Instance, namespace: anyopaque, localName: DOMString) anyerror!bool {
        
        return try SVGDefsElementImpl.call_hasAttributeNS(instance, namespace, localName);
    }

    pub fn call_checkVisibility(instance: *runtime.Instance, options: CheckVisibilityOptions) anyerror!bool {
        
        return try SVGDefsElementImpl.call_checkVisibility(instance, options);
    }

    pub fn call_getCTM(instance: *runtime.Instance) anyerror!anyopaque {
        return try SVGDefsElementImpl.call_getCTM(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_replaceChild(instance: *runtime.Instance, node: Node, child: Node) anyerror!Node {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try SVGDefsElementImpl.call_replaceChild(instance, node, child);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getBoundingClientRect(instance: *runtime.Instance) anyerror!DOMRect {
        // [NewObject] - Caller owns the returned object
        return try SVGDefsElementImpl.call_getBoundingClientRect(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_querySelectorAll(instance: *runtime.Instance, selectors: DOMString) anyerror!NodeList {
        // [NewObject] - Caller owns the returned object
        
        return try SVGDefsElementImpl.call_querySelectorAll(instance, selectors);
    }

    pub fn call_setPointerCapture(instance: *runtime.Instance, pointerId: i32) anyerror!void {
        
        return try SVGDefsElementImpl.call_setPointerCapture(instance, pointerId);
    }

};
