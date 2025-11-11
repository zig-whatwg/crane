//! Text interface per WHATWG DOM Standard
//! Spec: https://dom.spec.whatwg.org/#interface-text

const std = @import("std");
const webidl = @import("webidl");
const CharacterData = @import("character_data").CharacterData;

const Allocator = std.mem.Allocator;

/// DOM Spec: interface Text : CharacterData
/// CharacterData includes: ChildNode, NonDocumentTypeChildNode (inherited automatically)
/// Text includes: Slottable
pub const Text = webidl.interface(struct {
    pub const extends = CharacterData;
    // NOTE: Codegen will inherit ChildNode and NonDocumentTypeChildNode from CharacterData
    // pub const includes = .{ Slottable }; // TODO: Uncomment when Slottable mixin is created

    allocator: Allocator,

    pub fn init(allocator: Allocator) !Text {
        return .{
            .allocator = allocator,
            // TODO: Initialize CharacterData parent fields (will be added by codegen)
        };
    }

    pub fn deinit(self: *Text) void {
        _ = self;
        // NOTE: Parent CharacterData cleanup will be handled by codegen
        // TODO: Call parent CharacterData deinit (will be added by codegen)
    }
}, .{
    .exposed = &.{.Window},
});
