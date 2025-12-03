//! Session History - HTML Standard §7.4.1
//!
//! A session history entry holds state for navigation including URL, document state,
//! scroll position, and serialized state for the History and Navigation APIs.
//!
//! Spec: https://html.spec.whatwg.org/multipage/browsing-the-web.html#session-history
//!
//! ## Key Concepts
//!
//! - **Session History Entry**: Holds URL, document state, scroll position, API state
//! - **Document State**: Holds state for recreating a Document during traversal
//! - **Scroll Restoration Mode**: "auto" or "manual" for scroll position handling
//! - **Serialized State**: State for history.state and navigation API state
//!
//! ## Architecture
//!
//! ```
//! TraversableNavigable
//! └── session_history_entries: []SessionHistoryEntry
//!     └── document_state: DocumentState
//!         └── document: ?*Document
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

// ============================================================================
// Scroll Restoration Mode - HTML Standard §7.4.1.1
// ============================================================================

/// Scroll restoration mode indicates whether the user agent should restore
/// the persisted scroll position when traversing to an entry.
///
/// HTML Standard §7.4.1.1:
/// "A scroll restoration mode is one of the following:
/// - 'auto': The user agent is responsible for restoring the scroll position
/// - 'manual': The page is responsible for restoring the scroll position"
pub const ScrollRestorationMode = enum {
    /// User agent restores scroll position automatically
    auto,
    /// Page is responsible for scroll restoration
    manual,

    /// Convert to string for serialization
    pub fn toString(self: ScrollRestorationMode) []const u8 {
        return switch (self) {
            .auto => "auto",
            .manual => "manual",
        };
    }

    /// Parse from string
    pub fn fromString(str: []const u8) ?ScrollRestorationMode {
        if (std.mem.eql(u8, str, "auto")) return .auto;
        if (std.mem.eql(u8, str, "manual")) return .manual;
        return null;
    }
};

// ============================================================================
// Scroll Position Data - HTML Standard §7.4.1.1
// ============================================================================

/// Scroll position for a single scrollable region
pub const ScrollPosition = struct {
    /// X coordinate (scroll left)
    x: f64,
    /// Y coordinate (scroll top)
    y: f64,

    pub fn init() ScrollPosition {
        return .{ .x = 0, .y = 0 };
    }
};

/// Scroll position data for document's restorable scrollable regions
///
/// HTML Standard §7.4.1.1:
/// "scroll position data, which is scroll position data for the document's
/// restorable scrollable regions"
pub const ScrollPositionData = struct {
    allocator: Allocator,

    /// Viewport scroll position
    viewport: ScrollPosition,

    /// Scroll positions for elements with overflow (keyed by element ID or path)
    element_positions: std.StringHashMap(ScrollPosition),

    pub fn init(allocator: Allocator) ScrollPositionData {
        return .{
            .allocator = allocator,
            .viewport = ScrollPosition.init(),
            .element_positions = std.StringHashMap(ScrollPosition).init(allocator),
        };
    }

    pub fn deinit(self: *ScrollPositionData) void {
        var it = self.element_positions.keyIterator();
        while (it.next()) |key| {
            self.allocator.free(key.*);
        }
        self.element_positions.deinit();
    }

    /// Set scroll position for an element
    pub fn setElementPosition(self: *ScrollPositionData, element_id: []const u8, position: ScrollPosition) !void {
        const key = try self.allocator.dupe(u8, element_id);
        errdefer self.allocator.free(key);

        // Remove old key if exists
        if (self.element_positions.fetchRemove(element_id)) |kv| {
            self.allocator.free(kv.key);
        }

        try self.element_positions.put(key, position);
    }

    /// Get scroll position for an element
    pub fn getElementPosition(self: *const ScrollPositionData, element_id: []const u8) ?ScrollPosition {
        return self.element_positions.get(element_id);
    }

    /// Clone this scroll position data
    pub fn clone(self: *const ScrollPositionData, allocator: Allocator) !ScrollPositionData {
        var cloned = ScrollPositionData.init(allocator);
        cloned.viewport = self.viewport;

        var it = self.element_positions.iterator();
        while (it.next()) |entry| {
            try cloned.setElementPosition(entry.key_ptr.*, entry.value_ptr.*);
        }

        return cloned;
    }
};

