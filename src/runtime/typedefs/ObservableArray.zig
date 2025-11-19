//! ObservableArray<T> - Observable mutable array
//!
//! WebIDL ObservableArray<T> represents a mutable array that can be observed
//! for changes. Per the spec: "ObservableArray types are references to objects
//! that hold arrays of values that can be mutated and observed for changes."
//!
//! Specification authors can define algorithms:
//! - **set an indexed value**: Called when setting an element at an index
//! - **delete an indexed value**: Called when removing an element at an index
//!
//! Generic function to create the type (used in generated code):

const std = @import("std");

/// ObservableArray<T> - Mutable array with observation callbacks
pub fn ObservableArray(comptime T: type) type {
    return struct {
        /// The underlying mutable array data
        /// This is managed by the allocator and can be resized
        data: []T,

        /// Allocator used for this array
        allocator: std.mem.Allocator,

        /// Callback invoked when an indexed value is set
        /// Parameters: index, new_value
        /// This allows specification authors to define custom behavior
        on_set_indexed_value: ?*const fn (index: usize, value: T) void = null,

        /// Callback invoked when an indexed value is deleted
        /// Parameters: index, old_value
        /// This allows specification authors to define custom behavior
        on_delete_indexed_value: ?*const fn (index: usize, value: T) void = null,

        const Self = @This();

        /// Element type
        pub const ElementType = T;

        /// Initialize an empty observable array
        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .data = &[_]T{},
                .allocator = allocator,
            };
        }

        /// Initialize from existing data (copies the data)
        pub fn initFromSlice(allocator: std.mem.Allocator, items: []const T) !Self {
            const owned_data = try allocator.dupe(T, items);
            return .{
                .data = owned_data,
                .allocator = allocator,
            };
        }

        /// Free all memory used by this observable array
        pub fn deinit(self: *Self) void {
            self.allocator.free(self.data);
            self.data = &[_]T{};
        }

        /// Get the number of elements
        pub fn len(self: Self) usize {
            return self.data.len;
        }

        /// Check if the array is empty
        pub fn isEmpty(self: Self) bool {
            return self.data.len == 0;
        }

        /// Get element at index (no bounds checking - spec behavior)
        pub fn get(self: Self, index: usize) T {
            return self.data[index];
        }

        /// Set element at index (triggers observation callback)
        pub fn set(self: *Self, index: usize, value: T) void {
            self.data[index] = value;

            // Trigger observation callback if registered
            if (self.on_set_indexed_value) |callback| {
                callback(index, value);
            }
        }

        /// Append element to end of array (triggers observation callback)
        pub fn append(self: *Self, value: T) !void {
            const new_data = try self.allocator.realloc(self.data, self.data.len + 1);
            self.data = new_data;
            const new_index = self.data.len - 1;
            self.data[new_index] = value;

            // Trigger observation callback if registered
            if (self.on_set_indexed_value) |callback| {
                callback(new_index, value);
            }
        }

        /// Remove element at index (triggers observation callback)
        pub fn remove(self: *Self, index: usize) !void {
            if (index >= self.data.len) return error.IndexOutOfBounds;

            const old_value = self.data[index];

            // Trigger observation callback BEFORE deletion
            if (self.on_delete_indexed_value) |callback| {
                callback(index, old_value);
            }

            // Shift elements down
            if (index < self.data.len - 1) {
                std.mem.copyForwards(T, self.data[index..], self.data[index + 1 ..]);
            }

            // Shrink array
            const new_data = try self.allocator.realloc(self.data, self.data.len - 1);
            self.data = new_data;
        }

        /// Set the observation callbacks
        pub fn setCallbacks(
            self: *Self,
            on_set: ?*const fn (usize, T) void,
            on_delete: ?*const fn (usize, T) void,
        ) void {
            self.on_set_indexed_value = on_set;
            self.on_delete_indexed_value = on_delete;
        }
    };
}
