const HEADER_CACHE_TTL_MS = 30_000;
const HEADER_CLEANUP_INTERVAL_MS = 10_000;

const headerCache = new Map();

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

browser.contextMenus.create({
  id: "download-with-mdm",
  title: "Download with Mac Download Manager",
  contexts: ["link"],
});

browser.contextMenus.onClicked.addListener((info) => {
  if (info.menuItemId !== "download-with-mdm") return;

  const url = info.linkUrl;
  if (!url) return;

  const filename = url.split("/").pop() || "";
  const referrer = info.pageUrl || "";
  const cached = headerCache.get(url);

  browser.runtime.sendNativeMessage("com.macdownloadmanager.app.safari-extension", {
    type: "download",
    url: url,
    filename: filename,
    referrer: referrer,
    headers: cached?.headers || null,
    fileSize: null,
  });
});

browser.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request.type === "interceptedDownload") {
    const cached = headerCache.get(request.url);
    browser.runtime.sendNativeMessage("com.macdownloadmanager.app.safari-extension", {
      type: "download",
      url: request.url,
      filename: request.filename || "",
      referrer: request.referrer || "",
      headers: cached?.headers || null,
      fileSize: null,
    });
    return;
  }

  if (request.type === "getStatus") {
    browser.runtime.sendNativeMessage(
      "com.macdownloadmanager.app.safari-extension",
      { type: "getStatus" },
      (response) => {
        sendResponse(response || { connected: false });
      }
    );
    return true;
  }
});
