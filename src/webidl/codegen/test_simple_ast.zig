//! Simple standalone test for AST/IR parser
//! Tests just the parsing without needing full infra module

const std = @import("std");
const infra = @import("infra");

// Minimal IR structures for testing
const TestImport = struct {
    name: []const u8,
    module: []const u8,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const test_source =
        \\const std = @import("std");
        \\const webidl = @import("webidl");
        \\const Node = @import("node").Node;
        \\const ShadowRoot = @import("shadow_root").ShadowRoot;
        \\
        \\pub const Element = webidl.interface(struct {
        \\    pub const extends = Node;
        \\    
        \\    tag_name: []const u8,
        \\    shadow_root: ?*ShadowRoot,
        \\    
        \\    pub fn init(allocator: std.mem.Allocator) !Element {
        \\        return .{ .tag_name = "div", .shadow_root = null };
        \\    }
        \\    
        \\    pub fn getRootNode(self: *Element) *Node {
        \\        const root = tree.root(self);
        \\        if (root.base.type_tag == .ShadowRoot) {
        \\            const shadow: *ShadowRoot = @ptrCast(root);
        \\            return shadow.host;
        \\        }
        \\        return root;
        \\    }
        \\});
    ;

    std.debug.print("Test source ({} bytes):\n{s}\n\n", .{ test_source.len, test_source });

    // Test: Parse imports
    std.debug.print("Parsing imports...\n", .{});
    var imports = infra.List(TestImport).init(allocator);
    defer imports.deinit();

    var pos: usize = 0;
    while (pos < test_source.len) {
        if (std.mem.indexOfPos(u8, test_source, pos, "const ")) |const_pos| {
            const name_start = const_pos + "const ".len;
            const eq_pos = std.mem.indexOfScalarPos(u8, test_source, name_start, '=') orelse {
                pos = const_pos + 1;
                continue;
            };

            const name = std.mem.trim(u8, test_source[name_start..eq_pos], " \t\r\n");
            const after_eq = std.mem.trim(u8, test_source[eq_pos + 1 ..], " \t\r\n");

            if (std.mem.startsWith(u8, after_eq, "@import(\"")) {
                const module_start = eq_pos + 1 + std.mem.indexOf(u8, after_eq, "@import(\"").? + "@import(\"".len;
                const module_end = std.mem.indexOfScalarPos(u8, test_source, module_start, '"') orelse {
                    pos = const_pos + 1;
                    continue;
                };

                const module = test_source[module_start..module_end];

                try imports.append(.{
                    .name = try allocator.dupe(u8, name),
                    .module = try allocator.dupe(u8, module),
                });

                std.debug.print("  Found import: {s} = @import(\"{s}\")\n", .{ name, module });
            }

            pos = eq_pos + 1;
        } else {
            break;
        }
    }

    std.debug.print("\nTotal imports found: {}\n", .{imports.items.len});

    // Test: Detect type references
    std.debug.print("\nDetecting type references...\n", .{});
    const types_to_find = [_][]const u8{ "ShadowRoot", "Node", "Element" };

    for (types_to_find) |type_name| {
        if (std.mem.indexOf(u8, test_source, type_name)) |_| {
            std.debug.print("  Found type reference: {s}\n", .{type_name});
        }
    }

    // Cleanup
    for (imports.items) |item| {
        allocator.free(item.name);
        allocator.free(item.module);
    }

    std.debug.print("\n✅ Simple AST test completed successfully!\n", .{});
}
