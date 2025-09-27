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

    // Store nonce from message for later validation (case-insensitive)
    const nonceMatch = message.match(/nonce:\s*([a-zA-Z0-9]+)/i);
    if (nonceMatch) {
      const nonce = nonceMatch[1];
      sessionStorage.setItem("siwe_nonce", nonce);
      console.info("[SIWE] Stored nonce:", nonce);
    } else {
      console.warn("[SIWE] Could not extract nonce from message");
    }

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

      console.info(
        "[SIWE] About to fill form with result:",
        result.length,
        "items"
      );

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

      console.info("[SIWE] CSRF token found:", csrfToken ? "YES" : "NO");
      console.info("[SIWE] CSRF token value:", csrfToken);

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
        console.info(
          "[SIWE] CSRF token added to form:",
          csrfToken.substring(0, 10) + "..."
        );
      } else {
        console.warn("[SIWE] No CSRF token found - checking alternatives...");

        // Try alternative methods to get CSRF token
        const csrfMeta = document.querySelector('meta[name="csrf-token"]');
        const csrfCookie = document.cookie
          .split("; ")
          .find((row) => row.startsWith("csrf_token="));

        console.info("[SIWE] CSRF meta tag:", csrfMeta);
        console.info("[SIWE] CSRF cookie:", csrfCookie);

        // Try to get from Rails CSRF token endpoint
        console.warn("[SIWE] Attempting to get CSRF token from /session/csrf");
        try {
          const response = await fetch("/session/csrf.json");
          const data = await response.json();
          if (data.csrf) {
            const fallbackToken = data.csrf;
            let csrfInput = document.getElementById("csrf_token");
            if (!csrfInput) {
              csrfInput = document.createElement("input");
              csrfInput.type = "hidden";
              csrfInput.name = "authenticity_token";
              csrfInput.id = "csrf_token";
              form.appendChild(csrfInput);
            }
            csrfInput.value = fallbackToken;
            console.info(
              "[SIWE] CSRF token obtained from endpoint:",
              fallbackToken.substring(0, 10) + "..."
            );
          }
        } catch (e) {
          console.error("[SIWE] Failed to get CSRF token from endpoint:", e);
        }
      }

      // Add nonce from session (needed for SIWE validation)
      const siweNonce =
        sessionStorage.getItem("siwe_nonce") ||
        localStorage.getItem("siwe_nonce");
      if (siweNonce) {
        let nonceInput = document.getElementById("siwe_nonce");
        if (!nonceInput) {
          nonceInput = document.createElement("input");
          nonceInput.type = "hidden";
          nonceInput.name = "nonce";
          nonceInput.id = "siwe_nonce";
          form.appendChild(nonceInput);
        }
        nonceInput.value = siweNonce;
        console.info("[SIWE] Nonce added to form:", siweNonce);
      } else {
        console.warn(
          "[SIWE] No nonce found in session - this may cause validation to fail"
        );
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

      // Log form data before submission
      const formData = new FormData(form);
      console.info("[SIWE] Form data being submitted:");
      for (let [key, value] of formData.entries()) {
        console.info(`[SIWE] ${key}: ${value.toString().substring(0, 50)}...`);
      }

      form.submit();
    } catch (e) {
      console.error("[SIWE] Wallet connection failed:", e);
      throw e;
    }
  },
});

export default Web3Modal;
