"use client";

import { useEffect, useState } from "react";
import {
  createPublicClient,
  createWalletClient,
  custom,
  defineChain,
  formatUnits,
  parseSignature,
  parseUnits,
} from "viem";
import type { Address, EIP1193Provider } from "viem";
import { config, hasConfiguredContracts, tokenAbi, tokenBankAbi } from "@/lib/contracts";

declare global {
  interface Window {
    ethereum?: EIP1193Provider;
  }
}

const chain = defineChain({
  id: config.chainId,
  name: config.chainName,
  nativeCurrency: {
    name: "Ether",
    symbol: "ETH",
    decimals: 18,
  },
  rpcUrls: {
    default: { http: [config.rpcUrl] },
  },
});

const publicClient = createPublicClient({
  chain,
  transport: custom({
    async request({ method, params }) {
      const response = await fetch(config.rpcUrl, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          id: Date.now(),
          jsonrpc: "2.0",
          method,
          params,
        }),
      });

      const json = await response.json();

      if (json.error) {
        throw new Error(json.error.message ?? "RPC request failed");
      }

      return json.result;
    },
  }),
});

function formatTokenValue(value: bigint) {
  const formatted = Number(formatUnits(value, config.tokenDecimals));
  return Number.isFinite(formatted) ? formatted.toLocaleString("zh-CN", { maximumFractionDigits: 6 }) : "0";
}

