//! The Fetch domain on page sessions: request interception in HTTP-network fetch (design 3.10).
//!
//! TODO(lane cdpt): the handlers. Until then every Fetch command answers
//! "'Fetch.<command>' wasn't found" (src/devtools/dispatch.zig). The handler
//! interface is src/devtools/README.md's.

const PageSession = @import("../page_session.zig").PageSession;
const protocol = @import("../protocol/root.zig");

/// Per-session state of the domain.
pub const State = struct {};
