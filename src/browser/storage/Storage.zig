//! Storage - Browser Persistent Storage Manager
//!
//! This module manages persistent storage for the browser, including:
//! - Cookies
//! - LocalStorage / SessionStorage
//! - HTTP Cache
//! - IndexedDB
//! - History
//! - Service Worker registrations
//!
//! ## Directory Structure
//!
//! ```
//! ~/.whatwg/
//!     ├── cookies.db        (SQLite)
//!     ├── local_storage/    (Per-origin JSON files)
//!     │   └── {origin}/
//!     ├── cache/            (HTTP cache)
//!     ├── indexed_db/       (Per-origin databases)
//!     │   └── {origin}/
//!     ├── history.db        (SQLite)
//!     └── service_workers/  (Registration data)
//! ```
//!
//! ## Usage
//!
//! ```zig
//! const storage = try Storage.init(allocator, null, true);
//! defer storage.deinit();
//!
//! // Get cookie jar for domain
//! const cookies = try storage.cookies.getCookies("example.com", "/");
//!
//! // Get localStorage for origin
//! const local = try storage.getLocalStorage("https://example.com");
//! try local.setItem("key", "value");
//! ```

const std = @import("std");

/// Default storage root directory
const DEFAULT_STORAGE_ROOT = "~/.whatwg/";

/// Storage manager for browser persistent data
pub const Storage = struct {
    allocator: std.mem.Allocator,
    /// Root directory for storage
    root_path: []const u8,
    /// Whether to persist to disk
    persist: bool,
    /// Cookies storage (in-memory, optionally persisted)
    cookies: CookieStore,
    /// LocalStorage per origin
    local_storage: std.StringHashMap(*LocalStorage),
    /// SessionStorage per origin (not persisted)
    session_storage: std.StringHashMap(*SessionStorage),
    /// Whether directories have been created
    initialized: bool,

    /// Initialize the storage subsystem
    pub fn init(
        allocator: std.mem.Allocator,
        storage_root: ?[]const u8,
        persist: bool,
    ) !*Storage {
        const storage = try allocator.create(Storage);
        errdefer allocator.destroy(storage);

        const root = if (storage_root) |root|
            try allocator.dupe(u8, root)
        else
            try expandPath(allocator, DEFAULT_STORAGE_ROOT);

        storage.* = Storage{
            .allocator = allocator,
            .root_path = root,
            .persist = persist,
            .cookies = CookieStore.init(allocator),
            .local_storage = std.StringHashMap(*LocalStorage).init(allocator),
            .session_storage = std.StringHashMap(*SessionStorage).init(allocator),
            .initialized = false,
        };

        // Create directories if persisting
        if (persist) {
            try storage.ensureDirectories();
        }

        return storage;
    }

    /// Create storage directories
    fn ensureDirectories(self: *Storage) !void {
        if (self.initialized) return;

        // Create root directory
        std.fs.cwd().makePath(self.root_path) catch |err| {
            if (err != error.PathAlreadyExists) return err;
        };

        // Create subdirectories
        const subdirs = [_][]const u8{
            "local_storage",
            "cache",
            "indexed_db",
            "service_workers",
        };

        for (subdirs) |subdir| {
            const path = try std.fs.path.join(self.allocator, &.{ self.root_path, subdir });
            defer self.allocator.free(path);

            std.fs.cwd().makePath(path) catch |err| {
                if (err != error.PathAlreadyExists) return err;
            };
        }

        self.initialized = true;
    }

    /// Get LocalStorage for an origin
    pub fn getLocalStorage(self: *Storage, origin: []const u8) !*LocalStorage {
        if (self.local_storage.get(origin)) |ls| {
            return ls;
        }

        // Create new LocalStorage for this origin
        const ls = try LocalStorage.init(self.allocator, origin, self.root_path, self.persist);
        const origin_dup = try self.allocator.dupe(u8, origin);
        try self.local_storage.put(origin_dup, ls);
        return ls;
    }

    /// Get SessionStorage for an origin
    pub fn getSessionStorage(self: *Storage, origin: []const u8) !*SessionStorage {
        if (self.session_storage.get(origin)) |ss| {
            return ss;
        }

        // Create new SessionStorage for this origin (never persisted)
        const ss = try SessionStorage.init(self.allocator);
        const origin_dup = try self.allocator.dupe(u8, origin);
        try self.session_storage.put(origin_dup, ss);
        return ss;
    }

    /// Flush all storage to disk
    pub fn flush(self: *Storage) !void {
        if (!self.persist) return;

        // Flush cookies
        try self.cookies.flush(self.root_path);

        // Flush all LocalStorage instances
        var ls_iter = self.local_storage.iterator();
        while (ls_iter.next()) |entry| {
            try entry.value_ptr.*.flush();
        }
    }

    /// Deinitialize the storage subsystem
    pub fn deinit(self: *Storage) void {
        // Cleanup cookies
        self.cookies.deinit();

        // Cleanup local storage
        var ls_iter = self.local_storage.iterator();
        while (ls_iter.next()) |entry| {
            entry.value_ptr.*.deinit();
            self.allocator.destroy(entry.value_ptr.*);
            self.allocator.free(entry.key_ptr.*);
        }
        self.local_storage.deinit();

        // Cleanup session storage
        var ss_iter = self.session_storage.iterator();
        while (ss_iter.next()) |entry| {
            entry.value_ptr.*.deinit();
            self.allocator.destroy(entry.value_ptr.*);
            self.allocator.free(entry.key_ptr.*);
        }
        self.session_storage.deinit();

        self.allocator.free(self.root_path);
    }

    /// Clear all storage (for testing)
    pub fn clear(self: *Storage) void {
        self.cookies.clear();

        var ls_iter = self.local_storage.iterator();
        while (ls_iter.next()) |entry| {
            entry.value_ptr.*.clear();
        }

        var ss_iter = self.session_storage.iterator();
        while (ss_iter.next()) |entry| {
            entry.value_ptr.*.clear();
        }
    }
};

