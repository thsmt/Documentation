const themeToggle = document.querySelector(".theme-toggle");
const savedTheme = localStorage.getItem("knowledge-theme");
const preferredTheme = window.matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark";

const applyTheme = (theme) => {
  document.documentElement.dataset.theme = theme;

  if (!themeToggle) return;

  themeToggle.textContent = theme === "dark" ? "☀" : "☾";
  themeToggle.setAttribute("aria-label", theme === "dark" ? "ライトモードに切り替え" : "ダークモードに切り替え");
  themeToggle.setAttribute("title", theme === "dark" ? "ライトモードに切り替え" : "ダークモードに切り替え");
};

applyTheme(savedTheme || preferredTheme);

themeToggle?.addEventListener("click", () => {
  const currentTheme = document.documentElement.dataset.theme || "dark";
  const nextTheme = currentTheme === "dark" ? "light" : "dark";

  localStorage.setItem("knowledge-theme", nextTheme);
  applyTheme(nextTheme);
});

const sidebarToggle = document.querySelector(".sidebar-toggle");

const syncSidebarToggle = () => {
  if (!sidebarToggle) return;

  const isOpen = !document.body.classList.contains("sidebar-collapsed");

  sidebarToggle.setAttribute("aria-expanded", String(isOpen));
  sidebarToggle.setAttribute("title", isOpen ? "ナビゲーションを閉じる" : "ナビゲーションを開く");
  sidebarToggle.setAttribute("aria-label", isOpen ? "ナビゲーションを閉じる" : "ナビゲーションを開く");
};

sidebarToggle?.addEventListener("click", () => {
  document.body.classList.toggle("sidebar-collapsed");

  syncSidebarToggle();
});

syncSidebarToggle();

const removePageToc = () => {
  document.querySelector(".toc")?.remove();
  document.querySelector(".sidebar-page-menu")?.remove();
};

removePageToc();

const enhancePageSummaries = () => {
  document.querySelectorAll("main.content > p.lead").forEach((lead) => {
    const summary = document.createElement("div");
    const label = document.createElement("strong");

    summary.className = "page-summary";
    label.textContent = "⚡ このページの要約";
    lead.before(summary);
    summary.append(label, lead);
  });
};

enhancePageSummaries();

const pageUserValues = (document.body.dataset.userValues || "")
  .split(",")
  .map((value) => value.trim())
  .filter(Boolean)
  .sort((left, right) => right.length - left.length);

const escapeRegExp = (value) => value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

const userValuePatterns = [
  { pattern: /<[A-Z][A-Z0-9_:-]*>/g, group: 0 },
  { pattern: /\{[A-Z][A-Z0-9_:-]*\}/g, group: 0 },
  { pattern: /[:/]role\/([A-Za-z0-9+=,.@_-]+)/g, group: 1 },
  ...pageUserValues.map((value) => ({ pattern: new RegExp(escapeRegExp(value), "g"), group: 0 })),
];

const collectUserValueRanges = (text) => {
  const ranges = [];

  userValuePatterns.forEach(({ pattern, group }) => {
    pattern.lastIndex = 0;
    let match;

    while ((match = pattern.exec(text))) {
      const value = match[group];
      const offset = group === 0 ? 0 : match[0].lastIndexOf(value);
      const start = match.index + offset;
      const end = start + value.length;
      const overlaps = ranges.some((range) => start < range.end && end > range.start);

      if (!overlaps) ranges.push({ start, end });
    }
  });

  return ranges.sort((left, right) => left.start - right.start);
};

const highlightUserValues = () => {
  document.querySelectorAll("main").forEach((root) => {
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
    const textNodes = [];
    let textNode;

    while ((textNode = walker.nextNode())) {
      if (!textNode.parentElement?.closest("script, style, .user-value") && collectUserValueRanges(textNode.nodeValue).length > 0) {
        textNodes.push(textNode);
      }
    }

    textNodes.forEach((node) => {
      const fragment = document.createDocumentFragment();
      const ranges = collectUserValueRanges(node.nodeValue);
      let cursor = 0;

      ranges.forEach(({ start, end }) => {
        if (start > cursor) fragment.append(document.createTextNode(node.nodeValue.slice(cursor, start)));

        const value = document.createElement("span");
        value.className = "user-value";
        value.textContent = node.nodeValue.slice(start, end);
        fragment.append(value);
        cursor = end;
      });

      if (cursor < node.nodeValue.length) fragment.append(document.createTextNode(node.nodeValue.slice(cursor)));

      node.replaceWith(fragment);
    });
  });
};

