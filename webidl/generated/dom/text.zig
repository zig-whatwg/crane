//! Text interface per WHATWG DOM Standard
//! Spec: https://dom.spec.whatwg.org/#interface-text

const std = @import("std");
const webidl = @import("webidl");
const CharacterData = @import("character_data").CharacterData;

const Allocator = std.mem.Allocator;

pub const Text = webidl.interface(struct {
    allocator: Allocator,
    character_data: CharacterData,

    pub fn init(allocator: Allocator) !Text {
        return .{
            .allocator = allocator,
            .character_data = try CharacterData.init(allocator),
        };
    }

    pub fn deinit(self: *Text) void {
        self.character_data.deinit();
    }
});
