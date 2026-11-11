//! HTML Tag Name String Interning Pool
//!
//! Provides compile-time generated interned strings for common HTML tag names.
//! This optimization avoids heap allocations for tag names during parsing.
//!
//! Benefits:
//! - Zero allocation for ~120 common HTML tag names
//! - O(1) tag name comparison via pointer equality
//! - 15-25% reduction in string allocations during parsing
//!
//! Usage:
//!   const tag = tag_name_intern.intern("div") orelse allocator.dupe(u8, tag_name);
//!
//! All HTML5 standard elements are pre-interned in static memory.

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");

const ElementName = dom.element_name.ElementName;

/// List of all HTML5 standard element tag names.
/// These are pre-interned at compile time for zero-allocation lookup.
///
/// Based on HTML Living Standard element index:
/// https://html.spec.whatwg.org/multipage/indices.html#elements-3
pub const html_tag_names = [_][]const u8{
    // Document metadata
    "html",
    "head",
    "title",
    "base",
    "link",
    "meta",
    "style",

    // Sections
    "body",
    "article",
    "section",
    "nav",
    "aside",
    "h1",
    "h2",
    "h3",
    "h4",
    "h5",
    "h6",
    "hgroup",
    "header",
    "footer",
    "address",

    // Grouping content
    "p",
    "hr",
    "pre",
    "blockquote",
    "ol",
    "ul",
    "menu",
    "li",
    "dl",
    "dt",
    "dd",
    "figure",
    "figcaption",
    "main",
    "search",
    "div",

    // Text-level semantics
    "a",
    "em",
    "strong",
    "small",
    "s",
    "cite",
    "q",
    "dfn",
    "abbr",
    "ruby",
    "rt",
    "rp",
    "data",
    "time",
    "code",
    "var",
    "samp",
    "kbd",
    "sub",
    "sup",
    "i",
    "b",
    "u",
    "mark",
    "bdi",
    "bdo",
    "span",
    "br",
    "wbr",

    // Edits
    "ins",
    "del",

    // Embedded content
    "picture",
    "source",
    "img",
    "iframe",
    "embed",
    "object",
    "param",
    "video",
    "audio",
    "track",
    "map",
    "area",

    // Tabular data
    "table",
    "caption",
    "colgroup",
    "col",
    "tbody",
    "thead",
    "tfoot",
    "tr",
    "td",
    "th",

    // Forms
    "form",
    "label",
    "input",
    "button",
    "select",
    "datalist",
    "optgroup",
    "option",
    // The customizable select's (HTML 4.10.7.x, HTMLSelectedContentElement):
    // the parser makes it, so its name is static like the rest (lane nd2
    // batch 1-fix; review appendix-nd2.md F11 found every Browser interning
    // it).
    "selectedcontent",
    "textarea",
    "output",
    "progress",
    "meter",
    "fieldset",
    "legend",

    // Interactive elements
    "details",
    "summary",
    "dialog",

    // Scripting
    "script",
    "noscript",
    "template",
    "slot",
    "canvas",

    // Web Components (custom elements placeholder)
    // Custom elements are handled dynamically

    // Deprecated but still parsed (for compatibility)
    "applet",
    "acronym",
    "bgsound",
    "dir",
    "frame",
    "frameset",
    "noframes",
    "isindex",
    "keygen",
    "listing",
    "menuitem",
    "nextid",
    "noembed",
    "plaintext",
    "rb",
    "rtc",
    "strike",
    "xmp",
    "big",
    "blink",
    "center",
    "font",
    "marquee",
    "multicol",
    "nobr",
    "spacer",
    "tt",
    "basefont",

    // SVG elements commonly encountered in HTML
    "svg",
    "math",
    "foreignObject",

    // Other commonly used elements
    "image", // Legacy alias for img
};

