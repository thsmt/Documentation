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
      panels.forEach((panel) => panel.classList.remove("active"));

      tab.setAttribute("aria-selected", "true");
      group.querySelector(`#${tab.getAttribute("aria-controls")}`).classList.add("active");
    });
  });
});
