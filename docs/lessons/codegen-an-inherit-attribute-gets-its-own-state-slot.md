# Codegen: An `inherit attribute` gets its own State slot - one variable, two copies

**Date**: 2026-10-04
**Lesson**: Codegen gives every attribute an interface declares a field in that interface's State, `inherit attribute` included, so a mutable interface and its read-only parent each had their own x/y/width/height (DOMRect, DOMPoint, DOMMatrix) - and the parent's members read a copy the child never wrote.

**Why**: Geometry's internal member variables are the read-only interface's ("DOMPointReadOnly as well as the inheriting interface DOMPoint must be able to access and set the value of these variables"). `inherit attribute unrestricted double x;` on DOMPoint only makes the parent's read-only attribute writable (WebIDL 2.5.2) - it is the same variable. The generated `DOMPoint.State` nevertheless has its own `x` beside the flattened `DOMPointReadOnly.State`'s, and nothing says which one is real.

**What Happened**: Making the geometry interfaces [Serializable] needed their members to work first. DOMRect's constructor and setters wrote `DOMRect.State.own.x`; `top`, `right`, `bottom` and `left` are DOMRectReadOnly's members and read `DOMRectReadOnly.State.own` - fields DOMRect never wrote, declared `= undefined`, so `new DOMRect(1, 2, 3, 4).left` read undefined memory. DOMQuad read its points through `DOMPoint.State` while DOMPointReadOnly's `toJSON` and `matrixTransform` would read the other copy.

**Fix**: One storage per family, owned by the read-only interface (its impl keeps the variables in its own State and installs `dom.geometry_storage`'s setter at process start). The mutable interface reads through the parent's IDL getters (`interfaces.DOMRectReadOnly.get_x`) and writes through the hook; it creates its state through the parent's generated `initWithState`, and its own generated slots stay unused. Never by the child reading `interfaces.DOMRectReadOnly.State` - that is another impl's state, the impls boundary.

**Takeaway**: **A variable belongs to the interface that defines it; `inherit attribute` adds a setter, not a second variable - read it through the owner's getters and write it through the owner's hook, whatever slots codegen emitted.**
