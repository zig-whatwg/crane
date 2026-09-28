//! A script element's parser-set state, as the hook the parsers reach it
//! through.
//!
//! HTML's parsers set state on the script elements they create that no IDL
//! member reaches: the parser document and force async ("in head", a start
//! tag whose tag name is "script", step 4 - "Set the element's parser
//! document to the Document, and set the element's force async to false"),
//! and, for the fragment parser, already started ("If the parser was created
//! as part of the HTML fragment parsing algorithm, then set the script
//! element's already started to true"). That state is HTMLScriptElement's,
//! so its impl installs the steps here, from its `init` - necessarily before
//! any script element exists for a parser to create.
//!
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html#parsing-main-inhead
//!
//! lint-impls: hook for HTMLScriptElement

const runtime = @import("runtime");

/// What HTMLScriptElement supplies.
pub const Implementation = struct {
    mark_parser_inserted: *const fn (element: *runtime.Instance, parser_document: *runtime.Instance) void,
    mark_already_started: *const fn (element: *runtime.Instance) void,
};

/// Per thread, like the elements it serves.
threadlocal var implementation: ?Implementation = null;

/// Called by HTMLScriptElement. Idempotent: every call installs the same one.
pub fn install(impl: Implementation) void {
    implementation = impl;
}

/// Set `element`'s parser document to `parser_document`, and its force async
/// to false. A no-op for an element that is not an HTML script element.
pub fn markParserInserted(element: *runtime.Instance, parser_document: *runtime.Instance) void {
    const impl = implementation orelse return;
    impl.mark_parser_inserted(element, parser_document);
}

/// Set `element`'s already started to true. A no-op for an element that is
/// not an HTML script element.
pub fn markAlreadyStarted(element: *runtime.Instance) void {
    const impl = implementation orelse return;
    impl.mark_already_started(element);
}

test "without an installed implementation the steps do nothing" {
    const saved = implementation;
    defer implementation = saved;
    implementation = null;
    // Never dereferenced: with no implementation nothing reads them.
    var element: runtime.Instance = undefined;
    var document: runtime.Instance = undefined;
    markParserInserted(&element, &document);
    markAlreadyStarted(&element);
}
