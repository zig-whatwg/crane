//! Q60: path() fill-rule is rejected by the interoperable offset-path parser.
const std = @import("std");
const h = @import("bx1_helpers.zig");
const testing = std.testing;

// Motion 1 §2.1 imports <basic-shape>, and Shapes 1 defines path() with an
// optional fill-rule. However, fxtf-drafts#512 ended with the editor direction
// to ignore that component in path contexts; WPT
// css/motion/parsing/offset-path-parsing-invalid.html records the behavior
// shipped by Chrome 156, Firefox 159, and Safari 27.2 (all three reject both
// explicit values). Q60 therefore grants this offset-path-only restriction.
test "offset-path rejects an explicit path fill-rule but keeps other shapes" {
    inline for (.{
        "path(nonzero, \"M 0 0 H 100\")",
        "path(evenodd, \"M 0 0 H 100\")",
        "path(NONZERO, \"M 0 0 H 100\")",
        "path(EvEnOdD, \"M 0 0 H 100\")",
        "path(n\\6f nzero, \"M 0 0 H 100\")",
        "path(e\\76 enodd, \"M 0 0 H 100\")",
        "path( /* comment */ evenodd , \"M 0 0 H 100\")",
        "border-box path(nonzero, \"M 0 0 H 100\")",
        "path(evenodd, \"M 0 0 H 100\") content-box",
    }) |input| try h.check(testing.allocator, "offset-path", input, "", false);

    inline for (.{
        .{ "path(\"M 0 0 H 100\")", "path(\"M 0 0 H 100\")" },
        .{ "content-box path(\"M 0 0 H 100\")", "path(\"M 0 0 H 100\") content-box" },
        .{ "path(\"M 0 0 H 100\") border-box", "path(\"M 0 0 H 100\")" },
        .{ "polygon(evenodd, 0px 0px, 10px 0px, 10px 10px)", "polygon(evenodd, 0px 0px, 10px 0px, 10px 10px)" },
        .{ "polygon(nonzero, 0px 0px, 10px 0px, 10px 10px)", "polygon(0px 0px, 10px 0px, 10px 10px)" },
        .{ "shape(evenodd from 0px 0px, line to 10px 10px)", "shape(evenodd from 0px 0px, line to 10px 10px)" },
        .{ "shape(nonzero from 0px 0px, line to 10px 10px)", "shape(from 0px 0px, line to 10px 10px)" },
    }) |case| try h.check(testing.allocator, "offset-path", case[0], case[1], false);
}

test "shared clip-path parser still accepts path fill-rule" {
    try h.check(testing.allocator, "clip-path", "path(evenodd, \"M 0 0 H 100\")", "path(evenodd, \"M 0 0 H 100\")", false);
}

test "motion path fill-rule checks release every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailure, .{});
}

fn allocationFailure(allocator: h.Allocator) !void {
    inline for (.{
        .{ "offset-path", "path(nonzero, \"M 0 0 H 100\")", "" },
        .{ "offset-path", "path(\"M 0 0 H 100\") border-box", "path(\"M 0 0 H 100\")" },
        .{ "offset-path", "polygon(evenodd, 0px 0px, 10px 0px, 10px 10px)", "polygon(evenodd, 0px 0px, 10px 0px, 10px 10px)" },
        .{ "offset-path", "polygon(nonzero, 0px 0px, 10px 0px, 10px 10px)", "polygon(0px 0px, 10px 0px, 10px 10px)" },
        .{ "offset-path", "shape(evenodd from 0px 0px, line to 10px 10px)", "shape(evenodd from 0px 0px, line to 10px 10px)" },
        .{ "offset-path", "shape(nonzero from 0px 0px, line to 10px 10px)", "shape(from 0px 0px, line to 10px 10px)" },
        .{ "clip-path", "path(evenodd, \"M 0 0 H 100\")", "path(evenodd, \"M 0 0 H 100\")" },
    }) |case| try h.check(allocator, case[0], case[1], case[2], false);
}
