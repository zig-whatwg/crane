//! WebIDL dictionary: NotificationOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");
const NotificationAction = @import("NotificationAction.zig").NotificationAction;

pub const NotificationOptions = struct {
    dir: ?enums.NotificationDirection = null,
    lang: ?runtime.DOMString = null,
    body: ?runtime.DOMString = null,
    navigate: ?runtime.USVString = null,
    tag: ?runtime.DOMString = null,
    image: ?runtime.USVString = null,
    icon: ?runtime.USVString = null,
    badge: ?runtime.USVString = null,
    vibrate: ?typedefs.VibratePattern = null,
    timestamp: ?typedefs.EpochTimeStamp = null,
    renotify: ?bool = null,
    silent: ?bool = null,
    requireInteraction: ?bool = null,
    data: ?runtime.JSValue = null,
    actions: ?[]const NotificationAction = null,

    /// `any` members: one present with the value null converts to `.null`,
    /// not to "not present".
    pub const any_members = .{"data"};

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "dir", .{ .string = "auto" } },
        .{ "lang", .{ .string = "" } },
        .{ "body", .{ .string = "" } },
        .{ "tag", .{ .string = "" } },
        .{ "renotify", .{ .boolean = false } },
        .{ "silent", .null },
        .{ "requireInteraction", .{ .boolean = false } },
        .{ "data", .null },
        .{ "actions", .empty_sequence },
    };

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"silent"};
};
