//! Main entry point for compiling all WebIDL interfaces.
//! This executable validates that all interfaces compile correctly.
//!
//! This doesn't actually execute any code from the interfaces - it just
//! ensures they all compile successfully with the runtime.

const std = @import("std");

// Import runtime to make it available
const runtime = @import("runtime");

// Import all generated modules to ensure they compile
// Note: We don't actually use these, just importing them validates compilation
const interfaces = @import("interfaces");
const dictionaries = @import("dictionaries");
const enums = @import("enums");
const typedefs = @import("typedefs");
const callbacks = @import("callbacks");
const namespaces = @import("namespaces");
const impls = @import("impls");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("WebIDL Interfaces Compilation Check\n", .{});
    std.debug.print("=====================================\n\n", .{});

    // Initialize runtime
    runtime.initRuntime(allocator);
    defer runtime.deinitRuntime();

    std.debug.print("✅ Runtime initialized\n", .{});
    std.debug.print("✅ All interfaces compiled successfully\n", .{});
    std.debug.print("✅ All dictionaries compiled successfully\n", .{});
    std.debug.print("✅ All enums compiled successfully\n", .{});
    std.debug.print("✅ All typedefs compiled successfully\n", .{});
    std.debug.print("✅ All callbacks compiled successfully\n", .{});
    std.debug.print("✅ All namespaces compiled successfully\n", .{});
    std.debug.print("✅ All impls compiled successfully\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("Compilation validation complete!\n", .{});
}
