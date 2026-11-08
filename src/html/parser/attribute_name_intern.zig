//! The attribute qualified names every element shares (lane perf3, D1).
//!
//! An attribute's name record (`dom.element_data.QualifiedName`) is static
//! for a name in these tables and the attribute's own otherwise. Blink and
//! WebKit do the same: their QualifiedNames for the HTML, SVG, MathML, XLink
//! and XML attribute names are made once at start-up and shared by every
//! element (Blink core/html_names.json5 / svg_names.json5 -> html_names.h,
//! WebKit html/HTMLAttributeNames.in), so an Attribute is a pointer to its
//! name and its value. Here the tables are `const` data in the binary: no
//! process state, nothing to install.
//!
//! The names (an exact, case-sensitive match - an attribute's local name
//! keeps its case: setAttributeNS(null, "FOO") is not "foo"):
//! - HTML's attribute index (HTML "Index" > "Attributes", both lists) and
//!   the event handler content attributes of GlobalEventHandlers,
//!   WindowEventHandlers and DocumentAndElementEventHandlers (specs/idl);
//! - the obsolete and presentational attributes HTML 15 "Rendering" and 16
//!   "Obsolete features" still read (align, bgcolor, border, ...);
//! - ARIA's role and aria-* states and properties (WAI-ARIA 1.3);
//! - the SVG and MathML names the parser makes ("adjust SVG attributes",
//!   "adjust MathML attributes") and common SVG presentation attributes;
//! - in a namespace, the parser's "adjust foreign attributes" table
//!   (xlink:*, xml:*, xmlns), which is the only way a name with a namespace
//!   or prefix is static.
//!
//! Spec: https://html.spec.whatwg.org/multipage/indices.html#attributes-3
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html#adjust-foreign-attributes

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");

const QualifiedName = dom.element_data.QualifiedName;

