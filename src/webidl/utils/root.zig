//! WebIDL Utilities
//!
//! This module provides common utilities extracted from impl files to reduce
//! code duplication and improve maintainability.
//!
//! ## Available Utilities
//!
//! - `InstanceRegistry(T)` - Generic registry pattern for instance-to-state mapping
//! - `InternalStateAccessor(T, S)` - Generic accessor for internal state retrieval
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
pub const InternalStateAccessor = @import("internal_state.zig").InternalStateAccessor;
pub const OptionalInternalStateAccessor = @import("internal_state.zig").OptionalInternalStateAccessor;

// Note: CollectionMixin and StringCollectionMixin are NOT exported here
// to avoid module conflicts when impl files try to use them.
// See collection.zig for the utilities - they're available but must be
// imported differently by impl files if needed.

test {
    @import("std").testing.refAllDecls(@This());
    _ = @import("registry.zig");
    _ = @import("internal_state.zig");
    // Note: collection.zig tests are run separately, not through this root
}
