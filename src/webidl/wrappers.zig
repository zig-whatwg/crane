//! WebIDL Wrapper Types
//!
//! Spec: https://webidl.spec.whatwg.org/#idl-types
//!
//! This module implements WebIDL wrapper types that provide semantic meaning
//! on top of basic data structures:
//!
//! - **Nullable<T>**: Optional value (WebIDL `T?`)
//! - **Optional<T>**: Operation argument tracking (was parameter passed?)
//! - **Sequence<T>**: Dynamic array (uses Infra List)
//! - **Record<K, V>**: Ordered map (uses Infra OrderedMap)
//! - **Promise<T>**: Async value placeholder
//!
//! # Design Philosophy
//!
//! Following INFRA_BOUNDARY.md:
//! - Sequence<T> is a **thin wrapper** around infra.List(T)
//! - Record<K, V> is a **thin wrapper** around infra.OrderedMap(K, V)
//! - Nullable<T> and Optional<T> are **new types** (not in Infra)
//!
//! # Usage
//!
//! ```zig
//! const wrappers = @import("wrappers.zig");
//! const allocator = std.heap.page_allocator;
//!
//! // Nullable
//! var maybe_value = Nullable(u32).some(42);
//! if (!maybe_value.isNull()) {
//!     std.debug.print("Value: {}\n", .{maybe_value.value});
//! }
//!
//! // Sequence
//! var seq = try Sequence(u32).init(allocator);
//! defer seq.deinit();
//! try seq.append(1);
//! try seq.append(2);
//!
//! // Record
//! var rec = try Record([]const u8, u32).init(allocator);
//! defer rec.deinit();
//! try rec.set("key", 100);
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;
const infra = @import("infra");

// ============================================================================
// Nullable<T> - WebIDL T?
// ============================================================================

/// Nullable<T> represents a WebIDL nullable type (T?).
///
/// Spec: https://webidl.spec.whatwg.org/#idl-nullable-type
///
/// A nullable type allows the value null in addition to values of type T.
/// This is distinct from Optional<T>, which tracks whether an argument
/// was provided.
///
/// Example:
/// ```zig
/// // WebIDL: attribute DOMString? name;
/// var name: Nullable([]const u8) = Nullable([]const u8).null_value();
/// name = Nullable([]const u8).some("Alice");
/// ```
pub fn Nullable(comptime T: type) type {
    return struct {
        const Self = @This();

        is_null: bool,
        value: T,

        /// Creates a null value.
        pub fn null_value() Self {
            return .{
                .is_null = true,
                .value = undefined,
            };
        }

        /// Creates a non-null value.
        pub fn some(val: T) Self {
            return .{
                .is_null = false,
                .value = val,
            };
        }

        /// Returns true if the value is null.
        pub fn isNull(self: Self) bool {
            return self.is_null;
        }

        /// Returns the value if non-null, or null otherwise.
        pub fn get(self: Self) ?T {
            return if (self.is_null) null else self.value;
        }

        /// Sets the value to null.
        pub fn setNull(self: *Self) void {
            self.is_null = true;
            self.value = undefined;
        }

        /// Sets the value to a non-null value.
        pub fn set(self: *Self, val: T) void {
            self.is_null = false;
            self.value = val;
        }
    };
}

// ============================================================================
// Optional<T> - Operation argument tracking
// ============================================================================