export default function HomePage() {
  const [account, setAccount] = useState<Address | null>(null);
  const [walletNetwork, setWalletNetwork] = useState("未连接");
  const [walletBalance, setWalletBalance] = useState<bigint>(0n);
  const [bankBalance, setBankBalance] = useState<bigint>(0n);
  const [depositAmount, setDepositAmount] = useState("");
  const [permitDepositAmount, setPermitDepositAmount] = useState("");
  const [withdrawAmount, setWithdrawAmount] = useState("");
  const [status, setStatus] = useState("请先连接钱包。");
  const [isLoading, setIsLoading] = useState(false);

  async function refreshBalances(userAddress: Address) {
    const [tokenBalance, depositedBalance] = await Promise.all([
      publicClient.readContract({
        address: config.tokenAddress,
        abi: tokenAbi,
        functionName: "balanceOf",
        args: [userAddress],
      }),
      publicClient.readContract({
        address: config.tokenBankAddress,
        abi: tokenBankAbi,
        functionName: "balances",
        args: [userAddress],
      }),
    ]);

    setWalletBalance(tokenBalance);
    setBankBalance(depositedBalance);
  }

  async function refreshWalletNetwork(provider: EIP1193Provider) {
    const chainIdHex = (await provider.request({
      method: "eth_chainId",
    })) as string;
    const chainId = Number.parseInt(chainIdHex, 16);
    const networkName = chainId === config.chainId ? config.chainName : `Chain ID ${chainId}`;
    setWalletNetwork(`${networkName} (${chainId})`);
  }

  async function connectWallet() {
    if (!window.ethereum) {
      setStatus("未检测到钱包，请先安装 MetaMask。");
      return;
    }

    if (!hasConfiguredContracts()) {
      setStatus("请先在 frontend/.env.local 中配置 Token 和 TokenBank 合约地址。");
      return;
    }

    try {
      setIsLoading(true);
      const walletClient = createWalletClient({
        chain,
        transport: custom(window.ethereum),
      });

      try {
        await window.ethereum.request({
          method: "wallet_switchEthereumChain",
          params: [{ chainId: `0x${config.chainId.toString(16)}` }],
        });
      } catch (error) {
        const switchError = error as { code?: number };

        if (switchError.code === 4902) {
          await window.ethereum.request({
            method: "wallet_addEthereumChain",
            params: [
              {
                chainId: `0x${config.chainId.toString(16)}`,
                chainName: config.chainName,
                nativeCurrency: {
                  name: "Ether",
                  symbol: "ETH",
                  decimals: 18,
                },
                rpcUrls: [config.rpcUrl],
              },
            ],
          });
        } else {
          throw error;
        }
      }

      const [address] = await walletClient.requestAddresses();
      setAccount(address);
      await refreshWalletNetwork(window.ethereum);
      await refreshBalances(address);
      setStatus("钱包已连接。");
    } catch (error) {
      setStatus(error instanceof Error ? error.message : "连接钱包失败。");
    } finally {
      setIsLoading(false);
    }
  }

  async function submitDeposit() {
    if (!account || !window.ethereum) {
      setStatus("请先连接钱包。");
      return;
    }

    if (!depositAmount) {
      setStatus("请输入要存款的金额。");
      return;
    }

    try {
      setIsLoading(true);
      setStatus("正在授权并发起存款...");

      const walletClient = createWalletClient({
        chain,
        transport: custom(window.ethereum),
      });
      const amount = parseUnits(depositAmount, config.tokenDecimals);

      const approveHash = await walletClient.writeContract({
        account,
        address: config.tokenAddress,
        abi: tokenAbi,
        functionName: "approve",
        args: [config.tokenBankAddress, amount],
      });
      await publicClient.waitForTransactionReceipt({ hash: approveHash });

      const depositHash = await walletClient.writeContract({
        account,
        address: config.tokenBankAddress,
        abi: tokenBankAbi,
        functionName: "deposit",
        args: [amount],
      });
      await publicClient.waitForTransactionReceipt({ hash: depositHash });

      await refreshBalances(account);
      setDepositAmount("");
      setStatus(`存款成功，已存入 ${depositAmount} ${config.tokenSymbol}。`);
    } catch (error) {
      setStatus(error instanceof Error ? error.message : "存款失败。");
    } finally {
      setIsLoading(false);
    }
  }

  async function submitPermitDeposit() {
    if (!account || !window.ethereum) {
      setStatus("请先连接钱包。");
      return;
    }

    if (!permitDepositAmount) {
      setStatus("请输入要离线签名存款的金额。");
      return;
    }

    try {
      setIsLoading(true);
      setStatus("正在签名 permit 并发起离线授权存款...");

      const walletClient = createWalletClient({
        chain,
        transport: custom(window.ethereum),
      });
      const amount = parseUnits(permitDepositAmount, config.tokenDecimals);
      const nonce = await publicClient.readContract({
        address: config.tokenAddress,
        abi: tokenAbi,
        functionName: "nonces",
        args: [account],
      });
      const deadline = BigInt(Math.floor(Date.now() / 1000) + 30 * 60);

      const signature = await walletClient.signTypedData({
        account,
        domain: {
          name: config.tokenName,
          version: "1",
          chainId: config.chainId,
          verifyingContract: config.tokenAddress,
        },
        primaryType: "Permit",
        types: {
          Permit: [
            { name: "owner", type: "address" },
            { name: "spender", type: "address" },
            { name: "value", type: "uint256" },
            { name: "nonce", type: "uint256" },
            { name: "deadline", type: "uint256" },
          ],
        },
        message: {
          owner: account,
          spender: config.tokenBankAddress,
          value: amount,
          nonce,
          deadline,
        },
      });

      const parsedSignature = parseSignature(signature);
      const v =
        parsedSignature.v !== undefined
          ? Number(parsedSignature.v)
          : parsedSignature.yParity === 0
            ? 27
            : 28;
      const permitDepositHash = await walletClient.writeContract({
        account,
        address: config.tokenBankAddress,
        abi: tokenBankAbi,
        functionName: "permitDeposit",
        args: [amount, deadline, v, parsedSignature.r, parsedSignature.s],
      });
      await publicClient.waitForTransactionReceipt({ hash: permitDepositHash });

      await refreshBalances(account);
      setPermitDepositAmount("");
      setStatus(`离线签名存款成功，已存入 ${permitDepositAmount} ${config.tokenSymbol}。`);
    } catch (error) {
      setStatus(error instanceof Error ? error.message : "离线签名存款失败。");
    } finally {
      setIsLoading(false);
    }
  }

  async function submitWithdraw() {
    if (!account || !window.ethereum) {
      setStatus("请先连接钱包。");
      return;
    }

    if (!withdrawAmount) {
      setStatus("请输入要取款的金额。");
      return;
    }

    try {
      setIsLoading(true);
      setStatus("正在发起取款...");

      const walletClient = createWalletClient({
        chain,
        transport: custom(window.ethereum),
      });
      const amount = parseUnits(withdrawAmount, config.tokenDecimals);

      const withdrawHash = await walletClient.writeContract({
        account,
        address: config.tokenBankAddress,
        abi: tokenBankAbi,
        functionName: "withdraw",
        args: [amount],
      });
      await publicClient.waitForTransactionReceipt({ hash: withdrawHash });

      await refreshBalances(account);
      setWithdrawAmount("");
      setStatus(`取款成功，已提取 ${withdrawAmount} ${config.tokenSymbol}。`);
    } catch (error) {
      setStatus(error instanceof Error ? error.message : "取款失败。");
    } finally {
      setIsLoading(false);
    }
  }

  useEffect(() => {
    if (!window.ethereum) {
      return;
    }

    const provider = window.ethereum;

    async function syncAccounts() {
      await refreshWalletNetwork(provider);

      const accounts = (await provider.request({
        method: "eth_accounts",
      })) as Address[];

      const nextAccount = accounts[0] ?? null;
      setAccount(nextAccount);

      if (nextAccount && hasConfiguredContracts()) {
        await refreshBalances(nextAccount);
      }
    }

    void syncAccounts();

    const handleAccountsChanged = (accounts: unknown) => {
      const nextAccount = Array.isArray(accounts) ? ((accounts[0] as Address | undefined) ?? null) : null;
      setAccount(nextAccount);

      if (nextAccount && hasConfiguredContracts()) {
        void refreshBalances(nextAccount);
      } else {
        setWalletBalance(0n);
        setBankBalance(0n);
      }
    };

    const handleChainChanged = (chainIdHex: unknown) => {
      const chainId =
        typeof chainIdHex === "string" ? Number.parseInt(chainIdHex, 16) : Number.NaN;
      const networkName = chainId === config.chainId ? config.chainName : `Chain ID ${chainId}`;
      setWalletNetwork(`${networkName} (${chainId})`);

      if (account && hasConfiguredContracts()) {
        void refreshBalances(account);
      }
    };

    provider.on?.("accountsChanged", handleAccountsChanged);
    provider.on?.("chainChanged", handleChainChanged);

    return () => {
      provider.removeListener?.("accountsChanged", handleAccountsChanged);
      provider.removeListener?.("chainChanged", handleChainChanged);
    };
  }, []);

  return (
    <main
      style={{
        minHeight: "100vh",
        padding: "40px 20px 80px",
      }}
    >
      <section
        style={{
          maxWidth: 1040,
          margin: "0 auto",
          display: "grid",
          gap: 24,
        }}
      >
        <div
          style={{
            background: "var(--panel)",
            border: "1px solid var(--border)",
            borderRadius: 32,
            padding: "28px 28px 32px",
            boxShadow: "var(--shadow)",
            backdropFilter: "blur(18px)",
          }}
        >
          <p
            style={{
              margin: 0,
              fontSize: 13,
              letterSpacing: "0.24em",
              textTransform: "uppercase",
              color: "var(--accent-strong)",
            }}
          >
            Next.js + Viem
          </p>
          <h1
            style={{
              margin: "12px 0 8px",
              fontSize: "clamp(2.6rem, 6vw, 4.8rem)",
              lineHeight: 0.95,
            }}
          >
            Token Bank
          </h1>
          <p
            style={{
              margin: 0,
              maxWidth: 720,
              color: "var(--muted)",
              fontSize: 18,
              lineHeight: 1.6,
            }}
          >
            显示当前用户持有的 {config.tokenSymbol} 余额、已存入 TokenBank 的金额，并提供存款和取款操作。
          </p>
        </div>

        <div
          style={{
            display: "grid",
            gridTemplateColumns: "repeat(auto-fit, minmax(240px, 1fr))",
            gap: 18,
          }}
        >
          {[
            { label: "当前钱包", value: account ?? "未连接" },
            { label: "当前钱包连接网络", value: walletNetwork },
            { label: `钱包 ${config.tokenSymbol} 余额`, value: `${formatTokenValue(walletBalance)} ${config.tokenSymbol}` },
            { label: "已存入 TokenBank", value: `${formatTokenValue(bankBalance)} ${config.tokenSymbol}` },
          ].map((item) => (
            <article
              key={item.label}
              style={{
                background: "var(--panel-strong)",
                border: "1px solid var(--border)",
                borderRadius: 24,
                padding: 22,
                minHeight: 144,
              }}
            >
              <p style={{ margin: 0, color: "var(--muted)", fontSize: 14 }}>{item.label}</p>
              <p
                style={{
                  margin: "16px 0 0",
                  fontSize: 24,
                  lineHeight: 1.35,
                  wordBreak: "break-word",
                }}
              >
                {item.value}
              </p>
            </article>
          ))}
        </div>

        <div
          style={{
            display: "grid",
            gridTemplateColumns: "repeat(auto-fit, minmax(300px, 1fr))",
            gap: 18,
          }}
        >
          <ActionCard
            title="存款到 TokenBank"
            description={`输入要存入的 ${config.tokenSymbol} 数量，前端会先发起 approve，再调用 deposit。`}
            value={depositAmount}
            onChange={setDepositAmount}
            buttonLabel="授权并存款"
            onSubmit={submitDeposit}
            disabled={isLoading || !hasConfiguredContracts()}
          />
          <ActionCard
            title="permitDeposit 离线签名存款"
            description={`输入要存入的 ${config.tokenSymbol} 数量，前端会先用 EIP-2612 进行离线签名，再直接调用 TokenBank 的 permitDeposit。`}
            value={permitDepositAmount}
            onChange={setPermitDepositAmount}
            buttonLabel="签名并存款"
            onSubmit={submitPermitDeposit}
            disabled={isLoading || !hasConfiguredContracts()}
          />
          <ActionCard
            title="从 TokenBank 取款"
            description={`输入要提取的 ${config.tokenSymbol} 数量，直接调用 withdraw。`}
            value={withdrawAmount}
            onChange={setWithdrawAmount}
            buttonLabel="取款"
            onSubmit={submitWithdraw}
            disabled={isLoading || !hasConfiguredContracts()}
          />
        </div>

        <div
          style={{
            display: "flex",
            flexWrap: "wrap",
            alignItems: "center",
            gap: 12,
            background: "var(--panel)",
            border: "1px solid var(--border)",
            borderRadius: 24,
            padding: 20,
          }}
        >
          <button
            onClick={connectWallet}
            disabled={isLoading}
            style={buttonStyle}
          >
            {account ? "重新连接钱包" : "连接钱包"}
          </button>
          <span style={{ color: "var(--muted)", lineHeight: 1.6 }}>{status}</span>
        </div>

        {!hasConfiguredContracts() && (
          <div
            style={{
              background: "rgba(184, 92, 56, 0.08)",
              color: "var(--accent-strong)",
              border: "1px solid rgba(184, 92, 56, 0.18)",
              borderRadius: 20,
              padding: 18,
              lineHeight: 1.7,
            }}
          >
            当前 `NEXT_PUBLIC_TOKEN_BANK_ADDRESS` 还是占位地址。请在
            `frontend/.env.local` 中填入真实的 TokenBank 地址后再运行页面。
          </div>
        )}
      </section>
    </main>
  );
}

