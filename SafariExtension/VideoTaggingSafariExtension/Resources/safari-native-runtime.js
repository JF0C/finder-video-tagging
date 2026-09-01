const POLL_DELAY = 250;

class ListenerSet {
  #listeners = new Set();

  addListener(listener) {
    this.#listeners.add(listener);
  }

  emit(value) {
    for (const listener of this.#listeners) listener(value);
  }
}

class SafariNativePort {
  #runtime;
  #hostName;
  #active = true;
  #timer;
  onMessage = new ListenerSet();
  onDisconnect = new ListenerSet();

  constructor(runtime, hostName) {
    this.#runtime = runtime;
    this.#hostName = hostName;
  }

  start() {
    this.#poll();
    return this;
  }

  postMessage(message) {
    this.#call({ kind: "send", message }).catch(() => this.#disconnect());
  }

  async #poll() {
    if (!this.#active) return;
    try {
      const response = await this.#call({ kind: "receive" });
      if (response?.message) this.onMessage.emit(response.message);
      this.#timer = setTimeout(() => this.#poll(), POLL_DELAY);
    } catch {
      this.#disconnect();
    }
  }

  async #call(envelope) {
    const response = await this.#runtime.sendNativeMessage(this.#hostName, envelope);
    if (response?.error) throw new Error(response.error);
    return response;
  }

  #disconnect() {
    if (!this.#active) return;
    this.#active = false;
    clearTimeout(this.#timer);
    this.onDisconnect.emit();
  }
}

export function createSafariNativeRuntime(runtime) {
  return {
    onMessage: runtime.onMessage,
    connectNative: (hostName) => new SafariNativePort(runtime, hostName).start(),
  };
}