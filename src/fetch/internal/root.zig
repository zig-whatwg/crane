//! Fetch Internal Data Structures
//!
//! This module contains internal data structures used by the Fetch API
//! implementation that are not directly exposed to JavaScript.

pub const header_list = @import("header_list.zig");
pub const HeaderList = header_list.HeaderList;
pub const Header = header_list.Header;
pub const normalize = header_list.normalize;

test {
    _ = header_list;
}
