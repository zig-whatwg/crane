//! HTML "the element interface" for an element in the HTML namespace: which
//! interface an element with a given local name implements.
//!
//! Spec: https://html.spec.whatwg.org/multipage/dom.html#htmlelement (the
//! algorithm follows the HTMLElement interface's IDL)
//!
//! This module only NAMES the interface - each tag is the name of one - so it
//! needs no access to the interfaces. The factories that construct an element
//! (`Document.createHTMLElement` and the parser's) switch on the answer with
//! `@field(interfaces, @tagName(which))`, which keeps them from drifting apart:
//! there used to be two hand-written if-chains, both case-insensitive where
//! HTML's lookup is exact, both missing the obsolete elements that keep an
//! interface, and both answering HTMLUnknownElement for a custom element name.

const std = @import("std");
const names = @import("dom").names;

/// Every interface an element in the HTML namespace can implement.
pub const ElementInterface = enum {
    HTMLAnchorElement,
    HTMLAreaElement,
    HTMLAudioElement,
    HTMLBRElement,
    HTMLBaseElement,
    HTMLBodyElement,
    HTMLButtonElement,
    HTMLCanvasElement,
    HTMLDListElement,
    HTMLDataElement,
    HTMLDataListElement,
    HTMLDetailsElement,
    HTMLDialogElement,
    HTMLDirectoryElement,
    HTMLDivElement,
    HTMLElement,
    HTMLEmbedElement,
    HTMLFieldSetElement,
    HTMLFontElement,
    HTMLFormElement,
    HTMLFrameElement,
    HTMLFrameSetElement,
    HTMLHRElement,
    HTMLHeadElement,
    HTMLHeadingElement,
    HTMLHtmlElement,
    HTMLIFrameElement,
    HTMLImageElement,
    HTMLInputElement,
    HTMLLIElement,
    HTMLLabelElement,
    HTMLLegendElement,
    HTMLLinkElement,
    HTMLMapElement,
    HTMLMarqueeElement,
    HTMLMenuElement,
    HTMLMetaElement,
    HTMLMeterElement,
    HTMLModElement,
    HTMLOListElement,
    HTMLObjectElement,
    HTMLOptGroupElement,
    HTMLOptionElement,
    HTMLOutputElement,
    HTMLParagraphElement,
    HTMLParamElement,
    HTMLPictureElement,
    HTMLPreElement,
    HTMLProgressElement,
    HTMLQuoteElement,
    HTMLScriptElement,
    HTMLSelectElement,
    HTMLSelectedContentElement,
    HTMLSlotElement,
    HTMLSourceElement,
    HTMLSpanElement,
    HTMLStyleElement,
    HTMLTableCaptionElement,
    HTMLTableCellElement,
    HTMLTableColElement,
    HTMLTableElement,
    HTMLTableRowElement,
    HTMLTableSectionElement,
    HTMLTemplateElement,
    HTMLTextAreaElement,
    HTMLTimeElement,
    HTMLTitleElement,
    HTMLTrackElement,
    HTMLUListElement,
    HTMLUnknownElement,
    HTMLVideoElement,
};

