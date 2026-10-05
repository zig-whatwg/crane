//! WebIDL enum: BackgroundFetchFailureReason
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const BackgroundFetchFailureReason = enum {
    __,
    _aborted_,
    _bad_status_,
    _fetch_error_,
    _quota_exceeded_,
    _download_total_exceeded_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "", "aborted", "bad-status", "fetch-error", "quota-exceeded", "download-total-exceeded" };
};
