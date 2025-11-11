//! Text interface per WHATWG DOM Standard
//! Spec: https://dom.spec.whatwg.org/#interface-text

const std = @import("std");
const webidl = @import("webidl");
const CharacterData = @import("character_data").CharacterData;
const ChildNode = @import("child_node").ChildNode;
const NonDocumentTypeChildNode = @import("non_document_type_child_node").NonDocumentTypeChildNode;
const dom_types = @import("dom_types");
const Element = @import("element").Element;

const Allocator = std.mem.Allocator;

/// DOM Spec: interface Text : CharacterData
/// Text extends CharacterData (fields/methods inherited)
/// Text must EXPLICITLY include parent mixins (codegen doesn't inherit them)
/// CharacterData includes: ChildNode, NonDocumentTypeChildNode
/// Text also includes: Slottable
pub const Text = webidl.interface(struct {
    pub const extends = CharacterData;
    // CRITICAL: Must explicitly include parent mixins - codegen doesn't inherit them!
    pub const includes = .{ ChildNode, NonDocumentTypeChildNode }; // From parent CharacterData
    // TODO: Add Slottable when mixin is created

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
