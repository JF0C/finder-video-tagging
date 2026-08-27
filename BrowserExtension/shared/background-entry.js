import { BackgroundRouter } from "./background-router.js";

const extensionApi = globalThis.browser ?? globalThis.chrome;
const manifest = extensionApi.runtime.getManifest();

new BackgroundRouter({
  runtime: extensionApi.runtime,
  tabs: extensionApi.tabs,
  hostName: "com.findervideotagging.browser",
  browser: manifest.browser_specific_settings ? "firefox" : "chrome",
}).start();