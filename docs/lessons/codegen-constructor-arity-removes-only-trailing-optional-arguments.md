# Codegen: Constructor arity removes only trailing optional arguments

**Date**: 2026-10-21
**Lesson**: Compute constructor arity from the shortest effective IDL argument list by removing its trailing optional and variadic arguments.

**Why**: A required argument can follow an optional one. Counting leading required arguments, or counting all required arguments, gives different answers from the effective-overload algorithm. Nullable types and Zig optional representations also do not establish IDL optionality.

**What Happened**: GPUPipelineError declares an optional message followed by a required options dictionary. A new helper stopped at the first optional and emitted zero. A fixture with optional, required, optional arguments reproduced the mistake. Browser generator source split three ways for the same GPUPipelineError IDL: Chrome one, Firefox two, Safari zero. With no majority for this single mechanism, Crane follows the spec's two, matching Firefox.

**Fix**: WebIDL's effective-overload-set steps 5.8–5.9 remove arguments from the end until the first required argument. Interface object creation step 9.2 takes the shortest list across overloads. One generated value supplies constructor length and the pre-conversion argument check. The implementation design matches [Firefox's overloadLength](https://github.com/mozilla-firefox/firefox/blob/main/dom/bindings/Codegen.py), with no copied source. Full regeneration changed only GPUPipelineError among the 450 constructor counts affected by the new metadata.

**Takeaway**: **Test non-trailing optional arguments explicitly; optional, nullable, variadic and overloaded cases alone do not cover the effective-list algorithm.**
