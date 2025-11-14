//! CDATASection interface per WHATWG DOM Standard
//! Spec: https://dom.spec.whatwg.org/#interface-cdatasection
//! DOM §4.12

const std = @import("std");
const webidl = @import("webidl");
const infra = @import("infra");
const Text = @import("text").Text;

/// DOM §4.12 - CDATASection interface
/// CDATASection extends Text but adds no additional members.
/// It's used to represent CDATA sections in XML documents.
pub const CDATASection = webidl.interface(struct {
    pub const extends = Text;
    pub const includes = .{}; // No mixins

    pub fn init(allocator: std.mem.Allocator, data: []const u8) !CDATASection {
        const Node = @import("node").Node;
        return .{
            // EventTarget fields
            .event_listener_list = null,
            // Node fields
            .node_type = 4, // CDATA_SECTION_NODE
            .node_name = "#cdata-section",
            .parent_node = null,
            .child_nodes = infra.List(*Node).init(allocator),
            .owner_document = null,
            .registered_observers = infra.List(@import("registered_observer").RegisteredObserver).init(allocator),
            .cloning_steps_hook = null,
            .cached_child_nodes = null,
            // CharacterData/Text fields
            .allocator = allocator,
            .data = try allocator.dupe(u8, data),
            // Slottable mixin fields
            .slottable_name = "",
            .assigned_slot = null,
            .manual_slot_assignment = null,
        };
    }

    pub fn deinit(self: *CDATASection) void {
        self.allocator.free(self.data);
        // NOTE: Parent Text/CharacterData/Node cleanup will be handled by codegen
    }
}, .{
    .exposed = &.{.Window},
});
