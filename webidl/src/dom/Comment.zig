//! Comment interface per WHATWG DOM Standard

const std = @import("std");
const webidl = @import("webidl");
const CharacterData = @import("character_data").CharacterData;
const ChildNode = @import("child_node").ChildNode;
const NonDocumentTypeChildNode = @import("non_document_type_child_node").NonDocumentTypeChildNode;
const dom_types = @import("dom_types");

/// DOM Spec: interface Comment : CharacterData
/// Comment extends CharacterData (fields/methods inherited)
/// Comment must EXPLICITLY include parent mixins (codegen doesn't inherit them)
/// CharacterData includes: ChildNode, NonDocumentTypeChildNode
pub const Comment = webidl.interface(struct {
    pub const extends = CharacterData;
    // CRITICAL: Must explicitly include parent mixins - codegen doesn't inherit them!
    pub const includes = .{ ChildNode, NonDocumentTypeChildNode }; // From parent CharacterData

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !Comment {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Comment) void {
        _ = self;
        // NOTE: Parent CharacterData cleanup is handled by codegen
    }
}, .{
    .exposed = &.{.Window},
});
