//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const HTMLAudioElementImpl = @import("../impls/HTMLAudioElement.zig");
const HTMLMediaElement = @import("HTMLMediaElement.zig");

pub const HTMLAudioElement = struct {
    pub const Meta = struct {
        pub const name = "HTMLAudioElement";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *HTMLMediaElement;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "LegacyFactoryFunction", .value = .{ .identifier = "Audio" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(HTMLAudioElement, .{
        .deinit_fn = &deinit_wrapper,

        .get_ATTRIBUTE_NODE = &HTMLMediaElement.get_ATTRIBUTE_NODE,
        .get_CDATA_SECTION_NODE = &HTMLMediaElement.get_CDATA_SECTION_NODE,
        .get_COMMENT_NODE = &HTMLMediaElement.get_COMMENT_NODE,
        .get_DOCUMENT_FRAGMENT_NODE = &HTMLMediaElement.get_DOCUMENT_FRAGMENT_NODE,
        .get_DOCUMENT_NODE = &HTMLMediaElement.get_DOCUMENT_NODE,
        .get_DOCUMENT_POSITION_CONTAINED_BY = &HTMLMediaElement.get_DOCUMENT_POSITION_CONTAINED_BY,
        .get_DOCUMENT_POSITION_CONTAINS = &HTMLMediaElement.get_DOCUMENT_POSITION_CONTAINS,
        .get_DOCUMENT_POSITION_DISCONNECTED = &HTMLMediaElement.get_DOCUMENT_POSITION_DISCONNECTED,
        .get_DOCUMENT_POSITION_FOLLOWING = &HTMLMediaElement.get_DOCUMENT_POSITION_FOLLOWING,
        .get_DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC = &HTMLMediaElement.get_DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC,
        .get_DOCUMENT_POSITION_PRECEDING = &HTMLMediaElement.get_DOCUMENT_POSITION_PRECEDING,
        .get_DOCUMENT_TYPE_NODE = &HTMLMediaElement.get_DOCUMENT_TYPE_NODE,
        .get_ELEMENT_NODE = &HTMLMediaElement.get_ELEMENT_NODE,
        .get_ENTITY_NODE = &HTMLMediaElement.get_ENTITY_NODE,
        .get_ENTITY_REFERENCE_NODE = &HTMLMediaElement.get_ENTITY_REFERENCE_NODE,
        .get_HAVE_CURRENT_DATA = &HTMLMediaElement.get_HAVE_CURRENT_DATA,
        .get_HAVE_ENOUGH_DATA = &HTMLMediaElement.get_HAVE_ENOUGH_DATA,
        .get_HAVE_FUTURE_DATA = &HTMLMediaElement.get_HAVE_FUTURE_DATA,
        .get_HAVE_METADATA = &HTMLMediaElement.get_HAVE_METADATA,
        .get_HAVE_NOTHING = &HTMLMediaElement.get_HAVE_NOTHING,
        .get_NETWORK_EMPTY = &HTMLMediaElement.get_NETWORK_EMPTY,
        .get_NETWORK_IDLE = &HTMLMediaElement.get_NETWORK_IDLE,
        .get_NETWORK_LOADING = &HTMLMediaElement.get_NETWORK_LOADING,
        .get_NETWORK_NO_SOURCE = &HTMLMediaElement.get_NETWORK_NO_SOURCE,
        .get_NOTATION_NODE = &HTMLMediaElement.get_NOTATION_NODE,
        .get_PROCESSING_INSTRUCTION_NODE = &HTMLMediaElement.get_PROCESSING_INSTRUCTION_NODE,
        .get_TEXT_NODE = &HTMLMediaElement.get_TEXT_NODE,
        .get_accessKey = &get_accessKey,
        .get_accessKeyLabel = &get_accessKeyLabel,
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
        .get_audioTracks = &get_audioTracks,
        .get_autocapitalize = &get_autocapitalize,
        .get_autocorrect = &get_autocorrect,
        .get_autofocus = &get_autofocus,
        .get_autoplay = &get_autoplay,
        .get_baseURI = &get_baseURI,
        .get_buffered = &get_buffered,
        .get_childElementCount = &get_childElementCount,
        .get_childNodes = &get_childNodes,
        .get_children = &get_children,
        .get_classList = &get_classList,
        .get_className = &get_className,
        .get_clientHeight = &get_clientHeight,
        .get_clientLeft = &get_clientLeft,
        .get_clientTop = &get_clientTop,
        .get_clientWidth = &get_clientWidth,
        .get_contentEditable = &get_contentEditable,
        .get_controls = &get_controls,
        .get_crossOrigin = &get_crossOrigin,
        .get_currentCSSZoom = &get_currentCSSZoom,
        .get_currentSrc = &get_currentSrc,
        .get_currentTime = &get_currentTime,
        .get_customElementRegistry = &get_customElementRegistry,
        .get_dataset = &get_dataset,
        .get_defaultMuted = &get_defaultMuted,
        .get_defaultPlaybackRate = &get_defaultPlaybackRate,
        .get_dir = &get_dir,
        .get_disableRemotePlayback = &get_disableRemotePlayback,
        .get_draggable = &get_draggable,
        .get_duration = &get_duration,
        .get_editContext = &get_editContext,
        .get_elementTiming = &get_elementTiming,
        .get_ended = &get_ended,
        .get_enterKeyHint = &get_enterKeyHint,
        .get_error = &get_error,
        .get_firstChild = &get_firstChild,
        .get_firstElementChild = &get_firstElementChild,
        .get_headingOffset = &get_headingOffset,
        .get_headingReset = &get_headingReset,
        .get_hidden = &get_hidden,
        .get_id = &get_id,
        .get_inert = &get_inert,
        .get_innerHTML = &get_innerHTML,
        .get_innerText = &get_innerText,
        .get_inputMode = &get_inputMode,
        .get_isConnected = &get_isConnected,
        .get_isContentEditable = &get_isContentEditable,
        .get_lang = &get_lang,
        .get_lastChild = &get_lastChild,
        .get_lastElementChild = &get_lastElementChild,
        .get_localName = &get_localName,
        .get_loop = &get_loop,
        .get_mediaKeys = &get_mediaKeys,
        .get_muted = &get_muted,
        .get_namespaceURI = &get_namespaceURI,
        .get_networkState = &get_networkState,
        .get_nextElementSibling = &get_nextElementSibling,
        .get_nextSibling = &get_nextSibling,
        .get_nodeName = &get_nodeName,
        .get_nodeType = &get_nodeType,
        .get_nodeValue = &get_nodeValue,
        .get_nonce = &get_nonce,
        .get_offsetHeight = &get_offsetHeight,
        .get_offsetLeft = &get_offsetLeft,
        .get_offsetParent = &get_offsetParent,
        .get_offsetTop = &get_offsetTop,
        .get_offsetWidth = &get_offsetWidth,
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
        .get_onencrypted = &get_onencrypted,
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
        .get_onwaitingforkey = &get_onwaitingforkey,
        .get_onwebkitanimationend = &get_onwebkitanimationend,
        .get_onwebkitanimationiteration = &get_onwebkitanimationiteration,
        .get_onwebkitanimationstart = &get_onwebkitanimationstart,
        .get_onwebkittransitionend = &get_onwebkittransitionend,
        .get_onwheel = &get_onwheel,
        .get_outerHTML = &get_outerHTML,
        .get_outerText = &get_outerText,
        .get_ownerDocument = &get_ownerDocument,
        .get_parentElement = &get_parentElement,
        .get_parentNode = &get_parentNode,
        .get_part = &get_part,
        .get_paused = &get_paused,
        .get_playbackRate = &get_playbackRate,
        .get_played = &get_played,
        .get_popover = &get_popover,
        .get_prefix = &get_prefix,
        .get_preload = &get_preload,
        .get_preservesPitch = &get_preservesPitch,
        .get_previousElementSibling = &get_previousElementSibling,
        .get_previousSibling = &get_previousSibling,
        .get_readyState = &get_readyState,
        .get_regionOverset = &get_regionOverset,
        .get_remote = &get_remote,
        .get_role = &get_role,
        .get_scrollHeight = &get_scrollHeight,
        .get_scrollLeft = &get_scrollLeft,
        .get_scrollParent = &get_scrollParent,
        .get_scrollTop = &get_scrollTop,
        .get_scrollWidth = &get_scrollWidth,
        .get_seekable = &get_seekable,
        .get_seeking = &get_seeking,
        .get_shadowRoot = &get_shadowRoot,
        .get_sinkId = &get_sinkId,
        .get_slot = &get_slot,
        .get_spellcheck = &get_spellcheck,
        .get_src = &get_src,
        .get_srcObject = &get_srcObject,
        .get_style = &get_style,
        .get_style = &get_style,
        .get_tabIndex = &get_tabIndex,
        .get_tagName = &get_tagName,
        .get_textContent = &get_textContent,
        .get_textTracks = &get_textTracks,
        .get_title = &get_title,
        .get_translate = &get_translate,
        .get_videoTracks = &get_videoTracks,
        .get_virtualKeyboardPolicy = &get_virtualKeyboardPolicy,
        .get_volume = &get_volume,
        .get_writingSuggestions = &get_writingSuggestions,

        .set_accessKey = &set_accessKey,
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
        .set_autocapitalize = &set_autocapitalize,
        .set_autocorrect = &set_autocorrect,
        .set_autofocus = &set_autofocus,
        .set_autoplay = &set_autoplay,
        .set_className = &set_className,
        .set_contentEditable = &set_contentEditable,
        .set_controls = &set_controls,
        .set_crossOrigin = &set_crossOrigin,
        .set_currentTime = &set_currentTime,
        .set_defaultMuted = &set_defaultMuted,
        .set_defaultPlaybackRate = &set_defaultPlaybackRate,
        .set_dir = &set_dir,
        .set_disableRemotePlayback = &set_disableRemotePlayback,
        .set_draggable = &set_draggable,
        .set_editContext = &set_editContext,
        .set_elementTiming = &set_elementTiming,
        .set_enterKeyHint = &set_enterKeyHint,
        .set_headingOffset = &set_headingOffset,
        .set_headingReset = &set_headingReset,
        .set_hidden = &set_hidden,
        .set_id = &set_id,
        .set_inert = &set_inert,
        .set_innerHTML = &set_innerHTML,
        .set_innerText = &set_innerText,
        .set_inputMode = &set_inputMode,
        .set_lang = &set_lang,
        .set_loop = &set_loop,
        .set_muted = &set_muted,
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
        .set_onencrypted = &set_onencrypted,
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
        .set_onwaitingforkey = &set_onwaitingforkey,
        .set_onwebkitanimationend = &set_onwebkitanimationend,
        .set_onwebkitanimationiteration = &set_onwebkitanimationiteration,
        .set_onwebkitanimationstart = &set_onwebkitanimationstart,
        .set_onwebkittransitionend = &set_onwebkittransitionend,
        .set_onwheel = &set_onwheel,
        .set_outerHTML = &set_outerHTML,
        .set_outerText = &set_outerText,
        .set_playbackRate = &set_playbackRate,
        .set_popover = &set_popover,
        .set_preload = &set_preload,
        .set_preservesPitch = &set_preservesPitch,
        .set_role = &set_role,
        .set_scrollLeft = &set_scrollLeft,
        .set_scrollTop = &set_scrollTop,
        .set_slot = &set_slot,
        .set_spellcheck = &set_spellcheck,
        .set_src = &set_src,
        .set_srcObject = &set_srcObject,
        .set_tabIndex = &set_tabIndex,
        .set_textContent = &set_textContent,
        .set_title = &set_title,
        .set_translate = &set_translate,
        .set_virtualKeyboardPolicy = &set_virtualKeyboardPolicy,
        .set_volume = &set_volume,
        .set_writingSuggestions = &set_writingSuggestions,

        .call_addEventListener = &call_addEventListener,
        .call_addTextTrack = &call_addTextTrack,
        .call_after = &call_after,
        .call_animate = &call_animate,
        .call_append = &call_append,
        .call_appendChild = &call_appendChild,
        .call_attachInternals = &call_attachInternals,
        .call_attachShadow = &call_attachShadow,
        .call_before = &call_before,
        .call_blur = &call_blur,
        .call_canPlayType = &call_canPlayType,
        .call_captureStream = &call_captureStream,
        .call_checkVisibility = &call_checkVisibility,
        .call_click = &call_click,
        .call_cloneNode = &call_cloneNode,
        .call_closest = &call_closest,
        .call_compareDocumentPosition = &call_compareDocumentPosition,
        .call_computedStyleMap = &call_computedStyleMap,
        .call_contains = &call_contains,
        .call_convertPointFromNode = &call_convertPointFromNode,
        .call_convertQuadFromNode = &call_convertQuadFromNode,
        .call_convertRectFromNode = &call_convertRectFromNode,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_fastSeek = &call_fastSeek,
        .call_focus = &call_focus,
        .call_focusableAreas = &call_focusableAreas,
        .call_getAnimations = &call_getAnimations,
        .call_getAttribute = &call_getAttribute,
        .call_getAttributeNS = &call_getAttributeNS,
        .call_getAttributeNames = &call_getAttributeNames,
        .call_getAttributeNode = &call_getAttributeNode,
        .call_getAttributeNodeNS = &call_getAttributeNodeNS,
        .call_getBoundingClientRect = &call_getBoundingClientRect,
        .call_getBoxQuads = &call_getBoxQuads,
        .call_getClientRects = &call_getClientRects,
        .call_getElementsByClassName = &call_getElementsByClassName,
        .call_getElementsByTagName = &call_getElementsByTagName,
        .call_getElementsByTagNameNS = &call_getElementsByTagNameNS,
        .call_getHTML = &call_getHTML,
        .call_getRegionFlowRanges = &call_getRegionFlowRanges,
        .call_getRootNode = &call_getRootNode,
        .call_getSpatialNavigationContainer = &call_getSpatialNavigationContainer,
        .call_getStartDate = &call_getStartDate,
        .call_hasAttribute = &call_hasAttribute,
        .call_hasAttributeNS = &call_hasAttributeNS,
        .call_hasAttributes = &call_hasAttributes,
        .call_hasChildNodes = &call_hasChildNodes,
        .call_hasPointerCapture = &call_hasPointerCapture,
        .call_hidePopover = &call_hidePopover,
        .call_insertAdjacentElement = &call_insertAdjacentElement,
        .call_insertAdjacentHTML = &call_insertAdjacentHTML,
        .call_insertAdjacentText = &call_insertAdjacentText,
        .call_insertBefore = &call_insertBefore,
        .call_isDefaultNamespace = &call_isDefaultNamespace,
        .call_isEqualNode = &call_isEqualNode,
        .call_isSameNode = &call_isSameNode,
        .call_load = &call_load,
        .call_lookupNamespaceURI = &call_lookupNamespaceURI,
        .call_lookupPrefix = &call_lookupPrefix,
        .call_matches = &call_matches,
        .call_moveBefore = &call_moveBefore,
        .call_normalize = &call_normalize,
        .call_pause = &call_pause,
        .call_play = &call_play,
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
        .call_scroll = &call_scroll,
        .call_scrollBy = &call_scrollBy,
        .call_scrollBy = &call_scrollBy,
        .call_scrollIntoView = &call_scrollIntoView,
        .call_scrollTo = &call_scrollTo,
        .call_scrollTo = &call_scrollTo,
        .call_setAttribute = &call_setAttribute,
        .call_setAttributeNS = &call_setAttributeNS,
        .call_setAttributeNode = &call_setAttributeNode,
        .call_setAttributeNodeNS = &call_setAttributeNodeNS,
        .call_setHTMLUnsafe = &call_setHTMLUnsafe,
        .call_setMediaKeys = &call_setMediaKeys,
        .call_setPointerCapture = &call_setPointerCapture,
        .call_setSinkId = &call_setSinkId,
        .call_showPopover = &call_showPopover,
        .call_spatialNavigationSearch = &call_spatialNavigationSearch,
        .call_startViewTransition = &call_startViewTransition,
        .call_toggleAttribute = &call_toggleAttribute,
        .call_togglePopover = &call_togglePopover,
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
        
        // Initialize the state (Impl receives full hierarchy)
        HTMLAudioElementImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try HTMLAudioElementImpl.constructor(state);
        
        return instance;
    }

    pub fn get_nodeType(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_nodeType(state);
    }

    pub fn get_nodeName(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_nodeName(state);
    }

    pub fn get_baseURI(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_baseURI(state);
    }

    pub fn get_isConnected(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_isConnected(state);
    }

    pub fn get_ownerDocument(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ownerDocument(state);
    }

    pub fn get_parentNode(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_parentNode(state);
    }

    pub fn get_parentElement(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_parentElement(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_childNodes(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_childNodes) |cached| {
            return cached;
        }
        const value = HTMLAudioElementImpl.get_childNodes(state);
        state.cached_childNodes = value;
        return value;
    }

    pub fn get_firstChild(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_firstChild(state);
    }

    pub fn get_lastChild(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_lastChild(state);
    }

    pub fn get_previousSibling(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_previousSibling(state);
    }

    pub fn get_nextSibling(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_nextSibling(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_nodeValue(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_nodeValue(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_nodeValue(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_nodeValue(state, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_textContent(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_textContent(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_textContent(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_textContent(state, value);
    }

    pub fn get_namespaceURI(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_namespaceURI(state);
    }

    pub fn get_prefix(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_prefix(state);
    }

    pub fn get_localName(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_localName(state);
    }

    pub fn get_tagName(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_tagName(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_id(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_id(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_id(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_id(state, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_className(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_className(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_className(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_className(state, value);
    }

    /// Extended attributes: [SameObject], [PutForwards=value]
    pub fn get_classList(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_classList) |cached| {
            return cached;
        }
        const value = HTMLAudioElementImpl.get_classList(state);
        state.cached_classList = value;
        return value;
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn get_slot(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_slot(state);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn set_slot(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_slot(state, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_attributes(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_attributes) |cached| {
            return cached;
        }
        const value = HTMLAudioElementImpl.get_attributes(state);
        state.cached_attributes = value;
        return value;
    }

    pub fn get_shadowRoot(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_shadowRoot(state);
    }

    pub fn get_customElementRegistry(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_customElementRegistry(state);
    }

    pub fn get_onfullscreenchange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onfullscreenchange(state);
    }

    pub fn set_onfullscreenchange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onfullscreenchange(state, value);
    }

    pub fn get_onfullscreenerror(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onfullscreenerror(state);
    }

    pub fn set_onfullscreenerror(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onfullscreenerror(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_elementTiming(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_elementTiming(state);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_elementTiming(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_elementTiming(state, value);
    }

    /// Extended attributes: [SameObject], [PutForwards=value]
    pub fn get_part(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_part) |cached| {
            return cached;
        }
        const value = HTMLAudioElementImpl.get_part(state);
        state.cached_part = value;
        return value;
    }

    pub fn get_activeViewTransition(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_activeViewTransition(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_innerHTML(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_innerHTML(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_innerHTML(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_innerHTML(state, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_outerHTML(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_outerHTML(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_outerHTML(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_outerHTML(state, value);
    }

    pub fn get_scrollTop(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_scrollTop(state);
    }

    pub fn set_scrollTop(instance: *runtime.Instance, value: f64) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_scrollTop(state, value);
    }

    pub fn get_scrollLeft(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_scrollLeft(state);
    }

    pub fn set_scrollLeft(instance: *runtime.Instance, value: f64) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_scrollLeft(state, value);
    }

    pub fn get_scrollWidth(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_scrollWidth(state);
    }

    pub fn get_scrollHeight(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_scrollHeight(state);
    }

    pub fn get_clientTop(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_clientTop(state);
    }

    pub fn get_clientLeft(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_clientLeft(state);
    }

    pub fn get_clientWidth(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_clientWidth(state);
    }

    pub fn get_clientHeight(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_clientHeight(state);
    }

    pub fn get_currentCSSZoom(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_currentCSSZoom(state);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_role(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_role(state);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_role(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_role(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-activedescendant"]
    pub fn get_ariaActiveDescendantElement(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaActiveDescendantElement(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-activedescendant"]
    pub fn set_ariaActiveDescendantElement(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaActiveDescendantElement(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-atomic"]
    pub fn get_ariaAtomic(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaAtomic(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-atomic"]
    pub fn set_ariaAtomic(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaAtomic(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-autocomplete"]
    pub fn get_ariaAutoComplete(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaAutoComplete(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-autocomplete"]
    pub fn set_ariaAutoComplete(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaAutoComplete(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-braillelabel"]
    pub fn get_ariaBrailleLabel(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaBrailleLabel(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-braillelabel"]
    pub fn set_ariaBrailleLabel(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaBrailleLabel(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-brailleroledescription"]
    pub fn get_ariaBrailleRoleDescription(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaBrailleRoleDescription(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-brailleroledescription"]
    pub fn set_ariaBrailleRoleDescription(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaBrailleRoleDescription(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-busy"]
    pub fn get_ariaBusy(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaBusy(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-busy"]
    pub fn set_ariaBusy(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaBusy(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-checked"]
    pub fn get_ariaChecked(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaChecked(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-checked"]
    pub fn set_ariaChecked(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaChecked(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-colcount"]
    pub fn get_ariaColCount(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaColCount(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-colcount"]
    pub fn set_ariaColCount(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaColCount(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-colindex"]
    pub fn get_ariaColIndex(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaColIndex(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-colindex"]
    pub fn set_ariaColIndex(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaColIndex(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-colindextext"]
    pub fn get_ariaColIndexText(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaColIndexText(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-colindextext"]
    pub fn set_ariaColIndexText(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaColIndexText(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-colspan"]
    pub fn get_ariaColSpan(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaColSpan(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-colspan"]
    pub fn set_ariaColSpan(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaColSpan(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-controls"]
    pub fn get_ariaControlsElements(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaControlsElements(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-controls"]
    pub fn set_ariaControlsElements(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaControlsElements(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-current"]
    pub fn get_ariaCurrent(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaCurrent(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-current"]
    pub fn set_ariaCurrent(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaCurrent(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-describedby"]
    pub fn get_ariaDescribedByElements(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaDescribedByElements(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-describedby"]
    pub fn set_ariaDescribedByElements(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaDescribedByElements(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-description"]
    pub fn get_ariaDescription(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaDescription(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-description"]
    pub fn set_ariaDescription(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaDescription(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-details"]
    pub fn get_ariaDetailsElements(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaDetailsElements(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-details"]
    pub fn set_ariaDetailsElements(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaDetailsElements(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-disabled"]
    pub fn get_ariaDisabled(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaDisabled(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-disabled"]
    pub fn set_ariaDisabled(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaDisabled(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-errormessage"]
    pub fn get_ariaErrorMessageElements(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaErrorMessageElements(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-errormessage"]
    pub fn set_ariaErrorMessageElements(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaErrorMessageElements(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-expanded"]
    pub fn get_ariaExpanded(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaExpanded(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-expanded"]
    pub fn set_ariaExpanded(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaExpanded(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-flowto"]
    pub fn get_ariaFlowToElements(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaFlowToElements(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-flowto"]
    pub fn set_ariaFlowToElements(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaFlowToElements(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-haspopup"]
    pub fn get_ariaHasPopup(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaHasPopup(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-haspopup"]
    pub fn set_ariaHasPopup(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaHasPopup(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-hidden"]
    pub fn get_ariaHidden(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaHidden(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-hidden"]
    pub fn set_ariaHidden(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaHidden(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-invalid"]
    pub fn get_ariaInvalid(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaInvalid(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-invalid"]
    pub fn set_ariaInvalid(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaInvalid(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-keyshortcuts"]
    pub fn get_ariaKeyShortcuts(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaKeyShortcuts(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-keyshortcuts"]
    pub fn set_ariaKeyShortcuts(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaKeyShortcuts(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-label"]
    pub fn get_ariaLabel(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaLabel(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-label"]
    pub fn set_ariaLabel(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaLabel(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-labelledby"]
    pub fn get_ariaLabelledByElements(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaLabelledByElements(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-labelledby"]
    pub fn set_ariaLabelledByElements(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaLabelledByElements(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-level"]
    pub fn get_ariaLevel(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaLevel(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-level"]
    pub fn set_ariaLevel(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaLevel(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-live"]
    pub fn get_ariaLive(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaLive(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-live"]
    pub fn set_ariaLive(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaLive(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-modal"]
    pub fn get_ariaModal(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaModal(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-modal"]
    pub fn set_ariaModal(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaModal(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-multiline"]
    pub fn get_ariaMultiLine(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaMultiLine(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-multiline"]
    pub fn set_ariaMultiLine(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaMultiLine(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-multiselectable"]
    pub fn get_ariaMultiSelectable(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaMultiSelectable(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-multiselectable"]
    pub fn set_ariaMultiSelectable(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaMultiSelectable(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-orientation"]
    pub fn get_ariaOrientation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaOrientation(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-orientation"]
    pub fn set_ariaOrientation(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaOrientation(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-owns"]
    pub fn get_ariaOwnsElements(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaOwnsElements(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-owns"]
    pub fn set_ariaOwnsElements(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaOwnsElements(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-placeholder"]
    pub fn get_ariaPlaceholder(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaPlaceholder(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-placeholder"]
    pub fn set_ariaPlaceholder(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaPlaceholder(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-posinset"]
    pub fn get_ariaPosInSet(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaPosInSet(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-posinset"]
    pub fn set_ariaPosInSet(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaPosInSet(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-pressed"]
    pub fn get_ariaPressed(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaPressed(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-pressed"]
    pub fn set_ariaPressed(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaPressed(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-readonly"]
    pub fn get_ariaReadOnly(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaReadOnly(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-readonly"]
    pub fn set_ariaReadOnly(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaReadOnly(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-relevant"]
    pub fn get_ariaRelevant(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaRelevant(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-relevant"]
    pub fn set_ariaRelevant(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaRelevant(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-required"]
    pub fn get_ariaRequired(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaRequired(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-required"]
    pub fn set_ariaRequired(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaRequired(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-roledescription"]
    pub fn get_ariaRoleDescription(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaRoleDescription(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-roledescription"]
    pub fn set_ariaRoleDescription(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaRoleDescription(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-rowcount"]
    pub fn get_ariaRowCount(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaRowCount(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-rowcount"]
    pub fn set_ariaRowCount(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaRowCount(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-rowindex"]
    pub fn get_ariaRowIndex(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaRowIndex(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-rowindex"]
    pub fn set_ariaRowIndex(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaRowIndex(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-rowindextext"]
    pub fn get_ariaRowIndexText(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaRowIndexText(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-rowindextext"]
    pub fn set_ariaRowIndexText(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaRowIndexText(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-rowspan"]
    pub fn get_ariaRowSpan(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaRowSpan(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-rowspan"]
    pub fn set_ariaRowSpan(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaRowSpan(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-selected"]
    pub fn get_ariaSelected(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaSelected(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-selected"]
    pub fn set_ariaSelected(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaSelected(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-setsize"]
    pub fn get_ariaSetSize(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaSetSize(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-setsize"]
    pub fn set_ariaSetSize(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaSetSize(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-sort"]
    pub fn get_ariaSort(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaSort(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-sort"]
    pub fn set_ariaSort(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaSort(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-valuemax"]
    pub fn get_ariaValueMax(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaValueMax(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-valuemax"]
    pub fn set_ariaValueMax(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaValueMax(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-valuemin"]
    pub fn get_ariaValueMin(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaValueMin(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-valuemin"]
    pub fn set_ariaValueMin(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaValueMin(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-valuenow"]
    pub fn get_ariaValueNow(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaValueNow(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-valuenow"]
    pub fn set_ariaValueNow(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaValueNow(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-valuetext"]
    pub fn get_ariaValueText(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ariaValueText(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-valuetext"]
    pub fn set_ariaValueText(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_ariaValueText(state, value);
    }

    pub fn get_regionOverset(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_regionOverset(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_children(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_children) |cached| {
            return cached;
        }
        const value = HTMLAudioElementImpl.get_children(state);
        state.cached_children = value;
        return value;
    }

    pub fn get_firstElementChild(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_firstElementChild(state);
    }

    pub fn get_lastElementChild(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_lastElementChild(state);
    }

    pub fn get_childElementCount(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_childElementCount(state);
    }

    pub fn get_previousElementSibling(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_previousElementSibling(state);
    }

    pub fn get_nextElementSibling(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_nextElementSibling(state);
    }

    pub fn get_assignedSlot(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_assignedSlot(state);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_title(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_title(state);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_title(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_title(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_lang(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_lang(state);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_lang(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_lang(state, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_translate(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_translate(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_translate(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_translate(state, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_dir(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_dir(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_dir(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_dir(state, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_hidden(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_hidden(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_hidden(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_hidden(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_inert(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_inert(state);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_inert(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_inert(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_accessKey(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_accessKey(state);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_accessKey(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_accessKey(state, value);
    }

    pub fn get_accessKeyLabel(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_accessKeyLabel(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_draggable(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_draggable(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_draggable(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_draggable(state, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_spellcheck(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_spellcheck(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_spellcheck(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_spellcheck(state, value);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn get_writingSuggestions(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_writingSuggestions(state);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn set_writingSuggestions(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_writingSuggestions(state, value);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn get_autocapitalize(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_autocapitalize(state);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn set_autocapitalize(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_autocapitalize(state, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_autocorrect(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_autocorrect(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_autocorrect(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_autocorrect(state, value);
    }

    /// Extended attributes: [CEReactions], [LegacyNullToEmptyString]
    pub fn get_innerText(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_innerText(state);
    }

    /// Extended attributes: [CEReactions], [LegacyNullToEmptyString]
    pub fn set_innerText(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_innerText(state, value);
    }

    /// Extended attributes: [CEReactions], [LegacyNullToEmptyString]
    pub fn get_outerText(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_outerText(state);
    }

    /// Extended attributes: [CEReactions], [LegacyNullToEmptyString]
    pub fn set_outerText(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_outerText(state, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_popover(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_popover(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_popover(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_popover(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect], [ReflectRange=(0,8)]
    pub fn get_headingOffset(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_headingOffset(state);
    }

    /// Extended attributes: [CEReactions], [Reflect], [ReflectRange=(0,8)]
    pub fn set_headingOffset(instance: *runtime.Instance, value: u32) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_headingOffset(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_headingReset(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_headingReset(state);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_headingReset(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_headingReset(state, value);
    }

    pub fn get_editContext(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_editContext(state);
    }

    pub fn set_editContext(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_editContext(state, value);
    }

    pub fn get_scrollParent(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_scrollParent(state);
    }

    pub fn get_offsetParent(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_offsetParent(state);
    }

    pub fn get_offsetTop(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_offsetTop(state);
    }

    pub fn get_offsetLeft(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_offsetLeft(state);
    }

    pub fn get_offsetWidth(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_offsetWidth(state);
    }

    pub fn get_offsetHeight(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_offsetHeight(state);
    }

    /// Extended attributes: [SameObject], [PutForwards=cssText]
    pub fn get_style(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_style) |cached| {
            return cached;
        }
        const value = HTMLAudioElementImpl.get_style(state);
        state.cached_style = value;
        return value;
    }

    pub fn get_style(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_style(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_attributeStyleMap(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_attributeStyleMap) |cached| {
            return cached;
        }
        const value = HTMLAudioElementImpl.get_attributeStyleMap(state);
        state.cached_attributeStyleMap = value;
        return value;
    }

    pub fn get_onabort(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onabort(state);
    }

    pub fn set_onabort(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onabort(state, value);
    }

    pub fn get_onauxclick(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onauxclick(state);
    }

    pub fn set_onauxclick(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onauxclick(state, value);
    }

    pub fn get_onbeforeinput(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onbeforeinput(state);
    }

    pub fn set_onbeforeinput(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onbeforeinput(state, value);
    }

    pub fn get_onbeforematch(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onbeforematch(state);
    }

    pub fn set_onbeforematch(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onbeforematch(state, value);
    }

    pub fn get_onbeforetoggle(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onbeforetoggle(state);
    }

    pub fn set_onbeforetoggle(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onbeforetoggle(state, value);
    }

    pub fn get_onblur(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onblur(state);
    }

    pub fn set_onblur(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onblur(state, value);
    }

    pub fn get_oncancel(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_oncancel(state);
    }

    pub fn set_oncancel(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_oncancel(state, value);
    }

    pub fn get_oncanplay(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_oncanplay(state);
    }

    pub fn set_oncanplay(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_oncanplay(state, value);
    }

    pub fn get_oncanplaythrough(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_oncanplaythrough(state);
    }

    pub fn set_oncanplaythrough(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_oncanplaythrough(state, value);
    }

    pub fn get_onchange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onchange(state);
    }

    pub fn set_onchange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onchange(state, value);
    }

    pub fn get_onclick(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onclick(state);
    }

    pub fn set_onclick(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onclick(state, value);
    }

    pub fn get_onclose(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onclose(state);
    }

    pub fn set_onclose(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onclose(state, value);
    }

    pub fn get_oncommand(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_oncommand(state);
    }

    pub fn set_oncommand(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_oncommand(state, value);
    }

    pub fn get_oncontextlost(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_oncontextlost(state);
    }

    pub fn set_oncontextlost(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_oncontextlost(state, value);
    }

    pub fn get_oncontextmenu(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_oncontextmenu(state);
    }

    pub fn set_oncontextmenu(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_oncontextmenu(state, value);
    }

    pub fn get_oncontextrestored(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_oncontextrestored(state);
    }

    pub fn set_oncontextrestored(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_oncontextrestored(state, value);
    }

    pub fn get_oncopy(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_oncopy(state);
    }

    pub fn set_oncopy(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_oncopy(state, value);
    }

    pub fn get_oncuechange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_oncuechange(state);
    }

    pub fn set_oncuechange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_oncuechange(state, value);
    }

    pub fn get_oncut(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_oncut(state);
    }

    pub fn set_oncut(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_oncut(state, value);
    }

    pub fn get_ondblclick(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ondblclick(state);
    }

    pub fn set_ondblclick(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_ondblclick(state, value);
    }

    pub fn get_ondrag(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ondrag(state);
    }

    pub fn set_ondrag(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_ondrag(state, value);
    }

    pub fn get_ondragend(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ondragend(state);
    }

    pub fn set_ondragend(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_ondragend(state, value);
    }

    pub fn get_ondragenter(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ondragenter(state);
    }

    pub fn set_ondragenter(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_ondragenter(state, value);
    }

    pub fn get_ondragleave(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ondragleave(state);
    }

    pub fn set_ondragleave(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_ondragleave(state, value);
    }

    pub fn get_ondragover(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ondragover(state);
    }

    pub fn set_ondragover(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_ondragover(state, value);
    }

    pub fn get_ondragstart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ondragstart(state);
    }

    pub fn set_ondragstart(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_ondragstart(state, value);
    }

    pub fn get_ondrop(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ondrop(state);
    }

    pub fn set_ondrop(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_ondrop(state, value);
    }

    pub fn get_ondurationchange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ondurationchange(state);
    }

    pub fn set_ondurationchange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_ondurationchange(state, value);
    }

    pub fn get_onemptied(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onemptied(state);
    }

    pub fn set_onemptied(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onemptied(state, value);
    }

    pub fn get_onended(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onended(state);
    }

    pub fn set_onended(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onended(state, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onerror(state);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onerror(state, value);
    }

    pub fn get_onfocus(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onfocus(state);
    }

    pub fn set_onfocus(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onfocus(state, value);
    }

    pub fn get_onformdata(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onformdata(state);
    }

    pub fn set_onformdata(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onformdata(state, value);
    }

    pub fn get_oninput(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_oninput(state);
    }

    pub fn set_oninput(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_oninput(state, value);
    }

    pub fn get_oninvalid(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_oninvalid(state);
    }

    pub fn set_oninvalid(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_oninvalid(state, value);
    }

    pub fn get_onkeydown(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onkeydown(state);
    }

    pub fn set_onkeydown(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onkeydown(state, value);
    }

    pub fn get_onkeypress(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onkeypress(state);
    }

    pub fn set_onkeypress(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onkeypress(state, value);
    }

    pub fn get_onkeyup(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onkeyup(state);
    }

    pub fn set_onkeyup(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onkeyup(state, value);
    }

    pub fn get_onload(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onload(state);
    }

    pub fn set_onload(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onload(state, value);
    }

    pub fn get_onloadeddata(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onloadeddata(state);
    }

    pub fn set_onloadeddata(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onloadeddata(state, value);
    }

    pub fn get_onloadedmetadata(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onloadedmetadata(state);
    }

    pub fn set_onloadedmetadata(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onloadedmetadata(state, value);
    }

    pub fn get_onloadstart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onloadstart(state);
    }

    pub fn set_onloadstart(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onloadstart(state, value);
    }

    pub fn get_onmousedown(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onmousedown(state);
    }

    pub fn set_onmousedown(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onmousedown(state, value);
    }

    /// Extended attributes: [LegacyLenientThis]
    pub fn get_onmouseenter(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onmouseenter(state);
    }

    /// Extended attributes: [LegacyLenientThis]
    pub fn set_onmouseenter(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onmouseenter(state, value);
    }

    /// Extended attributes: [LegacyLenientThis]
    pub fn get_onmouseleave(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onmouseleave(state);
    }

    /// Extended attributes: [LegacyLenientThis]
    pub fn set_onmouseleave(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onmouseleave(state, value);
    }

    pub fn get_onmousemove(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onmousemove(state);
    }

    pub fn set_onmousemove(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onmousemove(state, value);
    }

    pub fn get_onmouseout(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onmouseout(state);
    }

    pub fn set_onmouseout(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onmouseout(state, value);
    }

    pub fn get_onmouseover(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onmouseover(state);
    }

    pub fn set_onmouseover(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onmouseover(state, value);
    }

    pub fn get_onmouseup(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onmouseup(state);
    }

    pub fn set_onmouseup(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onmouseup(state, value);
    }

    pub fn get_onpaste(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onpaste(state);
    }

    pub fn set_onpaste(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onpaste(state, value);
    }

    pub fn get_onpause(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onpause(state);
    }

    pub fn set_onpause(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onpause(state, value);
    }

    pub fn get_onplay(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onplay(state);
    }

    pub fn set_onplay(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onplay(state, value);
    }

    pub fn get_onplaying(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onplaying(state);
    }

    pub fn set_onplaying(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onplaying(state, value);
    }

    pub fn get_onprogress(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onprogress(state);
    }

    pub fn set_onprogress(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onprogress(state, value);
    }

    pub fn get_onratechange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onratechange(state);
    }

    pub fn set_onratechange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onratechange(state, value);
    }

    pub fn get_onreset(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onreset(state);
    }

    pub fn set_onreset(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onreset(state, value);
    }

    pub fn get_onresize(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onresize(state);
    }

    pub fn set_onresize(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onresize(state, value);
    }

    pub fn get_onscroll(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onscroll(state);
    }

    pub fn set_onscroll(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onscroll(state, value);
    }

    pub fn get_onscrollend(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onscrollend(state);
    }

    pub fn set_onscrollend(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onscrollend(state, value);
    }

    pub fn get_onsecuritypolicyviolation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onsecuritypolicyviolation(state);
    }

    pub fn set_onsecuritypolicyviolation(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onsecuritypolicyviolation(state, value);
    }

    pub fn get_onseeked(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onseeked(state);
    }

    pub fn set_onseeked(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onseeked(state, value);
    }

    pub fn get_onseeking(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onseeking(state);
    }

    pub fn set_onseeking(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onseeking(state, value);
    }

    pub fn get_onselect(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onselect(state);
    }

    pub fn set_onselect(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onselect(state, value);
    }

    pub fn get_onslotchange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onslotchange(state);
    }

    pub fn set_onslotchange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onslotchange(state, value);
    }

    pub fn get_onstalled(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onstalled(state);
    }

    pub fn set_onstalled(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onstalled(state, value);
    }

    pub fn get_onsubmit(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onsubmit(state);
    }

    pub fn set_onsubmit(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onsubmit(state, value);
    }

    pub fn get_onsuspend(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onsuspend(state);
    }

    pub fn set_onsuspend(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onsuspend(state, value);
    }

    pub fn get_ontimeupdate(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ontimeupdate(state);
    }

    pub fn set_ontimeupdate(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_ontimeupdate(state, value);
    }

    pub fn get_ontoggle(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ontoggle(state);
    }

    pub fn set_ontoggle(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_ontoggle(state, value);
    }

    pub fn get_onvolumechange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onvolumechange(state);
    }

    pub fn set_onvolumechange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onvolumechange(state, value);
    }

    pub fn get_onwaiting(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onwaiting(state);
    }

    pub fn set_onwaiting(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onwaiting(state, value);
    }

    pub fn get_onwebkitanimationend(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onwebkitanimationend(state);
    }

    pub fn set_onwebkitanimationend(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onwebkitanimationend(state, value);
    }

    pub fn get_onwebkitanimationiteration(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onwebkitanimationiteration(state);
    }

    pub fn set_onwebkitanimationiteration(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onwebkitanimationiteration(state, value);
    }

    pub fn get_onwebkitanimationstart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onwebkitanimationstart(state);
    }

    pub fn set_onwebkitanimationstart(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onwebkitanimationstart(state, value);
    }

    pub fn get_onwebkittransitionend(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onwebkittransitionend(state);
    }

    pub fn set_onwebkittransitionend(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onwebkittransitionend(state, value);
    }

    pub fn get_onwheel(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onwheel(state);
    }

    pub fn set_onwheel(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onwheel(state, value);
    }

    pub fn get_onselectstart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onselectstart(state);
    }

    pub fn set_onselectstart(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onselectstart(state, value);
    }

    pub fn get_onselectionchange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onselectionchange(state);
    }

    pub fn set_onselectionchange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onselectionchange(state, value);
    }

    pub fn get_onanimationstart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onanimationstart(state);
    }

    pub fn set_onanimationstart(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onanimationstart(state, value);
    }

    pub fn get_onanimationiteration(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onanimationiteration(state);
    }

    pub fn set_onanimationiteration(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onanimationiteration(state, value);
    }

    pub fn get_onanimationend(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onanimationend(state);
    }

    pub fn set_onanimationend(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onanimationend(state, value);
    }

    pub fn get_onanimationcancel(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onanimationcancel(state);
    }

    pub fn set_onanimationcancel(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onanimationcancel(state, value);
    }

    pub fn get_ontransitionrun(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ontransitionrun(state);
    }

    pub fn set_ontransitionrun(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_ontransitionrun(state, value);
    }

    pub fn get_ontransitionstart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ontransitionstart(state);
    }

    pub fn set_ontransitionstart(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_ontransitionstart(state, value);
    }

    pub fn get_ontransitionend(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ontransitionend(state);
    }

    pub fn set_ontransitionend(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_ontransitionend(state, value);
    }

    pub fn get_ontransitioncancel(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ontransitioncancel(state);
    }

    pub fn set_ontransitioncancel(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_ontransitioncancel(state, value);
    }

    pub fn get_onbeforexrselect(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onbeforexrselect(state);
    }

    pub fn set_onbeforexrselect(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onbeforexrselect(state, value);
    }

    pub fn get_onpointerover(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onpointerover(state);
    }

    pub fn set_onpointerover(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onpointerover(state, value);
    }

    pub fn get_onpointerenter(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onpointerenter(state);
    }

    pub fn set_onpointerenter(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onpointerenter(state, value);
    }

    pub fn get_onpointerdown(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onpointerdown(state);
    }

    pub fn set_onpointerdown(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onpointerdown(state, value);
    }

    pub fn get_onpointermove(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onpointermove(state);
    }

    pub fn set_onpointermove(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onpointermove(state, value);
    }

    /// Extended attributes: [SecureContext]
    pub fn get_onpointerrawupdate(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onpointerrawupdate(state);
    }

    /// Extended attributes: [SecureContext]
    pub fn set_onpointerrawupdate(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onpointerrawupdate(state, value);
    }

    pub fn get_onpointerup(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onpointerup(state);
    }

    pub fn set_onpointerup(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onpointerup(state, value);
    }

    pub fn get_onpointercancel(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onpointercancel(state);
    }

    pub fn set_onpointercancel(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onpointercancel(state, value);
    }

    pub fn get_onpointerout(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onpointerout(state);
    }

    pub fn set_onpointerout(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onpointerout(state, value);
    }

    pub fn get_onpointerleave(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onpointerleave(state);
    }

    pub fn set_onpointerleave(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onpointerleave(state, value);
    }

    pub fn get_ongotpointercapture(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ongotpointercapture(state);
    }

    pub fn set_ongotpointercapture(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_ongotpointercapture(state, value);
    }

    pub fn get_onlostpointercapture(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onlostpointercapture(state);
    }

    pub fn set_onlostpointercapture(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onlostpointercapture(state, value);
    }

    pub fn get_ontouchstart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ontouchstart(state);
    }

    pub fn set_ontouchstart(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_ontouchstart(state, value);
    }

    pub fn get_ontouchend(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ontouchend(state);
    }

    pub fn set_ontouchend(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_ontouchend(state, value);
    }

    pub fn get_ontouchmove(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ontouchmove(state);
    }

    pub fn set_ontouchmove(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_ontouchmove(state, value);
    }

    pub fn get_ontouchcancel(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ontouchcancel(state);
    }

    pub fn set_ontouchcancel(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_ontouchcancel(state, value);
    }

    pub fn get_onfencedtreeclick(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onfencedtreeclick(state);
    }

    pub fn set_onfencedtreeclick(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onfencedtreeclick(state, value);
    }

    pub fn get_onsnapchanged(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onsnapchanged(state);
    }

    pub fn set_onsnapchanged(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onsnapchanged(state, value);
    }

    pub fn get_onsnapchanging(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onsnapchanging(state);
    }

    pub fn set_onsnapchanging(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onsnapchanging(state, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_contentEditable(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_contentEditable(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_contentEditable(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_contentEditable(state, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_enterKeyHint(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_enterKeyHint(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_enterKeyHint(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_enterKeyHint(state, value);
    }

    pub fn get_isContentEditable(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_isContentEditable(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_inputMode(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_inputMode(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_inputMode(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_inputMode(state, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_virtualKeyboardPolicy(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_virtualKeyboardPolicy(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_virtualKeyboardPolicy(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_virtualKeyboardPolicy(state, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_dataset(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_dataset) |cached| {
            return cached;
        }
        const value = HTMLAudioElementImpl.get_dataset(state);
        state.cached_dataset = value;
        return value;
    }

    pub fn get_nonce(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_nonce(state);
    }

    pub fn set_nonce(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_nonce(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_autofocus(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_autofocus(state);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_autofocus(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_autofocus(state, value);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn get_tabIndex(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_tabIndex(state);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn set_tabIndex(instance: *runtime.Instance, value: i32) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_tabIndex(state, value);
    }

    pub fn get_error(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_error(state);
    }

    /// Extended attributes: [CEReactions], [ReflectURL]
    pub fn get_src(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_src(state);
    }

    /// Extended attributes: [CEReactions], [ReflectURL]
    pub fn set_src(instance: *runtime.Instance, value: runtime.USVString) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_src(state, value);
    }

    pub fn get_srcObject(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_srcObject(state);
    }

    pub fn set_srcObject(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_srcObject(state, value);
    }

    pub fn get_currentSrc(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_currentSrc(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_crossOrigin(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_crossOrigin(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_crossOrigin(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_crossOrigin(state, value);
    }

    pub fn get_networkState(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_networkState(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_preload(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_preload(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_preload(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_preload(state, value);
    }

    pub fn get_buffered(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_buffered(state);
    }

    pub fn get_readyState(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_readyState(state);
    }

    pub fn get_seeking(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_seeking(state);
    }

    pub fn get_currentTime(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_currentTime(state);
    }

    pub fn set_currentTime(instance: *runtime.Instance, value: f64) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_currentTime(state, value);
    }

    pub fn get_duration(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_duration(state);
    }

    pub fn get_paused(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_paused(state);
    }

    pub fn get_defaultPlaybackRate(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_defaultPlaybackRate(state);
    }

    pub fn set_defaultPlaybackRate(instance: *runtime.Instance, value: f64) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_defaultPlaybackRate(state, value);
    }

    pub fn get_playbackRate(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_playbackRate(state);
    }

    pub fn set_playbackRate(instance: *runtime.Instance, value: f64) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_playbackRate(state, value);
    }

    pub fn get_preservesPitch(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_preservesPitch(state);
    }

    pub fn set_preservesPitch(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_preservesPitch(state, value);
    }

    pub fn get_played(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_played(state);
    }

    pub fn get_seekable(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_seekable(state);
    }

    pub fn get_ended(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_ended(state);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_autoplay(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_autoplay(state);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_autoplay(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_autoplay(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_loop(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_loop(state);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_loop(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_loop(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_controls(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_controls(state);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_controls(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_controls(state, value);
    }

    pub fn get_volume(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_volume(state);
    }

    pub fn set_volume(instance: *runtime.Instance, value: f64) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_volume(state, value);
    }

    pub fn get_muted(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_muted(state);
    }

    pub fn set_muted(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_muted(state, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="muted"]
    pub fn get_defaultMuted(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_defaultMuted(state);
    }

    /// Extended attributes: [CEReactions], [Reflect="muted"]
    pub fn set_defaultMuted(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_defaultMuted(state, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_audioTracks(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_audioTracks) |cached| {
            return cached;
        }
        const value = HTMLAudioElementImpl.get_audioTracks(state);
        state.cached_audioTracks = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_videoTracks(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_videoTracks) |cached| {
            return cached;
        }
        const value = HTMLAudioElementImpl.get_videoTracks(state);
        state.cached_videoTracks = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_textTracks(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_textTracks) |cached| {
            return cached;
        }
        const value = HTMLAudioElementImpl.get_textTracks(state);
        state.cached_textTracks = value;
        return value;
    }

    /// Extended attributes: [SecureContext]
    pub fn get_sinkId(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_sinkId(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_remote(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_remote) |cached| {
            return cached;
        }
        const value = HTMLAudioElementImpl.get_remote(state);
        state.cached_remote = value;
        return value;
    }

    /// Extended attributes: [CEReactions]
    pub fn get_disableRemotePlayback(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_disableRemotePlayback(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_disableRemotePlayback(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLAudioElementImpl.set_disableRemotePlayback(state, value);
    }

    /// Extended attributes: [SecureContext]
    pub fn get_mediaKeys(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_mediaKeys(state);
    }

    pub fn get_onencrypted(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onencrypted(state);
    }

    pub fn set_onencrypted(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onencrypted(state, value);
    }

    pub fn get_onwaitingforkey(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.get_onwaitingforkey(state);
    }

    pub fn set_onwaitingforkey(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HTMLAudioElementImpl.set_onwaitingforkey(state, value);
    }

    pub fn call_isDefaultNamespace(instance: *runtime.Instance, namespace: anyopaque) bool {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_isDefaultNamespace(state, namespace);
    }

    pub fn call_getAttributeNS(instance: *runtime.Instance, namespace: anyopaque, localName: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_getAttributeNS(state, namespace, localName);
    }

    pub fn call_getAttribute(instance: *runtime.Instance, qualifiedName: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_getAttribute(state, qualifiedName);
    }

    pub fn call_hasAttribute(instance: *runtime.Instance, qualifiedName: runtime.DOMString) bool {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_hasAttribute(state, qualifiedName);
    }

    pub fn call_contains(instance: *runtime.Instance, other: anyopaque) bool {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_contains(state, other);
    }

    pub fn call_matches(instance: *runtime.Instance, selectors: runtime.DOMString) bool {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_matches(state, selectors);
    }

    pub fn call_releasePointerCapture(instance: *runtime.Instance, pointerId: i32) anyopaque {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_releasePointerCapture(state, pointerId);
    }

    /// Extended attributes: [SameObject]
    pub fn call_computedStyleMap(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.call_computedStyleMap(state);
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
            .ScrollToOptions => |arg| return HTMLAudioElementImpl.ScrollToOptions(state, arg),
            .unrestricted double_unrestricted double => |a| return HTMLAudioElementImpl.unrestricted double_unrestricted double(state, a.x, a.y),
        }
    }

    pub fn call_canPlayType(instance: *runtime.Instance, type_: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_canPlayType(state, type_);
    }

    pub fn call_togglePopover(instance: *runtime.Instance, options: anyopaque) bool {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_togglePopover(state, options);
    }

    pub fn call_getClientRects(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.call_getClientRects(state);
    }

    pub fn call_getRootNode(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_getRootNode(state, options);
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
            .ScrollToOptions => |arg| return HTMLAudioElementImpl.ScrollToOptions(state, arg),
            .unrestricted double_unrestricted double => |a| return HTMLAudioElementImpl.unrestricted double_unrestricted double(state, a.x, a.y),
        }
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_prepend(instance: *runtime.Instance, nodes: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return HTMLAudioElementImpl.call_prepend(state, nodes);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_dispatchEvent(state, event);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_replaceWith(instance: *runtime.Instance, nodes: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return HTMLAudioElementImpl.call_replaceWith(state, nodes);
    }

    pub fn call_convertQuadFromNode(instance: *runtime.Instance, quad: anyopaque, from: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_convertQuadFromNode(state, quad, from, options);
    }

    pub fn call_focus(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_focus(state, options);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_setAttributeNodeNS(instance: *runtime.Instance, attr: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return HTMLAudioElementImpl.call_setAttributeNodeNS(state, attr);
    }

    pub fn call_getAttributeNodeNS(instance: *runtime.Instance, namespace: anyopaque, localName: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_getAttributeNodeNS(state, namespace, localName);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_setAttributeNS(instance: *runtime.Instance, namespace: anyopaque, qualifiedName: runtime.DOMString, value: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return HTMLAudioElementImpl.call_setAttributeNS(state, namespace, qualifiedName, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_setAttributeNode(instance: *runtime.Instance, attr: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return HTMLAudioElementImpl.call_setAttributeNode(state, attr);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_when(state, type_, options);
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
            .ScrollToOptions => |arg| return HTMLAudioElementImpl.ScrollToOptions(state, arg),
            .unrestricted double_unrestricted double => |a| return HTMLAudioElementImpl.unrestricted double_unrestricted double(state, a.x, a.y),
        }
    }

    /// Extended attributes: [CEReactions]
    pub fn call_insertBefore(instance: *runtime.Instance, node: anyopaque, child: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return HTMLAudioElementImpl.call_insertBefore(state, node, child);
    }

    pub fn call_lookupNamespaceURI(instance: *runtime.Instance, prefix: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_lookupNamespaceURI(state, prefix);
    }

    pub fn call_addTextTrack(instance: *runtime.Instance, kind: anyopaque, label: runtime.DOMString, language: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_addTextTrack(state, kind, label, language);
    }

    pub fn call_getElementsByTagNameNS(instance: *runtime.Instance, namespace: anyopaque, localName: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_getElementsByTagNameNS(state, namespace, localName);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_replaceChildren(instance: *runtime.Instance, nodes: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return HTMLAudioElementImpl.call_replaceChildren(state, nodes);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_setSinkId(instance: *runtime.Instance, sinkId: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_setSinkId(state, sinkId);
    }

    pub fn call_getRegionFlowRanges(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.call_getRegionFlowRanges(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_removeChild(instance: *runtime.Instance, child: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return HTMLAudioElementImpl.call_removeChild(state, child);
    }

    pub fn call_focusableAreas(instance: *runtime.Instance, option: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_focusableAreas(state, option);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_normalize(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        return HTMLAudioElementImpl.call_normalize(state);
    }

    pub fn call_isEqualNode(instance: *runtime.Instance, otherNode: anyopaque) bool {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_isEqualNode(state, otherNode);
    }

    pub fn call_getBoxQuads(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_getBoxQuads(state, options);
    }

    pub fn call_convertPointFromNode(instance: *runtime.Instance, point: anyopaque, from: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_convertPointFromNode(state, point, from, options);
    }

    pub fn call_showPopover(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_showPopover(state, options);
    }

    pub fn call_hidePopover(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.call_hidePopover(state);
    }

    pub fn call_captureStream(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.call_captureStream(state);
    }

    pub fn call_getAnimations(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_getAnimations(state, options);
    }

    pub fn call_getElementsByClassName(instance: *runtime.Instance, classNames: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_getElementsByClassName(state, classNames);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_insertAdjacentElement(instance: *runtime.Instance, where: runtime.DOMString, element: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return HTMLAudioElementImpl.call_insertAdjacentElement(state, where, element);
    }

    pub fn call_webkitMatchesSelector(instance: *runtime.Instance, selectors: runtime.DOMString) bool {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_webkitMatchesSelector(state, selectors);
    }

    pub fn call_spatialNavigationSearch(instance: *runtime.Instance, dir: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_spatialNavigationSearch(state, dir, options);
    }

    pub fn call_getElementsByTagName(instance: *runtime.Instance, qualifiedName: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_getElementsByTagName(state, qualifiedName);
    }

    pub fn call_querySelector(instance: *runtime.Instance, selectors: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_querySelector(state, selectors);
    }

    pub fn call_compareDocumentPosition(instance: *runtime.Instance, other: anyopaque) u16 {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_compareDocumentPosition(state, other);
    }

    pub fn call_closest(instance: *runtime.Instance, selectors: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_closest(state, selectors);
    }

    pub fn call_getSpatialNavigationContainer(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.call_getSpatialNavigationContainer(state);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_remove(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        return HTMLAudioElementImpl.call_remove(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_removeAttribute(instance: *runtime.Instance, qualifiedName: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return HTMLAudioElementImpl.call_removeAttribute(state, qualifiedName);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_removeEventListener(state, type_, callback, options);
    }

    pub fn call_convertRectFromNode(instance: *runtime.Instance, rect: anyopaque, from: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_convertRectFromNode(state, rect, from, options);
    }

    /// Extended attributes: [CEReactions], [NewObject]
    pub fn call_cloneNode(instance: *runtime.Instance, subtree: bool) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        // [NewObject] - Caller owns the returned object
        
        return HTMLAudioElementImpl.call_cloneNode(state, subtree);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_removeAttributeNode(instance: *runtime.Instance, attr: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return HTMLAudioElementImpl.call_removeAttributeNode(state, attr);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_removeAttributeNS(instance: *runtime.Instance, namespace: anyopaque, localName: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return HTMLAudioElementImpl.call_removeAttributeNS(state, namespace, localName);
    }

    pub fn call_insertAdjacentText(instance: *runtime.Instance, where: runtime.DOMString, data: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_insertAdjacentText(state, where, data);
    }

    pub fn call_requestFullscreen(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_requestFullscreen(state, options);
    }

    pub fn call_animate(instance: *runtime.Instance, keyframes: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_animate(state, keyframes, options);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_append(instance: *runtime.Instance, nodes: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return HTMLAudioElementImpl.call_append(state, nodes);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_moveBefore(instance: *runtime.Instance, node: anyopaque, child: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return HTMLAudioElementImpl.call_moveBefore(state, node, child);
    }

    pub fn call_getHTML(instance: *runtime.Instance, options: anyopaque) runtime.DOMString {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_getHTML(state, options);
    }

    pub fn call_getAttributeNode(instance: *runtime.Instance, qualifiedName: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_getAttributeNode(state, qualifiedName);
    }

    pub fn call_isSameNode(instance: *runtime.Instance, otherNode: anyopaque) bool {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_isSameNode(state, otherNode);
    }

    pub fn call_blur(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.call_blur(state);
    }

    pub fn call_play(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.call_play(state);
    }

    pub fn call_startViewTransition(instance: *runtime.Instance, callbackOptions: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_startViewTransition(state, callbackOptions);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_setHTMLUnsafe(instance: *runtime.Instance, html: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return HTMLAudioElementImpl.call_setHTMLUnsafe(state, html);
    }

    pub fn call_lookupPrefix(instance: *runtime.Instance, namespace: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_lookupPrefix(state, namespace);
    }

    pub fn call_scrollIntoView(instance: *runtime.Instance, arg: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_scrollIntoView(state, arg);
    }

    pub fn call_hasAttributes(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.call_hasAttributes(state);
    }

    pub fn call_getStartDate(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.call_getStartDate(state);
    }

    pub fn call_hasPointerCapture(instance: *runtime.Instance, pointerId: i32) bool {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_hasPointerCapture(state, pointerId);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_toggleAttribute(instance: *runtime.Instance, qualifiedName: runtime.DOMString, force: bool) bool {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return HTMLAudioElementImpl.call_toggleAttribute(state, qualifiedName, force);
    }

    pub fn call_pseudo(instance: *runtime.Instance, type_: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_pseudo(state, type_);
    }

    pub fn call_load(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.call_load(state);
    }

    pub fn call_fastSeek(instance: *runtime.Instance, time: f64) anyopaque {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_fastSeek(state, time);
    }

    pub fn call_pause(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.call_pause(state);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_before(instance: *runtime.Instance, nodes: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return HTMLAudioElementImpl.call_before(state, nodes);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_after(instance: *runtime.Instance, nodes: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return HTMLAudioElementImpl.call_after(state, nodes);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_setAttribute(instance: *runtime.Instance, qualifiedName: runtime.DOMString, value: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return HTMLAudioElementImpl.call_setAttribute(state, qualifiedName, value);
    }

    pub fn call_attachInternals(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.call_attachInternals(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_appendChild(instance: *runtime.Instance, node: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return HTMLAudioElementImpl.call_appendChild(state, node);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_getAttributeNames(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.call_getAttributeNames(state);
    }

    pub fn call_hasChildNodes(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.call_hasChildNodes(state);
    }

    pub fn call_attachShadow(instance: *runtime.Instance, init: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_attachShadow(state, init);
    }

    pub fn call_requestPointerLock(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_requestPointerLock(state, options);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_insertAdjacentHTML(instance: *runtime.Instance, position: runtime.DOMString, string: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return HTMLAudioElementImpl.call_insertAdjacentHTML(state, position, string);
    }

    pub fn call_hasAttributeNS(instance: *runtime.Instance, namespace: anyopaque, localName: runtime.DOMString) bool {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_hasAttributeNS(state, namespace, localName);
    }

    pub fn call_checkVisibility(instance: *runtime.Instance, options: anyopaque) bool {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_checkVisibility(state, options);
    }

    pub fn call_click(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HTMLAudioElementImpl.call_click(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_replaceChild(instance: *runtime.Instance, node: anyopaque, child: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return HTMLAudioElementImpl.call_replaceChild(state, node, child);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getBoundingClientRect(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return HTMLAudioElementImpl.call_getBoundingClientRect(state);
    }

    /// Extended attributes: [NewObject]
    pub fn call_querySelectorAll(instance: *runtime.Instance, selectors: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return HTMLAudioElementImpl.call_querySelectorAll(state, selectors);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_setMediaKeys(instance: *runtime.Instance, mediaKeys: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_setMediaKeys(state, mediaKeys);
    }

    pub fn call_setPointerCapture(instance: *runtime.Instance, pointerId: i32) anyopaque {
        const state = instance.getState(State);
        
        return HTMLAudioElementImpl.call_setPointerCapture(state, pointerId);
    }

};
