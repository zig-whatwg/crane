# Spec Compliance: A [LegacyOverrideBuiltIns] getter shadows the unforgeables Crane puts on the prototype

**Date**: 2026-10-18
**Lesson**: WebIDL's named property visibility algorithm (3.9.7) hides a named property behind an OWN property of the object - and an [LegacyUnforgeable] attribute is one - but Crane's binding defines unforgeable members on the prototype (only Location's are own), so a [LegacyOverrideBuiltIns] named getter shadows them.

**Why**: Visibility step 2 is "If O has an own property named P, then return false"; step 3 then lets [LegacyOverrideBuiltIns] win over everything on the prototype chain. The binding answers step 2 with V8's real own properties. `document.location` is `[PutForwards=href, LegacyUnforgeable]`, an own property of every Document in the browsers; in Crane it sits on Document.prototype (v8 interface.zig `unforgeable_members` is true for Location only).

**What Happened**: Lane domindex1 gave Document a working named getter. `html/browsers/the-window-object/named-access-on-the-window-object/strict-mode-redefine-readonly-property.html` went 1/1 -> 0/1: `<form name=location>` made `document.location` the form. A probe printed `Object.getOwnPropertyDescriptor(document, "location")` as undefined and Document.prototype's as defined. The base had passed only because its getter answered nothing.

**Fix**: Document's `isSupportedPropertyName` and `getSupportedPropertyNames` leave out its unforgeable names (`location`), which is what the visibility algorithm would answer - a stated deviation in Document.zig, compensating for the binding. The general fix is the binding's: define [LegacyUnforgeable] members on the instance (WebIDL 3.7.5), for every interface, not only Location.

**Takeaway**: **When a [LegacyOverrideBuiltIns] interface gains a named getter, list its [LegacyUnforgeable] members and test that a named element of each name does not shadow it: Crane's binding cannot see them as own properties yet.**
