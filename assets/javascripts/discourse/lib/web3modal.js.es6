import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import loadScript from "discourse/lib/load-script";

const Web3Modal = EmberObject.extend({
  appKit: null,
  wagmiConfig: null,

  async providerInit(env) {
    // Remove any existing Web3Modal v1 elements to prevent conflicts
    document.querySelectorAll("w3m-modal").forEach((el) => el.remove());

    // Neutralize any global Web3Modal v1 instance
    if (window.Web3Modal && !window.Web3Modal.AppKit) {
      console.info(
        "[SIWE] Detected legacy Web3Modal, neutralizing to prevent conflicts"
      );
      window.Web3Modal_Legacy = window.Web3Modal;
      window.Web3Modal = undefined;
    }

    await this.loadScripts();

    const projectId = env.PROJECT_ID;

    // Chains via viem UMD
    const mainnet = window.viem.chains.mainnet;
    const polygon = window.viem.chains.polygon;
    const chains = [mainnet, polygon];

    // Wagmi v2 config using viem transports and AppKit connector
    const transports = {};
    transports[mainnet.id] = window.viem.http();
    transports[polygon.id] = window.viem.http();

    const wagmiConfig = window.Wagmi.createConfig({
      chains,
      transports,
      connectors: [window.AppKitWagmi.walletConnect({ projectId })],
      ssr: false,
      autoConnect: true,
    });

    this.wagmiConfig = wagmiConfig;

    // Initialize AppKit (Reown)
    this.appKit = window.AppKit.createAppKit({
      projectId,
      wagmiConfig,
    });

    return this.appKit;
  },

  async loadScripts() {
    // Load Reown AppKit + Wagmi v2 + viem UMDs (no legacy fallback)
    const urls = [
      "https://cdn.jsdelivr.net/npm/viem@2.14.1/dist/viem.umd.min.js",
      "https://cdn.jsdelivr.net/npm/wagmi@2.12.21/dist/wagmi.umd.js",
      "https://cdn.jsdelivr.net/npm/@reown/appkit@1.1.1/dist/index.umd.js",
      "https://cdn.jsdelivr.net/npm/@reown/appkit-wagmi@1.1.1/dist/index.umd.js",
    ];
    await urls.reduce(
      (p, url) => p.then(() => loadScript(url)),
      Promise.resolve()
    );
  },

  async signMessage(account) {
    let address = account.address;

    // Ensure lowercase, then checksum via viem if available
    try {
      address = window.viem.getAddress(address);
    } catch (e) {
      // fallback: sanitize
      address = (address || "").toString();
    }

    // Optional ENS lookup (best-effort)
    let name = null;
    let avatar = null;

    const { message } = await ajax("/discourse-siwe/message", {
      data: {
        eth_account: address,
        chain_id: account.chainId || (await this._getChainId()),
      },
    }).catch(popupAjaxError);

    // Try signing via EIP-1193 provider; fallback to wagmi if available
    let signature;
    try {
      if (window.Wagmi && typeof window.Wagmi.signMessage === "function") {
        signature = await window.Wagmi.signMessage(this.wagmiConfig, {
          message,
        });
      } else if (window.ethereum?.request) {
        signature = await window.ethereum.request({
          method: "personal_sign",
          params: [message, address],
        });
      } else {
        throw new Error("No wallet client available to sign message");
      }
    } catch (e) {
      throw e;
    }

    return [name || address, message, signature, avatar];
  },

  async _getChainId() {
    try {
      if (window.Wagmi && typeof window.Wagmi.getChainId === "function") {
        return await window.Wagmi.getChainId(this.wagmiConfig);
      }
      if (window.ethereum?.request) {
        const hex = await window.ethereum.request({ method: "eth_chainId" });
        return parseInt(hex, 16);
      }
    } catch (e) {}
    return null;
  },

  async runSigningProcess(cb) {
    // Subscribe to account changes (wagmi v2 UMD)
    window.Wagmi.watchAccount(this.wagmiConfig, {
      onChange: async (account) => {
        if (account.status === "connected" && account.address) {
          this.connected = true;
          cb(
            await this.signMessage({
              address: account.address,
              chainId: account.chainId,
            })
          );
        }
      },
    });

    if (this.appKit && this.appKit.open) {
      this.appKit.open();
    }
  },
});

export default Web3Modal;