// ============================================================================
// Serialized State - HTML Standard §7.4.1.1
// ============================================================================

/// Serialized state is a serialization (via StructuredSerializeForStorage)
/// of an object representing a user interface state.
///
/// HTML Standard §7.4.1.1:
/// "Serialized state is a serialization (via StructuredSerializeForStorage)
/// of an object representing a user interface state."
pub const SerializedState = struct {
    allocator: Allocator,
    /// The raw serialized bytes
    data: []const u8,

    pub fn init(allocator: Allocator) SerializedState {
        return .{
            .allocator = allocator,
            .data = &[_]u8{},
        };
    }

    pub fn initWithData(allocator: Allocator, data: []const u8) !SerializedState {
        return .{
            .allocator = allocator,
            .data = try allocator.dupe(u8, data),
        };
    }

    pub fn deinit(self: *SerializedState) void {
        if (self.data.len > 0) {
            self.allocator.free(self.data);
        }
    }

    /// Create serialized state representing null
    pub fn nullState(allocator: Allocator) !SerializedState {
        // Minimal serialization of null
        return try SerializedState.initWithData(allocator, &[_]u8{0x00});
    }

    /// Create serialized state representing undefined
    pub fn undefinedState(allocator: Allocator) !SerializedState {
        // Minimal serialization of undefined
        return try SerializedState.initWithData(allocator, &[_]u8{0x01});
    }

    /// Check if this represents null
    pub fn isNull(self: *const SerializedState) bool {
        return self.data.len == 1 and self.data[0] == 0x00;
    }

    /// Check if this represents undefined
    pub fn isUndefined(self: *const SerializedState) bool {
        return self.data.len == 1 and self.data[0] == 0x01;
    }

    /// Clone this serialized state
    pub fn clone(self: *const SerializedState, allocator: Allocator) !SerializedState {
        return try SerializedState.initWithData(allocator, self.data);
    }
};

// ============================================================================
// POST Resource - HTML Standard §7.4.1.2
// ============================================================================

/// Content type for POST resource
pub const PostContentType = enum {
    form_urlencoded,
    multipart_form_data,
    text_plain,

    pub fn toMimeType(self: PostContentType) []const u8 {
        return switch (self) {
            .form_urlencoded => "application/x-www-form-urlencoded",
            .multipart_form_data => "multipart/form-data",
            .text_plain => "text/plain",
        };
    }
};

/// POST resource for form submissions
///
/// HTML Standard §7.4.1.2:
/// "A POST resource has:
/// - A request body, a byte sequence or failure
/// - A request content-type"
pub const PostResource = struct {
    allocator: Allocator,

    /// Request body bytes
    request_body: ?[]const u8,

    /// Request content type
    request_content_type: PostContentType,

    pub fn init(allocator: Allocator, body: []const u8, content_type: PostContentType) !PostResource {
        return .{
            .allocator = allocator,
            .request_body = try allocator.dupe(u8, body),
            .request_content_type = content_type,
        };
    }

    pub fn deinit(self: *PostResource) void {
        if (self.request_body) |body| {
            self.allocator.free(body);
        }
    }

    /// Mark the body as failure (e.g., resource no longer accessible)
    pub fn markBodyFailure(self: *PostResource) void {
        if (self.request_body) |body| {
            self.allocator.free(body);
        }
        self.request_body = null;
    }

    pub fn isFailure(self: *const PostResource) bool {
        return self.request_body == null;
    }
};

// ============================================================================
// Document State - HTML Standard §7.4.1.2
// ============================================================================