/// The known attribute local names in no namespace. Distinct (a test checks).
pub const names = [_][]const u8{
    // HTML's attribute index.
    "abbr",                        "accept",                          "accept-charset",           "accesskey",                 "action",
    "allow",                       "allowfullscreen",                 "alpha",                    "alt",                       "as",
    "async",                       "autocapitalize",                  "autocomplete",             "autocorrect",               "autofocus",
    "autoplay",                    "blocking",                        "charset",                  "checked",                   "cite",
    "class",                       "closedby",                        "color",                    "colorspace",                "cols",
    "colspan",                     "command",                         "commandfor",               "content",                   "contenteditable",
    "controls",                    "coords",                          "crossorigin",              "data",                      "datetime",
    "decoding",                    "default",                         "defer",                    "dir",                       "dirname",
    "disabled",                    "download",                        "draggable",                "enctype",                   "enterkeyhint",
    "fetchpriority",               "for",                             "form",                     "formaction",                "formenctype",
    "formmethod",                  "formnovalidate",                  "formtarget",               "headers",                   "headingoffset",
    "headingreset",                "height",                          "hidden",                   "high",                      "href",
    "hreflang",                    "http-equiv",                      "id",                       "imagesizes",                "imagesrcset",
    "inert",                       "inputmode",                       "integrity",                "is",                        "ismap",
    "itemid",                      "itemprop",                        "itemref",                  "itemscope",                 "itemtype",
    "kind",                        "label",                           "lang",                     "list",                      "loading",
    "loop",                        "low",                             "max",                      "maxlength",                 "media",
    "method",                      "min",                             "minlength",                "multiple",                  "muted",
    "name",                        "nomodule",                        "nonce",                    "novalidate",                "open",
    "optimum",                     "pattern",                         "ping",                     "placeholder",               "playsinline",
    "popover",                     "popovertarget",                   "popovertargetaction",      "poster",                    "preload",
    "readonly",                    "referrerpolicy",                  "rel",                      "required",                  "reversed",
    "rows",                        "rowspan",                         "sandbox",                  "scope",                     "selected",
    "shadowrootclonable",          "shadowrootcustomelementregistry", "shadowrootdelegatesfocus", "shadowrootmode",            "shadowrootserializable",
    "shadowrootslotassignment",    "shape",                           "size",                     "sizes",                     "slot",
    "span",                        "spellcheck",                      "src",                      "srcdoc",                    "srclang",
    "srcset",                      "start",                           "step",                     "style",                     "tabindex",
    "target",                      "title",                           "translate",                "type",                      "usemap",
    "value",                       "width",                           "wrap",                     "writingsuggestions",

    // Event handler content attributes.
           "onabort",
    "onafterprint",                "onanimationcancel",               "onanimationend",           "onanimationiteration",      "onanimationstart",
    "onauxclick",                  "onbeforeinput",                   "onbeforematch",            "onbeforeprint",             "onbeforetoggle",
    "onbeforeunload",              "onblur",                          "oncancel",                 "oncanplay",                 "oncanplaythrough",
    "onchange",                    "onclick",                         "onclose",                  "oncommand",                 "oncontextlost",
    "oncontextmenu",               "oncontextrestored",               "oncopy",                   "oncuechange",               "oncut",
    "ondblclick",                  "ondrag",                          "ondragend",                "ondragenter",               "ondragleave",
    "ondragover",                  "ondragstart",                     "ondrop",                   "ondurationchange",          "onemptied",
    "onended",                     "onerror",                         "onfocus",                  "onformdata",                "ongotpointercapture",
    "onhashchange",                "oninput",                         "oninvalid",                "onkeydown",                 "onkeypress",
    "onkeyup",                     "onlanguagechange",                "onload",                   "onloadeddata",              "onloadedmetadata",
    "onloadstart",                 "onlostpointercapture",            "onmessage",                "onmessageerror",            "onmousedown",
    "onmouseenter",                "onmouseleave",                    "onmousemove",              "onmouseout",                "onmouseover",
    "onmouseup",                   "onoffline",                       "ononline",                 "onpagehide",                "onpagereveal",
    "onpageshow",                  "onpageswap",                      "onpaste",                  "onpause",                   "onplay",
    "onplaying",                   "onpointercancel",                 "onpointerdown",            "onpointerenter",            "onpointerleave",
    "onpointermove",               "onpointerout",                    "onpointerover",            "onpointerrawupdate",        "onpointerup",
    "onpopstate",                  "onprogress",                      "onratechange",             "onrejectionhandled",        "onreset",
    "onresize",                    "onscroll",                        "onscrollend",              "onsecuritypolicyviolation", "onseeked",
    "onseeking",                   "onselect",                        "onselectionchange",        "onselectstart",             "onslotchange",
    "onstalled",                   "onstorage",                       "onsubmit",                 "onsuspend",                 "ontimeupdate",
    "ontoggle",                    "ontouchcancel",                   "ontouchend",               "ontouchmove",               "ontouchstart",
    "ontransitioncancel",          "ontransitionend",                 "ontransitionrun",          "ontransitionstart",         "onunhandledrejection",
    "onunload",                    "onvolumechange",                  "onwaiting",                "onwebkitanimationend",      "onwebkitanimationiteration",
    "onwebkitanimationstart",      "onwebkittransitionend",           "onwheel",

    // Obsolete and presentational attributes HTML 15 and 16 still read.
                     "align",                     "alink",
    "archive",                     "axis",                            "background",               "bgcolor",                   "border",
    "bordercolor",                 "bottommargin",                    "cellpadding",              "cellspacing",               "char",
    "charoff",                     "classid",                         "clear",                    "code",                      "codebase",
    "codetype",                    "compact",                         "declare",                  "direction",                 "event",
    "face",                        "frame",                           "frameborder",              "hspace",                    "language",
    "leftmargin",                  "link",                            "longdesc",                 "lowsrc",                    "manifest",
    "marginheight",                "marginwidth",                     "nohref",                   "noshade",                   "nowrap",
    "profile",                     "rev",                             "rightmargin",              "rules",                     "scheme",
    "scrollamount",                "scrolldelay",                     "scrolling",                "standby",                   "summary",
    "text",                        "topmargin",                       "truespeed",                "valign",                    "valuetype",
    "version",                     "vlink",                           "vspace",                   "behavior",                  "allowtransparency",

    // ARIA.
    "role",                        "aria-activedescendant",           "aria-atomic",              "aria-autocomplete",         "aria-braillelabel",
    "aria-brailleroledescription", "aria-busy",                       "aria-checked",             "aria-colcount",             "aria-colindex",
    "aria-colindextext",           "aria-colspan",                    "aria-controls",            "aria-current",              "aria-describedby",
    "aria-description",            "aria-details",                    "aria-disabled",            "aria-dropeffect",           "aria-errormessage",
    "aria-expanded",               "aria-flowto",                     "aria-grabbed",             "aria-haspopup",             "aria-hidden",
    "aria-invalid",                "aria-keyshortcuts",               "aria-label",               "aria-labelledby",           "aria-level",
    "aria-live",                   "aria-modal",                      "aria-multiline",           "aria-multiselectable",      "aria-orientation",
    "aria-owns",                   "aria-placeholder",                "aria-posinset",            "aria-pressed",              "aria-readonly",
    "aria-relevant",               "aria-required",                   "aria-roledescription",     "aria-rowcount",             "aria-rowindex",
    "aria-rowindextext",           "aria-rowspan",                    "aria-selected",            "aria-setsize",              "aria-sort",
    "aria-valuemax",               "aria-valuemin",                   "aria-valuenow",            "aria-valuetext",

    // RDFa and Open Graph names real pages carry on meta and other elements.
               "property",
    "about",                       "typeof",                          "vocab",                    "resource",                  "prefix",

    // SVG: the names "adjust SVG attributes" makes, then common lowercase ones.
    "attributeName",               "attributeType",                   "baseFrequency",            "baseProfile",               "calcMode",
    "clipPathUnits",               "diffuseConstant",                 "edgeMode",                 "filterUnits",               "glyphRef",
    "gradientTransform",           "gradientUnits",                   "kernelMatrix",             "kernelUnitLength",          "keyPoints",
    "keySplines",                  "keyTimes",                        "lengthAdjust",             "limitingConeAngle",         "markerHeight",
    "markerUnits",                 "markerWidth",                     "maskContentUnits",         "maskUnits",                 "numOctaves",
    "pathLength",                  "patternContentUnits",             "patternTransform",         "patternUnits",              "pointsAtX",
    "pointsAtY",                   "pointsAtZ",                       "preserveAlpha",            "preserveAspectRatio",       "primitiveUnits",
    "refX",                        "refY",                            "repeatCount",              "repeatDur",                 "requiredExtensions",
    "requiredFeatures",            "specularConstant",                "specularExponent",         "spreadMethod",              "startOffset",
    "stdDeviation",                "stitchTiles",                     "surfaceScale",             "systemLanguage",            "tableValues",
    "targetX",                     "targetY",                         "textLength",               "viewBox",                   "viewTarget",
    "xChannelSelector",            "yChannelSelector",                "zoomAndPan",               "d",                         "fill",
    "stroke",                      "x",                               "y",                        "x1",                        "y1",
    "x2",                          "y2",                              "cx",                       "cy",                        "r",
    "rx",                          "ry",                              "dx",                       "dy",                        "fr",
    "fx",                          "fy",                              "points",                   "transform",                 "opacity",
    "fill-opacity",                "fill-rule",                       "stroke-width",             "stroke-opacity",            "stroke-linecap",
    "stroke-linejoin",             "stroke-dasharray",                "stroke-dashoffset",        "stroke-miterlimit",         "clip-path",
    "clip-rule",                   "mask",                            "filter",                   "offset",                    "stop-color",
    "stop-opacity",                "font-family",                     "font-size",                "font-weight",               "font-style",
    "font-variant",                "font-stretch",                    "text-anchor",              "text-decoration",           "dominant-baseline",
    "alignment-baseline",          "baseline-shift",                  "letter-spacing",           "word-spacing",              "writing-mode",
    "visibility",                  "display",                         "overflow",                 "color-interpolation",       "color-interpolation-filters",
    "flood-color",                 "flood-opacity",                   "lighting-color",           "marker-start",              "marker-mid",
    "marker-end",                  "vector-effect",                   "paint-order",              "pointer-events",            "shape-rendering",
    "text-rendering",              "image-rendering",                 "cursor",                   "focusable",                 "in",
    "in2",                         "result",                          "mode",                     "operator",                  "k1",
    "k2",                          "k3",                              "k4",                       "values",                    "begin",
    "dur",                         "end",                             "from",                     "to",                        "by",
    "rotate",                      "scale",                           "order",                    "radius",                    "azimuth",
    "elevation",                   "amplitude",                       "exponent",                 "intercept",                 "slope",
    "seed",                        "path",

    // MathML: "adjust MathML attributes" and the presentation attributes.
                               "definitionURL",            "mathvariant",               "displaystyle",
    "scriptlevel",                 "mathcolor",                       "mathbackground",           "mathsize",                  "linethickness",
    "stretchy",                    "symmetric",                       "largeop",                  "movablelimits",             "accent",
    "accentunder",                 "lspace",                          "rspace",                   "fence",                     "separator",
    "minsize",                     "maxsize",                         "columnspan",               "rowspacing",                "columnspacing",
    "notation",                    "encoding",
};

