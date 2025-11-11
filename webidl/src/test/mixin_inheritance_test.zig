// Test file to check if child interfaces inherit parent mixins
const webidl = @import("zoop");

// Test Case 1: Single mixin with field
pub const TestMixin = webidl.mixin(struct {
    mixin_field: u32 = 42,
});

// Parent interface that includes the mixin
pub const Parent = webidl.interface(struct {
    pub const includes = .{TestMixin};

    parent_field: u32 = 100,
});

// Child interface that extends Parent
// Expected: Child automatically gets mixin_field from Parent's TestMixin
pub const Child = webidl.interface(struct {
    pub const extends = Parent;

    child_field: u32 = 200,
});

// Test Case 2: Multiple mixins with fields
pub const MixinA = webidl.mixin(struct {
    field_a: u32 = 10,
});

pub const MixinB = webidl.mixin(struct {
    field_b: u32 = 20,
});

pub const ParentMulti = webidl.interface(struct {
    pub const includes = .{ MixinA, MixinB };

    parent_multi_field: u32 = 300,
});

// Expected: ChildMulti gets field_a, field_b, parent_multi_field
pub const ChildMulti = webidl.interface(struct {
    pub const extends = ParentMulti;

    child_multi_field: u32 = 400,
});

// Test Case 3: Grandchild (3-level inheritance)
// Expected: GrandChild gets field_a, field_b from ParentMulti's mixins,
//           plus parent_multi_field, child_multi_field
pub const GrandChild = webidl.interface(struct {
    pub const extends = ChildMulti;

    grandchild_field: u32 = 500,
});
