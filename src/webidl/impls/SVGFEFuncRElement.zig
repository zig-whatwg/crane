//! Filter Effects: this leaf inherits its component-transfer implementation.
//! Its generated construction/destruction chain owns all parent state.
const interfaces = @import("interfaces");
pub const State = interfaces.SVGFEFuncRElement.State;
pub const InternalState = struct {};
