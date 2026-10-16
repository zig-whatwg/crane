//! HTML 13.4: fragment parsing shares template and context rules with DOMParser.
const runtime = @import("runtime");
const dom_parser = @import("../dom_parser.zig");

pub fn parse(target: *runtime.Instance, input: []const u8) !*runtime.Instance {
    return dom_parser.parseFragment(target.ctx.allocator, target.ctx, input, target);
}

/// "Set and filter HTML" step 7 (setHTMLUnsafe): the HTML fragment parsing
/// algorithm with allowDeclarativeShadowRoots true.
pub fn parseUnsafe(target: *runtime.Instance, input: []const u8) !*runtime.Instance {
    return parseUnsafeIn(target, input, .inert);
}

/// "Set and filter HTML" step 7 when no sanitizer filters the result
/// (setHTMLUnsafe with no sanitizer): the HTML fragment parsing algorithm
/// with allowDeclarativeShadowRoots true and `scripting_mode` (step 6:
/// Fragment for runScripts), building in the target's own document as
/// innerHTML does - Blink's FragmentParser makes no streaming sanitizer for
/// unsafe mode without one and parses into the context's document, and
/// Gecko's nsContentUtils::SetHTMLUnsafe falls back to its plain fragment
/// parse when no sanitizer was passed.
pub fn parseUnsafeIn(target: *runtime.Instance, input: []const u8, scripting_mode: dom_parser.ScriptingMode) !*runtime.Instance {
    return dom_parser.parseFragmentWith(target.ctx.allocator, target.ctx, input, target, .{
        .allow_declarative_shadow_roots = true,
        .scripting_mode = scripting_mode,
    });
}

/// "Set and filter HTML" step 7 when a sanitizer filters the result -
/// setHTML, and setHTMLUnsafe given a sanitizer: the fragment is built in an
/// inert document (dom_parser.FragmentOptions.inert_document), so nothing
/// the sanitizer then removes fetches, compiles a handler or constructs a
/// custom element; inserting the survivors ("replace all" inserts the
/// fragment) adopts them into the target's document. `scripting_mode` is
/// step 5-6's: Inert, or Fragment for setHTMLUnsafe's runScripts (step 6.1
/// asserts the safe methods never pass it).
pub fn parseToFilter(target: *runtime.Instance, input: []const u8, scripting_mode: dom_parser.ScriptingMode) !*runtime.Instance {
    return dom_parser.parseFragmentWith(target.ctx.allocator, target.ctx, input, target, .{
        .allow_declarative_shadow_roots = true,
        .scripting_mode = scripting_mode,
        .inert_document = true,
    });
}
