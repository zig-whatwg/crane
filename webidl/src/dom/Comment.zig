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

    pub fn init(allocator: std.mem.Allocator, data: []const u8) !Comment {
        const infra = @import("infra");
        const Node = @import("node").Node;
        const RegisteredObserver = @import("registered_observer").RegisteredObserver;

        return .{
            // From EventTarget (via Node/CharacterData)
            .event_listener_list = null,
            // From Node (via CharacterData)
            .node_type = 8, // COMMENT_NODE
            .node_name = "#comment",
            .parent_node = null,
            .child_nodes = infra.List(*Node).init(allocator),
            .owner_document = null,
            .registered_observers = infra.List(RegisteredObserver).init(allocator),
            .cloning_steps_hook = null,
            .cached_child_nodes = null,
            // From CharacterData
            .data = try allocator.dupe(u8, data),
            // Comment-specific
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
