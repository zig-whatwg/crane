//! HTML 13.4: fragment parsing shares template and context rules with DOMParser.
const runtime = @import("runtime");

pub fn parse(target: *runtime.Instance, input: []const u8) !*runtime.Instance {
    return @import("../dom_parser.zig").parseFragment(target.ctx.allocator, target.ctx, input, target);
}
