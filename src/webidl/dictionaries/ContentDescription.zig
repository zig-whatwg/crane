//! WebIDL dictionary: ContentDescription
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const ImageResource = @import("ImageResource.zig").ImageResource;

pub const ContentDescription = struct {
    id: runtime.DOMString,
    title: runtime.DOMString,
    description: runtime.DOMString,
    category: ?enums.ContentCategory = null,
    icons: ?[]const ImageResource = null,
    url: runtime.USVString,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "category", .{ .string = "" } },
        .{ "icons", .empty_sequence },
    };
};
