// Test file to check if child interfaces inherit parent mixins
const webidl = @import("zoop");

// Define a mixin with a field
pub const TestMixin = webidl.mixin(struct {
    mixin_field: u32 = 42,
});

// Parent interface that includes the mixin
pub const Parent = webidl.interface(struct {
    pub const includes = .{TestMixin};

    parent_field: u32 = 100,
});

// Child interface that extends Parent
// Question: Does Child automatically get mixin_field from Parent's mixin?
pub const Child = webidl.interface(struct {
    pub const extends = Parent;

    child_field: u32 = 200,
});
