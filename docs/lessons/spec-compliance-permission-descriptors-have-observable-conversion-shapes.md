# Spec Compliance: Permission descriptors have observable conversion shapes

**Date**: 2026-10-16
**Lesson**: Check each permission's supported browsers before choosing its dictionary conversion; even reading the same name twice is observable.

**Why**: Permissions query step 5 describes a second dictionary conversion. Engines avoid it for ordinary descriptors, and disagree about which derived descriptors they implement. Repeating an inherited getter can throw, mutate the descriptor, or detach its document.

**What Happened**: Row 42 initially considered Blink's camera, push, MIDI and clipboard conversions as a common pattern. Gecko and WebKit read camera and push only once, while both engines shipping MIDI queries read MIDI's name twice. Blink and Gecko also retain the first read's MIDI kind when the second read names another supported permission. The legacy native permission-name enum was broader than the live API's supported set.

**Fix**: Use an explicit supported-name allowlist with an unsupported default. Compare individual subtests from aligned browser runs, then read each engine's conversion function. Crane follows one name read for its ordinary supported descriptors and two for MIDI, followed by sysex. Capture conversion exceptions into the returned promise without replacing primitive thrown values. Pin getter order, second-read validation, the selected kind, and the allowlist's default separately.

Evidence: [Gecko CreatePermissionStatus](https://github.com/mozilla-firefox/firefox/blob/main/dom/permission/Permissions.cpp), [WebKit Permissions::query](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/Modules/permissions/Permissions.cpp), [Blink ParsePermissionDescriptor](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/modules/permissions/permission_utils.cc), and [WPT midi-permission.html](https://wpt.fyi/results/permissions/midi-permission.html). Aligned stable run IDs: Chrome 6218298311311360, Firefox 4877098740350976, Safari 5164107446878208.

**Takeaway**: **A dictionary conversion is observable script execution; implement the conversion shape the supporting browsers agree on.**
