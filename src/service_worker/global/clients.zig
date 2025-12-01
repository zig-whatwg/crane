//! Clients WebIDL Interface
//!
//! Provides access to controlled clients from ServiceWorkerGlobalScope.
//!
//! Spec: https://w3c.github.io/ServiceWorker/#clients-interface
//!
//! WebIDL:
//! ```idl
//! [Exposed=ServiceWorker]
//! interface Clients {
//!   [NewObject] Promise<(Client or undefined)> get(DOMString id);
//!   [NewObject] Promise<FrozenArray<Client>> matchAll(optional ClientQueryOptions options = {});
//!   [NewObject] Promise<WindowClient?> openWindow(USVString url);
//!   [NewObject] Promise<undefined> claim();
//! };
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

// Internal types
const internal_client = @import("../client.zig");
const InternalClient = internal_client.Client;
const InternalWindowClient = internal_client.WindowClient;

const types = @import("../types.zig");
const ClientType = types.ClientType;
const ClientQueryOptions = types.ClientQueryOptions;

// Interface types
const iface_types = @import("../interfaces/types.zig");
const Promise = iface_types.Promise;
const VoidPromise = iface_types.VoidPromise;

const client_iface = @import("../interfaces/client.zig");
const ClientInterface = client_iface.ClientInterface;
const WindowClientInterface = client_iface.WindowClientInterface;

