//! Every callback function whose return value needs a WebIDL conversion is
//! either converted by generated code or listed (lane bind1, 2026-11-24).
//!
//! WebIDL "invoke a callback function" converts the returned value to the
//! callback's return type. Codegen generates no invocation yet, so an impl
//! converts by hand - and nothing said which callbacks those are: the
//! createParserOptions callback's `SetHTMLUnsafeOptions?` was found only when
//! its dictionary's union left codegen's table of hand-converted unions.
//! `callback_returns_converted_by_impl` is that list, at its true size: this
//! test reads every generated callback (src/webidl/callbacks/, which
//! `codegen-check` keeps equal to the IDL) and requires the list to be
//! exactly the ones whose return type is neither `undefined` nor `any`.
//! Batch B6 generates the invocation and takes entries out; the count below
//! only goes down.

const std = @import("std");
const codegen = @import("codegen");
const testing = std.testing;

const list = codegen.callback_returns.callback_returns_converted_by_impl;

fn read(path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(testing.io, path, testing.allocator, .limited(1024 * 1024));
}

/// The return type in a generated callback file's signature line,
/// `/// callback Name = <return type> (<arguments>)`; null when the file
/// has no such line for `name`.
fn returnTypeOf(source: []const u8, name: []const u8) ?[]const u8 {
    var lines = std.mem.splitScalar(u8, source, '\n');
    while (lines.next()) |line| {
        if (!std.mem.startsWith(u8, line, "/// callback ")) continue;
        const rest = line["/// callback ".len..];
        if (!std.mem.startsWith(u8, rest, name)) continue;
        const after = rest[name.len..];
        if (!std.mem.startsWith(u8, after, " = ")) continue;
        const signature = after[" = ".len..];
        const open = std.mem.indexOf(u8, signature, " (") orelse return null;
        return signature[0..open];
    }
    return null;
}

fn listed(name: []const u8) ?usize {
    for (list, 0..) |entry, i| if (std.mem.eql(u8, entry[0], name)) return i;
    return null;
}

test "the list is exactly the generated callbacks whose return type is neither undefined nor any" {
    const root = try read("src/webidl/callbacks/root.zig");
    defer testing.allocator.free(root);
    var seen: usize = 0;
    var callbacks: usize = 0;
    var lines = std.mem.splitScalar(u8, root, '\n');
    while (lines.next()) |line| {
        // `pub const Name = @import("Name.zig").Name;`
        if (!std.mem.startsWith(u8, line, "pub const ")) continue;
        const rest = line["pub const ".len..];
        const end = std.mem.indexOf(u8, rest, " = @import(\"") orelse continue;
        const name = rest[0..end];
        const path = try std.fmt.allocPrint(testing.allocator, "src/webidl/callbacks/{s}.zig", .{name});
        defer testing.allocator.free(path);
        const source = try read(path);
        defer testing.allocator.free(source);
        const return_type = returnTypeOf(source, name) orelse {
            std.debug.print("src/webidl/callbacks/{s}.zig has no `/// callback {s} = ...` line\n", .{ name, name });
            return error.TestUnexpectedResult;
        };
        callbacks += 1;
        const converts = !std.mem.eql(u8, return_type, "undefined") and !std.mem.eql(u8, return_type, "any");
        if (listed(name)) |index| {
            seen += 1;
            if (!converts) {
                std.debug.print("{s} returns {s}: nothing to convert, it does not belong in the list\n", .{ name, return_type });
                return error.TestUnexpectedResult;
            }
            try testing.expectEqualStrings(return_type, list[index][1]);
        } else if (converts) {
            std.debug.print("callback {s} returns {s} and is not in callback_returns_converted_by_impl\n", .{ name, return_type });
            return error.TestUnexpectedResult;
        }
    }
    // Every entry names a generated callback, once.
    try testing.expectEqual(list.len, seen);
    for (list, 0..) |entry, i| {
        for (list[0..i]) |earlier| try testing.expect(!std.mem.eql(u8, entry[0], earlier[0]));
    }
    try testing.expect(callbacks > list.len);
}

test "the callback returns an impl still converts only shrink" {
    // 28 at the start (2026-11-24): 10 with a value type, 4 promise types
    // whose resolution value has a type, Promise<undefined> x11 and
    // Promise<any> x3. Batch B6 is done at zero.
    try testing.expectEqual(@as(usize, 28), list.len);
    var by_kind: [4]usize = @splat(0);
    for (list) |entry| by_kind[@backingInt(entry[2])] += 1;
    const Conversion = codegen.callback_returns.Conversion;
    try testing.expectEqual(@as(usize, 6), by_kind[@backingInt(Conversion.hand)]);
    try testing.expectEqual(@as(usize, 1), by_kind[@backingInt(Conversion.protocol_typed)]);
    try testing.expectEqual(@as(usize, 12), by_kind[@backingInt(Conversion.promise_wrap)]);
    try testing.expectEqual(@as(usize, 9), by_kind[@backingInt(Conversion.not_invoked)]);
}
