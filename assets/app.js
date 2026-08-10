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
  sidebarToggle.setAttribute("title", isOpen ? "ページ一覧を閉じる" : "ページ一覧を開く");
  sidebarToggle.setAttribute("aria-label", isOpen ? "ページ一覧を閉じる" : "ページ一覧を開く");
};

sidebarToggle?.addEventListener("click", () => {
  document.body.classList.toggle("sidebar-collapsed");

  syncSidebarToggle();
});

syncSidebarToggle();

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

if (document.body.dataset.userValueHighlighting !== "off") {
  highlightUserValues();
}

document.querySelectorAll(".copy").forEach((button) => {
  button.addEventListener("click", async () => {
    const code = button.closest(".code").querySelector("code").innerText;
    await navigator.clipboard.writeText(code);
    button.innerText = "Copied";
    setTimeout(() => {
      button.innerText = "Copy";
    }, 1400);
  });
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
