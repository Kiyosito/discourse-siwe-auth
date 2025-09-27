import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

const Web3Modal = EmberObject.extend({
  async providerInit(env) {
    console.info("[SIWE] Initializing simple wallet provider...");

    // Check if wallet is available
    if (!window.ethereum) {
      throw new Error(
        "No wallet provider found. Please install MetaMask or similar wallet."
      );
    }

    console.info("[SIWE] Wallet provider found:", window.ethereum);
    return window.ethereum;
  },

  async signMessage(account) {
    let address = account.address;

    // Get message from server
    const { message } = await ajax("/discourse-siwe/message", {
      data: {
        eth_account: address,
        chain_id: account.chainId || 1,
      },
    }).catch(popupAjaxError);

    // Sign message with wallet
    const signature = await window.ethereum.request({
      method: "personal_sign",
      params: [message, address],
    });

    return [address, message, signature, null];
  },

  async runSigningProcess(cb) {
    try {
      // Request account access
      const accounts = await window.ethereum.request({
        method: "eth_requestAccounts",
      });

      if (accounts.length === 0) {
        throw new Error("No accounts found");
      }

      const address = accounts[0];
      const chainId = await window.ethereum.request({ method: "eth_chainId" });

      console.info("[SIWE] Connected to wallet:", address);

      // Sign message
      const result = await this.signMessage({
        address: address,
        chainId: parseInt(chainId, 16),
      });

      cb(result);
    } catch (e) {
      console.error("[SIWE] Wallet connection failed:", e);
      throw e;
    }
  },
});

export default Web3Modal;
