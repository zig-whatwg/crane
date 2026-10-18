//! WebIDL dictionary: StorageAccessTypes
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const StorageAccessTypes = struct {
    all: ?bool = null,
    cookies: ?bool = null,
    sessionStorage: ?bool = null,
    localStorage: ?bool = null,
    indexedDB: ?bool = null,
    locks: ?bool = null,
    caches: ?bool = null,
    getDirectory: ?bool = null,
    estimate: ?bool = null,
    createObjectURL: ?bool = null,
    revokeObjectURL: ?bool = null,
    BroadcastChannel: ?bool = null,
    SharedWorker: ?bool = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "all", .{ .boolean = false } },
        .{ "cookies", .{ .boolean = false } },
        .{ "sessionStorage", .{ .boolean = false } },
        .{ "localStorage", .{ .boolean = false } },
        .{ "indexedDB", .{ .boolean = false } },
        .{ "locks", .{ .boolean = false } },
        .{ "caches", .{ .boolean = false } },
        .{ "getDirectory", .{ .boolean = false } },
        .{ "estimate", .{ .boolean = false } },
        .{ "createObjectURL", .{ .boolean = false } },
        .{ "revokeObjectURL", .{ .boolean = false } },
        .{ "BroadcastChannel", .{ .boolean = false } },
        .{ "SharedWorker", .{ .boolean = false } },
    };
};
