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

const ensureWindowsUpgradePageLink = () => {
  const sidebar = document.querySelector("#site-sidebar");
  if (!sidebar) return;

  const targetFile = "windows-server-2016-2025-inplace-upgrade.html";
  const currentPath = window.location.pathname;
  const existingLink = sidebar.querySelector(`a[href$="${targetFile}"]`);

  if (existingLink) {
    existingLink.classList.toggle("active", currentPath.endsWith(`/${targetFile}`));
    return;
  }

  const windows2025Link = sidebar.querySelector('a[href$="windows-server-2025.html"]');
  if (!windows2025Link) return;

  const link = document.createElement("a");
  link.href = windows2025Link.getAttribute("href").replace("windows-server-2025.html", targetFile);
  link.textContent = "[移行] Windows Server 2016 → 2025";
  link.classList.toggle("active", currentPath.endsWith(`/${targetFile}`));
  windows2025Link.insertAdjacentElement("afterend", link);
};

ensureWindowsUpgradePageLink();

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