/// Optional<T> tracks whether an operation argument was provided.
///
/// This is used for optional operation arguments to distinguish between
/// "argument not provided" and "argument provided with default value".
///
/// Note: This is different from Nullable<T>. Optional tracks presence,
/// Nullable tracks null vs. non-null value.
///
/// Example:
/// ```zig
/// // WebIDL: undefined doSomething(optional long value = 0);
/// fn doSomething(value_arg: Optional(i32)) void {
///     if (value_arg.wasPassed()) {
///         // Argument was explicitly provided
///         const value = value_arg.value;
///     } else {
///         // Use default behavior (not just default value)
///     }
/// }
/// ```
pub fn Optional(comptime T: type) type {
    return struct {
        const Self = @This();

        was_passed: bool,
        value: T,

        /// Creates an Optional with no value (argument not passed).
        pub fn notPassed() Self {
            return .{
                .was_passed = false,
                .value = undefined,
            };
        }

        /// Creates an Optional with a value (argument was passed).
        pub fn passed(val: T) Self {
            return .{
                .was_passed = true,
                .value = val,
            };
        }

        /// Returns true if the argument was passed.
        pub fn wasPassed(self: Self) bool {
            return self.was_passed;
        }

        /// Gets the value (undefined behavior if not passed).
        pub fn getValue(self: Self) T {
            std.debug.assert(self.was_passed);
            return self.value;
        }

        /// Gets the value or a default.
        pub fn getOrDefault(self: Self, default: T) T {
            return if (self.was_passed) self.value else default;
        }
    };
}

// ============================================================================
// Sequence<T> - WebIDL sequence<T>
// ============================================================================

/// Sequence<T> represents a WebIDL sequence type.
///
/// Spec: https://webidl.spec.whatwg.org/#idl-sequence
///
/// Sequences are always passed by value. This is a thin wrapper around
/// Infra's List(T) to provide WebIDL-specific semantics.
///
/// Key characteristic: **Passed by value** (always copied).
///
/// Example:
/// ```zig
/// // WebIDL: sequence<long> getNumbers();
/// var numbers = try Sequence(i32).init(allocator);
/// defer numbers.deinit();
/// try numbers.append(1);
/// try numbers.append(2);
/// ```
pub fn Sequence(comptime T: type) type {
    return struct {
        const Self = @This();

        list: infra.List(T),

        /// Creates an empty sequence.
        pub fn init(allocator: Allocator) Self {
            return .{
                .list = infra.List(T).init(allocator),
            };
        }

        /// Frees the sequence memory.
        pub fn deinit(self: *Self) void {
            self.list.deinit();
        }

        /// Ensures the sequence can hold at least `capacity` items without reallocating.
        ///
        /// This is a performance optimization to avoid multiple allocations when
        /// the final size is known in advance.
        ///
        /// Example:
        /// ```zig
        /// var seq = Sequence(u32).init(allocator);
        /// defer seq.deinit();
        /// try seq.ensureCapacity(100);  // Pre-allocate for 100 items
        /// for (0..100) |i| {
        ///     try seq.append(@intCast(i));  // No reallocation needed
        /// }
        /// ```
        pub fn ensureCapacity(self: *Self, capacity: usize) !void {
            return self.list.ensureCapacity(capacity);
        }

        /// Appends an item to the end.
        pub fn append(self: *Self, item: T) !void {
            return self.list.append(item);
        }

        /// Prepends an item to the beginning.
        pub fn prepend(self: *Self, item: T) !void {
            return self.list.prepend(item);
        }

        /// Inserts an item at the given index.
        pub fn insert(self: *Self, index: usize, item: T) !void {
            return self.list.insert(index, item);
        }

        /// Removes and returns the item at the given index.
        pub fn remove(self: *Self, index: usize) !T {
            return self.list.remove(index);
        }

        /// Returns the item at the given index.
        pub fn get(self: *const Self, index: usize) T {
            return self.list.get(index) orelse unreachable;
        }

        /// Returns the number of items.
        pub fn len(self: *const Self) usize {
            return self.list.size();
        }

        /// Returns true if the sequence is empty.
        pub fn isEmpty(self: *const Self) bool {
            return self.list.isEmpty();
        }

        /// Clears all items.
        pub fn clear(self: *Self) void {
            self.list.clear();
        }

        /// Returns a slice of all items.
        pub fn items(self: *const Self) []const T {
            return self.list.items();
        }
    };
}

