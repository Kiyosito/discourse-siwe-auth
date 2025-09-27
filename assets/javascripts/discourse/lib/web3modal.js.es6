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

      // Fill form with correct parameter names for OmniAuth
      const form = document.getElementById("siwe-sign");

      // Get CSRF token from meta tag or cookie
      const csrfToken =
        document
          .querySelector('meta[name="csrf-token"]')
          ?.getAttribute("content") ||
        document.cookie
          .split("; ")
          .find((row) => row.startsWith("csrf_token="))
          ?.split("=")[1];

      if (csrfToken) {
        let csrfInput = document.getElementById("csrf_token");
        if (!csrfInput) {
          csrfInput = document.createElement("input");
          csrfInput.type = "hidden";
          csrfInput.name = "authenticity_token";
          csrfInput.id = "csrf_token";
          form.appendChild(csrfInput);
        }
        csrfInput.value = csrfToken;
        console.info("[SIWE] CSRF token added to form");
      } else {
        console.warn("[SIWE] No CSRF token found");
      }

      // Create hidden inputs with the correct parameter names
      let accountInput = document.getElementById("eth_account");
      let messageInput = document.getElementById("eth_message");
      let signatureInput = document.getElementById("eth_signature");

      if (!accountInput) {
        accountInput = document.createElement("input");
        accountInput.type = "hidden";
        accountInput.name = "address";
        accountInput.id = "eth_account";
        form.appendChild(accountInput);
      }
      accountInput.value = address;

      if (!messageInput) {
        messageInput = document.createElement("input");
        messageInput.type = "hidden";
        messageInput.name = "message";
        messageInput.id = "eth_message";
        form.appendChild(messageInput);
      }
      messageInput.value = result[1]; // message

      if (!signatureInput) {
        signatureInput = document.createElement("input");
        signatureInput.type = "hidden";
        signatureInput.name = "signature";
        signatureInput.id = "eth_signature";
        form.appendChild(signatureInput);
      }
      signatureInput.value = result[2]; // signature

      console.info("[SIWE] Form filled, submitting...");
      form.submit();
    } catch (e) {
      console.error("[SIWE] Wallet connection failed:", e);
      throw e;
    }
  },
});

export default Web3Modal;
