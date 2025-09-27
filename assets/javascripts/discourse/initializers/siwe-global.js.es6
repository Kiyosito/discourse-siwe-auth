import { withPluginApi } from "discourse/lib/plugin-api";
import Web3Modal from "../lib/web3modal";

export default {
  name: "siwe-global",
  initialize() {
    withPluginApi("0.8.31", (api) => {
      // Handle SIWE auth
      const startAuth = async function () {
        try {
          console.info("[SIWE] Starting authentication...");

          const siteSettings = api.container.lookup("site-settings:main");
          const env = {
            PROJECT_ID: siteSettings.siwe_project_id,
          };

          console.info("[SIWE] Project ID:", env.PROJECT_ID);

          if (!env.PROJECT_ID) {
            console.error(
              "[SIWE] No PROJECT_ID found! Please configure siwe_project_id in Admin > Settings > Plugins"
            );
            alert(
              "SIWE Project ID not configured. Please contact administrator."
            );
            return;
          }

          console.info("[SIWE] Creating Web3Modal provider...");
          let provider = Web3Modal.create();

          console.info("[SIWE] Initializing provider...");
          await provider.providerInit(env);

          console.info("[SIWE] Starting signing process...");
          await provider.runSigningProcess(async (res) => {
            try {
              console.info(
                "[SIWE] Signing process completed, processing result..."
              );
              const [account, message, signature, avatar] = res;

              // Fill form and submit
              document.getElementById("eth_account").value = account;
              document.getElementById("eth_message").value = message;
              document.getElementById("eth_signature").value = signature;
              document.getElementById("eth_avatar").value = avatar;
              document.getElementById("siwe-sign").submit();
            } catch (e) {
              console.error("[SIWE] Error in signing process:", e);
            }
          });
        } catch (e) {
          console.error("[SIWE] Error initializing auth:", e);
          alert("Authentication failed: " + e.message);
        }
      };

      // Attach click handler to button when route changes
      api.onPageChange(() => {
        setTimeout(() => {
          const button = document.getElementById("siwe-auth-button");
          if (button) {
            // Remove existing listeners by cloning
            const newButton = button.cloneNode(true);
            button.parentNode.replaceChild(newButton, button);

            // Add new event listener
            newButton.addEventListener("click", startAuth);
            console.info("[SIWE] Auth button handler attached");

            // Auto-start auth if URL has ?auto=true
            if (window.location.search.includes("auto=true")) {
              console.info("[SIWE] Auto-starting authentication");
              startAuth();
            }
          }
        }, 500);
      });

      console.info("[SIWE] Auth handler registered");
    });
  },
};
