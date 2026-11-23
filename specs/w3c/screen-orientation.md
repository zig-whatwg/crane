
The Screen Orientation specification standardizes the types and angles
for a device\'s screen orientation, and provides a means for locking and
unlocking it. The API, defined by this specification, exposes the
current type and angle of the device\'s screen orientation, and
dispatches events when it changes. This enables web applications to
programmatically adapt the user experience for multiple screen
orientations, working alongside CSS. This API is particularly useful for
applications such as computer games, where users physically rotate the
device, but the screen orientation itself should not change. The API
restricts locking the screen orientation only if certain \[=pre-lock
conditions=\] are met.

This document is a work in progress.

## Example of usage

In this example, selecting the \"Lock\" button requests to go into
fullscreen and then locks the screen to the opposite orientation.
Selecting the \"Unlock\" button unlocks the screen.

```

 <script>
 function updateLockButton() {
 const lockButton = document.getElementById("button");
 const newOrientation = getOppositeOrientation();
 lockButton.textContent = `Lock to ${newOrientation}`;
 }

 function getOppositeOrientation() {
 return screen
 .orientation
 .type
 .startsWith("portrait") ? "landscape" : "portrait";
 }

 async function rotate(lockButton) {
 if (!document.fullscreenElement) {
 await document.documentElement.requestFullscreen();
 }
 const newOrientation = getOppositeOrientation();
 await screen.orientation.lock(newOrientation);
 updateLockButton(lockButton);
 }

 screen.orientation.addEventListener("change", updateLockButton);

 window.addEventListener("load", updateLockButton);
 </script>

 <button onclick="rotate(this)" id="button">
 Lock to...
 </button>
 <button onclick="screen.orientation.unlock()">
 Unlock
 </button>

```

## Concepts

To [lock the screen orientation] to an
{{OrientationLockType}} \|orientation\| means that the screen can only
be rotated by the user to a specific \[=screen orientation=\] - possibly
at the exclusion of other orientations. The possible orientations to
which the screen can be rotated is determined by the user agent, a user
preference, the operating system\'s conventions, or the screen itself.
For example, locking the orientation to \[=landscape=\] means that the
screen can be rotated by the user to \[=landscape-primary=\] and maybe
\[=landscape-secondary=\] if the system allows it, but won\'t change the
orientation to \[=portrait-secondary=\] orientation.

To [unlock the screen orientation] the end user is
unrestricted to rotate the screen to any \[=screen orientation=\] that
the system allows.

## Screen orientation types

A screen can be in, or \[=locked=\] to, one of the following [screen
orientations]:

[Natural]

: The reference orientation for the device\'s display, from which
 orientation angles are measured, as determined by the user agent,
 the user, the operating system, or the screen itself. For example, a
 computer monitor\'s reference orientation is typically
 \[=landscape-primary=\], while the reference orientation for a
 mobile phone is typically \[=portrait-primary=\].

 How a user agent determines the \[=natural=\] orientation is
 implementation-defined and varies by platform. Some user agents use
 a fixed orientation per device class (for example,
 \[=portrait-primary=\] for handsets and \[=landscape-primary=\] for
 tablets, desktops, and TVs), while others derive it from the
 screen\'s physical dimensions and its default rotation. For devices
 without an obvious upright, such as square or foldable screens, the
 \[=natural=\] orientation can therefore differ between user agents.

[Landscape]
: The screen\'s aspect ratio has a width greater than the height.

[Portrait]
: The screen\'s aspect ratio has a height greater than the width.

[Primary]
: The device\'s screen \[=natural=\] orientation for either
 \[=portrait=\] or \[=landscape=\].

[Secondary]
: The opposite of the device\'s screen primary orientation for
 \[=portrait=\] or \[=landscape=\].

[Any]
: The screen can be rotated by the user to any orientation allowed by
 the device\'s operating system or by the end-user.