/// Cookie storage (in-memory with optional persistence)
pub const CookieStore = struct {
    allocator: std.mem.Allocator,
    /// Cookies indexed by domain
    cookies: std.StringHashMap(std.ArrayListUnmanaged(Cookie)),

    pub fn init(allocator: std.mem.Allocator) CookieStore {
        return CookieStore{
            .allocator = allocator,
            .cookies = std.StringHashMap(std.ArrayListUnmanaged(Cookie)).init(allocator),
        };
    }

    pub fn deinit(self: *CookieStore) void {
        var iter = self.cookies.iterator();
        while (iter.next()) |entry| {
            for (entry.value_ptr.items) |*cookie| {
                cookie.deinit(self.allocator);
            }
            entry.value_ptr.deinit(self.allocator);
            self.allocator.free(entry.key_ptr.*);
        }
        self.cookies.deinit();
    }

    pub fn clear(self: *CookieStore) void {
        var iter = self.cookies.iterator();
        while (iter.next()) |entry| {
            for (entry.value_ptr.items) |*cookie| {
                cookie.deinit(self.allocator);
            }
            entry.value_ptr.clearRetainingCapacity();
        }
    }

    pub fn flush(self: *CookieStore, _: []const u8) !void {
        // TODO: Persist to SQLite
        _ = self;
    }
};

/// Individual cookie
pub const Cookie = struct {
    name: []const u8,
    value: []const u8,
    domain: []const u8,
    path: []const u8,
    expires: ?i64,
    secure: bool,
    http_only: bool,
    same_site: SameSite,

    pub const SameSite = enum { strict, lax, none };

    pub fn deinit(self: *Cookie, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.value);
        allocator.free(self.domain);
        allocator.free(self.path);
    }
};