// ============================================================================
// Record<K, V> - WebIDL record<K, V>
// ============================================================================

/// Record<K, V> represents a WebIDL record type.
///
/// Spec: https://webidl.spec.whatwg.org/#idl-record
///
/// Records are ordered maps with string keys. Always passed by value.
/// This is a thin wrapper around Infra's OrderedMap(K, V).
///
/// Key must be DOMString, USVString, or ByteString.
///
/// Key characteristic: **Passed by value** (always copied).
///
/// Example:
/// ```zig
/// // WebIDL: record<DOMString, long> getCounts();
/// var counts = try Record([]const u8, i32).init(allocator);
/// defer counts.deinit();
/// try counts.set("apples", 5);
/// try counts.set("oranges", 3);
/// ```
pub fn Record(comptime K: type, comptime V: type) type {
    return struct {
        const Self = @This();

        map: infra.OrderedMap(K, V),

        /// Creates an empty record.
        pub fn init(allocator: Allocator) Self {
            return .{
                .map = infra.OrderedMap(K, V).init(allocator),
            };
        }

        /// Frees the record memory.
        pub fn deinit(self: *Self) void {
            self.map.deinit();
        }

        /// Sets a key-value pair.
        pub fn set(self: *Self, key: K, value: V) !void {
            return self.map.set(key, value);
        }

        /// Gets the value for a key, or null if not found.
        pub fn get(self: *const Self, key: K) ?V {
            return self.map.get(key);
        }

        /// Returns true if the key exists.
        pub fn has(self: *const Self, key: K) bool {
            return self.map.contains(key);
        }

        /// Removes a key-value pair.
        pub fn remove(self: *Self, key: K) void {
            _ = self.map.remove(key);
        }

        /// Returns the number of entries.
        pub fn len(self: *const Self) usize {
            return self.map.size();
        }

        /// Returns true if the record is empty.
        pub fn isEmpty(self: *const Self) bool {
            return self.map.isEmpty();
        }

        /// Clears all entries.
        pub fn clear(self: *Self) void {
            self.map.clear();
        }

        /// Returns an iterator over entries.
        pub fn iterator(self: *const Self) infra.OrderedMap(K, V).Iterator {
            return self.map.iterator();
        }
    };
}

// ============================================================================
// Promise<T> - WebIDL Promise<T>
// ============================================================================