function ActionCard({
  title,
  description,
  value,
  onChange,
  buttonLabel,
  onSubmit,
  disabled,
}: {
  title: string;
  description: string;
  value: string;
  onChange: (value: string) => void;
  buttonLabel: string;
  onSubmit: () => void;
  disabled: boolean;
}) {
  return (
    <section
      style={{
        background: "var(--panel)",
        border: "1px solid var(--border)",
        borderRadius: 28,
        padding: 24,
        boxShadow: "var(--shadow)",
      }}
    >
      <h2 style={{ margin: "0 0 10px", fontSize: 28 }}>{title}</h2>
      <p style={{ margin: "0 0 18px", color: "var(--muted)", lineHeight: 1.7 }}>{description}</p>
      <input
        inputMode="decimal"
        placeholder="0.0"
        value={value}
        onChange={(event) => onChange(event.target.value)}
        style={{
          width: "100%",
          borderRadius: 18,
          border: "1px solid var(--border)",
          padding: "16px 18px",
          fontSize: 18,
          marginBottom: 14,
          background: "rgba(255, 255, 255, 0.72)",
        }}
      />
      <button
        onClick={onSubmit}
        disabled={disabled}
        style={{
          ...buttonStyle,
          width: "100%",
          justifyContent: "center",
          opacity: disabled ? 0.65 : 1,
        }}
      >
        {buttonLabel}
      </button>
    </section>
  );
}

const buttonStyle: React.CSSProperties = {
  appearance: "none",
  border: "none",
  borderRadius: 999,
  padding: "14px 22px",
  background: "linear-gradient(135deg, var(--accent), var(--accent-strong))",
  color: "#fff9f4",
  fontSize: 16,
  display: "inline-flex",
  alignItems: "center",
  gap: 8,
};