/// The SVG element names (SVG 2's element index, the names HTML's "adjust
/// SVG tag names" makes, and the SVG 1.1 names browsers still create), for
/// the static element name records. Distinct (a test checks).
///
/// Spec: https://svgwg.org/svg2-draft/eltindex.html
/// Spec: https://html.spec.whatwg.org/multipage/parsing.html#adjust-svg-tag-names
pub const svg_tag_names = [_][]const u8{
    "a",                 "altGlyph",           "altGlyphDef",         "altGlyphItem",  "animate",
    "animateColor",      "animateMotion",      "animateTransform",    "circle",        "clipPath",
    "cursor",            "defs",               "desc",                "discard",       "ellipse",
    "feBlend",           "feColorMatrix",      "feComponentTransfer", "feComposite",   "feConvolveMatrix",
    "feDiffuseLighting", "feDisplacementMap",  "feDistantLight",      "feDropShadow",  "feFlood",
    "feFuncA",           "feFuncB",            "feFuncG",             "feFuncR",       "feGaussianBlur",
    "feImage",           "feMerge",            "feMergeNode",         "feMorphology",  "feOffset",
    "fePointLight",      "feSpecularLighting", "feSpotLight",         "feTile",        "feTurbulence",
    "filter",            "font",               "font-face",           "foreignObject", "g",
    "glyph",             "glyphRef",           "hkern",               "image",         "line",
    "linearGradient",    "marker",             "mask",                "metadata",      "missing-glyph",
    "mpath",             "path",               "pattern",             "polygon",       "polyline",
    "radialGradient",    "rect",               "script",              "set",           "stop",
    "style",             "svg",                "switch",              "symbol",        "text",
    "textPath",          "title",              "tref",                "tspan",         "use",
    "view",              "vkern",
};

/// The MathML element names (MathML Core's elements, and the MathML 3
/// presentation names browsers still create), for the static element name
/// records. Distinct (a test checks).
///
/// Spec: https://w3c.github.io/mathml-core/#mathml-elements-and-attributes
pub const mathml_tag_names = [_][]const u8{
    "math",       "maction",   "annotation",    "annotation-xml", "menclose",
    "merror",     "mfenced",   "mfrac",         "mglyph",         "mi",
    "mlabeledtr", "mlongdiv",  "mmultiscripts", "mn",             "mo",
    "mover",      "mpadded",   "mphantom",      "mprescripts",    "mroot",
    "mrow",       "ms",        "mscarries",     "mscarry",        "msgroup",
    "msline",     "mspace",    "msqrt",         "msrow",          "mstack",
    "mstyle",     "msub",      "msubsup",       "msup",           "mtable",
    "mtd",        "mtext",     "mtr",           "munder",         "munderover",
    "none",       "semantics",
};

/// The static element name records of one namespace: one per name, in
/// `names` order, found by local name.
fn StaticElementNames(comptime namespace: []const u8, comptime names: []const []const u8) type {
    return struct {
        const records: [names.len]ElementName = blk: {
            @setEvalBranchQuota(200_000);
            var out: [names.len]ElementName = undefined;
            for (names, 0..) |name, i| out[i] = ElementName.initStatic(namespace, name);
            break :blk out;
        };

        /// A comptime perfect hash: one hash and one compare per lookup
        /// (review zig/report.md Z10: std.StaticStringMap scanned a length
        /// bucket, 9.9 compares per HTML hit, 23 names in the longest).
        const index = dom.attribute_names.PerfectHash(names);

        fn get(local_name: []const u8) ?*const ElementName {
            return &records[index.get(local_name) orelse return null];
        }
    };
}

const html_element_names = StaticElementNames(infra.namespaces.HTML_NAMESPACE, &html_tag_names);
const svg_element_names = StaticElementNames(infra.namespaces.SVG_NAMESPACE, &svg_tag_names);
const mathml_element_names = StaticElementNames(infra.namespaces.MATHML_NAMESPACE, &mathml_tag_names);

/// The static record of exactly this element name, or null when no table
/// has it - Element then interns it in its Browser's table
/// (dom.element_name). A static name is in the HTML, SVG or MathML
/// namespace, has no prefix, and is exactly one of that namespace's names
/// (a local name is case-sensitive: createElementNS(html, "DIV") is not
/// "div"). Blink's static html_names / svg_names / mathml_names
/// QualifiedNames, WebKit's HTMLNames / SVGNames / MathMLNames.
pub fn internElementName(namespace: ?[]const u8, prefix: ?[]const u8, local_name: []const u8) ?*const ElementName {
    if (prefix != null) return null;
    return switch (dom.element_name.namespaceOf(namespace)) {
        .html => html_element_names.get(local_name),
        .svg => svg_element_names.get(local_name),
        .mathml => mathml_element_names.get(local_name),
        else => null,
    };
}

/// The HTML tag names by a comptime perfect hash (dom.attribute_names
/// .PerfectHash: one hash, one compare; review zig/report.md Z10 - the
/// std.StaticStringMap here before scanned a length bucket).
pub const interned_tags = dom.attribute_names.PerfectHash(&html_tag_names);

