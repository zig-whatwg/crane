//! A FileList's contents, as the hook its owners set them through.
//!
//! A FileList is read-only to script; what is in it is set natively, by the
//! object that hands it out: an input's selected files (HTML 4.10.5.1.18)
//! and a DataTransfer's files (HTML 6.11.3). Neither step has an IDL member,
//! and neither owner may reach into FileList's impl, so FileList installs
//! them here - the same shape as `live_collections.zig`.
//!
//! - `clear` empties a list IN PLACE, keeping its identity: Blink's
//!   FileInputType::SetValue (`file_list_->clear()`, value = "" and reset)
//!   and WebKit's FileInputType::setValue (`files()->clear()`) both do,
//!   and so a list shared by two inputs, or by an input and a DataTransfer,
//!   is emptied for all of them.
//! - `append` adds a File at the end and keeps it alive: Blink's
//!   DataTransfer::OnItemListChanged rebuilds its one `files_` with clear and
//!   Append on every item-list change.
//!
//! lint-impls: hook for FileList

const process_start = @import("process_start.zig");
const runtime = @import("runtime");

/// What the FileList impl supplies.
pub const Implementation = struct {
    clear: *const fn (list: *runtime.Instance) void,
    append: *const fn (list: *runtime.Instance, file: *runtime.Instance) error{ OutOfMemory, InvalidState }!void,
};

// process-wide: hook table written once at process start by FileList.installHooks (B0); the lists themselves are per-object state
var implementation: ?Implementation = null;

/// Called by FileList's installHooks, once, at process start (process_start.zig).
pub fn install(impl: Implementation) void {
    process_start.assertInstalling();
    implementation = impl;
}

/// Empty `list` (a FileList) in place: the same object, holding no File,
/// keeping none alive.
pub fn clear(list: *runtime.Instance) error{NotSupported}!void {
    const impl = implementation orelse return error.NotSupported;
    impl.clear(list);
}

/// Add `file` (a File) at the end of `list` (a FileList); the list keeps it
/// alive from then on.
pub fn append(list: *runtime.Instance, file: *runtime.Instance) error{ NotSupported, OutOfMemory, InvalidState }!void {
    const impl = implementation orelse return error.NotSupported;
    return impl.append(list, file);
}

test "with no FileList installed, clear and append report NotSupported" {
    const std = @import("std");
    const saved = implementation;
    defer implementation = saved;
    implementation = null;
    // Never dereferenced: with no implementation the call does not reach it.
    var object: runtime.Instance = undefined;
    try std.testing.expectError(error.NotSupported, clear(&object));
    try std.testing.expectError(error.NotSupported, append(&object, &object));
}
