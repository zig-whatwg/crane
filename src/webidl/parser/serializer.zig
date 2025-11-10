const std = @import("std");
const infra = @import("infra");
const ast = @import("ast.zig");
const ast_to_infra = @import("ast_to_infra.zig");

const AST = ast.AST;

pub fn writeToFile(ast_val: AST, filepath: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const infra_value = try ast_to_infra.astToInfraValue(allocator, ast_val);
    defer {
        infra_value.deinit(allocator);
        allocator.destroy(infra_value);
    }

    // Use pretty printing for better readability
    const json_bytes = try infra.json.serializeInfraValuePretty(allocator, infra_value.*);
    defer allocator.free(json_bytes);

    const file = try std.fs.cwd().createFile(filepath, .{});
    defer file.close();
    try file.writeAll(json_bytes);
}

pub fn serializeToWriter(ast_val: AST, writer: anytype) !void {
    _ = ast_val;
    _ = writer;
}
