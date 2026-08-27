const DEFAULT_DELAYS = [250, 500, 1_000, 2_000, 4_000, 8_000, 15_000];

export class BackgroundRouter {
  #runtime;
  #tabs;
  #hostName;
  #browser;
  #schedule;
  #delays;
  #port;
  #reconnectAttempt = 0;
  #reconnectPending = false;
  #connectionId;

  constructor({ runtime, tabs, hostName, browser, schedule = setTimeout, reconnectDelays = DEFAULT_DELAYS }) {
    this.#runtime = runtime;
    this.#tabs = tabs;
    this.#hostName = hostName;
    this.#browser = browser;
    this.#schedule = schedule;
    this.#delays = reconnectDelays;
  }

  start() {
    this.#runtime.onMessage.addListener((message, sender) => this.#fromContent(message, sender));
    this.#connect();
  }

  #connect() {
    this.#reconnectPending = false;
    try {
      const port = this.#runtime.connectNative(this.#hostName);
      this.#port = port;
      this.#connectionId = globalThis.crypto.randomUUID();
      port.onMessage.addListener((message) => this.#fromNative(message));
      port.onDisconnect.addListener(() => this.#disconnected(port));
      port.postMessage({
        version: 1,
        type: "connected",
        browser: this.#browser,
        connectionId: this.#connectionId,
      });
    } catch {
      this.#scheduleReconnect();
    }
  }

  #disconnected(port) {
    if (this.#port !== port) return;
    this.#port = undefined;
    this.#scheduleReconnect();
  }

  #scheduleReconnect() {
    if (this.#reconnectPending) return;
    const delay = this.#delays[Math.min(this.#reconnectAttempt, this.#delays.length - 1)];
    this.#reconnectAttempt += 1;
    this.#reconnectPending = true;
    this.#schedule(() => this.#connect(), delay);
  }

  #fromContent(message, sender) {
    if (message?.type !== "media-state" || !this.#port || sender.tab?.id == null) return;
    this.#port.postMessage({
      ...message,
      version: 1,
      browser: this.#browser,
      connectionId: this.#connectionId,
      tabId: sender.tab.id,
      frameId: sender.frameId ?? 0,
    });
  }

  async #fromNative(message) {
    if (message?.version === 1 && message?.type === "connected-result") {
      this.#reconnectAttempt = 0;
      return;
    }
    if (message?.version !== 1 || message?.type !== "resume-media") return;
    if (message.browser !== this.#browser || message.connectionId !== this.#connectionId) {
      this.#port?.postMessage(this.#routingResult(message, "session-not-found"));
      return;
    }

    try {
      const result = await this.#tabs.sendMessage(message.tabId, message, { frameId: message.frameId });
      this.#port?.postMessage({
        ...result,
        browser: this.#browser,
        connectionId: this.#connectionId,
        tabId: message.tabId,
        frameId: message.frameId,
      });
    } catch {
      this.#port?.postMessage(this.#routingResult(message, "session-not-found"));
    }
  }

  #routingResult(message, status) {
    return {
      version: 1,
      type: "resume-result",
      browser: this.#browser,
      connectionId: this.#connectionId,
      tabId: message.tabId,
      frameId: message.frameId,
      documentId: message.documentId,
      sessionId: message.sessionId,
      status,
    };
  }
}