/// Document state holds state inside a session history entry regarding how
/// to present and, if necessary, recreate, a Document.
///
/// HTML Standard §7.4.1.2:
/// "Document state holds state inside a session history entry regarding how
/// to present and, if necessary, recreate, a Document."
pub const DocumentState = struct {
    allocator: Allocator,

    /// A Document or null, initially null.
    /// When a history entry is active, it has a Document in its document state.
    document: ?*anyopaque, // Will be *Document when DOM is integrated

    /// A policy container or null, initially null.
    history_policy_container: ?*anyopaque, // Will be *PolicyContainer

    /// Request referrer: "no-referrer", "client", or a URL, initially "client"
    request_referrer: RequestReferrer,

    /// Request referrer policy, initially the default referrer policy
    request_referrer_policy: ReferrerPolicy,

    /// An origin or null, initially null.
    initiator_origin: ?[]const u8,

    /// An origin or null, initially null.
    /// This is the origin that we set "about:"-schemed Documents' origin to.
    origin: ?[]const u8,

    /// A URL or null, initially null.
    /// Will be populated only for "about:"-schemed Documents.
    about_base_url: ?[]const u8,

    /// A list of nested histories, initially an empty list.
    nested_histories: std.ArrayListUnmanaged(NestedHistory),

    /// A string, POST resource or null, initially null.
    resource: ?DocumentResource,

    /// A reload pending boolean, initially false.
    reload_pending: bool,

    /// An ever populated boolean, initially false.
    ever_populated: bool,

    /// A navigable target name string, initially the empty string.
    navigable_target_name: []const u8,

    pub fn init(allocator: Allocator) DocumentState {
        return .{
            .allocator = allocator,
            .document = null,
            .history_policy_container = null,
            .request_referrer = .client,
            .request_referrer_policy = .default,
            .initiator_origin = null,
            .origin = null,
            .about_base_url = null,
            .nested_histories = .{},
            .resource = null,
            .reload_pending = false,
            .ever_populated = false,
            .navigable_target_name = "",
        };
    }

    pub fn deinit(self: *DocumentState) void {
        if (self.initiator_origin) |origin| {
            self.allocator.free(origin);
        }
        if (self.origin) |origin| {
            self.allocator.free(origin);
        }
        if (self.about_base_url) |url| {
            self.allocator.free(url);
        }
        if (self.navigable_target_name.len > 0) {
            self.allocator.free(self.navigable_target_name);
        }
        if (self.resource) |*res| {
            res.deinit();
        }

        for (self.nested_histories.items) |*nh| {
            nh.deinit();
        }
        self.nested_histories.deinit(self.allocator);
    }

    /// Set the origin
    pub fn setOrigin(self: *DocumentState, origin: []const u8) !void {
        if (self.origin) |old| {
            self.allocator.free(old);
        }
        self.origin = try self.allocator.dupe(u8, origin);
    }

    /// Set the navigable target name
    pub fn setNavigableTargetName(self: *DocumentState, name: []const u8) !void {
        if (self.navigable_target_name.len > 0) {
            self.allocator.free(self.navigable_target_name);
        }
        self.navigable_target_name = try self.allocator.dupe(u8, name);
    }

    /// Clear the navigable target name (e.g., on cross-origin navigation)
    pub fn clearNavigableTargetName(self: *DocumentState) void {
        if (self.navigable_target_name.len > 0) {
            self.allocator.free(self.navigable_target_name);
            self.navigable_target_name = "";
        }
    }
};

/// Request referrer types
pub const RequestReferrer = union(enum) {
    no_referrer,
    client,
    url: []const u8,
};

/// Referrer policy enum
pub const ReferrerPolicy = enum {
    default,
    no_referrer,
    no_referrer_when_downgrade,
    same_origin,
    origin,
    strict_origin,
    origin_when_cross_origin,
    strict_origin_when_cross_origin,
    unsafe_url,
};

/// Document resource can be HTML string (srcdoc), POST resource, or null
pub const DocumentResource = union(enum) {
    /// HTML source for srcdoc iframes
    html_source: []const u8,
    /// POST resource for form submissions
    post_resource: PostResource,

    pub fn deinit(self: *DocumentResource) void {
        switch (self.*) {
            .html_source => |src| {
                // Assuming we own this memory
                _ = src;
            },
            .post_resource => |*post| {
                post.deinit();
            },
        }
    }
};

// ============================================================================
// Nested History - HTML Standard §7.4.1.2
// ============================================================================

/// A nested history for child navigables
///
/// HTML Standard §7.4.1.2:
/// "A nested history has:
/// - An id, a unique internal value
/// - Entries, a list of session history entries"
pub const NestedHistory = struct {
    allocator: Allocator,

    /// Unique internal value to associate with a navigable
    id: u64,

    /// List of session history entries for this nested history
    entries: std.ArrayListUnmanaged(*SessionHistoryEntry),

    /// Next ID generator
    var next_id: u64 = 1;

    pub fn init(allocator: Allocator) NestedHistory {
        return .{
            .allocator = allocator,
            .id = @atomicRmw(u64, &next_id, .Add, 1, .monotonic),
            .entries = .{},
        };
    }

    pub fn deinit(self: *NestedHistory) void {
        // Note: Don't free entries here - they're owned by the session history
        self.entries.deinit(self.allocator);
    }

    /// Add an entry to this nested history
    pub fn addEntry(self: *NestedHistory, entry: *SessionHistoryEntry) !void {
        try self.entries.append(self.allocator, entry);
    }
};