[Default] (unlocked)
: The device\'s default behavior for when the screen is \[=unlocked=\]
 (i.e., the \[=Screen/active orientation lock=\] is \`null\`). This
 orientation is determined by the device\'s operating system, or the
 user agent, or controlled by the end-user, or possibly set by an
 \[=installed web application=\]. For example, when the screen
 orientation is unlocked and the user rotates the device, some
 devices will limit orientation changes to \[=portrait-primary=\],
 \[=landscape-primary=\], and \[=landscape-secondary=\], but not to
 \[=portrait-secondary=\].

## The current screen orientation type and angle

The screen of the output device has the following associated concepts:

[Current orientation type]
: The \[=screen orientation=\] of the screen, represented as a
 {{OrientationType}}.

[Current orientation angle]
: The angle in degrees that the screen is rotated counter-clockwise
 from its \[=natural=\] orientation as derived from the \[=screen
 orientation values lists=\].

[Active orientation lock]
: The \[=screen orientation=\], represented as a
 {{OrientationLockType}}, to which the screen is \[=locked=\], or
 \`null\` when \[=unlocked=\].

The [screen orientation values lists] below standardize the angles
associated with each screen orientation type for screens with different
\[=natural=\] orientations:

For screens with a \[=natural=\] \[=portrait=\] orientation:

: - \[=portrait-primary=\]: 0°
 - \[=landscape-primary=\]: 90°
 - \[=portrait-secondary=\]: 180°
 - \[=landscape-secondary=\]: 270°

For screens with a \[=natural=\] \[=landscape=\] orientation:

: - \[=landscape-primary=\]: 0°
 - \[=portrait-primary=\]: 90°
 - \[=landscape-secondary=\]: 180°
 - \[=portrait-secondary=\]: 270°

## Extensions to the \`Document\` interface

## Internal Slots

The {{Document}} interface is extended with the following internal
slots:

 Internal Slot Description
 ---------------------------------------------------------------- ----------------------------------------------------------------------------------------------------------------------------------
 [\[\[\\orientationPendingPromise\]\]] Either \`null\` or a {{Promise}}. When assigned a {{Promise}}, that promise represents a request to lock the screen orientation.

## Extensions to the \`Screen\` interface

``` idl

 partial interface Screen {
 [SameObject] readonly attribute ScreenOrientation orientation;
 };

```

The {{Window}} object has an [associated \`ScreenOrientation\`],
which is a {{Screen}}\'s {{Screen/orientation}} object (i.e., the
{{ScreenOrientation}} instance at \`window.screen.orientation\`).

## [ScreenOrientation] interface

``` idl

 [Exposed=Window]
 interface ScreenOrientation : EventTarget {
 Promise<undefined> lock(OrientationLockType orientation);
 undefined unlock();
 readonly attribute OrientationType type;
 readonly attribute unsigned short angle;
 attribute EventHandler onchange;
 };

```

## Internal Slots

 Internal Slot Description
 ------------------------------- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 [\[\[\\angle\]\]] Represents the screen\'s last known \[=Screen/current orientation angle=\] in degrees as an {{unsigned short}} as derived from the \[=screen orientation values lists=\].
 [\[\[\\initialType\]\]] Represents the screen\'s \[=Screen/current orientation type=\] when the \[=browsing context=\] was created.
 [\[\[\\type\]\]] Represents the screen\'s last known \[=Screen/current orientation type=\] as an {{OrientationType}} enum value.

## \`lock()\` method

[pre-lock conditions] are optional requirements that a \[=user
agent=\] MAY impose before allowing screen orientation locking. Common
pre-lock conditions include requiring the document to be in fullscreen
mode or being part of an installed web application. See
\[\[\[#appmanifest-interaction\]\]\] and
\[\[\[#fullscreen-interaction\]\]\] for specific examples.

When the {{lock()}} method is invoked with {{OrientationLockType}}
\|orientation:OrientationLockType\|, the \[=user agent=\] MUST run the
following steps.

1. Let \|document:Document\| be \[=this=\]\'s \[=relevant global
 object=\]\'s \[=associated \`Document\`=\].
2. Run the \[=common safety checks=\] with \|document\|. If an
 \[=exception=\] is \[=exception/throw\|thrown=\], return \[=a
 promise rejected with=\] that exception and abort these steps.
3. If the \[=user agent=\] does not support locking the screen
 orientation to \|orientation\|, return \[=a promise rejected with=\]
 a {{\"NotSupportedError\"}} {{DOMException}} and abort these steps.
4. If the \[=user agent=\] requires \|document\| and its associated
 \[=Document/browsing context=\] to meet \[=pre-lock conditions=\] in
 order to \[=lock the screen orientation=\], and those conditions are
 not met, return \[=a promise rejected with=\] a
 {{\"NotAllowedError\"}} {{DOMException}} and abort these steps.
5. If \|document\|\'s {{Document/\[\[orientationPendingPromise\]\]}} is
 not \`null\`, \[=reject and nullify the current lock promise=\] of
 \|document\| with an {{\"AbortError\"}}.
6. Set \|document\|\'s {{Document/\[\[orientationPendingPromise\]\]}}
 to \[=a new promise=\].
7. \[=Apply orientation lock=\] \|orientation\| to \|document\|.
8. Return \|document\|\'s
 {{Document/\[\[orientationPendingPromise\]\]}}.

## \`unlock()\` method

When the {{unlock()}} method is invoked, the \[=user agent=\] MUST run
the following steps:

1. Let \|document:Document\| be \[=this=\]\'s \[=relevant global
 object=\]\'s \[=associated \`Document\`=\].
2. Run the \[=common safety checks=\] with \|document\|. If an
 \[=exception=\] is \[=exception/throw\|thrown=\], re-throw that
 exception and abort these steps.
3. If screen\'s \[=Screen/active orientation lock=\] is \`null\`,
 return \`undefined\`.
4. If \|document\|\'s {{Document/\[\[orientationPendingPromise\]\]}} is
 not \`null\`, \[=reject and nullify the current lock promise=\] of
 \|document\| with an {{\"AbortError\"}}.
5. \[=Apply orientation lock=\] \`null\` to \|document\|.

{{unlock()}} does not return a promise because it is equivalent to
locking to the \[=default screen orientation=\] which might or might not
be known by the \[=user agent=\]. Hence, the \[=user agent=\] can not
predict what the new orientation is going to be and even if it is going
to change at all.

## Common Safety Checks

The [common safety checks] for a {{Document}}
\|document:Document\| are the following steps:

1. If \|document\| is not a \[=Document/fully active descendant of a
 top-level traversable with user attention=\], \[=exception/throw=\]
 an {{\"InvalidStateError\"}} {{DOMException}}.
2. If \|document\| has the \[=sandboxed orientation lock browsing
 context flag=\] set, \[=exception/throw=\] {{\"SecurityError\"}}
 {{DOMException}}.
3. If \|document\|\'s \[=Document/visibility state=\] is \"hidden\",
 \[=exception/throw=\] {{\"SecurityError\"}} {{DOMException}}.

## \`type\` attribute

When getting, the {{type}} attribute returns \[=this=\]\'s
{{ScreenOrientation/\[\[type\]\]}}.

## \`angle\` attribute

When getting, the {{angle}} attribute returns \[=this=\]\'s
{{ScreenOrientation/\[\[angle\]\]}}.

The {{ScreenOrientation/angle}} attribute represents how far the screen
has rotated from its \[=natural=\] orientation. The screen orientation
values lists specify how the angle changes depending on how the screen
is rotated.

## \`onchange\` event handler attribute

The {{onchange}} attribute is an \[=event handler IDL attribute=\] for
the {{onchange}} \[=event handler=\], whose \[=event handler event
type=\] is [change].

## [OrientationLockType] enum

``` idl

 enum OrientationLockType {
 "any",
 "natural",
 "landscape",
 "portrait",
 "portrait-primary",
 "portrait-secondary",
 "landscape-primary",
 "landscape-secondary"
 };

```

The {{OrientationLockType}} enum represents the screen orientations to
which a screen can be potentially \[=locked=\].

User agents might only support a subset of the possible
{{OrientationLockType}} values. For example, a user agent might not
support locking to the \`\"portrait-secondary\"\` or
\`\"landscape-secondary\"\` orientations.

- \"[any]\" represents \[=any=\].
- \"[natural]\" represents \[=natural=\].
- \"[landscape]\" represents \[=landscape=\].
- \"[portrait]\" represents \[=portrait=\].
- \"[portrait-primary]\" represents \[=portrait-primary=\].
- \"[portrait-secondary]\" represents \[=portrait-secondary=\].
- \"[landscape-primary]\" represents \[=landscape-primary=\].
- \"[landscape-secondary]\" represents \[=landscape-secondary=\].

## [OrientationType] enum

``` idl

 enum OrientationType {
 "portrait-primary",
 "portrait-secondary",
 "landscape-primary",
 "landscape-secondary"
 };

```

The {{OrientationType}} enum values are used to represent the screen\'s
\[=Screen/current orientation type=\].

- \"[portrait-primary]\" represents \[=portrait-primary=\].
- \"[portrait-secondary]\" represents \[=portrait-secondary=\].
- \"[landscape-primary]\" represents \[=landscape-primary=\].
- \"[landscape-secondary]\" represents \[=landscape-secondary=\].

## Algorithms

## Initializing the \`ScreenOrientation\` object

When a \[=browsing context=\] \|context\| is created, the \[=user
agent=\] MUST:

1. Let \|screenOrientation\| be \|context\|\'s \[=associated
 \`ScreenOrientation\`=\].
2. Initialize \|screenOrientation\|\'s
 {{ScreenOrientation/\[\[initialType\]\]}} internal slot to the
 screen\'s \[=Screen/current orientation type=\].
3. Initialize \|screenOrientation\|\'s
 {{ScreenOrientation/\[\[type\]\]}} internal slot to the screen\'s
 \[=Screen/current orientation type=\].
4. Initialize \|screenOrientation\|\'s
 {{ScreenOrientation/\[\[angle\]\]}} internal slot to the screen\'s
 \[=Screen/current orientation angle=\].

## Rejecting a document\'s current lock promise

When steps require to [reject and nullify the current lock
promise] of {{Document}} \|document\| with a {{DOMString}}
\|exceptionName\|, the \[=user agent=\] MUST:

1. \[=/Assert=\]: {{Document/\[\[orientationPendingPromise\]\]}} is not
 \`null\`.
2. Let \|promise:Promise\| be \|document\|\'s
 {{Document/\[\[orientationPendingPromise\]\]}}.
3. \[=Queue a global task=\] on the \[=DOM manipulation task source=\]
 with \|document\|\'s \[=relevant global object=\] to \[=reject=\]
 \|promise\| with a new \|exceptionName\| {{DOMException}}.
4. Set \|document\|\'s {{Document/\[\[orientationPendingPromise\]\]}}
 to \`null\`.

## Applying an orientation lock

When steps require to [apply orientation lock] of
{{OrientationLockType?}} \|orientation\| to {{Document}} \|document\|,
the \[=user agent=\] MUST perform the following steps:

1. If \|document\| stops being \[=Document/fully active=\] while \[=in
 parallel=\], and {{Document/\[\[orientationPendingPromise\]\]}} is
 not \`null\`, \[=reject and nullify the current lock promise=\] of
 \|document\| with an {{\"AbortError\"}}.
2. Let \|topDocument\| be \|document\|\'s \[=top-level
 traversable=\]\'s \[=navigable/active document=\].
3. Let \|descendantDocs\| be an \[=ordered set=\] consisting of
 \|topDocument\|\'s \[=Document/descendant navigables=\]\'s
 \[=navigable/active documents=\], if any, in tree order.
4. \[=Set/For each=\] \|doc:Document\| in \|descendantDocs\|:
 1. If \|doc\| is \|document\|, continue.
 2. If \|doc\|\'s {{Document/\[\[orientationPendingPromise\]\]}} is
 \`null\`, continue.
 3. \[=Reject and nullify the current lock promise=\] of \|doc\|
 with an {{\"AbortError\"}}.
5. Run the following sub-steps \[=in parallel=\]:
 1. If \|document\| has stopped being \[=Document/fully active=\],
 and if the \|document\|\'s
 {{Document/\[\[orientationPendingPromise\]\]}} is not \`null\`,
 \[=reject and nullify the current lock promise=\] of
 \|document\| with an {{\"AbortError\"}} and abort these steps.

 2. If \|orientation\| is \`null\`, \[=unlock the screen
 orientation=\].

 3. Otherwise, attempt to \[=lock the screen orientation=\] to
 \|orientation\|. Depending on platform conventions, change how
 the viewport is drawn to match \|orientation\|.

 4. If the attempt fails due to previously-established user
 preference, or platform limitation, or any other reason:

 1. Set the screen\'s \[=Screen/active orientation lock=\] to
 \`null\`.
 2. \[=Queue a global task=\] on the \[=DOM manipulation task
 source=\] with \|document\|\'s \[=relevant global object=\]
 to:
 1. If the \|document\|\'s
 {{Document/\[\[orientationPendingPromise\]\]}} is not
 \`null\`, \[=reject and nullify the current lock
 promise=\] of \|document\| with a
 {{\"NotSupportedError\"}}.
 3. Abort these parallel sub-steps.

 This can happen if the user has set a preference that prevents
 web applications from changing the screen orientation, or if the
 underlying platform, rather than the user agent, does not allow
 locking the screen orientation to the given \|orientation\|.
 Note that differences in user preferences or platform
 capabilities could potentially be used for fingerprinting, as
 they may create detectable patterns in lock failure behavior.

 5. Set the screen\'s \[=Screen/active orientation lock=\] to
 \|orientation\| and update the \[=Screen/current orientation
 type=\] and \[=Screen/current orientation angle=\] to reflect
 any changes to the \[=screen orientation=\].

 6. \[=Queue a global task=\] on the \[=DOM manipulation task
 source=\] with \|document\|\'s \[=relevant global object=\] to:
 1. Let \|promise:Promise?\| be \|document\|\'s
 {{Document/\[\[orientationPendingPromise\]\]}}.

 As the promise needs to resolve after a
 \"[change]{link-for="ScreenOrientation"}\" event is fired,
 we keep a reference to prevent it from being aborted by an
 event\'s handler function calling
 {{ScreenOrientation/lock()}}.

 2. Set \|document\|\'s
 {{Document/\[\[orientationPendingPromise\]\]}} to \`null\`.

 3. Run the \[=screen orientation change steps=\] with
 \|topDocument\|.

 4. If \|promise\| is not \`null\`, \[=resolve=\] \|promise\|
 with \`undefined\`.

## Screen orientation change

When a user-agent determines that the screen\'s orientation has changed
for a \[=top-level traversable=\], or the user moves the \[=top-level
browsing context=\] to a different screen, then run the \[=screen
orientation change steps=\] with the \[=top-level traversable=\]\'s
\[=navigable/active document=\].

To [update the screen orientation] of {{Document}}
\|document:Document\|, run these steps:

1. If \|document\| is not a \[=Document/fully active descendant of a
 top-level traversable with user attention=\], abort these steps.
2. Let \|type\| and \|angle\| be the screen\'s \[=Screen/current
 orientation type=\] and \[=Screen/current orientation angle=\].
3. Let \|screenOrientation\| be \|document\|\'s \[=relevant global
 object=\]\'s \[=associated \`ScreenOrientation\`=\].
4. If \|type\| is equal to \|screenOrientation\|\'s
 {{ScreenOrientation/\[\[type\]\]}} and \|angle\| is equal to
 \|screenOrientation\|\'s {{ScreenOrientation/\[\[angle\]\]}}, abort
 these steps.
5. \[=Queue a global task=\] on the \[=user interaction task source=\]
 with \|document\|\'s \[=relevant global object=\] to perform the
 following steps:
 1. Set \|screenOrientation\|\'s {{ScreenOrientation/\[\[angle\]\]}}
 to \|angle\|.
 2. Set \|screenOrientation\|\'s {{ScreenOrientation/\[\[type\]\]}}
 to \|type\|.
 3. \[=Fire an event=\] named
 \"[change]{link-for="ScreenOrientation"}\" at
 \|screenOrientation\|.

The [screen orientation change steps] for {{Document}}
\|document:Document\| are as follows:

1. Let \|documents\| be an \[=ordered set=\] consisting of \|document\|
 followed by \|document\|\'s \[=Document/descendant navigables=\]\'s
 \[=navigable/active documents=\], if any, in tree order.
2. \[=Set/For each=\] \|doc:Document\| in \|documents\|, \[=update the
 screen orientation=\] of \|doc\|.

## Handling page visibility changes

\[\[HTML\]\]\'s \"update the visibility state\" algorithm runs the
\[=screen orientation change steps=\].

Developers need to be aware that \[=documents=\] that are not
\[=Document/fully active descendant of a top-level traversable with user
attention=\] will not receive orientation change events. However, once a
\[=document=\] meets these requirements again, it will receive change
events reflecting the current orientation.

## Handling unloading documents

Whenever the \[=unloading document cleanup steps=\] run with a
\|document\|, the user agent MUST run the following steps:

1. If \|document\| is not a \[=top-level traversable=\]\'s
 \[=navigable/active document=\], abort these steps.
2. Run the \[=fully unlock the screen orientation steps=\] with
 \|document\|.

## Fully unlocking the orientation

The [fully unlock the screen orientation steps] for
{{Document}} \|document:Document\| are as follows:

1. If \|document\|\'s {{Document/\[\[orientationPendingPromise\]\]}} is
 not \`null\`, \[=reject and nullify the current lock promise=\] of
 \|document\| with an {{\"AbortError\"}}.
2. Let \|topDocument\| be \|document\|\'s \[=top-level
 traversable=\]\'s \[=navigable/active document=\].
3. \[=Apply orientation lock=\] \`null\` to \|topDocument\|.

## Interaction with Fullscreen API

A user agent MUST restrict the use of {{ScreenOrientation/lock()}} to
simple fullscreen documents as a \[=pre-lock condition=\]. This
requirement prevents fingerprinting through differences in user agent
behavior regarding orientation locking permissions. \[\[fullscreen\]\]

When a \[=document=\] exits fullscreen, it also runs the \[=fully unlock
the screen orientation steps=\]. \[\[fullscreen\]\]

## Interaction with Web Application Manifest

The \[\[\[appmanifest\]\]\] specification allows web applications to set
the \[=default screen orientation=\] via the \[=manifest/orientation=\]
member.

A user agent SHOULD require \[=installed web applications=\] to be
presented in the \"fullscreen\" \[=display mode=\] as a \[=pre-lock
condition=\].

## Accessibility considerations

As users can have their devices mounted in a fixed orientation (e.g. on
the arm of a wheelchair), developers that expect users to rotate their
device when \[=locking the screen orientation=\] need to be aware of the
\[\[\[WCAG21\]\]\]\'s [Orientation Success
Criterion]. The criterion makes it
[essential] that content and
functionality is available regardless of the \[=screen orientation=\].
When a particular orientation is
[essential], web applications must
advise the user of the orientation requirements.

## Privacy and Security Considerations

A screen\'s \[=Screen/current orientation type\|type=\] and
\[=Screen/current orientation angle\|angle=\] are a potential
fingerprinting vectors. The following mitigations help protect a user\'s
privacy by not revealing how a device is being held, and also prevent
the \[=secondary=\] orientation type and associated angles from being
used for fingerprinting purposes.

### Event Delivery Restrictions

To protect user privacy, orientation change events are subject to
several delivery restrictions:

- Events only fire on a \[=document=\] that is a \[=Document/fully
 active descendant of a top-level traversable with user attention=\].
- Additional \[=Document/visibility state=\] checks provide
 defense-in-depth against hidden documents.
- Events originate from the \[=navigable/active document=\] of a
 \[=top-level traversable=\] and propagate to descendant documents.

The requirement for \[=documents=\] to be \[=Document/fully active
descendant of a top-level traversable with user attention=\] ensures
that orientation events are only delivered to documents in windows that
are both visible at the system level and have the user\'s attention
(either through focus or the ability to receive keyboard input). The
additional visibility state check provides defense in depth. These
restrictions prevent background tabs, hidden windows, and minimized
applications from collecting orientation data for fingerprinting
purposes.

### Anti-fingerprinting Mitigations

To resist fingerprinting, user agents SHOULD implement the following
protections, particularly in privacy-conscious contexts such as private
browsing modes:

1. For the life of a \[=top-level traversable=\], behave as if the
 screen\'s \[=natural=\] orientation is
 {{ScreenOrientation/\[\[initialType\]\]}}.
2. Restrict the possible return values of the
 {{ScreenOrientation/type}} getter to
 {{OrientationType/\"portrait-primary\"}} or
 {{OrientationType/\"landscape-primary\"}}. The screen aspect ratio
 determines which is returned.
3. If the \[=Screen/current orientation type=\] matches
 {{ScreenOrientation/\[\[initialType\]\]}}, return \`0\` for the
 {{ScreenOrientation/angle}} getter. Otherwise, return \`90\`.
4. If the screen orientation changes, only fire the
 [change]{link-for="ScreenOrientation"} event when the
 \[=Screen/current orientation type=\] changes from \[=portrait=\] to
 \[=landscape=\], or vice versa.

## Acknowledgments

Thanks Christophe Dumez, Anne van Kesteren, Chundong Wang, Fuqiao Xue,
and Chaals McCathie Nevile for their useful comments.

Special thanks to Chris Jones and Jonas Sicking for their contributions
to the initial design of this API.
