'use strict';

// "Crane replaces jsdom" (the user, 2026-11-22): the `jsdom` package as jest-environment-jsdom sees
// it, outside the test. Jest's environment builds its window with
//   new JSDOM('<!DOCTYPE html>', {pretendToBeVisual: true, runScripts: 'dangerously',
//                                 url: 'http://localhost/', virtualConsole, ...testEnvironmentOptions})
// (@jest/environment-jsdom-abstract 30.4.1). The browser page IS that document - served at that URL
// as exactly that markup, scripts running, frames requested - so the window it hands back is the
// page's own, and everything else the environment does (global.global, Error.stackTraceLimit,
// installCommonGlobals, Buffer, its error-event forwarding, jest-mock, the fake timers) runs as Jest
// wrote it. Options the page cannot be are refused rather than ignored.

const vm = require('vm');

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

class ResourceLoader {
  constructor() {
    throw new Error('jsdom ResourceLoader (testEnvironmentOptions.userAgent): the browser page has its own user agent');
  }
}

class JSDOM {
  constructor(html, options = {}) {
    if (html !== '<!DOCTYPE html>') {
      throw new Error(`The browser page is '<!DOCTYPE html>'; testEnvironmentOptions.html ${JSON.stringify(html)} cannot be`);
    }
    const unsupported = Object.keys(options).filter(k => !['pretendToBeVisual', 'resources', 'runScripts', 'url', 'virtualConsole', 'globalsCleanup', 'customExportConditions'].includes(k));
    if (unsupported.length > 0) throw new Error(`jsdom options the browser page cannot take: ${unsupported.join(', ')}`);
    if (options.url !== window.location.href) {
      throw new Error(`The browser page is at ${window.location.href}, not ${options.url}`);
    }
    if (options.runScripts !== 'dangerously' || options.pretendToBeVisual !== true) {
      throw new Error('The browser page runs scripts and is visual; jsdom options saying otherwise cannot apply');
    }
    this.window = window;
  }
  getInternalVMContext() {
    return vm.pageContext;
  }
}

module.exports = {JSDOM, VirtualConsole, ResourceLoader};