const addCodeLineNumbers = () => {
  document.querySelectorAll("main.content .code pre code").forEach((code) => {
    if (code.classList.contains("line-numbered")) return;

    const text = code.textContent.replace(/\r\n?/g, "\n");
    const prompt = code.closest(".code")?.dataset.prompt || "";
    code.dataset.copyText = text;
    code.textContent = "";
    code.classList.add("line-numbered");

    text.split("\n").forEach((line) => {
      const row = document.createElement("span");
      row.className = "code-line";
      if (prompt) {
        row.classList.add("prompted");
        row.dataset.prompt = line && !line.trimStart().startsWith("#") ? prompt : "";
      }
      row.textContent = line || "\u200b";
      code.append(row);
    });
  });
};

addCodeLineNumbers();

if (document.body.dataset.userValueHighlighting !== "off") {
  highlightUserValues();
}

const copyWithLegacyApi = (text) => {
  const textarea = document.createElement("textarea");
  const activeElement = document.activeElement;
  const selection = document.getSelection();
  const ranges = selection
    ? Array.from({ length: selection.rangeCount }, (_, index) => selection.getRangeAt(index))
    : [];

  textarea.value = text;
  textarea.setAttribute("readonly", "");
  textarea.style.position = "fixed";
  textarea.style.top = "0";
  textarea.style.left = "-9999px";
  textarea.style.opacity = "0";
  textarea.style.pointerEvents = "none";
  document.body.append(textarea);
  textarea.focus();
  textarea.select();
  textarea.setSelectionRange(0, textarea.value.length);

  let copied = false;
  try {
    copied = document.execCommand("copy");
  } finally {
    textarea.remove();
    if (selection) {
      selection.removeAllRanges();
      ranges.forEach((range) => selection.addRange(range));
    }
    if (activeElement instanceof HTMLElement) {
      activeElement.focus({ preventScroll: true });
    }
  }

  return copied;
};

const writeClipboardText = async (text) => {
  if (navigator.clipboard && typeof navigator.clipboard.writeText === "function") {
    try {
      await navigator.clipboard.writeText(text);
      return;
    } catch (error) {
      console.warn("Clipboard API failed; trying the compatibility fallback", error);
    }
  }

  if (!copyWithLegacyApi(text)) {
    throw new Error("No clipboard method succeeded");
  }
};

document.addEventListener("click", async (event) => {
  const button = event.target instanceof Element ? event.target.closest(".copy") : null;
  if (!button || button.disabled) return;

  const code = button.closest(".code")?.querySelector("pre code");
  const originalLabel = button.dataset.copyLabel || button.textContent.trim() || "Copy";
  button.dataset.copyLabel = originalLabel;
  button.setAttribute("aria-live", "polite");
  button.disabled = true;

  try {
    if (!code) throw new Error("Copy button is not associated with a code block");
    const copyText = code.dataset.copyText || code.textContent.replace(/\r\n?/g, "\n");
    await writeClipboardText(copyText);
    button.textContent = "Copied";
  } catch (error) {
    console.error("Code copy failed", error);
    button.textContent = "Copy failed";
  }

  setTimeout(() => {
    button.textContent = originalLabel;
    button.disabled = false;
  }, 1400);
});

document.querySelectorAll("[data-tabs]").forEach((group) => {
  const tabs = group.querySelectorAll("[role='tab']");
  const panels = group.querySelectorAll("[role='tabpanel']");

  tabs.forEach((tab) => {
    tab.addEventListener("click", () => {
      tabs.forEach((item) => item.setAttribute("aria-selected", "false"));
      panels.forEach((panel) => {
        panel.classList.remove("active");
        panel.hidden = true;
      });

      tab.setAttribute("aria-selected", "true");
      const activePanel = group.querySelector(`#${tab.getAttribute("aria-controls")}`);
      activePanel.classList.add("active");
      activePanel.hidden = false;
    });
  });
});
