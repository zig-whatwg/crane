# Third-party notices

Crane is MIT-licensed (see `LICENSE`). The following files contain code derived from other projects under their own licenses.

## Code translated from other engines

### `src/html/execcommand/visible_position.zig`

- Upstream project: Chromium (Blink), https://github.com/chromium/chromium
- Revision: `a7b97d6a9a7f7f897c77e2a6218e4cdcb136a099`
- Upstream files:
  - `third_party/blink/renderer/core/editing/visible_units.cc`
  - `third_party/blink/renderer/core/editing/editing_utilities.cc`
  - `third_party/blink/renderer/core/editing/position_units.cc`
- What was derived: the candidate and editing-boundary functions, `mostBackwardCaretPosition` through `previousPositionOf`. Each one names the Blink function it follows.
- License: BSD-2-Clause (Apple), text A below. Copyright lines:
  - `visible_units.cc`, `position_units.cc`: Copyright (C) 2004, 2005, 2006, 2007, 2008, 2009 Apple Inc. All rights reserved.
  - `editing_utilities.cc`: Copyright (C) 2004, 2005, 2006, 2007 Apple Inc. All rights reserved.

### `src/html/user_input.zig` (`filterNumberText`)

- Upstream project: Chromium (Blink), https://github.com/chromium/chromium
- Revision: `a7b97d6a9a7f7f897c77e2a6218e4cdcb136a099`
- Upstream file: `third_party/blink/renderer/core/html/forms/number_input_type.cc`, `NumberInputType::FilterBeforeTextInserted`
- License: BSD-3-Clause (Google), text B below. Copyright lines:
  - Copyright (C) 2010 Google Inc. All rights reserved.
  - Copyright (C) 2011 Apple Inc. All rights reserved.

### `src/runtime/engines/v8/cross_origin.zig` (`securityErrorMessage`)

- Upstream project: Chromium (Blink), https://github.com/chromium/chromium
- Revision: `671d6af90da4ab79e89cabbd7220cae70025cc11`
- Upstream files:
  - `third_party/blink/renderer/platform/bindings/exception_messages.cc`: `ExceptionMessages::AddContextToMessage`, `FailedToGetNamed`, `FailedToSetNamed`, `FailedToDeleteNamed`, `FailedToGetIndexed`, `FailedToSetIndexed`, `FailedToDeleteIndexed`, `OptionalNameProperty`, `OptionalIndexProperty`
  - `third_party/blink/renderer/core/frame/dom_window.cc`: `DOMWindow::SanitizedCrossDomainAccessErrorMessage`
- What was derived: the text of a cross-origin SecurityError's message - the access's context ("Failed to read a named property '<name>' from '<interface>': ") and the detail ("Blocked a frame with origin "<origin>" from accessing a cross-origin frame."), as message strings only.
- License: BSD-3-Clause. `exception_messages.cc`: text B below, with its own copyright line, Copyright (C) 2013 Google Inc. All rights reserved. `dom_window.cc`: Chromium's `LICENSE`, text C below (Copyright 2014 The Chromium Authors).

### `src/devtools/dom_editor.zig`

- Upstream project: Chromium (Blink), https://chromium.googlesource.com/chromium/src
- Revision: tag `157.0.8103.78` (commit `4b3d0dabb8250b6f152d2d85d79e7706e309d087`)
- Upstream files:
  - `third_party/blink/renderer/core/inspector/dom_editor.cc`: `DOMEditor` and its actions (`RemoveChildAction`, `InsertBeforeAction`, `RemoveAttributeAction`, `SetAttributeAction`, `SetOuterHTMLAction`, `ReplaceChildNodeAction`, `SetNodeValueAction`)
  - `third_party/blink/renderer/core/inspector/inspector_history.cc`: `InspectorHistory` (`Perform`, `AppendPerformedAction`, `MarkUndoableState`, `Undo`, `Redo`, `Reset`) and `UndoableStateMark`
- What was derived: the DOM agent's undoable edits and their history, translated action by action.
- License: BSD-3-Clause (Google), text B below. Copyright line (both files): Copyright (C) 2012 Google Inc. All rights reserved.

### `src/devtools/dom_patch.zig`

