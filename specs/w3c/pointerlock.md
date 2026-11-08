
This specification defines an API that provides scripted access to raw
mouse movement data while locking the target of mouse events to a single
element and removing the cursor from view. This is an essential input
mode for certain classes of applications, especially first person
perspective 3D applications and 3D modeling software.

A history of changes to this document can be found at
<https://github.com/w3c/pointerlock/commits/gh-pages/index.html>

Summary of changes since [W3C Recommendation 27 October
2016](https://www.w3.org/TR/2016/WD-pointerlock-2-20161122/):

- [IDL blocks
 updated](https://github.com/w3c/pointerlock/commit/027f57ae80cf5bdb03379203828aa234f3e7e433)
 to be machine
 [parsable](https://github.com/w3c/pointerlock/issues/13), no
 substantive change.

## Introduction

The Pointer Lock API provides applications the ability to directly
interpret mouse movements as an input method, rather than being limited
to only read the position of the mouse cursor. A popular example is that
of first person movement controls in three dimensional graphics
applications such as games: movement of the mouse is interpreted to
control the rotation/direction of the player\'s camera; no mouse cursor
is displayed, and the movement is not limited to the traditional
boundaries (such as the user agent\'s window, or the overall screen)
that the mouse cursor is usually subject to, meaning that any mouse
movements can be tracked indefinitely in any direction.

Pointer Lock is related to Mouse Capture \[\[MDN-SETCAPTURE\]\] (Mouse
Capture is unspecified: bug
[14600](https://www.w3.org/Bugs/Public/show_bug.cgi?id=14600)). Capture
provides continued event delivery to a target element while a mouse is
being dragged, but ceases when the mouse button is released. Pointer
Lock differs by being persistent, not limited by screen boundaries,
sending events regardless of mouse button state, hiding the cursor, and
not releasing until an API call or specific default unlock gesture by
the user.

Pointer Lock deals with capturing a single resource and relating it to a
single element. This is similar to the Fullscreen API
\[\[FULLSCREEN\]\], which promotes a single element to be full screen.
The Pointer Lock API chooses to pattern the resource capture, state
change, and release API as closely as possible after the Fullscreen API.

The Pointer Lock interaction mode was previously referred to as mouse
lock. The name was changed as many different controller types besides
mice can manipulate the on screen pointing cursor, and they are all
impacted.

## Pointer Lock and Interfaces

### The [pointer lock state] definition

The \[=pointer lock state=\] is the state where a single DOM element,
which we will call the [pointer-lock target], receives all mouse
events and the cursor is hidden.

Once in the \[=pointer lock state=\] the \[=user agent=\] has a
\[=pointer-lock target=\], a [pointer-lock options], which is a
{{PointerLockOptions}} and a [cursor position] which is a pair of
numbers representing the location of the system mouse cursor when the
Pointer Lock State was entered (the same location that is reported in
\`screenX\`, \`screenY\`). The \[=pointer-lock target=\] receives all
relevant user generated {{MouseEvent}} events: namely, all
user-generated \`mousemove\`, \`mousedown\`, \`mouseup\`, \`click\`,
\`dblclick\`, \`auxclick\`, and \`wheel\` \[\[POINTEREVENTS\]\]. No
other elements receive these events while in \[=pointer lock state=\].
There will be no dispatching of events that require the concept of a
mouse cursor: namely, \`mouseenter\`, \`mouseleave\`, \`mouseover\`,
\`mouseout\`, \`drag\`, and \`drop\`.

While in the \[=pointer lock state=\] if the \[=pointer-lock
options=\]\' {{PointerLockOptions/unadjustedMovement}} member is
\`true\`, the event coordinates will not be affected by the underlying
platform behaviors such as mouse acceleration. In other words, the user
agent uses the APIs provided by the underlying platform to guarantee
getting the raw events. If the {{PointerLockOptions}}\'
{{PointerLockOptions/unadjustedMovement}} member is \`false\`, the user
agent relies on the default behavior of the underlying platform
regarding the mouse acceleration.

In the \[=pointer lock state=\], the system mouse cursor is hidden and
the window is prevented from losing focus, regardless of mouse movement
or button presses. This is directly or indirectly achieved utilizing the
underlying operating system API.

Synthetic mouse events created by application script act the same
regardless of lock state.

### \`PointerLockOptions\` dictionary

``` idl

 dictionary PointerLockOptions {
 boolean unadjustedMovement = false;
 };

```

[PointerLockOptions] dictionary

: The options dictionary to customize how the pointer behaves in the
 locked mode.

[unadjustedMovement] member

: If this value is set to \`true\`, then the pointer movements will
 not be affected by the underlying platform modifications such as
 mouse accelaration.

### \`pointerlockchange\` and \`pointerlockerror\` Events

Two events are used to communicate pointer lock state change or an error
in changing state. They are named [pointerlockchange] and
[pointerlockerror]. Refer to algorithm of
\[\[\[#requestPointerLock\]\]\] for detail.

Magnification software increases the size of content on the screen. It
uses the mouse to move the magnified point of focus around. When a
pointer lock is initiated, the magnification software needs to switch to
using the keyboard to move the magnified point of focus around instead.
When a {{pointerlockchange}} event is fired, web browsers therefore need
to make sure the event is communicated to assistive technologies like
screen magnifiers.

### [Exit Pointer Lock]

The process of exiting pointer lock, given an \|element:Element\|, is as
follows:

1. The system mouse cursor must be displayed again and positioned at
 \[=cursor position=\].
2. \[=Queue an element task=\] on the \[=user interaction task
 source=\] to \[=fire an event=\] named {{pointerlockchange}} at the
 given \|element:Element\|\'s \[=Node/node document=\].
3. Exit the \[=pointer lock state=\] by setting \[=pointer-lock
 target=\], \[=pointer-lock options=\], and \[=cursor position=\] to
 null.

## Extensions to the \`Element\` Interface

The {{Element}} interface is extended to provide the ability to request
the pointer be locked.

``` idl

 partial interface Element {
 Promise<undefined> requestPointerLock(optional PointerLockOptions options = );
 };

```

``` example

 const lock_element = document.getElementById("lock_element");
 const lock_button = document.getElementById("lock");
 lock_button.addEventListener("click", async (event) => {
 try {
 await lock_element.requestPointerLock({ unadjustedMovement: true });
 console.log("successfully locked!");
 } catch (e) {
 console.log("lock failed with error: ", e);
 }
 });

```

requestPointerLock({{PointerLockOptions}} options) method

: A \[=parallel queue=\] named as [lock requests queue] is used
 for queuing all requests. When [requestPointerLock()] is
 invoked, perform the following steps:

 1. Let \|promise:Promise\| be \[=a new promise=\].
 2. When a {{Window/window}} is in \[=Window/focus=\], if the
 \[=this=\]\'s \[=shadow-including root=\] is the
 \[=navigable/active document=\] of a \[=Document/browsing
 context=\] (or has an \[=tree/ancestor=\] \[=browsing
 context=\]) that is not in focus:
 1. \[=Queue an element task=\] on the \[=user interaction task
 source=\], given \[=this=\], to perform the following steps:
 1. \[=Fire an event=\] named {{pointerlockerror}} at
 \[=this=\]\'s \[=Node/node document=\].
 2. \[=Reject=\] \|promise\| with a
 {{\"WrongDocumentError\"}} {{DOMException}}.
 2. Return `promise`.
 3. If the \'relevant global object does not have \[=transient
 activation=\] and the {{Document}} has not previously released a
 successful pointer lock with {{Document/exitPointerLock()}}:
 1. \[=Queue an element task=\] on the \[=user interaction task
 source=\], given \[=this=\], to perform the following steps:
 1. \[=Fire an event=\] named {{pointerlockerror}} at
 \[=this=\]\'s \[=Node/node document=\].
 2. \[=Reject=\] `promise` with a
 \"{{NotAllowedError}}\" {{DOMException}}.
 2. Return `promise`.

 When a single user activation initiates both pointer lock and
 fullscreen \[\[FULLSCREEN\]\], the {{requestPointerLock()}} call
 succeeds only when it is made before a fullscreen request
 because fullscreen is a transient activation-consuming API.
 4. If \[=this=\]\'s \[=Node/node document=\]\'s \[=Document/active
 sandboxing flag set=\] has the \[=sandboxed pointer lock
 browsing context flag=\] set:
 1. \[=Queue an element task=\] on the \[=user interaction task
 source=\], given \[=this=\], to perform the following steps:
 1. \[=Fire an event=\] named {{pointerlockerror}} at
 \[=this=\]\'s \[=Node/node document=\].
 2. \[=Reject=\] `promise` with a
 \"{{SecurityError}}\" {{DOMException}}.
 2. Return `promise`.
 5. If options\[\"{{PointerLockOptions/unadjustedMovement}}\"\] is
 true and the platform does not support
 {{PointerLockOptions/unadjustedMovement}}:
 1. \[=Queue an element task=\] on the \[=user interaction task
 source=\], given \[=this=\], to perform the following steps:
 1. \[=Fire an event=\] named {{pointerlockerror}} at
 \[=this=\]\'s \[=Node/node document=\].
 2. \[=Reject=\] `promise` with a
 \"{{NotSupportedError}}\" {{DOMException}}.
 2. Return `promise`.
 6. Enqueue the following steps to the \[=lock requests queue=\]:
 1. If the user agent\'s \[=pointer-lock target=\] is an element
 whose \[=shadow-including root=\] is not equal to
 \[=this=\]\'s \[=shadow-including root=\], then:
 1. \[=Queue an element task=\] on the \[=user interaction
 task source=\], given \[=this=\], to perform the
 following steps:
 1. \[=Fire an event=\] named {{pointerlockerror}} at
 \[=this=\]\'s \[=Node/node document=\].
 2. \[=Reject=\] `promise` with a
 \"{{InvalidStateError}}\" {{DOMException}}.
 2. If the user agent\'s \[=pointer-lock target=\]\'s
 \[=shadow-including root=\] is equal to \[=this=\]\'s
 \[=shadow-including root=\] and options are equivalent to
 the current \[=pointer-lock options=\], then:
 1. Set \[=pointer-lock target=\] to \[=this=\].
 2. \[=Queue an element task=\] on the \[=user interaction
 task source=\], given \[=this=\], to perform the
 following steps:
 1. \[=Fire an event=\] named {{pointerlockchange}} at
 \[=this=\]\'s \[=Node/node document=\].
 2. \[=Resolve=\] the `promise`.
 3. If \[=pointer-lock target=\] is null, or options is not
 equivalent to the current \[=pointer-lock options=\],
 process the lock request and handle response upon
 fulfillment:
 1. If the lock request failed:
 1. \[=Queue an element task=\] on the \[=user
 interaction task source=\], given \[=this=\], to
 perform the following steps:
 1. \[=Fire an event=\] named {{pointerlockerror}}
 at \[=this=\]\'s \[=Node/node document=\].
 2. \[=Reject=\] `promise` with a
 \"{{NotSupportedError}}\" {{DOMException}}.
 2. If the lock request succeed:
 1. Enter \[=pointer lock state=\] by performing the
 following:
 1. Set the user agent\'s \[=pointer-lock target=\]
 to \[=this=\].
 2. Set the user agent\'s \[=cursor position=\] to
 the current system mouse location.
 3. Set the \[=pointer-lock options=\] to options.
 2. \[=Queue an element task=\] on the \[=user
 interaction task source=\], given \[=this=\], to
 perform the following steps:
 1. \[=Fire an event=\] named {{pointerlockchange}}
 at \[=this=\]\'s \[=Node/node document=\].
 2. \[=Resolve=\] the `promise`.
 7. Return `promise`.

 This algorithm is under active development and may be modified in
 subsequent updates.

## Extensions to the \`Document\` Interface

``` idl

 partial interface Document {
 attribute EventHandler onpointerlockchange;
 attribute EventHandler onpointerlockerror;
 undefined exitPointerLock();
 };

```

[onpointerlockchange] attribute

: An \[=event handler idl attribute=\] for
 {{Document/pointerlockchange}} events.

[onpointerlockerror] attribute

: An \[=event handler idl attribute=\] for
 {{Document/pointerlockerror}} events.

[exitPointerLock()] method

: 1. If the user agent\'s pointer-lock target is null, then return.
 2. If \[=pointer-lock target=\]\'s \[=shadow-including root=\]is
 not equal to \[=this=\]\'s \[=Node/node document=\], return.
 3. \[=Exit pointer lock=\] with the user agent\'s \[=pointer-lock
 target=\].

## Extensions to the \`DocumentOrShadowRoot\` Mixin

``` idl

 partial interface mixin DocumentOrShadowRoot {
 readonly attribute Element? pointerLockElement;
 };

```

[pointerLockElement]

: While the pointer is locked, returns the result of \[=retargeting=\]
 the element, which is the target for mouse events, against
 \[=this=\] element if the result and \[=this=\] element are in the
 same tree, otherwise returns null.

 Returns null if lock is pending or if pointer is unlocked.

 ```

 <body>
 <div id="host1">
 <shadow-root id="root1">
 <canvas id="canvas1"></canvas>
 </shadow-root>
 </div>
 <div id="host2">
 <shadow-root id="root2">
 <canvas id="canvas2"></canvas>
 </shadow-root>
 </div>
 </body>

 ```

 The example uses fictional \`shadow-root\` element to denote a
 \[=Element/shadow root=\] instance.

 If \`#canvas1\` is the target, \`document.pointerLockElement\`
 returns \`#host1\`, and \`root1.pointerLockElement\` returns
 \`#canvas1\`. The result of \[=retargeting=\] \`#canvas1\` against
 \`#root2\` is \`#host1\`, but as \`#host1\` is not in the same tree
 as \`#root2\`, null will be returned for
 \`root2.pointerLockElement\`.

## Extensions to the \`MouseEvent\` Interface

``` idl

 partial interface MouseEvent {
 readonly attribute double movementX;
 readonly attribute double movementY;
 };

```

[movementX] attribute\
[movementY] attribute

: The attributes {{movementX}} and {{movementY}} must provide the
 change in position of the pointer, as if the values of \`screenX\`,
 \`screenY\`, were stored between two subsequent \`mousemove\` events
 \`eNow\` and \`ePrevious\` and the difference taken \`movementX =
 eNow.screenX - ePrevious.screenX\`.

 {{movementX}} and {{movementY}} must be zero for all mouse events
 except \`mousemove\` and \`pointermove\`. All motion data must be
 delivered via \`mousemove\` events such that between any two mouse
 events \`earlierEvent\` and \`currentEvent\` the value of
 \`currentEvent.screenX - earlierEvent.screenX\` is equivalent to the
 sum of all {{movementX}} in the events after \`earlierEvent\`, with
 the exception of when screenX can not be updated because the pointer
 is clipped by the \[=user agent=\] screen boundaries.

 {{movementX}} and {{movementY}} must be updated regardless of
 pointer lock state.

 When unlocked, the system cursor can exit and re-enter the \[=user
 agent=\] window. If it does so and the \[=user agent=\] was not the
 target of operating system mouse move events then the most recent
 pointer position will be unknown to the \[=user agent=\] and
 {{movementX}} / {{movementY}} can not be computed and must be set to
 zero.

 When pointer lock is enabled \`clientX\`, \`clientY\`, \`screenX\`,
 and \`screenY\` must hold constant values as if the pointer did not
 move at all once pointer lock was entered. But {{movementX}} and
 {{movementY}} must continue to provide the change in position of the
 pointer as when the pointer is unlocked. There will be no limit to
 {{movementX}} and {{movementY}} values if the mouse is continuously
 moved in a single direction. The concept of the mouse cursor will
 have been removed, and it will not move off the window or be clamped
 by a screen edge.

 The un-initialized value of {{movementX}} and {{movementY}} must be
 \`0\`.

 Large movement values must not appear in situations when mouse input
 is interupted, such as the mouse cursor leaving the window and then
 re-entering at another location. If a \[=user agent=\] experiences a
 gap in receiving mouse input data from the operating system then the
 next generated \`mousemove\` event must have {{movementX}} and
 {{movementY}} set to \`0\`. These gaps may appear for example when
 the \[=user agent=\] receives a mouse leaving event at the window
 system API. As an exception mouse capture may allow the \[=user
 agent=\] to continue receiving mouse events when the cursor moves
 outside the window.

## Extensions to the \`MouseEventInit\` Dictionary

``` idl

 partial dictionary MouseEventInit {
 double movementX = 0;
 double movementY = 0;
 };

```

[movementX] member\
[movementY] member
: The members {{movementX}} and {{movementY}} are used to initialize
 respective members of {{MouseEvent}}.

## Requirements

A [default unlock gesture] must always be available that will
\[=exit pointer lock=\] with the \[=user agent=\]\'s \[=pointer-lock
target=\].

The ESC key is the recommended \[=default unlock gesture=\] for \[=user
agents=\] with keyboard input. It is recommended that the unlock gesture
also match any used to exit fullscreen \[\[FULLSCREEN\]\].

Pointer lock must be exited if the \[=pointer-lock target=\] [becomes
disconnected], or the \[=user agent=\],
window, or tab loses focus. Moving focus between elements of
\[=navigable/active document=\], including between \[=Document/browsing
contexts=\] , does not \[=exit pointer lock=\]. E.g. using the keyboard
to move focus between contents of frames or iframes will not exit.

Pointer lock must not be exited when fullscreen \[\[FULLSCREEN\]\] is
entered or exited unless the pointer is required to enable interaction
with the \[=user agent=\] graphical user interface, the \[=default
unlock gesture=\] was used to exit both fullscreen and pointer lock, or
window or tab focus was lost.

## Use Cases

## Relative view-port rotation of free moving virtual actors

A player on a first/third person game will need to control the view-port
orientation. A widely used method is the use of mouse movements to
control the viewing angle. This kind of application can use the Pointer
Lock API to allow a complete freedom of control over the viewport\'s yaw
and pitch even when the user is not pressing mouse buttons. Those
buttons can be used for other actions while constantly providing
navigation via mouse movement.

## Free rotation of 3D models or panning of 2D layers

Users of a three dimensional modeling application will need to rotate
models. A application can use the Pointer Lock API to enable the author
to rotate the model freely in a drag operation without limiting motion.
Without pointer lock a drag would stop providing motion data when the
mouse cursor is limited by the edge of the screen.

Similarly, absolute motion panning of a large two dimensional image
could be permitted in a single drag operation without cursor / screen
limits.

## Relative movement of actors

A player on a fast reflexes game controls a paddle to bounce back a ball
to the opponent, while allowing the same paddle to execute actions based
on different mouse buttons being pressed. The application can use the
Pointer Lock API to allow the player to react quickly without being
concerned about the mouse cursor leaving the game play area and clicking
another system application, thus breaking the game flow.

## Jog movement over spinner controls

When modifying numerically magnitudes in applications sometimes the user
will prefer to \"drag\" a numeric control by its button handles to
increment or decrement the numeric value. E.g. a spinner with a number
entry text box and arrows pointing up and down that can be clicked or
dragged on to change the value. An application could use the Pointer
Lock API to allow modifying the numeric values beyond what the logical
screen bounds allow. The same could apply for a control that fast
forwards or rewinds a video or audio stream like a \"jog\".

## Synthetic cursor interaction with HTML DOM UI

Some games use a classical cursor, however they want it to be limited or
controlled in some manner. E.g. limited to the bounds of the game, or
movable by the game. Locking the pointer enables this if the application
creates their own cursor. However HTML and DOM should still be available
to use for user interface. Synthetic mouse events should be permitted to
allow an application defined cursor to interact with DOM. E.g. the
following code should permit a custom cursor to send click events while
the pointer is locked:

``` example

 document.addEventListener("click", function (e) {
 if (e._isSynthetic)
 return;
 // send a synthetic click
 var ee = document.createEvent("MouseEvents");
 ee._isSynthetic = true;
 x = myCursor.x;
 y = myCursor.y;
 ee.initMouseEvent("click", true, true, null, 1,
 x + e.screenX - e.clientX,
 y + e.screenY - e.clientY,
 x,
 y);
 var target = document.elementFromPoint(x, y);
 if (target)
 target.dispatchEvent(ee);
 });

```

Note that synthetic clicks may not be permitted by a \[=user agent=\] to
produce the same default action as a non-synthetic click. However,
application handlers can still take action and provide user interface
with existing HTML & DOM mechanisms.

## View-port panning by moving a mouse cursor against the bounds of a view-port.

Real Time Strategy games often use this technique. When the player moves
the pointer to the view-port borders, if they \"push\" the border with a
mouse movement, the view-port is panned over the game area according to
how much they move the mouse. When moving the mouse cursor within the
bounds of the view port it acts at is typically would on a system.
Applications may choose to implement this using pointer lock and the
previous use case of \"Synthetic cursor interaction with HTML DOM UI\"
to bring cursor behavior completely under their control.

## Game Lobby, timer based pointer lock

Games that use pointer lock may desire a traditional UI and system
cursor while players prepare in a game lobby. Games usually start after
a short timer when all players are ready. Ideally the game could then
switch to pointer lock mode without a \[=user activation=\]. Players
should be able to seamlessly move from the game lobby into game
navigation.

## Game Portal

Game portals, and other sites such as Facebook and Google Plus, host
games for users to play. These games may be hosted and served from a
different origin from that of the portal site. Embedded games should be
able to lock the pointer, even in non-full screen mode.

## Security

Security Concerns:

- User actions may be misdirected to elements the user did not intend to
 interact with.
- Pointer Lock will remove the ability of a user to interact with \[=
 user agent=\] and operating system controls
- Pointer Lock can be called repeated by script after user exits pointer
 lock, blocking user from meaningful progress.
- Full screen exit instructions are displayed in some \[=user agent=\]s
 when the pointer is moved to the top of the screen. During pointer
 lock that gesture is not possible.

Responses:

- The \[=user agents=\] may limit what security origins may lock the
 pointer.
- The \[=user agents=\] may prompt for confirmation before locking, this
 preference may be saved as a content setting.
- Escape will always be provided by a \[=default unlock gesture=\], e.g.
 Esc key.
- Persistent display of escape instructions can be provided.
- Repeated escapes of pointer lock can signal \[=user agent=\] to not
 re-lock the pointer without more specific user action, e.g. similar to
 how Chrome suppresses repeated alert() calls.
- Changing to new tabs, windows, or any other action that causes a page
 to lose focus will \[=exit pointer lock=\] with the \[=user
 agent=\]\'s \[=pointer-lock target=\].
- Pointer lock can only be engaged when the window is in focus in the
 \[=user agent=\] and operating system.

Recommendations:

- Esc key should \[=exit pointer lock=\] with the user agent\'s
 \[=pointer-lock target=\].
- Preferences per sub-domain can be used to allow or block pointer lock,
 similar to pop-up, geolocation, and fullscreen.

Pointer lock is a required user interaction mode for certain application
types, but carries a usability concern if maliciously used. An attacker
could remove the ability for a user to control their mouse cursor on
their system. \[=user agents=\] will prevent this by always providing a
mechanism to \[=exit pointer lock=\], by informing the user of how, and
by limiting how pointer lock can be entered.

\[=user agents=\] will determine their own appropriate policies, which
may be specialized per device or differ based on user options.

## Frequently Asked Questions

## Why not merge with Mouse Capture: setCapture()?

Mouse Capture \[\[MDN-SETCAPTURE\]\] handles low security risk mouse
event target lock for the duration of a mouse drag gesture. Pointer lock
removes the concept of the cursor and directs all events to a given
target. They are related, but different.

If a browser implemented both, it would be reasonable to support a
combination of traits: The security simplicity of \"automatically
release lock when mouse up\" and the increased functionality of total
control over mouse input and removal of the system cursor. The security
trait would allow more permissive use of the feature for applications
that only required a short burst of pointer lock during a drag event.

This functionality is omitted from the initial version of this spec
because it helps the minor use cases in windowed mode but we still do
not have an implementation solving the major ones. And, to implement
this a browser must implement both, which none does yet. It is not clear
if this feature should live on .lock or on .setCapture. If both were
implemented, either API could be augmented fairly easily to offer the
hybrid functionality.

## Why not repurpose MouseEvent\'s .clientX/Y .screenX/Y?

Even in non locked state, the delta values of mouse movement are useful.
Changing the meaning of .client or .screen based on lock state would
also cause easy errors in code not carefully monitoring the lock state.

## Why use .movementX/Y instead of .deltaX/Y?

When the pointer is locked \'wheel\' events should be sent to the
\[=pointer-lock target=\] element just as \'mousemove\' events are.
There is a naming conflict with
{{WheelEvent/deltaX}}/{{WheelEvent/deltaY}}/{{WheelEvent/deltaZ}}
\[\[POINTEREVENTS\]\].

## Why bundle all functionality (hiding cursor, providing mouse deltas) instead of using CSS to hide the cursor, always providing delta values, and offering an API to restrict the cursor movement to a portion of the web page?

There are good motivations to provide a more fine grained approach. E.g.
the use case \"View-port panning by moving a mouse cursor against the
bounds of a view-port\" doesn\'t require hiding the mouse cursor, only
bounding it and always having delta values available. Also, this
specification defines the movement deltas to be taken from how the
system mouse cursor moves, which incorporates operating system filtering
and acceleration of the mouse movement data. Applications may desire
access to a more raw form of movement data prior to adjustments
appropriate for a mouse cursor. Also, raw data may provide better than
pixel level accuracy for movement, as well as higher frequency updates.
Providing the raw delta movement would also not require special
permission or mode from a user, and for some set of applications that do
not require bounding the cursor may reduce the security barriers and
prompts needed.

There are two justifications for postponing this finer grained approach.
The first is a concern of specifying what units mouse movement data are
provided in. This specification defines .movementX/Y precisely as the
same values that could be recorded when the mouse is not under lock by
changes in .screenX/Y. Implementations across multiple \[=user agents=\]
and operating systems will easily be able to meet that requirement and
provide application developers and users with a consistent experience.
Further, users are expected to have already configured the full system
of hardware input and operating system options resulting in a
comfortable control the system mouse cursor. By specifying .movementX/Y
in the same units mouse lock API applications will be instantly usable
to all users because they have already settled their preferences.

Secondly, the implementation of providing movement data and bounding the
mouse cursor is more difficult in the fine grained approach. Bundling
the features together gives implementations freedom to use a variety of
techniques as appropriate on each operating system and is more practical
to implement. Direct APIs do not exist on major desktop platforms
(Windows, Mac OS X, Linux) to bound the cursor to a specific rectangle,
and prototypes have not yet been developed to demonstrate building that
behavior by e.g. [invisible
windows](https://tronche.com/gui/x/xlib/window/attributes/) with
[Xlib](https://en.wikipedia.org/wiki/Xlib) or manual cursor movement on
Mac. Unaccelerated Delta values have been proposed to be accessed by
reading raw Human Interface Device (HID) data. E.g. WM_INPUT messages on
Windows, and USB device APIs on Mac OS X / Linux. The challenge here is
interpreting and normalizing the units to some consistent and
specifiable scale. Also, most APIs considered to date are limited to USB
devices.

It would be reasonable to consider adding these capabilities in the
future, as the currently specified pointer lock API would be easy to
continue to support if the finer grained delta and confinement features
were implemented.

The bundled API is selected for implementation practicality, because the
desired use cases are supported, and because it will not conflict with
future improvements as discussed here.

## High resolution deltas / High frequency updates?

Not yet, for the same reasons in the previous question: [\"Why bundle
all functionality (hiding cursor, providing mouse deltas) instead of
using CSS to hide the cursor, always providing delta values, and
offering an API to restrict the cursor movement to a portion of the web
page?\"](#why-bundle).

## Why modify MouseEvent and reuse existing mouse events instead of creating a mouse delta event?

When under pointer lock many mouse events remain relevant, e.g. click,
mousedown, etc. These all share the same event data structure
MouseEvent. If movement data were reported via a new data structure then
a new event would be needed for reporting delta movement. The new data
structure would have many parallels to MouseEvent to offer the same
conveniences, e.g. button and modifier key states. When handling click,
down, and up events would the existing mousedown, mouseup be used? If
so, they would provide .clientX/Y and .screenX/Y with no useful data,
but would lack the convenience of containing the current movement data.
Or, new events would also be required for when the mouse is locked.

Also, movementX/Y are convenient even when the mouse is not locked. This
spec requires movement members to always be valid, even when the mouse
cursor exists. This reduces code required to track the last cursor state
and mouseover/mouseout transitions if applications wish to make use of
delta motion of the mouse.

The only negative of adding movementX/Y to MouseEvent appears to be the
unused values in clientX/Y and screenX/Y when under pointer lock. This
does not seem to be a significant problem.

Therefore the minimal change to add movementX/Y to MouseEvent is
selected to reduce API and implementation complexity.

## Why separate targets for mouse events under pointer lock and keyboard input focus?

Consider a game with a 3D view controlled by moving the mouse cursor,
while the user may still chat with other users via a text console. It is
reasonable for the application to accept text input to an element that
is different than where mouse events are being dispatched. This is
similar to pre-existing behavior of receiving mousemove events over any
element while typing into a form on a page.

This specification defines conformance criteria that apply to a single
product: the [user agent] that implements the interfaces that it
contains.

## Acknowledgments

Many thanks to lots of people who made contributions to the discussions
of this specification:

- Adam Barth
- Alexey Proskuryakov
- Aryeh Gregor
- Boris Zbarsky
- Brandon Andrews
- Darin Fisher
- Dimitri Glazkov
- Ella Ge
- Glenn Maynard
- Gregg Tavares
- Janice Shiu
- John Villar
- Jonas Sicking
- Kagami Sascha Rosylight
- Klaas Heidstra
- Léonie Watson
- Marcos Cáceres
- Ms2ger
- Mustaq Ahmed
- Navid Zolghadr
- Olli Pettay
- Patrick H. Lauke
- Philip Jägenstedt
- Philippe Le Hegaret
- Robert O\'Callahan
- Tab Atkins Jr.
- Takayoshi Kochi
- Timeless
- Vincent Scheib
- Xiaoqian Wu
- Yves Lafon
