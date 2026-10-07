import Foundation

/// JavaScript the agent runs inside a page. It runs in an isolated content
/// world, so the page's own scripts cannot see or tamper with it.
enum PageScripts {
    /// Returns a JSON string describing the page: url, title, a slice of the
    /// visible text, and a numbered list of things the agent can act on.
    static let snapshot = """
    const visible = (el) => {
      const r = el.getBoundingClientRect();
      if (r.width < 2 || r.height < 2) return false;
      const s = getComputedStyle(el);
      return s.visibility !== 'hidden' && s.display !== 'none' && s.opacity !== '0';
    };
    const sel = 'a[href],button,input,textarea,select,[role=button],[role=link],[role=textbox],' +
                '[role=checkbox],[role=menuitem],[role=tab],[role=option],[contenteditable=true],summary';
    const clean = (t) => (t || '').replace(/\\s+/g, ' ').trim().slice(0, 90);
    const els = [];
    const items = [];
    for (const el of document.querySelectorAll(sel)) {
      if (els.length >= maxItems) break;
      if (el.disabled || el.type === 'hidden' || !visible(el)) continue;
      const label = clean(el.getAttribute('aria-label') || el.innerText || el.value ||
                          el.placeholder || el.title || el.alt || el.name);
      if (!label && el.tagName === 'A') continue;
      const item = { id: els.length, tag: el.tagName.toLowerCase(), label };
      if (el.type) item.type = el.type;
      if (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA') item.value = clean(el.value);
      const r = el.getBoundingClientRect();
      item.onScreen = r.bottom > 0 && r.top < innerHeight;
      els.push(el);
      items.push(item);
    }
    window.__agentEls = els;
    return JSON.stringify({
      url: location.href,
      title: document.title,
      text: clean(document.body ? document.body.innerText : '').length
        ? document.body.innerText.replace(/\\s+/g, ' ').trim().slice(0, maxText) : '',
      scrollY: Math.round(scrollY),
      pageHeight: document.documentElement.scrollHeight,
      items
    });
    """

    static let click = """
    const el = (window.__agentEls || [])[id];
    if (!el || !el.isConnected) return 'missing';
    el.scrollIntoView({ block: 'center' });
    el.click();
    return 'ok';
    """

    /// Types into a field in a way that frameworks like React notice.
    static let type = """
    const el = (window.__agentEls || [])[id];
    if (!el || !el.isConnected) return 'missing';
    el.scrollIntoView({ block: 'center' });
    el.focus();
    if (el.isContentEditable) {
      document.execCommand('selectAll', false, null);
      document.execCommand('insertText', false, text);
    } else {
      const proto = el instanceof HTMLTextAreaElement ? HTMLTextAreaElement.prototype
                  : el instanceof HTMLSelectElement ? HTMLSelectElement.prototype
                  : HTMLInputElement.prototype;
      const setter = Object.getOwnPropertyDescriptor(proto, 'value').set;
      setter.call(el, text);
      el.dispatchEvent(new Event('input', { bubbles: true }));
      el.dispatchEvent(new Event('change', { bubbles: true }));
    }
    if (submit) {
      const opts = { key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true, cancelable: true };
      const go = el.dispatchEvent(new KeyboardEvent('keydown', opts));
      el.dispatchEvent(new KeyboardEvent('keyup', opts));
      if (go && el.form) el.form.requestSubmit ? el.form.requestSubmit() : el.form.submit();
    }
    return 'ok';
    """

    static let scroll = """
    window.scrollBy({ top: (down ? 1 : -1) * innerHeight * 0.8 });
    return 'ok';
    """

    /// The label of an element, read fresh, used for the safety check.
    static let label = """
    const el = (window.__agentEls || [])[id];
    if (!el) return '';
    return (el.getAttribute('aria-label') || el.innerText || el.value || '').replace(/\\s+/g, ' ').trim().slice(0, 120);
    """
}
