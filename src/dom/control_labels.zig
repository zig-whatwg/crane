//! Crane's UA form-control labels, shared by rendered text and accname.
//! HTML 15.5 leaves localization/masking to the UA. Q62/Q66's Chrome,
//! Firefox and Safari probe (integrator-probes-1023a/ctlfont-*.json) pins
//! these labels; Chrome/Firefox select password mask glyphs, not its value.
pub const submit = "Submit";
pub const reset = "Reset";
pub const choose_file = "Choose File";
pub const no_file = "No file chosen";
pub const password_mask = "\u{2022}";
