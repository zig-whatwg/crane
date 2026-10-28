//! Lane cascadefast2: the computed values of every longhand are what the
//! flat one-slot-per-longhand storage answered (characterization; the cases
//! and why are in cascadefast2_storage_cases.zig). Allocation failure on the
//! storage's paths: cascadefast2_groups_test.zig.
const std = @import("std");
const testing = std.testing;
const cases = @import("cascadefast2_storage_cases.zig");

const golden = @embedFile("cascadefast2_storage_golden.txt");

test "every longhand's resolved value is the flat storage's in every case" {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try cases.render(testing.allocator, &out);
    if (std.mem.eql(u8, out.items, golden)) return;
    // Name the first differing line and its case.
    var got = std.mem.splitScalar(u8, out.items, '\n');
    var want = std.mem.splitScalar(u8, golden, '\n');
    var case: []const u8 = "";
    var n: usize = 1;
    while (true) : (n += 1) {
        const g = got.next();
        const w = want.next();
        if (g == null and w == null) break;
        if (w) |line| if (std.mem.startsWith(u8, line, "== ")) {
            case = line;
        };
        if (g == null or w == null or !std.mem.eql(u8, g.?, w.?)) {
            std.debug.print("line {d} ({s}): got '{s}', golden '{s}'\n", .{ n, case, g orelse "<end>", w orelse "<end>" });
            break;
        }
    }
    return error.TestExpectedEqual;
}
