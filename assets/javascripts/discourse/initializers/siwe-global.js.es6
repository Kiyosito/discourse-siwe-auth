import { withPluginApi } from "discourse/lib/plugin-api";
import Web3Modal from "../lib/web3modal";

export default {
  name: "siwe-global",
  initialize() {
    withPluginApi("0.8.31", (api) => {
      // Create global function for SIWE auth
      window.siweAuthButton = async function () {
        try {
          console.info("[SIWE] Starting authentication...");

          const siteSettings = api.container.lookup("site-settings:main");
          const env = {
            PROJECT_ID: siteSettings.siwe_project_id,
          };

          let provider = Web3Modal.create();
          await provider.providerInit(env);
          await provider.runSigningProcess(async (res) => {
            try {
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
        }
      };

      console.info("[SIWE] Global authentication function registered");
    });
  },
};
