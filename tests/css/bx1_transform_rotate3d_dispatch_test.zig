//! Q68/Q69: Safari 27 operation model, integrator probe 2026-10-27.
//! Q71: finite control05 keeps Crane/Chrome/Firefox six-significant-digit text.
//! WebKit TransformationMatrix::rotate3d is a design reference, never copied.
const std = @import("std");
const h = @import("bx1_helpers.zig");
const testing = std.testing;

test "rotate3d ruled dispatch case 01" {
    try h.check(testing.allocator, "transform", "scale(2) rotate3d(1, 1, 1, 0deg)", "matrix(2, 0, 0, 2, 0, 0)", true);
}
test "rotate3d ruled dispatch case 01 releases every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, case01, .{});
}
fn case01(allocator: h.Allocator) !void {
    try h.check(allocator, "transform", "scale(2) rotate3d(1, 1, 1, 0deg)", "matrix(2, 0, 0, 2, 0, 0)", true);
}

test "rotate3d ruled dispatch case 02" {
    try h.check(testing.allocator, "transform", "scale(2) rotate3d(0, 0, 0, 45deg)", "matrix(2, 0, 0, 2, 0, 0)", true);
}
test "rotate3d ruled dispatch case 02 releases every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, case02, .{});
}
fn case02(allocator: h.Allocator) !void {
    try h.check(allocator, "transform", "scale(2) rotate3d(0, 0, 0, 45deg)", "matrix(2, 0, 0, 2, 0, 0)", true);
}

test "rotate3d ruled dispatch case 03" {
    try h.check(testing.allocator, "transform", "scale(2) rotate3d(0, 1, 0, 90deg)", "matrix3d(0, 0, -1, 0, 0, 2, 0, 0, 2, 0, 0, 0, 0, 0, 0, 1)", true);
}
test "rotate3d ruled dispatch case 03 releases every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, case03, .{});
}
fn case03(allocator: h.Allocator) !void {
    try h.check(allocator, "transform", "scale(2) rotate3d(0, 1, 0, 90deg)", "matrix3d(0, 0, -1, 0, 0, 2, 0, 0, 2, 0, 0, 0, 0, 0, 0, 1)", true);
}

test "rotate3d ruled dispatch case 04" {
    try h.check(testing.allocator, "transform", "scale(2) rotate3d(-1, 0, 0, 90deg)", "matrix3d(2, 0, 0, 0, 0, 0, -1, 0, 0, 2, 0, 0, 0, 0, 0, 1)", true);
}
test "rotate3d ruled dispatch case 04 releases every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, case04, .{});
}
fn case04(allocator: h.Allocator) !void {
    try h.check(allocator, "transform", "scale(2) rotate3d(-1, 0, 0, 90deg)", "matrix3d(2, 0, 0, 0, 0, 0, -1, 0, 0, 2, 0, 0, 0, 0, 0, 1)", true);
}

test "rotate3d ruled dispatch case 05" {
    try h.check(testing.allocator, "transform", "scale(2) rotate3d(1, 1, 1, 90deg)", "matrix3d(0.666667, 1.82137, -0.244017, 0, -0.488034, 0.666667, 0.910684, 0, 1.82137, -0.488034, 0.333333, 0, 0, 0, 0, 1)", true);
}
test "rotate3d ruled dispatch case 05 releases every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, case05, .{});
}
fn case05(allocator: h.Allocator) !void {
    try h.check(allocator, "transform", "scale(2) rotate3d(1, 1, 1, 90deg)", "matrix3d(0.666667, 1.82137, -0.244017, 0, -0.488034, 0.666667, 0.910684, 0, 1.82137, -0.488034, 0.333333, 0, 0, 0, 0, 1)", true);
}

test "rotate3d ruled dispatch case 06" {
    try h.check(testing.allocator, "transform", "scale(1e200) scale(1e200) rotate3d(1, 1, 1, 0deg)", "matrix3d(infinity, NaN, 0, 0, NaN, infinity, 0, 0, NaN, NaN, 1, 0, NaN, NaN, 0, 1)", true);
}
test "rotate3d ruled dispatch case 06 releases every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, case06, .{});
}
fn case06(allocator: h.Allocator) !void {
    try h.check(allocator, "transform", "scale(1e200) scale(1e200) rotate3d(1, 1, 1, 0deg)", "matrix3d(infinity, NaN, 0, 0, NaN, infinity, 0, 0, NaN, NaN, 1, 0, NaN, NaN, 0, 1)", true);
}

test "rotate3d ruled dispatch case 07" {
    try h.check(testing.allocator, "transform", "scale(1e200) scale(1e200) rotate3d(1, 1, 1, 360deg)", "matrix3d(infinity, -infinity, 0, 0, infinity, infinity, 0, 0, -infinity, infinity, 1, 0, NaN, NaN, 0, 1)", true);
}
test "rotate3d ruled dispatch case 07 releases every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, case07, .{});
}
fn case07(allocator: h.Allocator) !void {
    try h.check(allocator, "transform", "scale(1e200) scale(1e200) rotate3d(1, 1, 1, 360deg)", "matrix3d(infinity, -infinity, 0, 0, infinity, infinity, 0, 0, -infinity, infinity, 1, 0, NaN, NaN, 0, 1)", true);
}

test "rotate3d ruled dispatch case 08" {
    try h.check(testing.allocator, "transform", "scale(1e200) scale(1e200) rotate3d(0, 0, 0, 45deg)", "matrix(infinity, 0, 0, infinity, 0, 0)", true);
}
test "rotate3d ruled dispatch case 08 releases every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, case08, .{});
}
fn case08(allocator: h.Allocator) !void {
    try h.check(allocator, "transform", "scale(1e200) scale(1e200) rotate3d(0, 0, 0, 45deg)", "matrix(infinity, 0, 0, infinity, 0, 0)", true);
}

