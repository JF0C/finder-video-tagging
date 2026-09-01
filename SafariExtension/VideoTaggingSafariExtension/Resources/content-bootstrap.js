const extensionApi = globalThis.browser ?? globalThis.chrome;
void import(extensionApi.runtime.getURL("content-entry.js"));