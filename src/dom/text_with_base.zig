//! TextWithBase - Temporary Text/CharacterData implementation with NodeBase
//!
//! This is a temporary type that demonstrates the NodeBase pattern for CharacterData-based nodes.
//! It combines Text and CharacterData functionality into a single type.
//!
//! Key difference from webidl/generated/dom/text.zig:
//! - Has `base: NodeBase` as the FIRST field (critical for safe casting)
//! - Allows safe downcasting from NodeBase* to TextWithBase*
//! - Enables XPath to extract text content from NodeBase* pointers
//!
//! NOTE: Codegen now generates NodeBase, but this is still used by XPath.
//! Can be migrated to generated types once XPath is updated to use webidl/generated/dom/Text.zig

const std = @import("std");
const node_base = @import("node_base.zig");
const Allocator = std.mem.Allocator;

pub const NodeBase = node_base.NodeBase;

/// Text node with NodeBase integration
/// Combines CharacterData and Text functionality
pub const TextWithBase = struct {
    // ========================================================================
    // CRITICAL: NodeBase MUST be the first field for safe @ptrCast
    // ========================================================================
    base: NodeBase,

    // ========================================================================
    // CharacterData fields (text content)
    // ========================================================================
    data: []u8,

    /// Initialize a new Text node
    pub fn init(allocator: Allocator, data: []const u8) !TextWithBase {
        return .{
            .base = NodeBase{
                .allocator = allocator,
                .node_type = NodeBase.TEXT_NODE,
                .node_name = "#text",
                .parent_node = null,
                .child_nodes = @import("infra").List(*NodeBase).init(allocator),
                .owner_document = null,
                .registered_observers = std.ArrayList(@TypeOf(node_base.RegisteredObserverType)).init(allocator),
            },
            .data = try allocator.dupe(u8, data),
        };
    }

    /// Clean up resources
    pub fn deinit(self: *TextWithBase) void {
        self.base.allocator.free(self.data);
        self.base.child_nodes.deinit();
        self.base.registered_observers.deinit();
    }

    /// Upcast Text to NodeBase
    pub fn asNode(self: *TextWithBase) *NodeBase {
        return &self.base;
    }

    /// Upcast Text to const NodeBase
    pub fn asNodeConst(self: *const TextWithBase) *const NodeBase {
        return &self.base;
    }

    /// Get text data (CharacterData interface)
    pub fn getData(self: *const TextWithBase) []const u8 {
        return self.data;
    }

    /// Set text data (CharacterData interface)
    pub fn setData(self: *TextWithBase, new_data: []const u8) !void {
        self.base.allocator.free(self.data);
        self.data = try self.base.allocator.dupe(u8, new_data);
    }

    /// Get length (number of code units)
    pub fn getLength(self: *const TextWithBase) usize {
        return self.data.len;
    }

    /// Append data
    pub fn appendData(self: *TextWithBase, append_data: []const u8) !void {
        const new_len = self.data.len + append_data.len;
        const new_data = try self.base.allocator.alloc(u8, new_len);

        @memcpy(new_data[0..self.data.len], self.data);
        @memcpy(new_data[self.data.len..], append_data);

        self.base.allocator.free(self.data);
        self.data = new_data;
    }
};

/// Comment node with NodeBase integration
pub const CommentWithBase = struct {
    // ========================================================================
    // CRITICAL: NodeBase MUST be the first field for safe @ptrCast
    // ========================================================================
    base: NodeBase,

    // ========================================================================
    // CharacterData fields (comment content)
    // ========================================================================
    data: []u8,

    /// Initialize a new Comment node
    pub fn init(allocator: Allocator, data: []const u8) !CommentWithBase {
        return .{
            .base = NodeBase{
                .allocator = allocator,
                .node_type = NodeBase.COMMENT_NODE,
                .node_name = "#comment",
                .parent_node = null,
                .child_nodes = @import("infra").List(*NodeBase).init(allocator),
                .owner_document = null,
                .registered_observers = std.ArrayList(@TypeOf(node_base.RegisteredObserverType)).init(allocator),
            },
            .data = try allocator.dupe(u8, data),
        };
    }

    /// Clean up resources
    pub fn deinit(self: *CommentWithBase) void {
        self.base.allocator.free(self.data);
        self.base.child_nodes.deinit();
        self.base.registered_observers.deinit();
    }

    /// Upcast Comment to NodeBase
    pub fn asNode(self: *CommentWithBase) *NodeBase {
        return &self.base;
    }

    /// Upcast Comment to const NodeBase
    pub fn asNodeConst(self: *const CommentWithBase) *const NodeBase {
        return &self.base;
    }

    /// Get comment data (CharacterData interface)
    pub fn getData(self: *const CommentWithBase) []const u8 {
        return self.data;
    }

    /// Set comment data (CharacterData interface)
    pub fn setData(self: *CommentWithBase, new_data: []const u8) !void {
        self.base.allocator.free(self.data);
        self.data = try self.base.allocator.dupe(u8, new_data);
    }
};
