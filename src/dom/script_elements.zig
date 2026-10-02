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
const process_start = @import("process_start.zig");

const runtime = @import("runtime");

/// What HTMLScriptElement supplies. Each step is a no-op for an element that
/// is not an HTML script element.
pub const Implementation = struct {
    mark_parser_inserted: *const fn (element: *runtime.Instance, parser_document: *runtime.Instance) void,
    mark_already_started: *const fn (element: *runtime.Instance) void,
};

/// The script element state an SVG script keeps: HTML's parser-inserted (its
/// "parser document" is not null) and already started.
pub const ScriptFlags = struct {
    parser_inserted: bool = false,
    already_started: bool = false,
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
