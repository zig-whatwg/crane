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
//! `get` is brand-checked: another interface's object answers null.
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
        /// Get the internal state from an instance: its `own._internal`, or
        /// null when the instance is not a `StateT` - another interface's
        /// object, which the brand check (`instance.stateAs`) declines - when
        /// `StateT`'s own level keeps no `_internal`, or when it is null.
        ///
        /// The brand check is the read `getState` already made first: it
        /// fell back to a bare cast when the check failed, and so read
        /// another type's State at this level's offset as a pointer - type
        /// confusion, for any instance a hook can hand an impl
        /// (docs/lessons/debugging-a-layout-change-that-crashes-a-type-it-
        /// never-touched-look-for-an-unchecked-cast.md). Now it answers null
        /// there; the path a real `StateT` takes is the same read (lane
        /// crash1 batch 3). Measured, ReleaseSafe on server1: DOMTokenList's
        /// length getter, one of this accessor's users, 168.6 ns a call with
        /// the check and 167.6 without (medians of 5 x 5,000,000 calls) - inside
        /// the 2% spread between rounds.
        pub fn get(instance: InstanceT) ?*InternalT {
            if (!@hasField(@FieldType(StateT, "own"), "_internal")) return null;
            const state = instance.stateAs(StateT) orelse return null;
            return state.own._internal;
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
            // Brand-checked, as InternalStateAccessor.get.
            const state = instance.stateAs(StateT) orelse return null;
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

test "InternalStateAccessor - get reads its own type's state and declines another's" {
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
        /// Whether this object is a TestState: what the brand check reads.
        branded: bool,
        pub fn getState(self: *@This(), comptime _: type) *TestState {
            return &self.state;
        }
        pub fn stateAs(self: *@This(), comptime _: type) ?*TestState {
            return if (self.branded) &self.state else null;
        }
    };

    const Accessor = InternalStateAccessor(TestInternal, TestState, *MockInstance);

    var internal: TestInternal = .{ .value = 7 };
    var own: MockInstance = .{ .state = .{ .own = .{ ._internal = &internal } }, .branded = true };
    try std.testing.expectEqual(@as(?*TestInternal, &internal), Accessor.get(&own));
    try std.testing.expectEqual(&internal, try Accessor.getOrError(&own));
    // Another interface's object: `get` declines it through the brand check
    // and never reads the bytes where this level's pointer would be.
    var foreign: MockInstance = .{ .state = .{ .own = .{ ._internal = @ptrFromInt(0xaaaaaaaaaaaaaaa8) } }, .branded = false };
    try std.testing.expectEqual(@as(?*TestInternal, null), Accessor.get(&foreign));
    try std.testing.expectError(error.InvalidStateError, Accessor.getOrError(&foreign));
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

/// Create the inherited Event InternalState on a directly-constructed Event
/// SUBCLASS, and set its initialized flag.
///
/// https://dom.spec.whatwg.org/#concept-event-constructor
///
/// Every Event subclass constructor runs the Event constructor's steps, which
/// set the "initialized flag". `dispatchEvent` step 1 throws
/// `InvalidStateError` when that flag is unset, so a subclass constructor that
/// skips it builds an event which can be created but NEVER dispatched.
///
/// Nine subclass constructors hand-rolled the inherited attributes
/// (`state.base.own.type`, `.bubbles`, `.timeStamp` …) and filled in their OWN
/// InternalState, but never created Event's. `Event.getInternal` then returned
/// null, `initializeEvent` silently no-opped on its `orelse return`, and the
/// flag stayed unset - so `new CustomEvent(...)` + `dispatchEvent` threw, while
/// the same event delivered through an `onX` IDL attribute worked, because that
/// path does not check the flag. Hand-rolling it in each constructor is how the
/// nine drifted apart in the first place, so it lives here instead.
///
/// `base_own` is a POINTER to the subclass's `state.base.own`. The Event
/// InternalState type is read back off that struct's own `_internal` field
/// rather than imported, so this stays on the right side of the impls boundary:
/// an impl reaches Event through `interfaces`, never through `impls/Event.zig`.
/// `arena` is the event's Browser's (`runtime.arenaOf(instance)`), passed in rather
/// than imported: the `webidl` module does not depend on `runtime`, and adding
/// that edge to reach one allocator would be the wrong trade. Event's own
/// constructor takes the InternalState from that arena, so passing it keeps the
/// lifetime identical to the events Event already builds.
/// Create the inherited Event InternalState on a directly-constructed Event
/// SUBCLASS and set its initialized flag.
///
/// `base_own` is a POINTER to the subclass's `state.base.own` - the same view
/// MouseEvent, PointerEvent and WheelEvent already write by hand
/// (`state.base.base.own._internal`, one level deeper because they descend from
/// UIEvent). Those three dispatch correctly today; the six that did not do this
/// could be constructed but never dispatched.
///
/// The Event InternalState type is read back off that struct's own `_internal`
/// field rather than imported, so this stays on the right side of the impls
/// boundary: an impl reaches Event through `interfaces`, never through
/// `impls/Event.zig`. `arena` is `runtime.arenaOf(instance)` - the event's
/// Browser's - passed in because the `webidl` module does not depend on
/// `runtime`.
pub fn initEventBase(base_own: anytype, arena: anytype, allocator: std.mem.Allocator) !void {
    const FieldT = @TypeOf(base_own._internal);
    const Internal = @typeInfo(@typeInfo(FieldT).optional.child).pointer.child;

    const internal = try arena.create(Internal);
    internal.* = Internal.init(allocator);
    internal.initialized_flag = true;
    base_own._internal = internal;
}
