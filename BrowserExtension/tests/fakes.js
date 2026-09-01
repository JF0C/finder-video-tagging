export class FakeMedia {
  constructor({ paused = true, ended = false, currentTime = 0, playError, seekError } = {}) {
    this.paused = paused;
    this.ended = ended;
    this._currentTime = currentTime;
    this.isConnected = true;
    this.playError = playError;
    this.seekError = seekError;
    this.listeners = new Map();
  }

  get currentTime() {
    return this._currentTime;
  }

  set currentTime(value) {
    if (this.seekError) throw this.seekError;
    this._currentTime = value;
  }

  matches(selector) {
    return selector === "audio,video";
  }

  querySelectorAll() {
    return [];
  }

  addEventListener(name, listener) {
    this.listeners.set(name, listener);
  }

  removeEventListener(name) {
    this.listeners.delete(name);
  }

  emit(type) {
    this.listeners.get(type)?.({ type });
  }

  async play() {
    if (this.playError) throw this.playError;
    this.paused = false;
  }
}

export class FakeRoot {
  constructor(media = []) {
    this.media = media;
    this.documentElement = this;
  }

  matches() {
    return false;
  }

  querySelectorAll() {
    return this.media;
  }
}

export function observerHarness() {
  let callback;
  return {
    createObserver: (next) => {
      callback = next;
      return { observe() {}, disconnect() {} };
    },
    mutate: (record) => callback([record]),
  };
}

export function eventHook() {
  const listeners = [];
  return {
    addListener: (listener) => listeners.push(listener),
    emit: (...arguments_) => listeners.map((listener) => listener(...arguments_)),
  };
}

export function fakePort() {
  return {
    onMessage: eventHook(),
    onDisconnect: eventHook(),
    messages: [],
    postMessage(message) {
      this.messages.push(message);
    },
  };
}