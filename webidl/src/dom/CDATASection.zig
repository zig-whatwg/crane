//! CDATASection interface per WHATWG DOM Standard
//! Spec: https://dom.spec.whatwg.org/#interface-cdatasection
//! DOM §4.12

const std = @import("std");
const webidl = @import("webidl");
const Text = @import("text").Text;

/// DOM §4.12 - CDATASection interface
/// CDATASection extends Text but adds no additional members.
/// It's used to represent CDATA sections in XML documents.
pub const CDATASection = webidl.interface(struct {
    pub const extends = Text;
    pub const includes = .{}; // No mixins

    pub fn init(allocator: std.mem.Allocator, data: []const u8) !CDATASection {
        return .{
            .allocator = allocator,
            .data = try allocator.dupe(u8, data),
        };
    }

    pub fn deinit(self: *CDATASection) void {
        self.allocator.free(self.data);
        // NOTE: Parent Text/CharacterData/Node cleanup will be handled by codegen
    }
}, .{
    .exposed = &.{.Window},
});
