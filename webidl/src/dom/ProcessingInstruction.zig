//! ProcessingInstruction interface per WHATWG DOM Standard
//! Spec: https://dom.spec.whatwg.org/#interface-processinginstruction
//! DOM §4.13

const std = @import("std");
const webidl = @import("webidl");
const CharacterData = @import("character_data").CharacterData;
const dom_types = @import("dom_types");
const Element = @import("element").Element;

/// DOM §4.13 - ProcessingInstruction interface
/// ProcessingInstruction nodes represent processing instructions.
/// They extend CharacterData and have an associated target.
pub const ProcessingInstruction = webidl.interface(struct {
    pub const extends = CharacterData;
    pub const includes = .{}; // No mixins

    /// The target of this processing instruction
    target: []const u8,

    pub fn init(allocator: std.mem.Allocator, target: []const u8, data: []const u8) !ProcessingInstruction {
        return .{
            .allocator = allocator,
            .target = try allocator.dupe(u8, target),
            .data = try allocator.dupe(u8, data),
            // TODO: Initialize Node parent fields (will be added by codegen)
        };
    }

    pub fn deinit(self: *ProcessingInstruction) void {
        self.allocator.free(self.target);
        self.allocator.free(self.data);
        // NOTE: Parent CharacterData/Node cleanup will be handled by codegen
    }

    /// DOM §4.13 - target getter
    /// Returns this's target.
    pub fn get_target(self: *const ProcessingInstruction) []const u8 {
        return self.target;
    }
}, .{
    .exposed = &.{.Window},
});
