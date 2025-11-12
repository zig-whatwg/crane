const std = @import("std");
const webidl = @import("webidl");

const Allocator = std.mem.Allocator;

pub const CustomElementRegistry = webidl.interface(struct {
    allocator: Allocator,
    is_scoped: bool,
    scoped_document_set: std.ArrayList(*anyopaque),

    pub fn init(allocator: Allocator, is_scoped: bool) !CustomElementRegistry {
        return .{
            .allocator = allocator,
            .is_scoped = is_scoped,
            .scoped_document_set = std.ArrayList(*anyopaque).init(allocator),
        };
    }

    pub fn deinit(self: *CustomElementRegistry) void {
        self.scoped_document_set.deinit();
    }
}, .{
    .exposed = &.{.Window},
});
