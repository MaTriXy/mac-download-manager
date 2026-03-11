const NATIVE_HOST = "com.macdownloadmanager.helper";

const DEFAULT_FILE_TYPES = [
  "zip", "dmg", "iso", "pkg", "tar.gz", "7z", "rar",
  "mp4", "mkv", "avi", "mov", "mp3", "flac",
  "exe", "msi", "deb", "AppImage"
];

const DEFAULT_SETTINGS = {
  enabled: true,
  fileTypes: DEFAULT_FILE_TYPES,
  minSizeMB: 5
};

const HEADER_CACHE_TTL_MS = 30_000;
const HEADER_CLEANUP_INTERVAL_MS = 10_000;

const headerCache = new Map();
let nativePort = null;
let nativeConnected = false;

function cacheHeaders(details) {
  const headers = {};
  for (const header of details.requestHeaders || []) {
    const name = header.name.toLowerCase();
    if (["cookie", "authorization", "referer", "user-agent"].includes(name)) {
      headers[name] = header.value;
    }
  }
  headerCache.set(details.url, { headers, timestamp: Date.now() });
}

function cleanHeaderCache() {
  const cutoff = Date.now() - HEADER_CACHE_TTL_MS;
  for (const [url, entry] of headerCache) {
    if (entry.timestamp < cutoff) {
      headerCache.delete(url);
    }
  }
}

setInterval(cleanHeaderCache, HEADER_CLEANUP_INTERVAL_MS);

browser.webRequest.onSendHeaders.addListener(
  cacheHeaders,
  { urls: ["<all_urls>"] },
  ["requestHeaders"]
);

function getExtension(filename) {
  if (!filename) return "";
  if (filename.endsWith(".tar.gz")) return "tar.gz";
  const dot = filename.lastIndexOf(".");
  return dot >= 0 ? filename.slice(dot + 1).toLowerCase() : "";
}

function shouldIntercept(settings, filename, fileSize) {
  const ext = getExtension(filename);
  const typeMatch = ext && settings.fileTypes.some(t => t.toLowerCase() === ext);
  const sizeMatch = fileSize && fileSize >= settings.minSizeMB * 1024 * 1024;
  return typeMatch || sizeMatch;
}

browser.downloads.onCreated.addListener((downloadItem) => {
  browser.storage.sync.get(DEFAULT_SETTINGS).then((settings) => {
    if (!settings.enabled || !nativeConnected) {
      return;
    }

    const filename = downloadItem.filename || downloadItem.url.split("/").pop() || "";

    if (!shouldIntercept(settings, filename, downloadItem.fileSize)) {
      return;
    }

    browser.downloads.cancel(downloadItem.id).then(() => {
      browser.downloads.erase({ id: downloadItem.id });
    });

    const cached = headerCache.get(downloadItem.url);
    const message = {
      url: downloadItem.url,
      headers: cached?.headers || null,
      filename,
      fileSize: downloadItem.fileSize > 0 ? downloadItem.fileSize : null,
      referrer: downloadItem.referrer || cached?.headers?.referer || null
    };

    sendNativeMessage(message);
  });
});

function connectNative() {
  try {
    nativePort = browser.runtime.connectNative(NATIVE_HOST);
    nativeConnected = true;
    updateBadge();

    nativePort.onMessage.addListener((response) => {
      if (response.activeCount !== undefined) {
        browser.action.setBadgeText({
          text: response.activeCount > 0 ? String(response.activeCount) : ""
        });
      }
    });

    nativePort.onDisconnect.addListener(() => {
      nativeConnected = false;
      nativePort = null;
      updateBadge();
      setTimeout(connectNative, 5000);
    });
  } catch {
    nativeConnected = false;
    nativePort = null;
    updateBadge();
    setTimeout(connectNative, 5000);
  }
}

function sendNativeMessage(message) {
  if (nativePort && nativeConnected) {
    nativePort.postMessage(message);
  }
}

function updateBadge() {
  if (nativeConnected) {
    browser.action.setBadgeText({ text: "" });
    browser.action.setBadgeBackgroundColor({ color: "#4CAF50" });
  } else {
    browser.action.setBadgeText({ text: "!" });
    browser.action.setBadgeBackgroundColor({ color: "#F44336" });
  }
}

browser.runtime.onMessage.addListener((request, _sender, sendResponse) => {
  if (request.type === "getStatus") {
    sendResponse({ connected: nativeConnected });
  }
  return false;
});

connectNative();
