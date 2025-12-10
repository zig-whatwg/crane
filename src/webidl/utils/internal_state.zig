//! InternalStateAccessor - Generic accessor patterns for internal state retrieval
//!
//! This utility provides type-safe accessor functions for retrieving internal
//! state from runtime instances. It handles the common patterns found across
//! impl files: direct state access, optional state access, and pointer casting.
//!
//! ## Usage Patterns
//!
//! ### Pattern A - Direct State Access (most common)
//! ```zig
//! const Accessor = InternalStateAccessor(InternalState, State);
//!
//! // In methods:
//! const internal = Accessor.get(instance) orelse return error.InvalidStateError;
//! ```
//!
//! ### Pattern B - Optional State Access (returns null on error)
//! ```zig
//! const internal = Accessor.getOptional(instance);
//! if (internal) |int| {
//!     // use int
//! }
//! ```
//!
//! ### Pattern C - Pointer Cast Access (when _internal is anyopaque)
//! ```zig
//! const internal = Accessor.getCast(instance);
//! ```
//!
//! ## Benefits
//!
//! - Consistent state access across all impl files
//! - Reduced boilerplate (~5 lines per impl file)
//! - Type-safe with comptime verification
//! - Clear error handling patterns

const std = @import("std");

/// Generic internal state accessor for retrieving state from runtime instances.
///
/// This provides compile-time generated accessors that match the specific
/// internal state structure of each impl file.
///
/// @param InternalT - The InternalState type to retrieve
/// @param StateT - The State type containing `own._internal`
/// @param InstanceT - The instance type (typically *runtime.Instance)
pub fn InternalStateAccessor(comptime InternalT: type, comptime StateT: type, comptime InstanceT: type) type {
    return struct {
        /// Get the internal state from an instance.
        /// Returns null if instance state doesn't have an _internal field
        /// or if _internal is null.
        ///
        /// This is the most common pattern - direct access to state.own._internal.
        pub fn get(instance: InstanceT) ?*InternalT {
            const state = instance.getState(StateT);
            const OwnType = @TypeOf(state.own);

            // Check if _internal field exists
            if (@hasField(OwnType, "_internal")) {
                return state.own._internal;
            }
            return null;
        }

        /// Get the internal state, returning an error if not found.
        /// Use when internal state is required for the operation.
        pub fn getOrError(instance: InstanceT) !*InternalT {
            return get(instance) orelse return error.InvalidStateError;
        }

        /// Get the internal state via pointer cast.
        /// Use when _internal is stored as *anyopaque and needs casting.
        ///
        /// WARNING: Only use this when you know _internal is *anyopaque.
        /// Using on a correctly-typed _internal will cause compilation to fail.
        pub fn getCast(instance: InstanceT) *InternalT {
            const state = instance.getState(StateT);
            return @ptrCast(@alignCast(state.own._internal));
        }

        /// Set the internal state on an instance.
        /// Use during initialization.
        pub fn set(instance: InstanceT, internal: *InternalT) void {
            const state = instance.getState(StateT);
            state.own._internal = internal;
        }
    };
}

/// Variant accessor for impls that need to check hasField at runtime
/// because _internal may not exist in all State types.
///
/// This is useful for generic code that operates on multiple impl types.
/// @param InternalT - The InternalState type to retrieve
/// @param InstanceT - The instance type (typically *runtime.Instance)
pub fn OptionalInternalStateAccessor(comptime InternalT: type, comptime InstanceT: type) type {
    return struct {
        /// Get the internal state from an instance, checking field existence.
        /// Returns null if the state type doesn't have _internal or if it's null.
        pub fn get(comptime StateT: type, instance: InstanceT) ?*InternalT {
            const state = instance.getState(StateT);
            const OwnType = @TypeOf(state.own);

            if (@hasField(OwnType, "_internal")) {
                const internal = state.own._internal;
                if (internal) |int| {
                    // If _internal is optional
                    return int;
                } else if (@typeInfo(@TypeOf(internal)) == .pointer) {
                    // If _internal is non-optional pointer
                    return internal;
                }
            }
            return null;
        }
    };
}

// =============================================================================
// Tests
// =============================================================================

test "InternalStateAccessor - basic get" {
    // This is a compile-time test - we verify the type generates correctly
    const TestInternal = struct {
        value: u32,
    };

    const TestState = struct {
        own: struct {
            _internal: ?*TestInternal,
        },
    };

    // Use a simple mock instance type for testing
    const MockInstance = struct {
        state: TestState,
        pub fn getState(_: @This(), comptime _: type) TestState {
            return TestState{
                .own = .{ ._internal = null },
            };
        }
    };

    const Accessor = InternalStateAccessor(TestInternal, TestState, *MockInstance);

    // Verify the type has the expected functions
    _ = Accessor.get;
    _ = Accessor.getOrError;
    _ = Accessor.set;
}

test "InternalStateAccessor - getCast compiles" {
    const TestInternal = struct {
        data: []const u8,
    };

    const TestStateWithAnyopaque = struct {
        own: struct {
            _internal: *anyopaque,
        },
    };

    // Use a simple mock instance type for testing
    const MockInstance = struct {
        pub fn getState(_: @This(), comptime _: type) TestStateWithAnyopaque {
            var dummy: u8 = 0;
            return TestStateWithAnyopaque{
                .own = .{ ._internal = @ptrCast(&dummy) },
            };
        }
    };

    const Accessor = InternalStateAccessor(TestInternal, TestStateWithAnyopaque, *MockInstance);

    // Verify getCast is available
    _ = Accessor.getCast;
}