/// Steps 1-4 as one exact-match table; no name appears in two of them.
const by_local_name = std.StaticStringMap(ElementInterface).initComptime(.{
    // Step 1: "If name is applet, bgsound, blink, isindex, keygen, multicol,
    // nextid, or spacer, then return HTMLUnknownElement."
    .{ "applet", .HTMLUnknownElement },
    .{ "bgsound", .HTMLUnknownElement },
    .{ "blink", .HTMLUnknownElement },
    .{ "isindex", .HTMLUnknownElement },
    .{ "keygen", .HTMLUnknownElement },
    .{ "multicol", .HTMLUnknownElement },
    .{ "nextid", .HTMLUnknownElement },
    .{ "spacer", .HTMLUnknownElement },

    // Step 2: "If name is acronym, basefont, big, center, nobr, noembed,
    // noframes, plaintext, rb, rtc, strike, or tt, then return HTMLElement."
    .{ "acronym", .HTMLElement },
    .{ "basefont", .HTMLElement },
    .{ "big", .HTMLElement },
    .{ "center", .HTMLElement },
    .{ "nobr", .HTMLElement },
    .{ "noembed", .HTMLElement },
    .{ "noframes", .HTMLElement },
    .{ "plaintext", .HTMLElement },
    .{ "rb", .HTMLElement },
    .{ "rtc", .HTMLElement },
    .{ "strike", .HTMLElement },
    .{ "tt", .HTMLElement },

    // Step 3: "If name is listing or xmp, then return HTMLPreElement."
    .{ "listing", .HTMLPreElement },
    .{ "xmp", .HTMLPreElement },

    // Step 4: "if this specification defines an interface appropriate for the
    // element type corresponding to the local name name, then return that
    // interface" - the index of element interfaces...
    .{ "a", .HTMLAnchorElement },
    .{ "abbr", .HTMLElement },
    .{ "address", .HTMLElement },
    .{ "area", .HTMLAreaElement },
    .{ "article", .HTMLElement },
    .{ "aside", .HTMLElement },
    .{ "audio", .HTMLAudioElement },
    .{ "b", .HTMLElement },
    .{ "base", .HTMLBaseElement },
    .{ "bdi", .HTMLElement },
    .{ "bdo", .HTMLElement },
    .{ "blockquote", .HTMLQuoteElement },
    .{ "body", .HTMLBodyElement },
    .{ "br", .HTMLBRElement },
    .{ "button", .HTMLButtonElement },
    .{ "canvas", .HTMLCanvasElement },
    .{ "caption", .HTMLTableCaptionElement },
    .{ "cite", .HTMLElement },
    .{ "code", .HTMLElement },
    .{ "col", .HTMLTableColElement },
    .{ "colgroup", .HTMLTableColElement },
    .{ "data", .HTMLDataElement },
    .{ "datalist", .HTMLDataListElement },
    .{ "dd", .HTMLElement },
    .{ "del", .HTMLModElement },
    .{ "details", .HTMLDetailsElement },
    .{ "dfn", .HTMLElement },
    .{ "dialog", .HTMLDialogElement },
    .{ "div", .HTMLDivElement },
    .{ "dl", .HTMLDListElement },
    .{ "dt", .HTMLElement },
    .{ "em", .HTMLElement },
    .{ "embed", .HTMLEmbedElement },
    .{ "fieldset", .HTMLFieldSetElement },
    .{ "figcaption", .HTMLElement },
    .{ "figure", .HTMLElement },
    .{ "footer", .HTMLElement },
    .{ "form", .HTMLFormElement },
    .{ "h1", .HTMLHeadingElement },
    .{ "h2", .HTMLHeadingElement },
    .{ "h3", .HTMLHeadingElement },
    .{ "h4", .HTMLHeadingElement },
    .{ "h5", .HTMLHeadingElement },
    .{ "h6", .HTMLHeadingElement },
    .{ "head", .HTMLHeadElement },
    .{ "header", .HTMLElement },
    .{ "hgroup", .HTMLElement },
    .{ "hr", .HTMLHRElement },
    .{ "html", .HTMLHtmlElement },
    .{ "i", .HTMLElement },
    .{ "iframe", .HTMLIFrameElement },
    .{ "img", .HTMLImageElement },
    .{ "input", .HTMLInputElement },
    .{ "ins", .HTMLModElement },
    .{ "kbd", .HTMLElement },
    .{ "label", .HTMLLabelElement },
    .{ "legend", .HTMLLegendElement },
    .{ "li", .HTMLLIElement },
    .{ "link", .HTMLLinkElement },
    .{ "main", .HTMLElement },
    .{ "map", .HTMLMapElement },
    .{ "mark", .HTMLElement },
    .{ "menu", .HTMLMenuElement },
    .{ "meta", .HTMLMetaElement },
    .{ "meter", .HTMLMeterElement },
    .{ "nav", .HTMLElement },
    .{ "noscript", .HTMLElement },
    .{ "object", .HTMLObjectElement },
    .{ "ol", .HTMLOListElement },
    .{ "optgroup", .HTMLOptGroupElement },
    .{ "option", .HTMLOptionElement },
    .{ "output", .HTMLOutputElement },
    .{ "p", .HTMLParagraphElement },
    .{ "picture", .HTMLPictureElement },
    .{ "pre", .HTMLPreElement },
    .{ "progress", .HTMLProgressElement },
    .{ "q", .HTMLQuoteElement },
    .{ "rp", .HTMLElement },
    .{ "rt", .HTMLElement },
    .{ "ruby", .HTMLElement },
    .{ "s", .HTMLElement },
    .{ "samp", .HTMLElement },
    .{ "search", .HTMLElement },
    .{ "script", .HTMLScriptElement },
    .{ "section", .HTMLElement },
    .{ "select", .HTMLSelectElement },
    .{ "selectedcontent", .HTMLSelectedContentElement },
    .{ "slot", .HTMLSlotElement },
    .{ "small", .HTMLElement },
    .{ "source", .HTMLSourceElement },
    .{ "span", .HTMLSpanElement },
    .{ "strong", .HTMLElement },
    .{ "style", .HTMLStyleElement },
    .{ "sub", .HTMLElement },
    .{ "summary", .HTMLElement },
    .{ "sup", .HTMLElement },
    .{ "table", .HTMLTableElement },
    .{ "tbody", .HTMLTableSectionElement },
    .{ "td", .HTMLTableCellElement },
    .{ "template", .HTMLTemplateElement },
    .{ "textarea", .HTMLTextAreaElement },
    .{ "tfoot", .HTMLTableSectionElement },
    .{ "th", .HTMLTableCellElement },
    .{ "thead", .HTMLTableSectionElement },
    .{ "time", .HTMLTimeElement },
    .{ "title", .HTMLTitleElement },
    .{ "tr", .HTMLTableRowElement },
    .{ "track", .HTMLTrackElement },
    .{ "u", .HTMLElement },
    .{ "ul", .HTMLUListElement },
    .{ "var", .HTMLElement },
    .{ "video", .HTMLVideoElement },
    .{ "wbr", .HTMLElement },
    // ...and the obsolete elements § 16.3 still gives an interface ("The
    // marquee element must implement the HTMLMarqueeElement interface", ...).
    .{ "dir", .HTMLDirectoryElement },
    .{ "font", .HTMLFontElement },
    .{ "frame", .HTMLFrameElement },
    .{ "frameset", .HTMLFrameSetElement },
    .{ "marquee", .HTMLMarqueeElement },
    .{ "param", .HTMLParamElement },
});

