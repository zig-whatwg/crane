//! Comment interface per WHATWG DOM Standard

const std = @import("std");
const webidl = @import("webidl");
const CharacterData = @import("character_data").CharacterData;

/// DOM Spec: interface Comment : CharacterData
/// CharacterData includes: ChildNode, NonDocumentTypeChildNode (inherited automatically)
pub const Comment = webidl.interface(struct {
    pub const extends = CharacterData;
    // NOTE: Codegen will inherit ChildNode and NonDocumentTypeChildNode from CharacterData

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !Comment {
        return .{
            .allocator = allocator,
            // TODO: Initialize CharacterData parent fields (will be added by codegen)
        };
    }

    pub fn deinit(self: *Comment) void {
        _ = self;
        // NOTE: Parent CharacterData cleanup will be handled by codegen
        // TODO: Call parent CharacterData deinit (will be added by codegen)
    }
}, .{
    .exposed = &.{.Window},
});
