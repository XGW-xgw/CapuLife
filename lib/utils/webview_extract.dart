/// Hook `document.title` so the WebView extraction protocol also reaches the
/// native bridge on WebViews whose title-change callback is unreliable.
const String titleBridgeHook = r"""
(function(){
  try {
    if (window.__capTitleHook || !window.CapBridge) return;
    window.__capTitleHook = true;
    var descriptor = Object.getOwnPropertyDescriptor(Document.prototype, 'title');
    if (!descriptor || !descriptor.set) return;
    Object.defineProperty(document, 'title', {
      configurable: true,
      get: descriptor.get,
      set: function(value) {
        descriptor.set.call(this, value);
        try { window.CapBridge.postMessage(String(value)); } catch (e) {}
      }
    });
  } catch (e) {}
})();
""";