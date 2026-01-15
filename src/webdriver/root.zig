//! WebDriver Server Implementation
//!
//! Implements the W3C WebDriver protocol to allow external tools like wptrunner
//! to control the Crane browser.
//!
//! ## Supported Endpoints
//!
//! | Method | Path | Command |
//! |--------|------|---------|
//! | GET | /status | Server status |
//! | POST | /session | New session |
//! | DELETE | /session/{id} | Delete session |
//! | POST | /session/{id}/url | Navigate to URL |
//! | GET | /session/{id}/url | Get current URL |
//! | GET | /session/{id}/title | Get page title |
//! | POST | /session/{id}/execute/sync | Execute script |
//! | POST | /session/{id}/execute/async | Execute async script |
//! | POST | /session/{id}/timeouts | Set timeouts |
//! | GET | /session/{id}/timeouts | Get timeouts |
//!
//! ## Usage
//!
//! ```zig
//! var server = try WebDriverServer.init(allocator, 9515);
//! defer server.deinit();
//! try server.run(); // Blocks until shutdown
//! ```
//!
//! ## References
//!
//! - W3C WebDriver Spec: https://w3c.github.io/webdriver/
//! - Servo WebDriver: https://book.servo.org/architecture/servodriver.html

pub const Server = @import("server.zig").Server;
pub const Session = @import("session.zig").Session;
pub const protocol = @import("protocol.zig");
pub const commands = @import("commands.zig");

test {
    _ = @import("server.zig");
    _ = @import("session.zig");
    _ = @import("protocol.zig");
    _ = @import("commands.zig");
}
