//! HTML 13.4: fragment parsing shares template and context rules with DOMParser.
const runtime = @import("runtime");
const dom_parser = @import("../dom_parser.zig");

pub fn parse(target: *runtime.Instance, input: []const u8) !*runtime.Instance {
    return dom_parser.parseFragment(target.ctx.allocator, target.ctx, input, target);
}

/// "Set and filter HTML" step 7 (setHTMLUnsafe): the HTML fragment parsing
/// algorithm with allowDeclarativeShadowRoots true.
pub fn parseUnsafe(target: *runtime.Instance, input: []const u8) !*runtime.Instance {
    return dom_parser.parseFragmentWith(target.ctx.allocator, target.ctx, input, target, .{ .allow_declarative_shadow_roots = true });
}
