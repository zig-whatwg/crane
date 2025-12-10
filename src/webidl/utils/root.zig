//! WebIDL Utilities
//!
//! This module provides common utilities extracted from impl files to reduce
//! code duplication and improve maintainability.
//!
//! ## Available Utilities
//!
//! - `InstanceRegistry(T)` - Generic registry pattern for instance-to-state mapping
//! - `InternalStateAccessor(T, S)` - Generic accessor for internal state retrieval
//! - `CollectionMixin(T)` - Generic collection patterns (get_length, call_item, etc.)
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
//!
//! // Use collection helpers
//! const CollectionHelpers = utils.CollectionMixin(*runtime.Instance);
//! ```

pub const InstanceRegistry = @import("registry.zig").InstanceRegistry;
pub const InternalStateAccessor = @import("internal_state.zig").InternalStateAccessor;
pub const OptionalInternalStateAccessor = @import("internal_state.zig").OptionalInternalStateAccessor;
pub const CollectionMixin = @import("collection.zig").CollectionMixin;
pub const StringCollectionMixin = @import("collection.zig").StringCollectionMixin;

test {
    @import("std").testing.refAllDecls(@This());
    _ = @import("registry.zig");
    _ = @import("internal_state.zig");
    _ = @import("collection.zig");
}
