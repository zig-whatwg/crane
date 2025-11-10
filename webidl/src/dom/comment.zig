//! Comment interface per WHATWG DOM Standard

const std = @import("std");
const webidl = @import("webidl");
const CharacterData = @import("character_data").CharacterData;

pub const Comment = webidl.interface(struct {
    allocator: std.mem.Allocator,
    character_data: CharacterData,

    pub fn init(allocator: std.mem.Allocator) !Comment {
        return .{
            .allocator = allocator,
            .character_data = try CharacterData.init(allocator),
        };
    }

    pub fn deinit(self: *Comment) void {
        self.character_data.deinit();
    }
}, .{
    .exposed = &.{.Window},
});