// ============================================================================
// Session History Entry - HTML Standard §7.4.1.1
// ============================================================================

/// A session history entry is a struct that holds navigation state.
///
/// HTML Standard §7.4.1.1:
/// "A session history entry is a struct with the following items:
/// - step, a non-negative integer or 'pending', initially 'pending'
/// - URL, a URL
/// - document state, a document state
/// - classic history API state, which is serialized state
/// - navigation API state, which is a serialized state
/// - navigation API key, which is a string
/// - navigation API ID, which is a string
/// - scroll restoration mode, a scroll restoration mode, initially 'auto'
/// - scroll position data
/// - persisted user state"
pub const SessionHistoryEntry = struct {
    allocator: Allocator,

    /// A non-negative integer or "pending", initially "pending"
    step: Step,

    /// The URL for this entry
    url: []const u8,

    /// Document state for this entry
    document_state: DocumentState,

    /// Classic history API state (for history.state)
    classic_history_api_state: SerializedState,

    /// Navigation API state (for navigation.currentEntry.getState())
    navigation_api_state: SerializedState,

    /// Navigation API key (UUID for traverseTo)
    navigation_api_key: [36]u8,

    /// Navigation API ID (UUID for this specific entry)
    navigation_api_id: [36]u8,

    /// Scroll restoration mode, initially "auto"
    scroll_restoration_mode: ScrollRestorationMode,

    /// Scroll position data for the document's restorable scrollable regions
    scroll_position_data: ScrollPositionData,

    /// Implementation-defined persisted user state (e.g., form values)
    persisted_user_state: ?*anyopaque,

    /// Step can be a number or "pending"
    pub const Step = union(enum) {
        pending,
        value: u64,

        pub fn isPending(self: Step) bool {
            return self == .pending;
        }

        pub fn getValue(self: Step) ?u64 {
            return switch (self) {
                .pending => null,
                .value => |v| v,
            };
        }
    };

    /// Create a new session history entry
    pub fn init(allocator: Allocator, url: []const u8) !*SessionHistoryEntry {
        const entry = try allocator.create(SessionHistoryEntry);
        errdefer allocator.destroy(entry);

        entry.* = .{
            .allocator = allocator,
            .step = .pending,
            .url = try allocator.dupe(u8, url),
            .document_state = DocumentState.init(allocator),
            .classic_history_api_state = try SerializedState.nullState(allocator),
            .navigation_api_state = try SerializedState.undefinedState(allocator),
            .navigation_api_key = undefined,
            .navigation_api_id = undefined,
            .scroll_restoration_mode = .auto,
            .scroll_position_data = ScrollPositionData.init(allocator),
            .persisted_user_state = null,
        };

        // Generate UUIDs for navigation API key and ID
        generateUUID(&entry.navigation_api_key);
        generateUUID(&entry.navigation_api_id);

        return entry;
    }

    /// Deinitialize and free resources
    pub fn deinit(self: *SessionHistoryEntry) void {
        self.allocator.free(self.url);
        self.document_state.deinit();
        self.classic_history_api_state.deinit();
        self.navigation_api_state.deinit();
        self.scroll_position_data.deinit();
        self.allocator.destroy(self);
    }

    /// Get the document from this entry's document state
    pub fn getDocument(self: *const SessionHistoryEntry) ?*anyopaque {
        return self.document_state.document;
    }

    /// Set the URL for this entry
    pub fn setUrl(self: *SessionHistoryEntry, url: []const u8) !void {
        self.allocator.free(self.url);
        self.url = try self.allocator.dupe(u8, url);
    }

    /// Set the classic history API state
    pub fn setClassicHistoryApiState(self: *SessionHistoryEntry, state: SerializedState) void {
        self.classic_history_api_state.deinit();
        self.classic_history_api_state = state;
    }

    /// Set the navigation API state
    pub fn setNavigationApiState(self: *SessionHistoryEntry, state: SerializedState) void {
        self.navigation_api_state.deinit();
        self.navigation_api_state = state;
    }

    /// Set the step value
    pub fn setStep(self: *SessionHistoryEntry, step_value: u64) void {
        self.step = .{ .value = step_value };
    }

    /// Check if this entry's document equals the given document
    pub fn hasDocument(self: *const SessionHistoryEntry, document: *anyopaque) bool {
        if (self.document_state.document) |doc| {
            return doc == document;
        }
        return false;
    }
};