- Upstream project: Chromium (Blink), https://chromium.googlesource.com/chromium/src
- Revision: tag `157.0.8103.78` (commit `4b3d0dabb8250b6f152d2d85d79e7706e309d087`; Chrome for Testing 157, the CDP pin's Chrome)
- Upstream file: `third_party/blink/renderer/core/inspector/dom_patch_support.cc`: `DOMPatchSupport::PatchDocument`, `PatchNode`, `InnerPatchNode`, `Diff`, `InnerPatchChildren`, `CreateDigest`, `InsertBeforeAndMarkAsUsed`, `RemoveChildAndMoveToNew`, `MarkNodeAsUsed`
- What was derived: DOM.setOuterHTML's digest-based patch (the diff of old and new children, the merges, the moves), translated function by function.
- License: BSD-3-Clause (Google), text B below. Copyright line: Copyright (C) 2012 Google Inc. All rights reserved.

### `src/html/file_selection.zig`

- Upstream project: Chromium, https://chromium.googlesource.com/chromium/src
- Revision: tag `157.0.8103.78` (commit `4b3d0dabb8250b6f152d2d85d79e7706e309d087`)
- Upstream file: `net/base/mime_util.cc`: the tables `kPrimaryMappings` and `kSecondaryMappings` (the MIME type for a file extension that `GetWellKnownMimeTypeFromExtension` reads, and so Blink's `File::CreateForUserProvidedFile`)
- What was derived: the two tables' entries, in their order, as data.
- License: BSD-3-Clause, Chromium's `LICENSE`, text C below. Copyright line: Copyright 2012 The Chromium Authors.

## Vendored and pinned dependencies

These are listed here by reference. Their license texts are kept beside them:

- Brotli (MIT): `src/platform/kit/brotli/LICENSE`, with the version and commit in `src/platform/kit/brotli/README.md`.
- libjpeg-turbo (IJG and BSD-style): `src/platform/kit/image_codecs/licenses/libjpeg-turbo-LICENSE.md` and `src/platform/kit/image_codecs/licenses/README.ijg`. This software is based in part on the work of the Independent JPEG Group.
- NanoSVG (zlib): `src/platform/kit/image_codecs/licenses/nanosvg-LICENSE.txt`.
- Expat (MIT): `src/platform/kit/image_codecs/licenses/expat-LICENSE.txt`.

Versions and commits for the image codecs are in `src/platform/kit/image_codecs/README.md`.

- Chrome DevTools Protocol definitions (BSD-3-Clause, Copyright 2014 The Chromium Authors): `specs/devtools-protocol/browser_protocol.json` and `js_protocol.json`, from the `devtools-protocol` npm package 0.0.1717327, license text in `specs/devtools-protocol/LICENSE`, version and checksums in `specs/devtools-protocol/PIN.md`. The types generated from them (`src/devtools/protocol/`, by `tools/devtools_protocol_gen.zig`) carry their descriptions; `GET /json/protocol` serves the definitions.

- curl (the curl license, MIT-style: `COPYING` in its tree), pinned in `build.zig.zon` as Crane's fork, https://github.com/zig-whatwg/curl branch `crane/8.18.0` at `8300fa889e5e2177068328fcf14eec240375cbc1`: curl 8.18.0 (tag `curl-8_18_0`) plus three commits - the Zig packaging of allyourcodebase/curl at `5184bb9ff29cb0878be7983734c6852602570ea5` (MIT License (Expat), Copyright (c) contributors; text in the fork's `zig/LICENSE-allyourcodebase-curl`), a CONNECT_ONLY connection left without curl's HTTP/2 filter, and `CURLOPT_HTTP_LENIENT`. The two curl changes are Crane's own code, drafted for upstream curl.

## License texts

### A. BSD-2-Clause (Apple), as it appears in the Blink editing files

```
Copyright (C) 2004, 2005, 2006, 2007, 2008, 2009 Apple Inc. All rights
reserved.

Copyright (C) 2004, 2005, 2006, 2007 Apple Inc. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:
1. Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY APPLE COMPUTER, INC. ``AS IS'' AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE COMPUTER, INC. OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```

### B. BSD-3-Clause (Google), as it appears in `number_input_type.cc`

```
Copyright (C) 2010 Google Inc. All rights reserved.
Copyright (C) 2011 Apple Inc. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

    * Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above
copyright notice, this list of conditions and the following disclaimer
in the documentation and/or other materials provided with the
distribution.
    * Neither the name of Google Inc. nor the names of its
contributors may be used to endorse or promote products derived from
this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```

### C. BSD-3-Clause (The Chromium Authors), Chromium's `LICENSE`

```
Copyright 2015 The Chromium Authors

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

   * Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.
   * Redistributions in binary form must reproduce the above
copyright notice, this list of conditions and the following disclaimer
in the documentation and/or other materials provided with the
distribution.
   * Neither the name of Google LLC nor the names of its
contributors may be used to endorse or promote products derived from
this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```
