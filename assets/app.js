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
