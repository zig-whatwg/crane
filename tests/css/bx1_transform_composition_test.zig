//! Q57 / probe1026r: component majorities form Chrome's whole composition model.
//! Matrix44 / Transform are DESIGN references; no engine source is copied.
const std = @import("std");
const h = @import("bx1_helpers.zig");
const testing = std.testing;

// Exact 24 Chrome records ruled by Q57, including four finite controls.
const probe_cases = .{
    .{ "scale(2) translateX(1px)", "matrix(2, 0, 0, 2, 2, 0)" },
    .{ "scale(2) rotate(90deg)", "matrix(0, 2, -2, 0, 0, 0)" },
    .{ "scale(2) skewX(45deg)", "matrix(2, 0, 2, 2, 0, 0)" },
    .{ "scale(2) matrix(1, 2, 3, 4, 5, 6)", "matrix(2, 4, 6, 8, 10, 12)" },
    .{ "scale(1e200) scale(1e200) translateX(0px)", "matrix(infinity, 0, 0, infinity, NaN, NaN)" },
    .{ "scale(1e200) scale(1e200) translateX(1px)", "matrix(infinity, 0, 0, infinity, infinity, NaN)" },
    .{ "scale(1e200) scale(1e200) translateY(1px)", "matrix(infinity, 0, 0, infinity, NaN, infinity)" },
    .{ "scale(1e200) scale(1e200) translateZ(1px)", "matrix3d(infinity, 0, 0, 0, 0, infinity, 0, 0, 0, 0, 1, 0, NaN, NaN, 1, 1)" },
    .{ "scale(1e200) scale(1e200) translate3d(1px, 2px, 3px)", "matrix3d(infinity, 0, 0, 0, 0, infinity, 0, 0, 0, 0, 1, 0, infinity, infinity, 3, 1)" },
    .{ "scale(1e200) scale(1e200) rotate(0deg)", "matrix(infinity, 0, 0, infinity, 0, 0)" },
    .{ "scale(1e200) scale(1e200) rotate(90deg)", "matrix(NaN, infinity, -infinity, NaN, 0, 0)" },
    .{ "scale(1e200) scale(1e200) rotate(45deg)", "matrix(infinity, infinity, -infinity, infinity, 0, 0)" },
    .{ "scale(1e200) scale(1e200) rotateX(90deg)", "matrix3d(infinity, 0, 0, 0, 0, NaN, 1, 0, 0, -infinity, 0, 0, 0, 0, 0, 1)" },
    .{ "scale(1e200) scale(1e200) rotate3d(1, 1, 1, 90deg)", "matrix3d(infinity, infinity, -0.244017, 0, -infinity, infinity, 0.910684, 0, infinity, -infinity, 0.333333, 0, NaN, NaN, 0, 1)" },
    .{ "scale(1e200) scale(1e200) skewX(0deg)", "matrix(infinity, 0, 0, infinity, 0, 0)" },
    .{ "scale(1e200) scale(1e200) skewX(45deg)", "matrix(infinity, NaN, infinity, infinity, 0, 0)" },
    .{ "scale(1e200) scale(1e200) skewY(45deg)", "matrix(infinity, infinity, NaN, infinity, 0, 0)" },
    .{ "scale(1e200) scale(1e200) skew(45deg, -45deg)", "matrix(infinity, -infinity, infinity, infinity, 0, 0)" },
    .{ "scale(1e200) scale(1e200) matrix(1, 0, 0, 1, 0, 0)", "matrix3d(infinity, NaN, 0, 0, NaN, infinity, 0, 0, NaN, NaN, 1, 0, NaN, NaN, 0, 1)" },
    .{ "scale(1e200) scale(1e200) matrix(1, 2, 3, 4, 5, 6)", "matrix3d(infinity, infinity, 0, 0, infinity, infinity, 0, 0, NaN, NaN, 1, 0, infinity, infinity, 0, 1)" },
    .{ "scale(1e200) scale(1e200) matrix3d(1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1)", "matrix3d(infinity, NaN, 0, 0, NaN, infinity, 0, 0, NaN, NaN, 1, 0, NaN, NaN, 0, 1)" },
    .{ "scale(1e200) scale(1e200) matrix3d(1,0,0,0,0,1,0,0,0,0,1,0,1,2,3,1)", "matrix3d(infinity, NaN, 0, 0, NaN, infinity, 0, 0, NaN, NaN, 1, 0, infinity, infinity, 3, 1)" },
    .{ "scale(1e200) scale(1e200) perspective(none)", "matrix(infinity, 0, 0, infinity, 0, 0)" },
    .{ "scale(1e200) scale(1e200) perspective(10px)", "matrix3d(infinity, 0, 0, 0, 0, infinity, 0, 0, 0, 0, 1, -0.1, 0, 0, 0, 1)" },
};