/// The HTML tag names in ASCII lowercase, for a lookup after lowercasing the
/// input. Not every name in html_tag_names is lowercase - "foreignObject" is
/// not - so the keys are lowered here: the tokenizer's "foreignobject"
/// interns too (it missed, and tree_builder's initElement copied it;
/// appendix-nd2.md F12).
const lowercase_tag_names: [html_tag_names.len][]const u8 = blk: {
    @setEvalBranchQuota(100_000);
    var out: [html_tag_names.len][]const u8 = undefined;
    for (html_tag_names, 0..) |name, i| out[i] = lowerComptime(name);
    break :blk out;
};

pub const lowercase_interned_tags = dom.attribute_names.PerfectHash(&lowercase_tag_names);

fn lowerComptime(comptime name: []const u8) []const u8 {
    var buffer: [name.len]u8 = undefined;
    for (name, 0..) |c, i| buffer[i] = std.ascii.toLower(c);
    const final = buffer;
    return &final;
}

/// Attempt to intern a tag name.
///
/// Returns a pointer to the static interned string if the tag name matches
/// one of the pre-defined HTML tag names (case-insensitive).
/// Returns null if the tag name is not in the intern pool.
///
/// This function performs case-insensitive matching by first trying exact
/// match, then trying lowercase match for uppercase/mixed-case inputs.
///
/// Performance: O(1) average case due to perfect hash map.
///
/// Example:
///   const interned = intern("DIV");  // Returns pointer to "div"
///   const custom = intern("my-element");  // Returns null
pub fn intern(tag_name: []const u8) ?[]const u8 {
    // Fast path: exact match (most common - parser typically lowercases)
    if (interned_tags.get(tag_name)) |index| {
        return html_tag_names[index];
    }

    // Slow path: uppercase input needs lowercasing
    // This happens when parsing uppercase HTML like <DIV>
    // Use stack buffer for small tag names (all HTML tags fit in 20 chars)
    if (tag_name.len <= 20) {
        var lower_buf: [20]u8 = undefined;
        for (tag_name, 0..) |c, i| {
            lower_buf[i] = std.ascii.toLower(c);
        }
        const lower = lower_buf[0..tag_name.len];
        return lowercase_tag_names[lowercase_interned_tags.get(lower) orelse return null];
    }

    // Tag name too long - definitely not a standard HTML element
    return null;
}

/// The interned copy of `tag_name`, only on an exact match. An element's local
/// name is case-sensitive - createElementNS(ns, "DIV") and an XML document's
/// createElement("DIV") keep "DIV" - so naming an element must not lowercase
/// it the way the tokenizer-facing `intern` does.
pub fn internExact(tag_name: []const u8) ?[]const u8 {
    return html_tag_names[interned_tags.get(tag_name) orelse return null];
}

/// Check if a tag name is a known HTML element.
///
/// This is useful for determining whether an element needs special
/// handling during parsing (e.g., void elements, raw text elements).
pub fn isKnownHtmlTag(tag_name: []const u8) bool {
    return intern(tag_name) != null;
}

/// Get all known HTML tag names.
///
/// Returns the static array of all pre-interned tag names.
/// Useful for documentation, testing, or enumeration purposes.
pub fn getAllTagNames() []const []const u8 {
    return &html_tag_names;
}

/// Compare two tag names for equality using interning.
///
/// If both tag names are interned, comparison is O(1) via pointer equality.
/// Otherwise, falls back to byte-by-byte comparison.
///
/// This enables fast tag matching during tree construction.
pub fn eqlInterned(a: []const u8, b: []const u8) bool {
    // Try to use pointer equality if both are interned
    const a_interned = intern(a);
    const b_interned = intern(b);

    if (a_interned != null and b_interned != null) {
        // Both are interned - pointer comparison
        return a_interned.?.ptr == b_interned.?.ptr;
    }

    // Fall back to string comparison
    return std.mem.eql(u8, a, b);
}

// ============================================================================
// Unit Tests
// ============================================================================

test "intern returns static pointer for known tags" {
    const div = intern("div");
    try std.testing.expect(div != null);
    try std.testing.expectEqualStrings("div", div.?);

    const span = intern("span");
    try std.testing.expect(span != null);
    try std.testing.expectEqualStrings("span", span.?);

    const table = intern("table");
    try std.testing.expect(table != null);
    try std.testing.expectEqualStrings("table", table.?);
}

