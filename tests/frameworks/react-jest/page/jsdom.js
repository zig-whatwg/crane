'use strict';

// "Crane replaces jsdom" (the user, 2026-11-22): the `jsdom` package as a test sees it (server.mjs
// maps `^jsdom$` here with Jest's moduleNameMapper). A test that builds its own JSDOM wants a second
// document with a window of its own - ReactDOMFiber-test says so ("creating new JSDOM instance to get
// a second window as window.open is not implemented") - so it gets the browser's: a same-origin
// <iframe>, its document written from the given markup. jsdom runs no scripts unless runScripts is
// 'dangerously'; the frame is sandboxed without allow-scripts unless so. The frame hangs off the root
// element, outside head and body, which the tests empty and inspect.

class JSDOM {
  constructor(html = '', options = {}) {
    const frame = document.createElement('iframe');
    if (options.runScripts !== 'dangerously') frame.setAttribute('sandbox', 'allow-same-origin');
    document.documentElement.appendChild(frame);
    const doc = frame.contentDocument;
    doc.open();
    doc.write(String(html));
    doc.close();
    this.window = frame.contentWindow;
    this._frame = frame;
  }
  serialize() {
    const doc = this.window.document;
    const doctype = doc.doctype ? new XMLSerializer().serializeToString(doc.doctype) : '';
    return doctype + doc.documentElement.outerHTML;
  }
  getInternalVMContext() {
    throw new Error("jsdom's getInternalVMContext: a test's JSDOM is a browser frame");
  }
}

class VirtualConsole {
  sendTo() {
    return this;
  }
  forwardTo() {
    return this;
  }
  on() {
    return this;
  }
}

module.exports = {JSDOM, VirtualConsole};
