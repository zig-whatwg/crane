//! Relative color channels are scoped numeric leaves, never retained contexts.
const std = @import("std");
const math = @import("css").math_values;
const testing = std.testing;
const has_api = @hasDecl(math, "Symbol") and @hasDecl(math, "SymbolValues");

test "relative color symbols are rejected by default outside a color channel" {
    try testing.expect((try math.parse(testing.allocator, "calc(r + 1)", .{ .kind = .number })) == null);
}

test "relative color symbols are admitted only by their channel grammar" {
    if (comptime !has_api) return error.ColorSymbolApiNotImplemented;
    const allowed = math.Symbol.r.bit() | math.Symbol.alpha.bit();
    const grammar: math.Grammar = .{ .kind = .number, .allowed_symbols = allowed };
    try testing.expect((try math.parse(testing.allocator, "calc(g + 1)", grammar)) == null);
    const parsed = (try math.parse(testing.allocator, "calc(R + alpha)", grammar)).?;
    defer parsed.expression.unref();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try parsed.expression.serialize(&out, testing.allocator);
    try testing.expectEqualStrings("calc(r + alpha)", out.items);
}

test "relative color computation copies scalar channels and never keeps their context" {
    if (comptime !has_api) return error.ColorSymbolApiNotImplemented;
    const parsed = (try math.parse(testing.allocator, "calc(r / 2 + alpha)", .{ .kind = .number, .allowed_symbols = math.Symbol.r.bit() | math.Symbol.alpha.bit() })).?;
    defer parsed.expression.unref();
    var symbols = math.SymbolValues{};
    symbols.values[@intFromEnum(math.Symbol.r)] = 80;
    symbols.values[@intFromEnum(math.Symbol.alpha)] = 0.5;
    const computed = try parsed.expression.compute(testing.allocator, .{ .symbols = &symbols });
    defer computed.unref();
    symbols.values[@intFromEnum(math.Symbol.r)] = 20;
    try testing.expectEqual(@as(f64, 40.5), computed.computedNumber().?.value);
    const again = try parsed.expression.compute(testing.allocator, .{ .symbols = &symbols });
    defer again.unref();
    try testing.expectEqual(@as(f64, 10.5), again.computedNumber().?.value);
    try testing.expect(parsed.expression.computedNumber() == null);
}

test "relative color symbols retain CSS numeric types and distinguish their names" {
    if (comptime !has_api) return error.ColorSymbolApiNotImplemented;
    const allowed = math.Symbol.r.bit() | math.Symbol.b.bit();
    const red = (try math.parse(testing.allocator, "calc(r)", .{ .kind = .number, .allowed_symbols = allowed })).?;
    defer red.expression.unref();
    const blue = (try math.parse(testing.allocator, "calc(b)", .{ .kind = .number, .allowed_symbols = allowed })).?;
    defer blue.expression.unref();
    try testing.expect(!red.expression.eql(blue.expression));
    try testing.expect((try math.parse(testing.allocator, "calc(r + 10%)", .{ .kind = .number, .allowed_symbols = allowed })) == null);
    const percentage = (try math.parse(testing.allocator, "calc(r * 100%)", .{ .kind = .percentage, .allowed_symbols = allowed })).?;
    defer percentage.expression.unref();
    var symbols = math.SymbolValues{};
    symbols.values[@intFromEnum(math.Symbol.r)] = 0.5;
    const result = try percentage.expression.compute(testing.allocator, .{ .symbols = &symbols });
    defer result.unref();
    try testing.expectEqual(math.Unit.percent, result.computedNumber().?.unit);
    try testing.expectEqual(@as(f64, 50), result.computedNumber().?.value);
}

test "relative color symbol parse and compute release every allocation failure" {
    if (comptime !has_api) return error.ColorSymbolApiNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailure, .{});
}

fn allocationFailure(allocator: std.mem.Allocator) !void {
    const parsed = (try math.parse(allocator, "calc(r / 2 + alpha)", .{ .kind = .number, .allowed_symbols = math.Symbol.r.bit() | math.Symbol.alpha.bit() })).?;
    defer parsed.expression.unref();
    var symbols = math.SymbolValues{};
    symbols.values[@intFromEnum(math.Symbol.r)] = 0.8;
    symbols.values[@intFromEnum(math.Symbol.alpha)] = 0.1;
    const result = try parsed.expression.compute(allocator, .{ .symbols = &symbols });
    defer result.unref();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try result.serialize(&out, allocator);
    try testing.expectEqualStrings("0.5", out.items);
}
