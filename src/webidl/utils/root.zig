//! WebIDL Utilities
//!
//! This module provides common utilities extracted from impl files to reduce
//! code duplication and improve maintainability.
//!
//! ## Available Utilities
//!
//! - `InstanceRegistry(T)` - Generic registry pattern for instance-to-state mapping
//! - `InternalStateAccessor(T, S)` - Generic accessor for internal state retrieval
//! - `tombstones.TombstoneGuard` - when to rehash a long-lived address-keyed side table
//!
//! ## Note on CollectionMixin
//!
//! CollectionMixin is available in `collection.zig` but NOT exported here.
//! This is intentional: impl files are in a separate Zig module ('impls')
//! and importing utils from the 'webidl' module would cause module conflicts.
//!
//! For impl files that need collection helpers, the utility is still available
//! in the file but should not be imported via this root.zig.
//!
//! ## Usage
//!
//! ```zig
//! const utils = @import("utils");
//!
//! // Use registry pattern
//! const Registry = utils.InstanceRegistry(InternalState);
//!
//! // Use state accessor
//! const Accessor = utils.InternalStateAccessor(InternalState, State);
//! ```

pub const InstanceRegistry = @import("registry.zig").InstanceRegistry;
/// A runtime begins: the registries' entries from before it are an earlier
/// runtime's, whose arena is gone (registry.zig `runtime_epoch`).
pub const beginRegistryRuntime = @import("registry.zig").beginRuntime;
/// When to rehash a long-lived address-keyed side table (see tombstones.zig).
pub const tombstones = @import("tombstones.zig");
pub const InternalStateAccessor = @import("internal_state.zig").InternalStateAccessor;
pub const OptionalInternalStateAccessor = @import("internal_state.zig").OptionalInternalStateAccessor;

/// Create the inherited Event InternalState on a directly-constructed Event
/// SUBCLASS. Without it `dispatchEvent` throws InvalidStateError, so the event
/// can be constructed but never dispatched.
pub const initEventBase = @import("internal_state.zig").initEventBase;

// Typed dictionary/sequence extraction utilities
pub const typed_extraction = @import("typed_extraction.zig");
pub const extractDictionarySlice = typed_extraction.extractDictionarySlice;
pub const extractOptionalDictionarySlice = typed_extraction.extractOptionalDictionarySlice;
pub const extractDictionary = typed_extraction.extractDictionary;
pub const extractOptionalDictionary = typed_extraction.extractOptionalDictionary;

// Note: CollectionMixin and StringCollectionMixin are NOT exported here
// to avoid module conflicts when impl files try to use them.
// See collection.zig for the utilities - they're available but must be
// imported differently by impl files if needed.

test {
    @import("std").testing.refAllDecls(@This());
    _ = @import("registry.zig");
    _ = @import("tombstones.zig");
    _ = @import("internal_state.zig");
    _ = @import("typed_extraction.zig");
    // Note: collection.zig tests are run separately, not through this root
}