// ============================================================================
// UUID Generation
// ============================================================================

/// Generate a random UUID v4 string
fn generateUUID(buffer: *[36]u8) void {
    var prng = std.Random.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        std.posix.getrandom(std.mem.asBytes(&seed)) catch {
            seed = @intCast(std.time.timestamp());
        };
        break :blk seed;
    });
    const random = prng.random();

    // Generate 16 random bytes
    var bytes: [16]u8 = undefined;
    random.bytes(&bytes);

    // Set version (4) and variant (RFC 4122)
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // Version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // Variant RFC 4122

    // Format as UUID string
    const hex = "0123456789abcdef";
    var pos: usize = 0;

    for (bytes, 0..) |byte, i| {
        if (i == 4 or i == 6 or i == 8 or i == 10) {
            buffer[pos] = '-';
            pos += 1;
        }
        buffer[pos] = hex[byte >> 4];
        buffer[pos + 1] = hex[byte & 0x0f];
        pos += 2;
    }
}

// ============================================================================
// Session History List
// ============================================================================

/// A list of session history entries for a traversable navigable
pub const SessionHistoryList = struct {
    allocator: Allocator,

    /// The list of entries
    entries: std.ArrayListUnmanaged(*SessionHistoryEntry),

    /// Current session history step
    current_step: u64,

    pub fn init(allocator: Allocator) SessionHistoryList {
        return .{
            .allocator = allocator,
            .entries = .{},
            .current_step = 0,
        };
    }

    pub fn deinit(self: *SessionHistoryList) void {
        for (self.entries.items) |entry| {
            entry.deinit();
        }
        self.entries.deinit(self.allocator);
    }

    /// Get the number of entries
    pub fn length(self: *const SessionHistoryList) usize {
        return self.entries.items.len;
    }

    /// Get entry at index
    pub fn getEntry(self: *const SessionHistoryList, index: usize) ?*SessionHistoryEntry {
        if (index >= self.entries.items.len) return null;
        return self.entries.items[index];
    }

    /// Get entry by step value
    pub fn getEntryByStep(self: *const SessionHistoryList, step: u64) ?*SessionHistoryEntry {
        for (self.entries.items) |entry| {
            if (entry.step.getValue()) |s| {
                if (s == step) return entry;
            }
        }
        return null;
    }

    /// Get entry by navigation API key
    pub fn getEntryByKey(self: *const SessionHistoryList, key: []const u8) ?*SessionHistoryEntry {
        for (self.entries.items) |entry| {
            if (std.mem.eql(u8, &entry.navigation_api_key, key)) {
                return entry;
            }
        }
        return null;
    }

    /// Append an entry
    pub fn append(self: *SessionHistoryList, entry: *SessionHistoryEntry) !void {
        try self.entries.append(self.allocator, entry);
    }

    /// Remove entries with step greater than the given value
    /// HTML Standard: "clear the forward session history"
    pub fn clearForward(self: *SessionHistoryList, step: u64) void {
        var i: usize = 0;
        while (i < self.entries.items.len) {
            const entry = self.entries.items[i];
            if (entry.step.getValue()) |s| {
                if (s > step) {
                    entry.deinit();
                    _ = self.entries.orderedRemove(i);
                    continue;
                }
            }
            i += 1;
        }
    }

    /// Replace an entry with another
    pub fn replaceEntry(self: *SessionHistoryList, old_entry: *SessionHistoryEntry, new_entry: *SessionHistoryEntry) bool {
        for (self.entries.items, 0..) |entry, i| {
            if (entry == old_entry) {
                self.entries.items[i] = new_entry;
                return true;
            }
        }
        return false;
    }

    /// Get all used history steps, sorted
    pub fn getAllUsedSteps(self: *const SessionHistoryList, allocator: Allocator) ![]u64 {
        var steps = std.ArrayListUnmanaged(u64){};
        defer steps.deinit(allocator);

        for (self.entries.items) |entry| {
            if (entry.step.getValue()) |s| {
                try steps.append(allocator, s);
            }
        }

        // Sort the steps
        std.mem.sort(u64, steps.items, {}, std.sort.asc(u64));

        return try allocator.dupe(u64, steps.items);
    }

    /// Get the index of the current entry
    pub fn getCurrentIndex(self: *const SessionHistoryList) ?usize {
        for (self.entries.items, 0..) |entry, i| {
            if (entry.step.getValue()) |s| {
                if (s == self.current_step) return i;
            }
        }
        return null;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "SessionHistoryEntry - init and deinit" {
    const allocator = std.testing.allocator;

    const entry = try SessionHistoryEntry.init(allocator, "https://example.com/page");
    defer entry.deinit();

    try std.testing.expectEqualStrings("https://example.com/page", entry.url);
    try std.testing.expect(entry.step.isPending());
    try std.testing.expectEqual(ScrollRestorationMode.auto, entry.scroll_restoration_mode);
}

test "SessionHistoryEntry - set step" {
    const allocator = std.testing.allocator;

    const entry = try SessionHistoryEntry.init(allocator, "https://example.com/");
    defer entry.deinit();

    try std.testing.expect(entry.step.isPending());

    entry.setStep(5);
    try std.testing.expectEqual(@as(?u64, 5), entry.step.getValue());
}

test "DocumentState - init and deinit" {
    const allocator = std.testing.allocator;

    var state = DocumentState.init(allocator);
    defer state.deinit();

    try std.testing.expect(state.document == null);
    try std.testing.expect(!state.ever_populated);
    try std.testing.expect(!state.reload_pending);
}

test "SessionHistoryList - basic operations" {
    const allocator = std.testing.allocator;

    var list = SessionHistoryList.init(allocator);
    defer list.deinit();

    const entry1 = try SessionHistoryEntry.init(allocator, "https://example.com/page1");
    entry1.setStep(0);
    try list.append(entry1);

    const entry2 = try SessionHistoryEntry.init(allocator, "https://example.com/page2");
    entry2.setStep(1);
    try list.append(entry2);

    try std.testing.expectEqual(@as(usize, 2), list.length());

    const found = list.getEntryByStep(1);
    try std.testing.expect(found != null);
    try std.testing.expectEqualStrings("https://example.com/page2", found.?.url);
}

test "SessionHistoryList - clear forward" {
    const allocator = std.testing.allocator;

    var list = SessionHistoryList.init(allocator);
    defer list.deinit();

    const entry1 = try SessionHistoryEntry.init(allocator, "https://example.com/page1");
    entry1.setStep(0);
    try list.append(entry1);

    const entry2 = try SessionHistoryEntry.init(allocator, "https://example.com/page2");
    entry2.setStep(1);
    try list.append(entry2);

    const entry3 = try SessionHistoryEntry.init(allocator, "https://example.com/page3");
    entry3.setStep(2);
    try list.append(entry3);

    list.clearForward(0);

    try std.testing.expectEqual(@as(usize, 1), list.length());
}

test "SerializedState - null and undefined" {
    const allocator = std.testing.allocator;

    var null_state = try SerializedState.nullState(allocator);
    defer null_state.deinit();

    var undefined_state = try SerializedState.undefinedState(allocator);
    defer undefined_state.deinit();

    try std.testing.expect(null_state.isNull());
    try std.testing.expect(!null_state.isUndefined());

    try std.testing.expect(undefined_state.isUndefined());
    try std.testing.expect(!undefined_state.isNull());
}

test "ScrollPositionData - basic operations" {
    const allocator = std.testing.allocator;

    var scroll_data = ScrollPositionData.init(allocator);
    defer scroll_data.deinit();

    scroll_data.viewport = .{ .x = 100, .y = 200 };
    try scroll_data.setElementPosition("element-1", .{ .x = 50, .y = 75 });

    try std.testing.expectEqual(@as(f64, 100), scroll_data.viewport.x);
    try std.testing.expectEqual(@as(f64, 200), scroll_data.viewport.y);

    const elem_pos = scroll_data.getElementPosition("element-1");
    try std.testing.expect(elem_pos != null);
    try std.testing.expectEqual(@as(f64, 50), elem_pos.?.x);
}
