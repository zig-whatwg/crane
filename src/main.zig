const std = @import("std");
const whatwg = @import("whatwg");
const infra = @import("infra");

pub fn main() !void {
    // Prints to stderr, ignoring potential errors.
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
    try whatwg.bufferedPrint();
}


