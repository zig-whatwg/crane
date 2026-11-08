//! A parse or a computation that fails releases only what it made, whatever
//! bytes its frame held before.
//!
//! `x = .{ .field = try make() }` builds the literal in place: Zig makes an
//! optional `x` non-null, or gives a union `x` its tag, BEFORE the `try`
//! runs (lane linux1's probe on chat2, aarch64 Debug: after a failed
//! `u = .{ .some = try fail() }` the tag read `some`; the same for an
//! `orelse return null`, and an optional struct read non-null). A `defer` or
//! `errdefer` that releases `x` then releases a payload never written - the
//! bytes the frame held before. Those were harmless on macOS and 0xAA,
//! Zig's undefined byte, on x86-64 Linux, where five css tests crashed
//! (server1's first native run, 2026-11-07): ci1_shape_arc_math ("index 170,
//! len 2": an Arc's rotation tag read 0xAA) and fm1_motion (a GP fault
//! releasing a ray position that was 0xAAAA...).
//!
//! Each test here fills the stack its subject will run on with 0xAA first,
//! so the payload a failure leaves behind is poison on every platform.

const std = @import("std");
const css = @import("css");
const h = @import("bx1_helpers.zig");
const testing = std.testing;
const Allocator = std.mem.Allocator;

/// 64 KiB of the stack below the caller's frame - where the caller's next
/// call runs - filled with 0xAA, the byte Zig's Debug builds write for
/// `undefined`.
noinline fn fillStackWithUndefined() void {
    var bytes: [64 * 1024]u8 = undefined;
    @memset(&bytes, 0xAA);
    std.mem.doNotOptimizeAway(&bytes);
}

test "an invalid ray() path releases nothing it did not make" {
    // Motion 1 2.1.1: each is not a <ray()>, so offset-path keeps no value.
    inline for (.{ "ray()", "ray(contain)", "ray(1deg 2deg)", "ray(at left)", "ray(10deg at 1px 2px 3px)" }) |input| {
        fillStackWithUndefined();
        try h.check(testing.allocator, "offset-path", input, "", false);
    }
}

fn computeArcRotation(allocator: Allocator) !void {
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    try testing.expect(try block.setProperty(.{ .allocator = allocator }, "clip-path", "shape(from 0 0, arc by 10px 20px of 5px rotate calc(10deg + 5deg))", ""));
    fillStackWithUndefined();
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    style.destroy();
}

test "a shape arc whose rotation fails to compute releases nothing it did not make" {
    // Shapes 1 3.1.1: the rotation is an <angle>, computed (Values 4 10.11)
    // with the rest of the command - each allocation of it may fail.
    try testing.checkAllAllocationFailures(testing.allocator, computeArcRotation, .{});
}
