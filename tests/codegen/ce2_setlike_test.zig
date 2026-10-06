//! WebIDL 3.7.12: CustomStateSet's setlike declaration must reach the binding.
const std = @import("std");
const codegen = @import("codegen");
const testing = std.testing;

test "CE2 codegen: setlike query and mutation members survive the merged model" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const parsed = try codegen.idl_parser.Parser.parse(arena.allocator(),
        \\[Exposed=Window] interface CustomStateSet { setlike<DOMString>; };
    );
    var model = try codegen.ir.IR.init(testing.allocator);
    defer model.deinit();
    try model.addInterface(parsed.interfaces[0], "ce2.idl");
    try model.finish();
    const members = model.interfaces.get("CustomStateSet").?.members.items;
    inline for (.{ "has", "add", "delete", "clear", "forEach" }) |name| {
        var found = false;
        for (members) |member| {
            if (member.asOperation()) |operation| {
                if (operation.name) |value| if (std.mem.eql(u8, value, name)) {
                    found = true;
                };
            }
        }
        try testing.expect(found);
    }
    var has_size = false;
    for (members) |member| {
        if (member.asAttribute()) |attribute| {
            if (std.mem.eql(u8, attribute.name, "size")) {
                try testing.expect(attribute.readonly);
                has_size = true;
            }
        }
    }
    try testing.expect(has_size);
}
