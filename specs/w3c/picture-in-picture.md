## 1. Introduction

*This section is non-normative.*

Many users want to continue consuming media while they interact with
other content, sites, or applications on their device. A common UI
affordance for this type of activity is Picture-in-Picture (PiP), where
the video is contained in a separate miniature window that is always on
top of other windows. This window stays visible even when the user agent
is not visible. Picture-in-Picture is a common platform-level feature
among desktop and mobile OSs.

This specification extends
[`HTMLVideoElement`](https://html.spec.whatwg.org/multipage/media.html#htmlvideoelement) allowing websites to initiate and control this behavior
by exposing the following sets of properties:

- Notify the website when it enters and leaves Picture-in-Picture mode.

- Allow the website to trigger Picture-in-Picture mode via a user
 gesture on a video element.

- Allow the website to know the size of the Picture-in-Picture window
 and notify the website when it changes.

- Allow the website to exit Picture-in-Picture mode.

- Allow the website to check if Picture-in-Picture mode can be
 triggered.

## 2. Examples

### 2.1. Add a custom Picture-in-Picture button

```
<video id="video" src="https://example.com/file.mp4"></video>

<button id="togglePipButton"></button>

<script>
 const video = document.getElementById("video");
 const togglePipButton = document.getElementById("togglePipButton");

 // Hide button if Picture-in-Picture is not supported or disabled.
 togglePipButton.hidden =
 !document.pictureInPictureEnabled || video.disablePictureInPicture;

 togglePipButton.addEventListener("click", async () => {
 // If there is no element in Picture-in-Picture yet, let's request
 // Picture-in-Picture for the video, otherwise leave it.
 try {
 if (document.pictureInPictureElement) {
 await document.exitPictureInPicture();
 } else {
 await video.requestPictureInPicture();
 }
 } catch (err) {
 // Video failed to enter/leave Picture-in-Picture mode.
 }
 });
</script>
```

### 2.2. Monitor video Picture-in-Picture changes

```
<video id="video" src="https://example.com/file.mp4"></video>

<script>
 const video = document.getElementById("video");

 video.addEventListener("enterpictureinpicture", (event) => {
 // Video entered Picture-in-Picture mode.
 const pipWindow = event.pictureInPictureWindow;
 console.log(`Picture-in-Picture window width: ${pipWindow.width}`);
 console.log(`Picture-in-Picture window height: ${pipWindow.height}`);
 });

 video.addEventListener("leavepictureinpicture", () => {
 // Video left Picture-in-Picture mode.
 });
</script>
```

### 2.3. Update video size based on Picture-in-Picture window size changes

```
<video id="video" src="https://example.com/file.mp4"></video>

<button id="pipButton"></button>

<script>
 const video = document.getElementById("video");
 const pipButton = document.getElementById("pipButton");

 pipButton.addEventListener("click", async () => {
 try {
 await video.requestPictureInPicture();
 } catch (error) {
 // Video failed to enter Picture-in-Picture mode.
 }
 });

 video.addEventListener("enterpictureinpicture", (event) => {
 // Video entered Picture-in-Picture mode.
 const pipWindow = event.pictureInPictureWindow;
 updateVideoSize(pipWindow.width, pipWindow.height);
 pipWindow.addEventListener("resize", onPipWindowResize);
 });

 video.addEventListener("leavepictureinpicture", (event) => {
 // Video left Picture-in-Picture mode.
 const pipWindow = event.pictureInPictureWindow;
 pipWindow.removeEventListener("resize", onPipWindowResize);
 });

 function onPipWindowResize(event) {
 // Picture-in-Picture window has been resized.
 const { width, height } = event.target;
 updateVideoSize(width, height);
 }

 function updateVideoSize(width, height) {
 // TODO: Update video size based on pip window width and height.
 }
</script>
```

## 3. Concepts

### 3.1. Definitions

A [Picture-in-Picture window] is a window displaying the
[`video`](https://html.spec.whatwg.org/multipage/media.html#video) element.

A
[`DocumentOrShadowRoot`](https://dom.spec.whatwg.org/#documentorshadowroot) has:

1. A [Picture-in-Picture element], which is an
 [`Element`](https://dom.spec.whatwg.org/#element) or `null`, initially `null`.

A [traversable
navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#traversable-navigable) has:

1. A [picture-in-picture parallel
 queue], which is a [parallel
 queue](https://html.spec.whatwg.org/multipage/infrastructure.html#parallel-queue) created by [starting a new parallel
 queue](https://html.spec.whatwg.org/multipage/infrastructure.html#starting-a-new-parallel-queue).

A [user
agent](https://infra.spec.whatwg.org/#user-agent) has:

1. An [initiators of active Picture-in-Picture
 sessions] list of zero or more
 [origins](https://dom.spec.whatwg.org/#concept-document-origin), which is initially empty.

 In case a [user
 agent](https://infra.spec.whatwg.org/#user-agent) supports multiple Picture-in-Picture windows, the
 list allows duplicates.

An origin is said to have an active Picture-in-Picture session if any of
the origins in [initiators of active Picture-in-Picture
sessions](#initiators-of-active-picture-in-picture-sessions) are [same
origin-domain](https://html.spec.whatwg.org/multipage/browsers.html#same-origin-domain) with origin.

### 3.2. Picture-in-Picture

It is RECOMMENDED that video frames are not rendered in the page and in
the Picture-in-Picture window at the same time but if they are, they
MUST be kept in sync.

When a video is played in Picture-in-Picture mode, the states SHOULD
transition as if it was played inline. That means that the events SHOULD
fire at the same time, calling methods SHOULD have the same behaviour,
etc. However, the user agent MAY transition out of Picture-in-Picture
when the video element enters a state that is considered not compatible
with Picture-in-Picture.

Styles applied to `video` (such as opacity, visibility,
transform, etc.) MUST NOT apply in the Picture-in-Picture window. Its
aspect ratio is based on the video size.

It is also RECOMMENDED that the Picture-in-Picture window has a maximum
and minimum size. For example, it could be restricted to be between a
quarter and a half of one dimension of the screen.

When a
[`DocumentOrShadowRoot`](https://dom.spec.whatwg.org/#documentorshadowroot)'s [Picture-in-Picture
element](#picture-in-picture-element) is set, the [Picture-in-Picture
window](#picture-in-picture-window) MUST be visible, even when the
[`DocumentOrShadowRoot`](https://dom.spec.whatwg.org/#documentorshadowroot)'s [relevant global
object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global)'s [associated
Document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window)'s [visibility
state](https://html.spec.whatwg.org/multipage/interaction.html#visibility-state) is \"hidden\". The user agent SHOULD provide a way for
users to manually close the Picture-in-Picture window.

### 3.3. Exit Picture-in-Picture

When the [exit Picture-in-Picture
algorithm] is invoked, the user agent MUST run the
following steps:

1. If
 [`pictureInPictureElement`](#dom-documentorshadowroot-pictureinpictureelement) is `null`, throw a
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) and abort these steps.

2. Run the [close window
 algorithm](#close-window-algorithm) with the [Picture-in-Picture
 window](#picture-in-picture-window) associated with
 [`pictureInPictureElement`](#dom-documentorshadowroot-pictureinpictureelement).

3. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire) named
 [`leavepictureinpicture`](#eventdef-htmlvideoelement-leavepictureinpicture) using
 [`PictureInPictureEvent`](#pictureinpictureevent) at the `video` with its
 [`bubbles`](https://dom.spec.whatwg.org/#dom-event-bubbles) attribute initialized to `true` and its
 [`pictureInPictureWindow`](#dom-pictureinpictureevent-pictureinpicturewindow) attribute initialized to [Picture-in-Picture
 window](#picture-in-picture-window) associated with
 [`pictureInPictureElement`](#dom-documentorshadowroot-pictureinpictureelement).

4. Unset
 [`pictureInPictureElement`](#dom-documentorshadowroot-pictureinpictureelement).

5. Remove one
 [item](https://infra.spec.whatwg.org/#list-item) matching [relevant settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object)'s
 [origin](https://dom.spec.whatwg.org/#concept-document-origin) from [initiators of active Picture-in-Picture
 sessions](#initiators-of-active-picture-in-picture-sessions).

It is NOT RECOMMENDED that the video playback state changes when the
[exit Picture-in-Picture
algorithm](#exit-picture-in-picture-algorithm) is invoked. The website SHOULD be in control of the
experience if it is website initiated. However, the user agent MAY
expose Picture-in-Picture window controls that change video playback
state (e.g., pause).

As one of the [unloading document cleanup
steps](https://html.spec.whatwg.org/multipage/document-lifecycle.html#unloading-document-cleanup-steps), run the [exit Picture-in-Picture
algorithm](#exit-picture-in-picture-algorithm).

### 3.4. Disable Picture-in-Picture

Some pages may want to disable Picture-in-Picture mode for a video
element; for example, they may want to prevent the user agent from
suggesting a Picture-in-Picture context menu in some cases. To support
these use cases, a new
[`disablePictureInPicture`](#dom-htmlvideoelement-disablepictureinpicture) attribute is added to the list of content attributes
for video elements.

The
[`disablePictureInPicture`](#dom-htmlvideoelement-disablepictureinpicture) IDL attribute MUST
[reflect](https://html.spec.whatwg.org/multipage/common-dom-interfaces.html#reflect) the content attribute of the same name.

If the
[`disablePictureInPicture`](#dom-htmlvideoelement-disablepictureinpicture) attribute is present on the video element, the user
agent MAY prevent the video element from playing in Picture-in-Picture
mode or present any UI to do so.

When the
[`disablePictureInPicture`](#dom-htmlvideoelement-disablepictureinpicture) attribute is added to a `video` element, the
user agent MAY run these steps:

1. Reject any pending promises returned by the
 [`requestPictureInPicture()`](#dom-htmlvideoelement-requestpictureinpicture) method with
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror).

2. If `video` is
 [`pictureInPictureElement`](#dom-documentorshadowroot-pictureinpictureelement), run the [exit Picture-in-Picture
 algorithm](#exit-picture-in-picture-algorithm).

### 3.5. Interaction with Fullscreen

It is RECOMMENDED to run the [exit Picture-in-Picture
algorithm](#exit-picture-in-picture-algorithm) when the
[`pictureInPictureElement`](#dom-documentorshadowroot-pictureinpictureelement) [fullscreen
flag](https://fullscreen.spec.whatwg.org#fullscreen-flag) is set.

### 3.6. Interaction with Page Visibility

The Picture-in-Picture window visibility MUST NOT be taken into account
by the user agent to determine if the [system visibility
state](https://html.spec.whatwg.org/multipage/interaction.html#system-visibility-state) of a [traversable
navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#traversable-navigable) has changed.

### 3.7. One Picture-in-Picture window

Operating systems with a Picture-in-Picture API usually restrict
Picture-in-Picture mode to only one window. Whether only one window is
allowed in Picture-in-Picture mode will be left to the implementation
and the platform. However, because of the one Picture-in-Picture window
limitation, the specification assumes that a given
[`Document`](https://dom.spec.whatwg.org/#document) can only have one Picture-in-Picture window.

What happens when there is a Picture-in-Picture request while a window
is already in Picture-in-Picture will be left as an implementation
detail: the current Picture-in-Picture window could be closed, the
Picture-in-Picture request could be rejected or even two
Picture-in-Picture windows could be created. Regardless, the User Agent
will have to fire the appropriate events in order to notify the website
of the Picture-in-Picture status changes.

## 4. API

### 4.1. Extensions to `HTMLVideoElement`

```
partial interface HTMLVideoElement {
 [NewObject] Promise<PictureInPictureWindow> requestPictureInPicture();

 attribute EventHandler onenterpictureinpicture;
 attribute EventHandler onleavepictureinpicture;

 [CEReactions] attribute boolean disablePictureInPicture;
};
```

The
[`requestPictureInPicture()`](#dom-htmlvideoelement-requestpictureinpicture) method steps [request
Picture-in-Picture]:

1. If [Picture-in-Picture
 support](#picture-in-picture-support) is `false`, return [a promise rejected
 with](https://webidl.spec.whatwg.org/#a-promise-rejected-with)
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

2. Let `doc` be
 [this](https://webidl.spec.whatwg.org/#this)'s [node
 document](https://dom.spec.whatwg.org/#concept-node-document).

3. If `doc` is not [allowed to
 use](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#allowed-to-use) the [policy-controlled
 feature](https://w3c.github.io/webappsec-permissions-policy/#policy-controlled-feature) named `"picture-in-picture"`, return [a promise
 rejected
 with](https://webidl.spec.whatwg.org/#a-promise-rejected-with)
 [`NotAllowedError`](https://webidl.spec.whatwg.org/#notallowederror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

4. If [this](https://webidl.spec.whatwg.org/#this)'s
 [`readyState`](https://html.spec.whatwg.org/multipage/media.html#dom-media-readystate) attribute is
 [`HAVE_NOTHING`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_nothing), return [a promise rejected
 with](https://webidl.spec.whatwg.org/#a-promise-rejected-with)
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

5. If [this](https://webidl.spec.whatwg.org/#this) has no video track, return [a promise rejected
 with](https://webidl.spec.whatwg.org/#a-promise-rejected-with)
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

6. If [this](https://webidl.spec.whatwg.org/#this)'s
 [`disablePictureInPicture`](#dom-htmlvideoelement-disablepictureinpicture) is true, user agent may return [a promise rejected
 with](https://webidl.spec.whatwg.org/#a-promise-rejected-with)
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

7. If `doc`'s [Picture-in-Picture
 element](#picture-in-picture-element) is `null`:

 1. If [this](https://webidl.spec.whatwg.org/#this)'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global) does not have a [transient
 activation](https://html.spec.whatwg.org/multipage/interaction.html#transient-activation), then return [a promise rejected
 with](https://webidl.spec.whatwg.org/#a-promise-rejected-with)
 [`NotAllowedError`](https://webidl.spec.whatwg.org/#notallowederror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 2. [Consume user
 activation](https://html.spec.whatwg.org/multipage/interaction.html#consume-user-activation) given
 [this](https://webidl.spec.whatwg.org/#this)'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global).

8. If [this](https://webidl.spec.whatwg.org/#this) is `doc`'s [Picture-in-Picture
 element](#picture-in-picture-element):

 1. Return [a promise resolved
 with](https://webidl.spec.whatwg.org/#a-promise-resolved-with) the [Picture-in-Picture
 window](#picture-in-picture-window) associated with `doc`'s
 [Picture-in-Picture
 element](#picture-in-picture-element).

9. Let `global` be
 [this](https://webidl.spec.whatwg.org/#this)'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global).

10. Let `p` be [a new
 promise](https://webidl.spec.whatwg.org/#a-new-promise) created in
 [this](https://webidl.spec.whatwg.org/#this)'s [relevant
 realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm).

11. Return `p`, and [enqueue the following
 steps](https://html.spec.whatwg.org/multipage/infrastructure.html#enqueue-the-following-steps) to `doc`'s [picture-in-picture parallel
 queue](#picture-in-picture-parallel-queue):

 1. If [this](https://webidl.spec.whatwg.org/#this) is `doc`'s [Picture-in-Picture
 element](#picture-in-picture-element):

 1. [Queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task) on the [media element event task
 source](https://html.spec.whatwg.org/multipage/media.html#media-element-event-task-source) given `global` to
 [resolve](https://webidl.spec.whatwg.org/#resolve) `p` with the [Picture-in-Picture
 window](#picture-in-picture-window) associated with
 [this](https://webidl.spec.whatwg.org/#this).

 2. Abort these steps.

 2. Attempt to associate a [Picture-in-Picture
 window](#picture-in-picture-window) with
 [this](https://webidl.spec.whatwg.org/#this).

 3. If the previous step failed:

 1. [Queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task) on the [media element event task
 source](https://html.spec.whatwg.org/multipage/media.html#media-element-event-task-source) given `global` to
 [reject](https://webidl.spec.whatwg.org/#reject) `p` with
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 2. Abort these steps.

 4. Let `pipWindow` be a new instance of
 [`PictureInPictureWindow`](#pictureinpicturewindow) that represents
 [this](https://webidl.spec.whatwg.org/#this)'s associated [Picture-in-Picture
 window](#picture-in-picture-window).

 5. [Queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task) on the [media element event task
 source](https://html.spec.whatwg.org/multipage/media.html#media-element-event-task-source) given `global`, to perform the
 following steps:

 1. If
 [`pictureInPictureElement`](#dom-documentorshadowroot-pictureinpictureelement) is not `null`, run the [exit
 Picture-in-Picture
 algorithm](#exit-picture-in-picture-algorithm).

 2. Set `doc`'s [Picture-in-Picture
 element](#picture-in-picture-element) to
 [this](https://webidl.spec.whatwg.org/#this).

 3. [Append](https://infra.spec.whatwg.org/#list-append) [relevant settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object)'s
 [origin](https://dom.spec.whatwg.org/#concept-document-origin) to [initiators of active Picture-in-Picture
 sessions](#initiators-of-active-picture-in-picture-sessions).

 4. If
 [this](https://webidl.spec.whatwg.org/#this) is
 [fullscreenElement](https://fullscreen.spec.whatwg.org#dom-document-fullscreenelement), [exit
 fullscreen](https://fullscreen.spec.whatwg.org#fully-exit-fullscreen).

 5. [Fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire) named
 [`enterpictureinpicture`](#eventdef-htmlvideoelement-enterpictureinpicture) using
 [`PictureInPictureEvent`](#pictureinpictureevent) at
 [this](https://webidl.spec.whatwg.org/#this) with its
 [`bubbles`](https://dom.spec.whatwg.org/#dom-event-bubbles) attribute initialized to `true` and its
 [`pictureInPictureWindow`](#dom-pictureinpictureevent-pictureinpicturewindow) attribute initialized to
 [Picture-in-Picture
 window](#picture-in-picture-window).

 6. [Resolve](https://webidl.spec.whatwg.org/#resolve) `p` with `pipWindow`.

### 4.2. Extensions to `Document`

```
partial interface Document {
 readonly attribute boolean pictureInPictureEnabled;

 [NewObject] Promise<undefined> exitPictureInPicture();
};
```

The
[`pictureInPictureEnabled`](#dom-document-pictureinpictureenabled) attribute's getter must return `true` if
[Picture-in-Picture
support](#picture-in-picture-support) is `true` and
[this](https://webidl.spec.whatwg.org/#this) is [allowed to
use](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#allowed-to-use) the feature indicated by attribute name
`picture-in-picture`, and `false` otherwise.

[Picture-in-Picture support] is `false` if there's a user
preference that disables it or a platform limitation. It is `true`
otherwise.

The
[`exitPictureInPicture()`](#dom-document-exitpictureinpicture) method, when invoked, MUST return [a new
promise](https://webidl.spec.whatwg.org/#a-new-promise) `promise` and run the following steps [in
parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel):

1. Run the [exit Picture-in-Picture
 algorithm](#exit-picture-in-picture-algorithm).

2. If the previous step threw an exception, reject `promise`
 with that exception and abort these steps.

3. [Resolve](https://webidl.spec.whatwg.org/#resolve) `promise`.

### 4.3. Extension to `DocumentOrShadowRoot`

```
partial interface mixin DocumentOrShadowRoot {
 readonly attribute Element? pictureInPictureElement;
};
```

The
[`pictureInPictureElement`](#dom-documentorshadowroot-pictureinpictureelement) attribute's getter must run these steps:

1. If [this](https://webidl.spec.whatwg.org/#this) is a [shadow
 root](https://dom.spec.whatwg.org/#concept-shadow-root) and its
 [host](https://dom.spec.whatwg.org/#concept-documentfragment-host) is not
 [connected](https://dom.spec.whatwg.org/#connected), return `null` and abort these steps.

2. Let `candidate` be the result of
 [retargeting](https://dom.spec.whatwg.org/#retarget) [Picture-in-Picture
 element](#picture-in-picture-element) against
 [this](https://webidl.spec.whatwg.org/#this).

3. If `candidate` and
 [this](https://webidl.spec.whatwg.org/#this) are in the same
 [tree](https://dom.spec.whatwg.org/#concept-tree), return `candidate` and abort these
 steps.

4. Return `null`.

### 4.4. Interface `PictureInPictureWindow`

```
[Exposed=Window]
interface PictureInPictureWindow : EventTarget {
 readonly attribute long width;
 readonly attribute long height;

 attribute EventHandler onresize;
};
```

A
[`PictureInPictureWindow`](#pictureinpicturewindow) instance represents a [Picture-in-Picture
window](#picture-in-picture-window) associated with an
[`HTMLVideoElement`](https://html.spec.whatwg.org/multipage/media.html#htmlvideoelement). When instantiated, an instance of
[`PictureInPictureWindow`](#pictureinpicturewindow) has its `state` set to `opened`.

When the [close window algorithm] with an instance of
[`PictureInPictureWindow`](#pictureinpicturewindow) is invoked, its `state` is set to `closed`.

The
[`width`](#dom-pictureinpicturewindow-width) attribute MUST return the width in [CSS
pixels](https://drafts.csswg.org/css-values-4/#px) of the [Picture-in-Picture
window](#picture-in-picture-window) associated with
[`pictureInPictureElement`](#dom-documentorshadowroot-pictureinpictureelement) if the `state` is `opened`. Otherwise, it
MUST return 0.

The
[`height`](#dom-pictureinpicturewindow-height) attribute MUST return the height in [CSS
pixels](https://drafts.csswg.org/css-values-4/#px) of the [Picture-in-Picture
window](#picture-in-picture-window) associated with
[`pictureInPictureElement`](#dom-documentorshadowroot-pictureinpictureelement) if the `state` is `opened`. Otherwise, it
MUST return 0.

When the size of a [Picture-in-Picture
window](#picture-in-picture-window) `pipWindow` changes, the user agent MUST
[queue a
task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to [fire an
event](https://dom.spec.whatwg.org/#concept-event-fire) named
[`resize`](#eventdef-pictureinpicturewindow-resize) at `pipWindow`.

### 4.5. Event types

```
[Exposed=Window]
interface PictureInPictureEvent : Event {
 constructor(DOMString type, PictureInPictureEventInit eventInitDict);
 [SameObject] readonly attribute PictureInPictureWindow pictureInPictureWindow;
};

dictionary PictureInPictureEventInit : EventInit {
 required PictureInPictureWindow pictureInPictureWindow;
};
```

[`enterpictureinpicture`]

: Fired on a
 [`HTMLVideoElement`](https://html.spec.whatwg.org/multipage/media.html#htmlvideoelement) when it enters Picture-in-Picture.

[`leavepictureinpicture`]

: Fired on a
 [`HTMLVideoElement`](https://html.spec.whatwg.org/multipage/media.html#htmlvideoelement) when it leaves Picture-in-Picture mode.

[`resize`]

: Fired on a
 [`PictureInPictureWindow`](#pictureinpicturewindow) when it changes size.

### 4.6. Task source

The [task
source](https://html.spec.whatwg.org/multipage/webappapis.html#task-source) for all the tasks queued in this specification is the
[media element event task
source](https://html.spec.whatwg.org/multipage/media.html#media-element-event-task-source) of the video element in question.

### 4.7. CSS pseudo-class

The `:picture-in-picture`
[pseudo-class](https://drafts.csswg.org/selectors-4/#pseudo-class) MUST match the Picture-in-Picture element. It is
different from the
[`pictureInPictureElement`](#dom-documentorshadowroot-pictureinpictureelement) as it does NOT apply to the shadow host chain.

## 5. Security considerations

*This section is non-normative.*

To limit potential abuse through spoofing, the API applies only to
[`HTMLVideoElement`](https://html.spec.whatwg.org/multipage/media.html#htmlvideoelement). User interaction with the Picture-in-Picture window is
intentionally limited so that the only effect is on the
Picture-in-Picture window itself or the media being played.

### 5.1. Secure Context

The API is not limited to
[\[SECURE-CONTEXTS\]](#biblio-secure-contexts "Secure Contexts")
because it exposes a feature to web applications that user agents
usually offer natively on all media regardless of the [browsing
context](https://html.spec.whatwg.org/multipage/document-sequences.html#browsing-context).

### 5.2. Permissions Policy

This specification defines a [policy-controlled
feature](https://w3c.github.io/webappsec-permissions-policy/#policy-controlled-feature) named `"picture-in-picture"` that controls whether
[request
Picture-in-Picture](#request-picture-in-picture) returns a
[`SecurityError`](https://webidl.spec.whatwg.org/#securityerror) and whether
[`pictureInPictureEnabled`](#dom-document-pictureinpictureenabled) is `true` or `false`.

The [default
allowlist](https://w3c.github.io/webappsec-permissions-policy/#policy-controlled-feature-default-allowlist) for this feature is `*`.

## 6. Acknowledgments

Thanks to Jennifer Apacible, Zouhir Chahoud, Marcos Cáceres, Philip
Jägenstedt, Jeremy Jones, Chris Needham, Jer Noble, Justin Uberti, Yoav
Weiss, and Eckhart Wörner for their contributions to this document.
