import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "siwe-login-button",
  initialize() {
    withPluginApi("0.8.31", (api) => {
      // Fix login button on homepage
      api.onPageChange(() => {
        setTimeout(() => {
          const loginButtons = document.querySelectorAll(".login-button");
          if (loginButtons && loginButtons.length > 0) {
            loginButtons.forEach((btn) => {
              // Remove existing click handlers
              const newBtn = btn.cloneNode(true);
              btn.parentNode.replaceChild(newBtn, btn);

              // Add direct redirect to SIWE
              newBtn.addEventListener("click", (e) => {
                e.preventDefault();
                e.stopPropagation();
                window.location.href = "/discourse-siwe/auth";
              });

              console.info("[SIWE] Login button handler attached");
            });
          }
        }, 500);
      });
    });
  },
};
