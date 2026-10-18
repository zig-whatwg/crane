# Architecture: A returned dictionary hands its JavaScript values over as a result does

**Date**: 2026-10-18
**Lesson**: The binding released the object it made for a dictionary an operation returned, but kept every `.handle` member in it, while the impl handed those members over with `engine.Owned.take()` - so NavigationResult's two promises leaked on every navigation API call.

**Why**: `conversions.memberValueIsOwned` answers for a value put into an object in ANY conversion, and there a runtime.JSValue `.handle` is the impl's own handle: kept. A runtime.JSValue RESULT follows the opposite rule - "what an impl returns is the binding's" (convertReturnValue releases it). A dictionary result sits between the two, and took the member rule: the object was released (`dictionaryValueIsOwned`), its members never were.

**What Happened**: Lane leaks5's base measurement (leaks --atExit, main d5762d302d's runner) found 4 leaks in html/semantics/embedded-content/ - Navigation.navigate and reload -> derivedResult -> retainValue -> v8_Global_Clone - one per call in the two files that call them. Over navigation-api/ the same method found 1,170 leaks, 1,154 of them NavigationResult members: derivedResult's retained promises (1,070) and earlyErrorWith's and settledResult's new ones (84). PerformanceResourceTiming's toJSON already said so: it returned `serverTiming` as undefined because "the binding owner must add member ownership before this record can include the array safely".

**Fix**: `conversions.releaseReturnedDictionaryHandles(T, value)`, run by convertReturnValue's dictionary branch after toV8Value (a defer, so a failed conversion releases too): each runtime.JSValue member's `.handle`, through optionals, webidl.Opt and the inherited `base`. Every other arm holds nothing; `.instance` is the wrapper cache's. The audit (in the helper's doc comment) found NavigationResult the only returned dictionary or [Default] toJSON record that hands a handle over; the rest are NotImplemented. tests/v8/returned_dictionary_handles_test.zig pins it, with a control showing toV8Value alone keeps the members.

**Takeaway**: **A value an impl RETURNS is the binding's, at any depth: a dictionary result's JavaScript members are handed over like a JSValue result, and an impl must never put a handle it keeps into one.**