/// Clients WebIDL interface.
///
/// Provides methods to access and interact with controlled clients.
///
/// Spec: https://w3c.github.io/ServiceWorker/#clients-interface
pub const Clients = struct {
    allocator: Allocator,

    /// Map of client ID to client.
    clients: std.StringHashMapUnmanaged(*InternalClient),

    /// Map of window client ID to window client.
    window_clients: std.StringHashMapUnmanaged(*InternalWindowClient),

    /// The service worker's registration.
    /// Used to determine which clients are controlled.
    registration_scope: []const u8,

    const Self = @This();

    // =========================================================================
    // Construction
    // =========================================================================

    pub fn init(allocator: Allocator, registration_scope: []const u8) !*Self {
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        const scope_copy = try allocator.dupe(u8, registration_scope);

        self.* = .{
            .allocator = allocator,
            .clients = .{},
            .window_clients = .{},
            .registration_scope = scope_copy,
        };

        return self;
    }

    pub fn deinit(self: *Self) void {
        // Free client map keys (clients themselves are not owned)
        var iter = self.clients.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.clients.deinit(self.allocator);

        var witer = self.window_clients.iterator();
        while (witer.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.window_clients.deinit(self.allocator);

        self.allocator.free(self.registration_scope);
        self.allocator.destroy(self);
    }

    // =========================================================================
    // WebIDL Methods
    // =========================================================================

    /// Get a client by ID.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#clients-get
    ///
    /// Steps:
    /// 1. Let promise be a new promise.
    /// 2. Run these steps in parallel:
    ///    2.1. For each service worker client c:
    ///         If c's id equals id and c is an environment settings object:
    ///         - If c's execution ready flag is set:
    ///           Queue a task to resolve promise with c exposed object
    ///         Return.
    ///    2.2. Queue a task to resolve promise with undefined.
    /// 3. Return promise.
    pub fn get(self: *Self, id: []const u8) Promise(?*ClientInterface) {
        var promise = Promise(?*ClientInterface).init();

        // Check if we have this client
        if (self.clients.get(id)) |internal_client_ptr| {
            // Create interface wrapper
            const iface = ClientInterface.init(self.allocator, internal_client_ptr) catch {
                promise.reject(error.OutOfMemory);
                return promise;
            };
            promise.resolve(iface);
            return promise;
        }

        // Not found
        promise.resolve(null);
        return promise;
    }

    /// Get all matching clients.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#clients-matchall
    ///
    /// Returns clients that match the query options.
    /// By default, returns only controlled window clients.
    pub fn matchAll(self: *Self, options: ClientQueryOptions) !Promise([]*ClientInterface) {
        var promise = Promise([]*ClientInterface).init();

        var results = std.ArrayList(*ClientInterface).init(self.allocator);
        errdefer {
            for (results.items) |iface| {
                iface.deinit();
            }
            results.deinit();
        }

        // Iterate through clients
        var iter = self.clients.iterator();
        while (iter.next()) |entry| {
            const client_ptr = entry.value_ptr.*;

            // Skip discarded clients
            if (client_ptr.discarded) continue;

            // Type filter
            if (options.client_type != .all) {
                if (client_ptr.client_type != options.client_type) continue;
            }

            // Include uncontrolled filter
            if (!options.include_uncontrolled) {
                // Only include if controlled by this SW
                if (!client_ptr.isControlled()) continue;
            }

            // Create interface
            const iface = try ClientInterface.init(self.allocator, client_ptr);
            try results.append(iface);
        }

        const slice = try results.toOwnedSlice();
        promise.resolve(slice);
        return promise;
    }

    /// Open a new window.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#clients-openwindow
    ///
    /// Note: This requires user activation to work.
    pub fn openWindow(self: *Self, url: []const u8) Promise(?*WindowClientInterface) {
        _ = url;
        var promise = Promise(?*WindowClientInterface).init();

        // In a real implementation:
        // 1. Check for user activation
        // 2. Create a new window/tab with the URL
        // 3. Wait for window to load
        // 4. Return WindowClient for the new window

        // Stub: reject with InvalidAccessError (no user activation)
        _ = self;
        promise.reject(error.InvalidAccessError);
        return promise;
    }

    /// Claim all clients.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#clients-claim
    ///
    /// Takes control of all uncontrolled clients whose URL matches
    /// this service worker's scope.
    pub fn claim(self: *Self) VoidPromise {
        var promise = VoidPromise.init();

        // TODO: In a real implementation:
        // 1. For each service worker client c whose creation URL matches
        //    this service worker registration's scope URL:
        //    1.1. If c is not controlled, claim c
        // 2. Resolve promise

        // Stub: just resolve
        _ = self;
        promise.resolve({});
        return promise;
    }

    // =========================================================================
    // Internal Methods (for managing clients)
    // =========================================================================

    /// Add a client to the managed set.
    pub fn addClient(self: *Self, client_ptr: *InternalClient) !void {
        const id_copy = try self.allocator.dupe(u8, client_ptr.id);
        errdefer self.allocator.free(id_copy);

        // Remove old entry if exists
        if (self.clients.fetchRemove(client_ptr.id)) |old| {
            self.allocator.free(old.key);
        }

        try self.clients.put(self.allocator, id_copy, client_ptr);
    }

    /// Add a window client to the managed set.
    pub fn addWindowClient(self: *Self, window_client: *InternalWindowClient) !void {
        // Add to both maps
        try self.addClient(window_client.base);

        const id_copy = try self.allocator.dupe(u8, window_client.base.id);
        errdefer self.allocator.free(id_copy);

        if (self.window_clients.fetchRemove(window_client.base.id)) |old| {
            self.allocator.free(old.key);
        }

        try self.window_clients.put(self.allocator, id_copy, window_client);
    }

    /// Remove a client by ID.
    pub fn removeClient(self: *Self, id: []const u8) void {
        if (self.clients.fetchRemove(id)) |entry| {
            self.allocator.free(entry.key);
        }
        if (self.window_clients.fetchRemove(id)) |entry| {
            self.allocator.free(entry.key);
        }
    }

    /// Get the count of clients.
    pub fn count(self: *const Self) usize {
        return self.clients.count();
    }

    /// Check if a client exists.
    pub fn hasClient(self: *const Self, id: []const u8) bool {
        return self.clients.contains(id);
    }
};

// =============================================================================
// Tests
// =============================================================================

test "Clients.init and deinit" {
    const allocator = std.testing.allocator;

    const clients = try Clients.init(allocator, "https://example.com/");
    defer clients.deinit();

    try std.testing.expectEqualStrings("https://example.com/", clients.registration_scope);
    try std.testing.expectEqual(@as(usize, 0), clients.count());
}

test "Clients.addClient" {
    const allocator = std.testing.allocator;

    const clients = try Clients.init(allocator, "https://example.com/");
    defer clients.deinit();

    const client_ptr = try InternalClient.init(allocator, "https://example.com/page.html", .window);
    defer client_ptr.deinit();

    try clients.addClient(client_ptr);

    try std.testing.expectEqual(@as(usize, 1), clients.count());
    try std.testing.expect(clients.hasClient(client_ptr.id));
}

test "Clients.get" {
    const allocator = std.testing.allocator;

    const clients = try Clients.init(allocator, "https://example.com/");
    defer clients.deinit();

    const client_ptr = try InternalClient.init(allocator, "https://example.com/page.html", .window);
    defer client_ptr.deinit();

    try clients.addClient(client_ptr);

    // Get existing client
    const promise = clients.get(client_ptr.id);
    try std.testing.expect(promise.isFulfilled());
    try std.testing.expect(promise.value.? != null);

    // Clean up interface
    promise.value.?.?.deinit();

    // Get non-existing client
    const promise2 = clients.get("non-existent");
    try std.testing.expect(promise2.isFulfilled());
    try std.testing.expect(promise2.value.? == null);
}

test "Clients.matchAll" {
    const allocator = std.testing.allocator;

    const clients = try Clients.init(allocator, "https://example.com/");
    defer clients.deinit();

    // Add some clients
    const client1 = try InternalClient.init(allocator, "https://example.com/page1.html", .window);
    defer client1.deinit();
    try clients.addClient(client1);

    const client2 = try InternalClient.init(allocator, "https://example.com/page2.html", .worker);
    defer client2.deinit();
    try clients.addClient(client2);

    // Match all types including uncontrolled
    const promise = try clients.matchAll(.{
        .include_uncontrolled = true,
        .client_type = .all,
    });
    try std.testing.expect(promise.isFulfilled());

    const results = promise.value.?;
    defer {
        for (results) |iface| {
            iface.deinit();
        }
        allocator.free(results);
    }

    try std.testing.expectEqual(@as(usize, 2), results.len);
}

test "Clients.openWindow requires user activation" {
    const allocator = std.testing.allocator;

    const clients = try Clients.init(allocator, "https://example.com/");
    defer clients.deinit();

    const promise = clients.openWindow("https://example.com/new-page.html");
    try std.testing.expect(promise.isRejected());
}

test "Clients.claim" {
    const allocator = std.testing.allocator;

    const clients = try Clients.init(allocator, "https://example.com/");
    defer clients.deinit();

    const promise = clients.claim();
    try std.testing.expect(promise.isFulfilled());
}
