//! Test for AST/IR-based codegen pipeline

const std = @import("std");
const parser = @import("parser.zig");
const optimizer = @import("optimizer.zig");
const generator = @import("generator.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Test with Node.zig
    const node_source_path = "webidl/src/dom/Node.zig";
    const node_source = try std.fs.cwd().readFileAlloc(allocator, node_source_path, 10 * 1024 * 1024);
    defer allocator.free(node_source);

    std.debug.print("Parsing {s}...\n", .{node_source_path});

    // Step 1: Parse
    var file_ir = try parser.parseFile(allocator, node_source, node_source_path);
    defer file_ir.deinit(allocator);

    std.debug.print("  Found {} classes\n", .{file_ir.classes.len});
    std.debug.print("  Found {} module imports\n", .{file_ir.module_imports.len});

    if (file_ir.classes.len > 0) {
        const class = file_ir.classes[0];
        std.debug.print("  Class: {s}\n", .{class.name});
        std.debug.print("    Fields: {}\n", .{class.own_fields.len});
        std.debug.print("    Methods: {}\n", .{class.own_methods.len});
        std.debug.print("    Parent: {s}\n", .{class.parent orelse "none"});
        std.debug.print("    Required imports: {}\n", .{class.required_imports.len});
    }

    // Step 2: Optimize (create registry)
    var registry = optimizer.ClassRegistry.init(allocator);
    defer registry.deinit();

    for (file_ir.classes) |*class| {
        try registry.register(class);
    }

    if (file_ir.classes.len > 0) {
        std.debug.print("\nEnhancing class...\n", .{});
        var enhanced = try optimizer.enhanceClass(allocator, &file_ir.classes[0], &registry);
        defer enhanced.deinit(allocator);

        std.debug.print("  All fields: {}\n", .{enhanced.all_fields.len});
        std.debug.print("  All methods: {}\n", .{enhanced.all_methods.len});
        std.debug.print("  All imports: {}\n", .{enhanced.all_imports.len});

        // Step 3: Generate
        std.debug.print("\nGenerating code...\n", .{});
        const generated_code = try generator.generateCode(allocator, enhanced);
        defer allocator.free(generated_code);

        std.debug.print("Generated {} bytes\n", .{generated_code.len});
        std.debug.print("\nFirst 500 characters:\n", .{});
        std.debug.print("{s}\n", .{generated_code[0..@min(500, generated_code.len)]});
    }

    std.debug.print("\n✅ AST pipeline test completed successfully!\n", .{});
}
