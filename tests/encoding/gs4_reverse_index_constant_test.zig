//! The legacy CJK encoders' reverse indexes (src/encoding/reverse_index.zig)
//! are constants, built at compile time (lane gstate4): no thread builds,
//! initialises or frees one, so two threads' first lookups cannot race. They
//! were five process-wide `var`s built on first use behind atomic flags -
//! two threads' first lookups both built the index and both wrote it while a
//! third read it - and a test's `deinit()` freed them under any other
//! thread's encoder.
const std = @import("std");
const encoding = @import("encoding");
const reverse_index = encoding.reverse_index;

test "the reverse indexes are compile-time constants" {
    comptime {
        // Index jis0208's pointer 0 is U+3000 IDEOGRAPHIC SPACE.
        std.debug.assert(reverse_index.jis0208.findPointer(0x3000).? == 0);
        std.debug.assert(reverse_index.euc_kr.findPointer(0xAC00) != null);
        std.debug.assert(reverse_index.gb18030.findPointer(0x4E2D) != null);
        std.debug.assert(reverse_index.big5.findPointer(0x3000) != null);
        std.debug.assert(reverse_index.jis0212.len() > 0);
    }
    try std.testing.expect(@typeInfo(@TypeOf(&reverse_index.jis0208)).pointer.attrs.@"const");
}

test "threads that encode at once read the same tables" {
    const tables = [_]*const reverse_index.ReverseIndex{ &reverse_index.jis0208, &reverse_index.jis0212, &reverse_index.big5, &reverse_index.gb18030, &reverse_index.euc_kr };
    const Encode = struct {
        fn run(found: *[tables.len]?u16) void {
            for (tables, found) |table, *pointer| {
                // A code point the table maps, from the middle of its order.
                const code_point = table.index[table.pointerAt(table.len() / 2)];
                pointer.* = table.findPointer(code_point);
            }
        }
    };
    var results: [4][tables.len]?u16 = undefined;
    var threads: [4]std.Thread = undefined;
    for (&threads, &results) |*thread, *found| thread.* = try std.Thread.spawn(.{}, Encode.run, .{found});
    for (threads) |thread| thread.join();
    for (results[1..]) |found| try std.testing.expectEqualSlices(?u16, &results[0], &found);
    for (results[0]) |pointer| try std.testing.expect(pointer != null);
}
