//! A script element's parser-set state, as the hook the parsers reach it
//! through.
//!
//! HTML's parsers set state on the script elements they create that no IDL
//! member reaches: the parser document and force async ("in head", a start
//! tag whose tag name is "script", step 4 - "Set the element's parser
//! document to the Document, and set the element's force async to false"),
//! and, for the fragment parser, already started ("If the parser was created
//! as part of the HTML fragment parsing algorithm, then set the script
//! element's already started to true"). That state is the script element's:
//! HTMLScriptElement's and SVGScriptElement's impls each install their half
//! here, once, at process start (their installHooks).
//!
//! An SVG script shares HTML's processing model (SVG 2 §15.2: "A script
//! element is equivalent to the script element in HTML"), which html's
//! script_execution runs for it; its state is reached through `svgFlags`.
//!
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html#parsing-main-inhead
//!
//! lint-impls: hook for HTMLScriptElement, SVGScriptElement
const std = @import("std");
const process_start = @import("process_start.zig");

const runtime = @import("runtime");
const interfaces = @import("interfaces");

/// What HTMLScriptElement supplies. Each step is a no-op for an element that
/// is not an HTML script element.
pub const Implementation = struct {
    mark_parser_inserted: *const fn (element: *runtime.Instance, parser_document: *runtime.Instance) void,
    mark_already_started: *const fn (element: *runtime.Instance) void,
    /// The element's script text, if it is an HTML script element.
    script_text: ?*const fn (element: *runtime.Instance) ?*ScriptText = null,
};

/// Trusted Types 4.1.2.1: a script element's "script text" - "A string,
/// containing the body of the script to execute that was set through a
/// compliant sink. Equivalent to script's child text content. Initially an
/// empty string." Set by the parser at the script's end tag (4.1.2.6) and by
/// the Trusted Types-aware setters; "prepare the script text" (3.6) compares
/// it with the child text content. Owned.
pub const ScriptText = struct {
    allocator: ?std.mem.Allocator = null,
    value: []u8 = &.{},

    pub fn get(self: *const ScriptText) []const u8 {
        return self.value;
    }

    /// Set it to a copy of `text`.
    pub fn set(self: *ScriptText, allocator: std.mem.Allocator, text: []const u8) error{OutOfMemory}!void {
        const copy = try allocator.dupe(u8, text);
        self.deinit();
        self.* = .{ .allocator = allocator, .value = copy };
    }

    pub fn deinit(self: *ScriptText) void {
        if (self.allocator) |allocator| allocator.free(self.value);
        self.* = .{};
    }
};

/// The script element state an SVG script keeps: HTML's parser-inserted (its
/// "parser document" is not null) and already started.
pub const ScriptFlags = struct {
    parser_inserted: bool = false,
    already_started: bool = false,
    /// Trusted Types 4.1.2.1 (an SVG script element has one too). Freed by
    /// SVGScriptElement's teardown.
    script_text: ScriptText = .{},
};

/// What SVGScriptElement supplies: an SVG script element's flags, or null for
/// any other element.
pub const SvgImplementation = struct {
    flags: *const fn (element: *runtime.Instance) ?*ScriptFlags,
};

/// Process-wide, written once at start-up (process_start.zig).
var implementation: ?Implementation = null;
var svg_implementation: ?SvgImplementation = null;

/// Called by HTMLScriptElement's installHooks, once, at process start (process_start.zig).
pub fn install(impl: Implementation) void {
    process_start.assertInstalling();
    implementation = impl;
}

/// Called by SVGScriptElement's installHooks, once, at process start (process_start.zig).
pub fn installSvg(impl: SvgImplementation) void {
    process_start.assertInstalling();
    svg_implementation = impl;
}

/// Set `element`'s parser document to `parser_document`, and its force async
/// to false - for an SVG script, mark it parser-inserted. A no-op for an
/// element that is no script element.
pub fn markParserInserted(element: *runtime.Instance, parser_document: *runtime.Instance) void {
    if (implementation) |impl| impl.mark_parser_inserted(element, parser_document);
    if (svgFlags(element)) |flags| flags.parser_inserted = true;
}

/// Set `element`'s already started to true. A no-op for an element that is
/// no script element.
pub fn markAlreadyStarted(element: *runtime.Instance) void {
    if (implementation) |impl| impl.mark_already_started(element);
    if (svgFlags(element)) |flags| flags.already_started = true;
}

/// `element`'s script text (Trusted Types 4.1.2.1), if it is an HTML or SVG
/// script element.
pub fn scriptTextOf(element: *runtime.Instance) ?*ScriptText {
    if (implementation) |impl| {
        if (impl.script_text) |of| {
            if (of(element)) |text| return text;
        }
    }
    if (svgFlags(element)) |flags| return &flags.script_text;
    return null;
}

/// DOM "child text content" of `element`: its Text children's data,
/// concatenated (Text includes CDATASection). OWNED by `allocator`.
pub fn childTextContent(allocator: std.mem.Allocator, element: *runtime.Instance) error{OutOfMemory}![]u8 {
    var result: std.ArrayListUnmanaged(u8) = .empty;
    errdefer result.deinit(allocator);
    var child = interfaces.Node.get_firstChild(element) catch null;
    while (child) |c| : (child = interfaces.Node.get_nextSibling(c) catch null) {
        const node_type = interfaces.Node.get_nodeType(c) catch continue;
        if (node_type != interfaces.Node.get_TEXT_NODE() and node_type != interfaces.Node.get_CDATA_SECTION_NODE()) continue;
        var data = interfaces.CharacterData.get_data(c) catch continue;
        defer data.deinit(c.ctx.allocator);
        try result.appendSlice(allocator, data.asSlice());
    }
    return result.toOwnedSlice(allocator);
}

/// Trusted Types 4.1.2.6, at a script's end tag: "Set script's script text
/// value to its child text content." A no-op for an element that is no
/// script element.
pub fn setScriptTextToChildTextContent(allocator: std.mem.Allocator, element: *runtime.Instance) error{OutOfMemory}!void {
    const slot = scriptTextOf(element) orelse return;
    const text = try childTextContent(allocator, element);
    defer allocator.free(text);
    try slot.set(element.ctx.allocator, text);
}

/// `element`'s script element state if it is an SVG script element, else
/// null.
pub fn svgFlags(element: *runtime.Instance) ?*ScriptFlags {
    const impl = svg_implementation orelse return null;
    return impl.flags(element);
}

test "without an installed implementation the steps do nothing" {
    const saved = implementation;
    const saved_svg = svg_implementation;
    defer implementation = saved;
    defer svg_implementation = saved_svg;
    implementation = null;
    svg_implementation = null;
    // Never dereferenced: with no implementation nothing reads them.
    var element: runtime.Instance = undefined;
    var document: runtime.Instance = undefined;
    markParserInserted(&element, &document);
    markAlreadyStarted(&element);
    try @import("std").testing.expect(svgFlags(&element) == null);
}