/// One static record per known name, in `names` order.
const records: [names.len]QualifiedName = blk: {
    var out: [names.len]QualifiedName = undefined;
    for (names, 0..) |name, i| out[i] = .{ .local_name = name };
    break :blk out;
};

/// Name -> its index in `records`.
const index: std.StaticStringMap(u16) = blk: {
    @setEvalBranchQuota(200_000);
    var kvs: [names.len]struct { []const u8, u16 } = undefined;
    for (names, 0..) |name, i| kvs[i] = .{ name, i };
    break :blk std.StaticStringMap(u16).initComptime(&kvs);
};

/// HTML "adjust foreign attributes": the names the parser puts in a
/// namespace, each with its prefix.
pub const foreign = [_]QualifiedName{
    .{ .namespace_uri = infra.namespaces.XLINK_NAMESPACE, .prefix = "xlink", .local_name = "actuate" },
    .{ .namespace_uri = infra.namespaces.XLINK_NAMESPACE, .prefix = "xlink", .local_name = "arcrole" },
    .{ .namespace_uri = infra.namespaces.XLINK_NAMESPACE, .prefix = "xlink", .local_name = "href" },
    .{ .namespace_uri = infra.namespaces.XLINK_NAMESPACE, .prefix = "xlink", .local_name = "role" },
    .{ .namespace_uri = infra.namespaces.XLINK_NAMESPACE, .prefix = "xlink", .local_name = "show" },
    .{ .namespace_uri = infra.namespaces.XLINK_NAMESPACE, .prefix = "xlink", .local_name = "title" },
    .{ .namespace_uri = infra.namespaces.XLINK_NAMESPACE, .prefix = "xlink", .local_name = "type" },
    .{ .namespace_uri = infra.namespaces.XML_NAMESPACE, .prefix = "xml", .local_name = "lang" },
    .{ .namespace_uri = infra.namespaces.XML_NAMESPACE, .prefix = "xml", .local_name = "space" },
    .{ .namespace_uri = infra.namespaces.XMLNS_NAMESPACE, .prefix = null, .local_name = "xmlns" },
    .{ .namespace_uri = infra.namespaces.XMLNS_NAMESPACE, .prefix = "xmlns", .local_name = "xlink" },
};