// Transforms 1 section 12 / Transforms 2 section 16 finite controls.
const finite_cases = .{
    .{ "rotate(0deg) translate(2px, 3px)", "matrix(1, 0, 0, 1, 2, 3)" },
    .{ "translate(2px, 3px) rotate(0deg)", "matrix(1, 0, 0, 1, 2, 3)" },
    .{ "rotate(45deg) translateX(2px)", "matrix(0.707107, 0.707107, -0.707107, 0.707107, 1.41421, 1.41421)" },
    .{ "translateX(2px) rotate(45deg)", "matrix(0.707107, 0.707107, -0.707107, 0.707107, 2, 0)" },
    .{ "rotate(90deg) translate(2px, 3px)", "matrix(0, 1, -1, 0, -3, 2)" },
    .{ "translate(2px, 3px) rotate(90deg)", "matrix(0, 1, -1, 0, 2, 3)" },
    .{ "rotate(180deg) translate(2px, 3px)", "matrix(-1, 0, 0, -1, -2, -3)" },
    .{ "translate(2px, 3px) rotate(180deg)", "matrix(-1, 0, 0, -1, 2, 3)" },
    .{ "rotateX(90deg) translate3d(1px, 2px, 3px)", "matrix3d(1, 0, 0, 0, 0, 0, 1, 0, 0, -1, 0, 0, 1, -3, 2, 1)" },
    .{ "translate3d(1px, 2px, 3px) rotateX(90deg)", "matrix3d(1, 0, 0, 0, 0, 0, 1, 0, 0, -1, 0, 0, 1, 2, 3, 1)" },
    .{ "rotateY(90deg) translate3d(1px, 2px, 3px)", "matrix3d(0, 0, -1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 3, 2, -1, 1)" },
    .{ "translate3d(1px, 2px, 3px) rotateY(90deg)", "matrix3d(0, 0, -1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 2, 3, 1)" },
    .{ "rotateZ(90deg) translate3d(1px, 2px, 3px)", "matrix3d(0, 1, 0, 0, -1, 0, 0, 0, 0, 0, 1, 0, -2, 1, 3, 1)" },
    .{ "translate3d(1px, 2px, 3px) rotateZ(90deg)", "matrix3d(0, 1, 0, 0, -1, 0, 0, 0, 0, 0, 1, 0, 1, 2, 3, 1)" },
    .{ "rotate3d(1, 1, 0, 180deg) translate3d(2px, 3px, 4px)", "matrix3d(0, 1, 0, 0, 1, 0, 0, 0, 0, 0, -1, 0, 3, 2, -4, 1)" },
    .{ "translate3d(2px, 3px, 4px) rotate3d(1, 1, 0, 180deg)", "matrix3d(0, 1, 0, 0, 1, 0, 0, 0, 0, 0, -1, 0, 2, 3, 4, 1)" },
    .{ "skewX(45deg) translate(2px, 3px)", "matrix(1, 0, 1, 1, 5, 3)" },
    .{ "translate(2px, 3px) skewX(45deg)", "matrix(1, 0, 1, 1, 2, 3)" },
    .{ "skewY(45deg) translate(2px, 3px)", "matrix(1, 1, 0, 1, 2, 5)" },
    .{ "translate(2px, 3px) skewY(45deg)", "matrix(1, 1, 0, 1, 2, 3)" },
    .{ "skew(45deg, -45deg) translate(2px, 3px)", "matrix(1, -1, 1, 1, 5, 1)" },
    .{ "translate(2px, 3px) skew(45deg, -45deg)", "matrix(1, -1, 1, 1, 2, 3)" },
    .{ "skew(0deg, 0deg) translate(2px, 3px)", "matrix(1, 0, 0, 1, 2, 3)" },
    .{ "translate(2px, 3px) skew(0deg, 0deg)", "matrix(1, 0, 0, 1, 2, 3)" },
    .{ "perspective(none) translateZ(5px)", "matrix3d(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 5, 1)" },
    .{ "translateZ(5px) perspective(none)", "matrix3d(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 5, 1)" },
    .{ "perspective(10px) translateZ(5px)", "matrix3d(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, -0.1, 0, 0, 5, 0.5)" },
    .{ "translateZ(5px) perspective(10px)", "matrix3d(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0.5, -0.1, 0, 0, 5, 1)" },
    .{ "scale3d(2, 3, 4) translate3d(5px, 6px, 7px)", "matrix3d(2, 0, 0, 0, 0, 3, 0, 0, 0, 0, 4, 0, 10, 18, 28, 1)" },
    .{ "translate3d(5px, 6px, 7px) scale3d(2, 3, 4)", "matrix3d(2, 0, 0, 0, 0, 3, 0, 0, 0, 0, 4, 0, 5, 6, 7, 1)" },
};

test "transform follow on operations match all twenty four ruled browser records" {
    inline for (probe_cases) |case| try h.check(testing.allocator, "transform", case[0], case[1], true);
}

test "specialized transform operations retain finite mixed order composition" {
    inline for (finite_cases) |case| try h.check(testing.allocator, "transform", case[0], case[1], true);
}

test "transform operation composition releases every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailure, .{});
}

fn allocationFailure(allocator: h.Allocator) !void {
    inline for (probe_cases) |case| try h.check(allocator, "transform", case[0], case[1], true);
    inline for (finite_cases) |case| try h.check(allocator, "transform", case[0], case[1], true);
}