test "rotate3d ruled dispatch case 09" {
    try h.check(testing.allocator, "transform", "scale(1e200) scale(1e200) rotate3d(1, 0, 0, 90deg)", "matrix3d(infinity, NaN, 0, 0, NaN, NaN, 1, 0, NaN, -infinity, 0, 0, NaN, NaN, 0, 1)", true);
}
test "rotate3d ruled dispatch case 09 releases every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, case09, .{});
}
fn case09(allocator: h.Allocator) !void {
    try h.check(allocator, "transform", "scale(1e200) scale(1e200) rotate3d(1, 0, 0, 90deg)", "matrix3d(infinity, NaN, 0, 0, NaN, NaN, 1, 0, NaN, -infinity, 0, 0, NaN, NaN, 0, 1)", true);
}

test "rotate3d ruled dispatch case 10" {
    try h.check(testing.allocator, "transform", "scale(1e200) scale(1e200) rotate3d(0, 1, 0, 90deg)", "matrix3d(NaN, NaN, -1, 0, NaN, infinity, 0, 0, infinity, NaN, 0, 0, NaN, NaN, 0, 1)", true);
}
test "rotate3d ruled dispatch case 10 releases every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, case10, .{});
}
fn case10(allocator: h.Allocator) !void {
    try h.check(allocator, "transform", "scale(1e200) scale(1e200) rotate3d(0, 1, 0, 90deg)", "matrix3d(NaN, NaN, -1, 0, NaN, infinity, 0, 0, infinity, NaN, 0, 0, NaN, NaN, 0, 1)", true);
}

test "rotate3d ruled dispatch case 11" {
    try h.check(testing.allocator, "transform", "scale(1e200) scale(1e200) rotate3d(0, 0, 1, 90deg)", "matrix3d(NaN, infinity, 0, 0, -infinity, NaN, 0, 0, NaN, NaN, 1, 0, NaN, NaN, 0, 1)", true);
}
test "rotate3d ruled dispatch case 11 releases every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, case11, .{});
}
fn case11(allocator: h.Allocator) !void {
    try h.check(allocator, "transform", "scale(1e200) scale(1e200) rotate3d(0, 0, 1, 90deg)", "matrix3d(NaN, infinity, 0, 0, -infinity, NaN, 0, 0, NaN, NaN, 1, 0, NaN, NaN, 0, 1)", true);
}

test "rotate3d ruled dispatch case 12" {
    try h.check(testing.allocator, "transform", "scale(1e200) scale(1e200) rotate3d(-1, 0, 0, 90deg)", "matrix3d(infinity, NaN, 0, 0, NaN, NaN, -1, 0, NaN, infinity, 0, 0, NaN, NaN, 0, 1)", true);
}
test "rotate3d ruled dispatch case 12 releases every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, case12, .{});
}
fn case12(allocator: h.Allocator) !void {
    try h.check(allocator, "transform", "scale(1e200) scale(1e200) rotate3d(-1, 0, 0, 90deg)", "matrix3d(infinity, NaN, 0, 0, NaN, NaN, -1, 0, NaN, infinity, 0, 0, NaN, NaN, 0, 1)", true);
}

test "rotate3d ruled dispatch case 13" {
    try h.check(testing.allocator, "transform", "scale(1e200) scale(1e200) rotate3d(0, 0, -1, 45deg)", "matrix3d(infinity, -infinity, 0, 0, infinity, infinity, 0, 0, NaN, NaN, 1, 0, NaN, NaN, 0, 1)", true);
}
test "rotate3d ruled dispatch case 13 releases every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, case13, .{});
}
fn case13(allocator: h.Allocator) !void {
    try h.check(allocator, "transform", "scale(1e200) scale(1e200) rotate3d(0, 0, -1, 45deg)", "matrix3d(infinity, -infinity, 0, 0, infinity, infinity, 0, 0, NaN, NaN, 1, 0, NaN, NaN, 0, 1)", true);
}

test "rotate3d ruled dispatch case 14" {
    try h.check(testing.allocator, "transform", "scale(1e200) scale(1e200) rotate3d(1, 1e-200, 0, 90deg)", "matrix3d(infinity, NaN, 0, 0, NaN, NaN, 1, 0, NaN, -infinity, 0, 0, NaN, NaN, 0, 1)", true);
}
test "rotate3d ruled dispatch case 14 releases every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, case14, .{});
}
fn case14(allocator: h.Allocator) !void {
    try h.check(allocator, "transform", "scale(1e200) scale(1e200) rotate3d(1, 1e-200, 0, 90deg)", "matrix3d(infinity, NaN, 0, 0, NaN, NaN, 1, 0, NaN, -infinity, 0, 0, NaN, NaN, 0, 1)", true);
}

test "rotate3d ruled dispatch case 15" {
    try h.check(testing.allocator, "transform", "scale(1e200) scale(1e200) rotate3d(1, 1, 1, 90deg)", "matrix3d(infinity, infinity, -0.244017, 0, -infinity, infinity, 0.910684, 0, infinity, -infinity, 0.333333, 0, NaN, NaN, 0, 1)", true);
}
test "rotate3d ruled dispatch case 15 releases every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, case15, .{});
}
fn case15(allocator: h.Allocator) !void {
    try h.check(allocator, "transform", "scale(1e200) scale(1e200) rotate3d(1, 1, 1, 90deg)", "matrix3d(infinity, infinity, -0.244017, 0, -infinity, infinity, 0.910684, 0, infinity, -infinity, 0.333333, 0, NaN, NaN, 0, 1)", true);
}