/// Promise<T> represents a WebIDL Promise type.
///
/// Spec: https://webidl.spec.whatwg.org/#idl-promise
///
/// A promise is a placeholder for the eventual result of an asynchronous
/// operation. This is a placeholder implementation for testing.
///
/// In a real implementation, this would integrate with:
/// - V8: v8::Local<v8::Promise>
/// - JavaScriptCore: JSObjectRef (Promise object)
/// - SpiderMonkey: JS::PromiseObject
///
/// Example:
/// ```zig
/// // WebIDL: Promise<DOMString> fetchData();
/// fn fetchData() Promise([]const u8) {
///     return Promise([]const u8).pending();
/// }
/// ```
pub fn Promise(comptime T: type) type {
    return struct {
        const Self = @This();

        state: State,

        pub const State = union(enum) {
            pending: void,
            fulfilled: T,
            rejected: []const u8, // Error message
        };

        /// Creates a pending promise.
        pub fn pending() Self {
            return .{ .state = .pending };
        }

        /// Creates a fulfilled promise with a value.
        pub fn fulfilled(value: T) Self {
            return .{ .state = .{ .fulfilled = value } };
        }

        /// Creates a rejected promise with an error message.
        pub fn rejected(error_message: []const u8) Self {
            return .{ .state = .{ .rejected = error_message } };
        }

        /// Returns true if the promise is pending.
        pub fn isPending(self: Self) bool {
            return self.state == .pending;
        }

        /// Returns true if the promise is fulfilled.
        pub fn isFulfilled(self: Self) bool {
            return self.state == .fulfilled;
        }

        /// Returns true if the promise is rejected.
        pub fn isRejected(self: Self) bool {
            return self.state == .rejected;
        }
    };
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "Nullable - null value" {
    var value = Nullable(u32).null_value();
    try testing.expect(value.isNull());
    try testing.expectEqual(@as(?u32, null), value.get());
}

test "Nullable - some value" {
    var value = Nullable(u32).some(42);
    try testing.expect(!value.isNull());
    try testing.expectEqual(@as(?u32, 42), value.get());
}

test "Nullable - set and get" {
    var value = Nullable(u32).null_value();
    value.set(100);
    try testing.expect(!value.isNull());
    try testing.expectEqual(@as(u32, 100), value.value);

    value.setNull();
    try testing.expect(value.isNull());
}

test "Optional - not passed" {
    const opt = Optional(i32).notPassed();
    try testing.expect(!opt.wasPassed());
    try testing.expectEqual(@as(i32, 42), opt.getOrDefault(42));
}

test "Optional - passed" {
    const opt = Optional(i32).passed(100);
    try testing.expect(opt.wasPassed());
    try testing.expectEqual(@as(i32, 100), opt.getValue());
}

test "Sequence - basic operations" {
    const allocator = testing.allocator;

    var seq = Sequence(u32).init(allocator);
    defer seq.deinit();

    try testing.expect(seq.isEmpty());
    try testing.expectEqual(@as(usize, 0), seq.len());

    try seq.append(1);
    try seq.append(2);
    try seq.append(3);

    try testing.expectEqual(@as(usize, 3), seq.len());
    try testing.expectEqual(@as(u32, 1), seq.get(0));
    try testing.expectEqual(@as(u32, 2), seq.get(1));
    try testing.expectEqual(@as(u32, 3), seq.get(2));
}

test "Sequence - remove" {
    const allocator = testing.allocator;

    var seq = Sequence(u32).init(allocator);
    defer seq.deinit();

    try seq.append(10);
    try seq.append(20);
    try seq.append(30);

    const removed = try seq.remove(1);
    try testing.expectEqual(@as(u32, 20), removed);
    try testing.expectEqual(@as(usize, 2), seq.len());
    try testing.expectEqual(@as(u32, 30), seq.get(1));
}

test "Record - basic operations" {
    const allocator = testing.allocator;

    var rec = Record([]const u8, u32).init(allocator);
    defer rec.deinit();

    try testing.expect(rec.isEmpty());

    try rec.set("apples", 5);
    try rec.set("oranges", 3);

    try testing.expectEqual(@as(usize, 2), rec.len());
    try testing.expect(rec.has("apples"));
    try testing.expectEqual(@as(?u32, 5), rec.get("apples"));
    try testing.expectEqual(@as(?u32, 3), rec.get("oranges"));
    try testing.expectEqual(@as(?u32, null), rec.get("bananas"));
}

test "Record - remove" {
    const allocator = testing.allocator;

    var rec = Record([]const u8, i32).init(allocator);
    defer rec.deinit();

    try rec.set("key1", 100);
    try rec.set("key2", 200);

    rec.remove("key1");
    try testing.expect(!rec.has("key1"));
    try testing.expect(rec.has("key2"));
    try testing.expectEqual(@as(usize, 1), rec.len());
}

test "Promise - states" {
    const pending = Promise(u32).pending();
    try testing.expect(pending.isPending());
    try testing.expect(!pending.isFulfilled());
    try testing.expect(!pending.isRejected());

    const fulfilled = Promise(u32).fulfilled(42);
    try testing.expect(fulfilled.isFulfilled());
    try testing.expectEqual(@as(u32, 42), fulfilled.state.fulfilled);

    const rejected = Promise(u32).rejected("Error occurred");
    try testing.expect(rejected.isRejected());
    try testing.expectEqualStrings("Error occurred", rejected.state.rejected);
}
