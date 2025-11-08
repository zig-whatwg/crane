const std = @import("std");
const Token = @import("lexer.zig").Token;

pub const ParseError = error{
    UnexpectedToken,
    UnexpectedEof,
    InvalidType,
    InvalidExtendedAttribute,
    OutOfMemory,
    Overflow,
    InvalidCharacter,
};

pub fn reportError(
    filename: []const u8,
    token: Token,
    comptime fmt: []const u8,
    args: anytype,
) void {
    std.debug.print("{s}:{}:{}: error: ", .{ filename, token.line, token.column });
    std.debug.print(fmt, args);
    std.debug.print("\n", .{});
}

pub fn reportErrorSimple(
    filename: []const u8,
    token: Token,
    message: []const u8,
) void {
    std.debug.print("{s}:{}:{}: error: {s}\n", .{ filename, token.line, token.column, message });
}
