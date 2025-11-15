//! DocumentType interface per WHATWG DOM Standard

const std = @import("std");
const webidl = @import("webidl");
const infra = @import("infra");
const Node = @import("node").Node;
const Document = @import("document").Document;
const ChildNode = @import("child_node").ChildNode;
const dom_types = @import("dom_types");

/// DOM Spec: interface DocumentType : Node
pub const DocumentType = webidl.interface(struct {
    pub const extends = Node;
    pub const includes = .{ChildNode};

    allocator: std.mem.Allocator,
    /// The name of the doctype (e.g., "html" for <!DOCTYPE html>)
    name: []const u8,
    /// The public identifier (empty string if not specified)
    public_id: []const u8,
    /// The system identifier (empty string if not specified)
    system_id: []const u8,

    pub fn init(
        allocator: std.mem.Allocator,
        name: []const u8,
        public_id: []const u8,
        system_id: []const u8,
    ) !DocumentType {
        // NOTE: Parent Node/EventTarget fields must be initialized here
        return .{
            .event_listener_list = null, // From EventTarget
            .allocator = allocator,
            .node_type = 10, // DOCUMENT_TYPE_NODE
            .node_name = name, // Per DOM spec, DocumentType's nodeName is its name
            .parent_node = null,
            .child_nodes = infra.List(*Node).init(allocator),
            .owner_document = null,
            .registered_observers = infra.List(@import("registered_observer").RegisteredObserver).init(allocator),
            .cloning_steps_hook = null,
            .cached_child_nodes = null,
            .name = try allocator.dupe(u8, name),
            .public_id = try allocator.dupe(u8, public_id),
            .system_id = try allocator.dupe(u8, system_id),
        };
    }

    pub fn deinit(self: *DocumentType) void {
        self.allocator.free(self.name);
        self.allocator.free(self.public_id);
        self.allocator.free(self.system_id);
        // NOTE: Parent Node cleanup is handled by codegen
    }

    /// DOM §4.7 - name getter
    /// Returns this's name.
    pub fn get_name(self: *const DocumentType) []const u8 {
        return self.name;
    }

    /// DOM §4.7 - publicId getter
    /// Returns this's public ID.
    pub fn get_publicId(self: *const DocumentType) []const u8 {
        return self.public_id;
    }

    /// DOM §4.7 - systemId getter
    /// Returns this's system ID.
    pub fn get_systemId(self: *const DocumentType) []const u8 {
        return self.system_id;
    }
}, .{
    .exposed = &.{.Window},
});
