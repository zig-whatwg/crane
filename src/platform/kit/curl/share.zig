//! kit/curl's part of a Browser's network that src/fetch and src/websocket
//! reach directly (module `kit_curl_share`): the connection share below, and
//! the network options a transfer is made with (`options`).
//!
//! A connection share: curl's connection cache and DNS cache, one
//! per Browser's network context (fetch.network.NetworkContext), which every
//! transfer of that Browser joins (CURLOPT_SHARE) and no other Browser's
//! does - so a Browser reuses its own connections and never observes
//! another's.
//!
//! curl locks a share's data through the lock callbacks it is given, from
//! whichever thread runs a transfer - the window agent's or a worker's. The
//! share keeps its own locks, one per curl lock data kind, and is the
//! callbacks' user data, so two shares never wait on each other.
//!
//! Step 2 of the platform protocol moves transfers behind the port; until
//! then src/fetch/network makes them and joins them to this share. The kit
//! links no curl headers yet: the share API is declared here, with curl.h's
//! values (CURLSHoption and curl_lock_data, libcurl 8), and libcurl - linked
//! into `fetch` - provides it at link time.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// A Browser's network options on a curl easy handle: user agent, proxy,
/// TLS verification (options.zig).
pub const options = @import("options.zig");

/// curl.h's CURLSH (`typedef void CURLSH`).
const CURLSH = anyopaque;

// Declared with the types translate-c gives curl.h's (CURLSH is void, the
// options and results C enums), so they are the same externs as `fetch`'s
// @cImport of them.
extern fn curl_share_init() ?*CURLSH;
extern fn curl_share_setopt(share: ?*CURLSH, option: c_uint, ...) c_uint;
extern fn curl_share_cleanup(share: ?*CURLSH) c_uint;

/// CURLSHoption.
const CURLSHOPT_SHARE: c_uint = 1;
const CURLSHOPT_LOCKFUNC: c_uint = 3;
const CURLSHOPT_UNLOCKFUNC: c_uint = 4;
const CURLSHOPT_USERDATA: c_uint = 5;

/// curl_lock_data: the kinds of data a share holds, each locked on its own.
pub const LockData = enum(c_int) {
    dns = 3,
    connect = 5,
};

/// CURL_LOCK_DATA_LAST: every kind curl may lock.
const lock_kinds = 8;

pub const Share = struct {
    allocator: Allocator,
    handle: *CURLSH,
    /// One per curl_lock_data kind, taken by `lock` and `unlock`.
    locks: [lock_kinds]std.Io.Mutex = @splat(.init),

    /// A share of connections and DNS lookups, or null when curl cannot make
    /// one (then every transfer opens its own connection). curl's global
    /// state must be initialized first.
    pub fn create(allocator: Allocator) Allocator.Error!?*Share {
        const self = try allocator.create(Share);
        const handle = curl_share_init() orelse {
            allocator.destroy(self);
            return null;
        };
        self.* = .{ .allocator = allocator, .handle = handle };
        // The callbacks find this share - its locks - as the user data.
        _ = curl_share_setopt(handle, CURLSHOPT_USERDATA, @as(?*anyopaque, self));
        _ = curl_share_setopt(handle, CURLSHOPT_LOCKFUNC, @as(*const anyopaque, @ptrCast(&lock)));
        _ = curl_share_setopt(handle, CURLSHOPT_UNLOCKFUNC, @as(*const anyopaque, @ptrCast(&unlock)));
        _ = curl_share_setopt(handle, CURLSHOPT_SHARE, @as(c_int, @intFromEnum(LockData.connect)));
        _ = curl_share_setopt(handle, CURLSHOPT_SHARE, @as(c_int, @intFromEnum(LockData.dns)));
        return self;
    }

    /// The end: curl closes the connections the share kept - an HTTP/2 one
    /// with a GOAWAY. Every transfer that joined it has ended.
    pub fn destroy(self: *Share) void {
        _ = curl_share_cleanup(self.handle);
        self.allocator.destroy(self);
    }

    /// The curl share handle, for a transfer's CURLOPT_SHARE.
    pub fn curlShare(self: *Share) *anyopaque {
        return self.handle;
    }

    /// Take one kind's lock as curl would - for a test that holds a share's
    /// connection cache while another share's transfer runs.
    pub fn hold(self: *Share, data: LockData) void {
        std.Io.Threaded.mutexLock(&self.locks[@intCast(@intFromEnum(data))]);
    }

    pub fn release(self: *Share, data: LockData) void {
        std.Io.Threaded.mutexUnlock(&self.locks[@intCast(@intFromEnum(data))]);
    }

    fn lock(_: ?*anyopaque, data: c_int, _: c_int, user: ?*anyopaque) callconv(.c) void {
        const self: *Share = @ptrCast(@alignCast(user orelse return));
        if (data >= 0 and data < lock_kinds) std.Io.Threaded.mutexLock(&self.locks[@intCast(data)]);
    }

    fn unlock(_: ?*anyopaque, data: c_int, user: ?*anyopaque) callconv(.c) void {
        const self: *Share = @ptrCast(@alignCast(user orelse return));
        if (data >= 0 and data < lock_kinds) std.Io.Threaded.mutexUnlock(&self.locks[@intCast(data)]);
    }
};