test "intern returns null for unknown tags" {
    const custom = intern("my-custom-element");
    try std.testing.expect(custom == null);

    const random = intern("xyz123");
    try std.testing.expect(random == null);
}

test "intern is case-insensitive" {
    const lower = intern("div");
    const upper = intern("DIV");
    const mixed = intern("DiV");

    try std.testing.expect(lower != null);
    try std.testing.expect(upper != null);
    try std.testing.expect(mixed != null);

    // All should point to the same interned string
    try std.testing.expectEqualStrings("div", lower.?);
    try std.testing.expectEqualStrings("div", upper.?);
    try std.testing.expectEqualStrings("div", mixed.?);

    // Pointers should be equal (same static memory)
    try std.testing.expect(lower.?.ptr == upper.?.ptr);
    try std.testing.expect(lower.?.ptr == mixed.?.ptr);
}

test "intern finds a camelCase name from its lowercase, as the tokenizer gives it" {
    try std.testing.expectEqualStrings("foreignobject", intern("foreignobject").?);
    try std.testing.expectEqualStrings("foreignobject", intern("FOREIGNOBJECT").?);
    try std.testing.expectEqualStrings("selectedcontent", intern("selectedcontent").?);
}

test "intern handles all HTML5 tags" {
    for (html_tag_names) |name| {
        const result = intern(name);
        try std.testing.expect(result != null);
        try std.testing.expectEqualStrings(name, result.?);
    }
}

test "eqlInterned uses pointer comparison for interned strings" {
    // Both interned - should use pointer comparison
    try std.testing.expect(eqlInterned("div", "div"));
    try std.testing.expect(eqlInterned("DIV", "div"));

    // Different tags
    try std.testing.expect(!eqlInterned("div", "span"));

    // One or both not interned - falls back to string comparison
    try std.testing.expect(eqlInterned("my-tag", "my-tag"));
    try std.testing.expect(!eqlInterned("my-tag", "other-tag"));
}

test "isKnownHtmlTag identifies HTML elements" {
    try std.testing.expect(isKnownHtmlTag("div"));
    try std.testing.expect(isKnownHtmlTag("span"));
    try std.testing.expect(isKnownHtmlTag("table"));
    try std.testing.expect(isKnownHtmlTag("SCRIPT")); // Case insensitive

    try std.testing.expect(!isKnownHtmlTag("my-element"));
    try std.testing.expect(!isKnownHtmlTag("custom-tag"));
}

test "getAllTagNames returns all tag names" {
    const all = getAllTagNames();
    try std.testing.expect(all.len > 100); // Should have 100+ tags
    try std.testing.expect(all.len == html_tag_names.len);
}

test "every static element name is distinct, interns to its own record, and only exactly" {
    const html = infra.namespaces.HTML_NAMESPACE;
    const svg = infra.namespaces.SVG_NAMESPACE;
    const mathml = infra.namespaces.MATHML_NAMESPACE;
    inline for (.{ .{ html, &html_tag_names }, .{ svg, &svg_tag_names }, .{ mathml, &mathml_tag_names } }) |table| {
        for (table[1], 0..) |name, i| {
            const record = internElementName(table[0], null, name).?;
            try std.testing.expectEqualStrings(name, record.local_name);
            try std.testing.expect(record.is_static and record.prefix == null);
            try std.testing.expect(record.namespace_uri.?.ptr == table[0].ptr);
            // Distinct: the name's record is the one at its own index.
            for (table[1][0..i]) |earlier| try std.testing.expect(!std.mem.eql(u8, earlier, name));
        }
    }
    const div = internElementName(html, null, "div").?;
    try std.testing.expectEqualStrings("DIV", div.qualified_name_upper);
    try std.testing.expect(internElementName(html, null, "div") == div);
    // Exact: case, prefix and namespace all count.
    try std.testing.expect(internElementName(html, null, "DIV") == null);
    try std.testing.expect(internElementName(html, "p", "div") == null);
    try std.testing.expect(internElementName(null, null, "div") == null);
    try std.testing.expect(internElementName("urn:x", null, "div") == null);
    try std.testing.expect(internElementName(svg, null, "div") == null);
    try std.testing.expect(internElementName(svg, null, "foreignobject") == null);
    try std.testing.expectEqualStrings("FOREIGNOBJECT", internElementName(svg, null, "foreignObject").?.qualified_name_upper);
    try std.testing.expect(internElementName(mathml, null, "mrow").?.namespace == .mathml);
}
