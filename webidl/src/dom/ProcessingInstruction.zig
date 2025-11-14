//! ProcessingInstruction interface per WHATWG DOM Standard
//! Spec: https://dom.spec.whatwg.org/#interface-processinginstruction
//! DOM §4.13

const std = @import("std");
const webidl = @import("webidl");
const CharacterData = @import("character_data").CharacterData;
const dom_types = @import("dom_types");

/// DOM §4.13 - ProcessingInstruction interface
/// ProcessingInstruction nodes represent processing instructions.
/// They extend CharacterData and have an associated target.
pub const ProcessingInstruction = webidl.interface(struct {
    pub const extends = CharacterData;
    pub const includes = .{}; // No mixins

    /// The target of this processing instruction
    target: []const u8,

    pub fn init(allocator: std.mem.Allocator, target: []const u8, data: []const u8) !ProcessingInstruction {
        const infra = @import("infra");
        const Node = @import("node").Node;
        const RegisteredObserver = @import("registered_observer").RegisteredObserver;

        return .{
            // From EventTarget (via Node/CharacterData)
            .event_listener_list = null,
            // From Node (via CharacterData)
            .node_type = 7, // PROCESSING_INSTRUCTION_NODE
            .node_name = try allocator.dupe(u8, target),
            .parent_node = null,
            .child_nodes = infra.List(*Node).init(allocator),
            .owner_document = null,
            .registered_observers = infra.List(RegisteredObserver).init(allocator),
            .cloning_steps_hook = null,
            .cached_child_nodes = null,
            // From CharacterData
            .data = try allocator.dupe(u8, data),
            // ProcessingInstruction-specific
            .allocator = allocator,
            .target = try allocator.dupe(u8, target),
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