/// LocalStorage implementation (per-origin, persisted)
pub const LocalStorage = struct {
    allocator: std.mem.Allocator,
    origin: []const u8,
    storage_path: []const u8,
    persist: bool,
    data: std.StringHashMap([]const u8),

    pub fn init(
        allocator: std.mem.Allocator,
        origin: []const u8,
        root_path: []const u8,
        persist: bool,
    ) !*LocalStorage {
        const ls = try allocator.create(LocalStorage);
        errdefer allocator.destroy(ls);

        // Create storage path
        const escaped_origin = try escapeOrigin(allocator, origin);
        defer allocator.free(escaped_origin);

        const storage_path = try std.fs.path.join(allocator, &.{ root_path, "local_storage", escaped_origin });

        ls.* = LocalStorage{
            .allocator = allocator,
            .origin = try allocator.dupe(u8, origin),
            .storage_path = storage_path,
            .persist = persist,
            .data = std.StringHashMap([]const u8).init(allocator),
        };

        // Load from disk if persisting
        if (persist) {
            ls.load() catch {};
        }

        return ls;
    }

    pub fn deinit(self: *LocalStorage) void {
        var iter = self.data.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.data.deinit();
        self.allocator.free(self.origin);
        self.allocator.free(self.storage_path);
    }

    pub fn getItem(self: *LocalStorage, key: []const u8) ?[]const u8 {
        return self.data.get(key);
    }

    pub fn setItem(self: *LocalStorage, key: []const u8, value: []const u8) !void {
        // Remove old value if exists
        if (self.data.fetchRemove(key)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value);
        }

        const key_dup = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(key_dup);
        const value_dup = try self.allocator.dupe(u8, value);

        try self.data.put(key_dup, value_dup);
    }

    pub fn removeItem(self: *LocalStorage, key: []const u8) void {
        if (self.data.fetchRemove(key)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value);
        }
    }

    pub fn clear(self: *LocalStorage) void {
        var iter = self.data.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.data.clearRetainingCapacity();
    }

    pub fn length(self: *LocalStorage) usize {
        return self.data.count();
    }

    pub fn flush(self: *LocalStorage) !void {
        _ = self;
        // TODO: Persist to JSON file when persist is true
    }

    fn load(self: *LocalStorage) !void {
        _ = self;
        // TODO: Load from JSON file
    }
};

/// SessionStorage implementation (per-origin, not persisted)
pub const SessionStorage = struct {
    allocator: std.mem.Allocator,
    data: std.StringHashMap([]const u8),

    pub fn init(allocator: std.mem.Allocator) !*SessionStorage {
        const ss = try allocator.create(SessionStorage);
        ss.* = SessionStorage{
            .allocator = allocator,
            .data = std.StringHashMap([]const u8).init(allocator),
        };
        return ss;
    }

    pub fn deinit(self: *SessionStorage) void {
        var iter = self.data.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.data.deinit();
    }

    pub fn getItem(self: *SessionStorage, key: []const u8) ?[]const u8 {
        return self.data.get(key);
    }

    pub fn setItem(self: *SessionStorage, key: []const u8, value: []const u8) !void {
        if (self.data.fetchRemove(key)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value);
        }

        const key_dup = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(key_dup);
        const value_dup = try self.allocator.dupe(u8, value);

        try self.data.put(key_dup, value_dup);
    }

    pub fn removeItem(self: *SessionStorage, key: []const u8) void {
        if (self.data.fetchRemove(key)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value);
        }
    }

    pub fn clear(self: *SessionStorage) void {
        var iter = self.data.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.data.clearRetainingCapacity();
    }

    pub fn length(self: *SessionStorage) usize {
        return self.data.count();
    }
};

/// Expand ~ to home directory
fn expandPath(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    if (path.len > 0 and path[0] == '~') {
        const home = std.posix.getenv("HOME") orelse "/tmp";
        return std.fs.path.join(allocator, &.{ home, path[1..] });
    }
    return allocator.dupe(u8, path);
}

/// Escape origin for use as directory name
fn escapeOrigin(allocator: std.mem.Allocator, origin: []const u8) ![]const u8 {
    var result: std.ArrayListUnmanaged(u8) = .{};
    errdefer result.deinit(allocator);

    for (origin) |c| {
        switch (c) {
            '/', ':', '?', '#', '[', ']', '@', '!', '$', '&', '\'', '(', ')', '*', '+', ',', ';', '=' => {
                try result.append(allocator, '_');
            },
            else => try result.append(allocator, c),
        }
    }

    return result.toOwnedSlice(allocator);
}

test "Storage - basic lifecycle" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var storage = try Storage.init(allocator, null, false);
    defer {
        storage.deinit();
        allocator.destroy(storage);
    }

    // Test LocalStorage
    const ls = try storage.getLocalStorage("https://example.com");
    try ls.setItem("key", "value");
    try testing.expectEqualStrings("value", ls.getItem("key").?);

    // Test SessionStorage
    const ss = try storage.getSessionStorage("https://example.com");
    try ss.setItem("session_key", "session_value");
    try testing.expectEqualStrings("session_value", ss.getItem("session_key").?);
}

test "escapeOrigin" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const escaped = try escapeOrigin(allocator, "https://example.com:8080");
    defer allocator.free(escaped);

    try testing.expectEqualStrings("https___example.com_8080", escaped);
}