/// The static record of exactly this name, or null when no table has it -
/// the attribute then gets a record of its own.
pub fn intern(namespace: ?[]const u8, prefix: ?[]const u8, local_name: []const u8) ?*const QualifiedName {
    if (namespace == null) {
        if (prefix != null) return null;
        return &records[index.get(local_name) orelse return null];
    }
    for (&foreign) |*record| {
        if (record.eql(namespace, prefix, local_name)) return record;
    }
    return null;
}

test "every known name is distinct and interns to its own static record" {
    for (names, 0..) |name, i| {
        try std.testing.expectEqual(@as(u16, @intCast(i)), index.get(name).?);
        const record = intern(null, null, name).?;
        try std.testing.expect(record == &records[i]);
        try std.testing.expect(!record.isOwned());
        try std.testing.expect(record.namespace_uri == null and record.prefix == null);
        try std.testing.expectEqualStrings(name, record.local_name);
    }
}

test "interning is exact: case, prefix and namespace all count" {
    try std.testing.expect(intern(null, null, "class") != null);
    try std.testing.expect(intern(null, null, "CLASS") == null);
    try std.testing.expect(intern(null, null, "viewBox") != null);
    try std.testing.expect(intern(null, null, "viewbox") == null);
    try std.testing.expect(intern(null, null, "data-x") == null);
    // A prefix with no namespace is never static.
    try std.testing.expect(intern(null, "p", "class") == null);
    // In a namespace only the foreign table counts, prefix included.
    const href = intern(infra.namespaces.XLINK_NAMESPACE, "xlink", "href").?;
    try std.testing.expectEqualStrings("xlink", href.prefix.?);
    try std.testing.expect(href.namespace_uri.?.ptr == infra.namespaces.XLINK_NAMESPACE.ptr);
    try std.testing.expect(intern(infra.namespaces.XLINK_NAMESPACE, "other", "href") == null);
    try std.testing.expect(intern(infra.namespaces.XLINK_NAMESPACE, null, "href") == null);
    try std.testing.expect(intern("urn:x", null, "class") == null);
    try std.testing.expect(intern(infra.namespaces.XMLNS_NAMESPACE, null, "xmlns") != null);
}
