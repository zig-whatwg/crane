//! TRANSITIONAL: only the real Fetch API src/platform/network_adapter.zig
//! reaches, for tests/platform/retained_old_platform.zig. The old platform
//! root shares files with the platform facade and cannot import all Fetch
//! now that integrity verification reaches that facade. Delete this root
//! with network_adapter.zig in platform recipes step 2a.

pub const network = struct {
    pub const backend = @import("network/backend.zig");
};