/// The element interface for an element with local name `name` in the HTML
/// namespace. `name` is matched exactly: the parser and createElement() in an
/// HTML document have already lowercased it, and createElementNS() has not -
/// `createElementNS(htmlNS, "DIV")` is an HTMLUnknownElement.
pub fn forLocalName(name: []const u8) ElementInterface {
    // Steps 1-4.
    if (by_local_name.get(name)) |which| return which;

    // Step 5: "If other applicable specifications define an appropriate
    // interface for name, then return the interface they define." None does
    // for an element in the HTML namespace here.

    // Step 6: "If name is a valid custom element name, then return
    // HTMLElement."
    if (names.isValidCustomElementName(name)) return .HTMLElement;

    // Step 7: "Return HTMLUnknownElement."
    return .HTMLUnknownElement;
}

const testing = std.testing;

test "element interface: steps 1-3 name their interface" {
    try testing.expectEqual(ElementInterface.HTMLUnknownElement, forLocalName("applet"));
    try testing.expectEqual(ElementInterface.HTMLUnknownElement, forLocalName("keygen"));
    try testing.expectEqual(ElementInterface.HTMLElement, forLocalName("center"));
    try testing.expectEqual(ElementInterface.HTMLElement, forLocalName("tt"));
    try testing.expectEqual(ElementInterface.HTMLPreElement, forLocalName("listing"));
    try testing.expectEqual(ElementInterface.HTMLPreElement, forLocalName("xmp"));
}

test "element interface: step 4 covers the obsolete elements that keep one" {
    try testing.expectEqual(ElementInterface.HTMLMarqueeElement, forLocalName("marquee"));
    try testing.expectEqual(ElementInterface.HTMLFrameSetElement, forLocalName("frameset"));
    try testing.expectEqual(ElementInterface.HTMLFrameElement, forLocalName("frame"));
    try testing.expectEqual(ElementInterface.HTMLDirectoryElement, forLocalName("dir"));
    try testing.expectEqual(ElementInterface.HTMLFontElement, forLocalName("font"));
    try testing.expectEqual(ElementInterface.HTMLParamElement, forLocalName("param"));
    try testing.expectEqual(ElementInterface.HTMLSelectedContentElement, forLocalName("selectedcontent"));
}

test "element interface: the lookup is exact, not case-insensitive" {
    try testing.expectEqual(ElementInterface.HTMLDivElement, forLocalName("div"));
    try testing.expectEqual(ElementInterface.HTMLUnknownElement, forLocalName("DIV"));
    try testing.expectEqual(ElementInterface.HTMLUnknownElement, forLocalName("Div"));
}

test "element interface: a valid custom element name is HTMLElement (step 6)" {
    try testing.expectEqual(ElementInterface.HTMLElement, forLocalName("x-foo"));
    try testing.expectEqual(ElementInterface.HTMLElement, forLocalName("my-element"));
    // Not valid custom element names: uppercase, reserved, no hyphen.
    try testing.expectEqual(ElementInterface.HTMLUnknownElement, forLocalName("X-foo"));
    try testing.expectEqual(ElementInterface.HTMLUnknownElement, forLocalName("annotation-xml"));
    try testing.expectEqual(ElementInterface.HTMLUnknownElement, forLocalName("foo"));
}

test "element interface: every name longer than any table entry still resolves" {
    // The old factories lowercased into a 64-byte buffer and matched the
    // truncation; the table matches the whole name.
    const long = "a-" ++ "x" ** 100;
    try testing.expectEqual(ElementInterface.HTMLElement, forLocalName(long));
    const long_unknown = "div" ++ "x" ** 100;
    try testing.expectEqual(ElementInterface.HTMLUnknownElement, forLocalName(long_unknown));
}
