#!/usr/bin/env node

/**
 * Submit the DonationHandler upgrade proposal to the Safe Transaction Service.
 * Uses PROPOSER_PRIVATE_KEY (or PROPOSER_PK) from env. Proposer must be a Safe owner.
 *
 * Usage:
 *   node scripts/submit-upgrade-to-safe.mjs <chain> [nonce]
 *   Or: pnpm run upgrade:submit-to-safe -- mainnet
 *   Or: pnpm run upgrade:submit-to-safe -- base 514
 *
 * Optional: SAFE_TX_NONCE or third argument sets the Safe transaction nonce (e.g. when you have
 * other transactions in the queue and want this one to execute in a specific order).
 *
 * Loads .env from project root automatically. Required: SAFE_ADDRESS, PROXY_ADMIN_ADDRESS,
 * PROXY_ADDRESS, NEW_IMPLEMENTATION_ADDRESS, PROPOSER_PRIVATE_KEY (or PROPOSER_PK), <CHAIN>_RPC.
 */

import { fileURLToPath } from 'url';
import path from 'path';
import { config } from 'dotenv';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
// override: true so .env wins over any MAINNET_RPC etc. already set in the shell (e.g. from another file)
config({ path: path.join(__dirname, '..', '.env'), override: true });

// CJS default export can appear as .default when imported from ESM
import SafeModule from '@safe-global/protocol-kit';
import SafeApiKitModule from '@safe-global/api-kit';
import { OperationType } from '@safe-global/types-kit';
import { ethers } from 'ethers';

const Safe = SafeModule?.default ?? SafeModule;
const SafeApiKit = SafeApiKitModule?.default ?? SafeApiKitModule;

const CHAIN_IDS = {
    mainnet: 1,
    sepolia: 11155111,
    base: 8453,
    arbitrum: 42161,
    optimism: 10,
    polygon: 137,
    gnosis: 100,
    celo: 42220,
};

const SAFE_APP_CHAIN_SLUG = {
    mainnet: 'eth',
    sepolia: 'sep',
    base: 'base',
    arbitrum: 'arbitrum',
    optimism: 'oeth',
    polygon: 'matic',
    gnosis: 'gno',
    celo: 'celo',
};

function getChainId(chain) {
    const id = CHAIN_IDS[chain ? chain.toLowerCase() : 'mainnet'];
    if (id == null) throw new Error(`Unknown chain: ${chain}. Supported: ${Object.keys(CHAIN_IDS).join(', ')}`);
    return BigInt(id);
}

function getRpcUrl(chain) {
    const key = chain.toLowerCase().replace(/-/g, '_');
    const envKey = key === 'mainnet' ? 'MAINNET_RPC' : `${key.toUpperCase()}_RPC`;
    let url = (process.env[envKey] || '').trim();
    // Strip optional surrounding single/double quotes (e.g. .env: MAINNET_RPC="https://..." or 'https://...')
    if ((url.startsWith('"') && url.endsWith('"')) || (url.startsWith("'") && url.endsWith("'"))) {
        url = url.slice(1, -1).trim();
    }
    if (!url) throw new Error(`Missing ${envKey} in .env`);
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
        const preview = url.length > 30 ? `${url.slice(0, 25)}...` : url;
        throw new Error(`${envKey} must be a full RPC URL starting with https:// (e.g. https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY). Got: ${preview}`);
    }
    return url;
}

function getProposerPrivateKey() {
    const key = process.env.PROPOSER_PRIVATE_KEY || process.env.PROPOSER_PK;
    if (!key) throw new Error('Missing PROPOSER_PRIVATE_KEY or PROPOSER_PK in .env');
    return key.startsWith('0x') ? key : `0x${key}`;
}

function main() {
    const chain = process.argv[2] || process.env.CHAIN || 'mainnet';
    const safeAddress = process.env.SAFE_ADDRESS;
    const proxyAdmin = process.env.PROXY_ADMIN_ADDRESS;
    const proxy = process.env.PROXY_ADDRESS;
    const newImplementation = process.env.NEW_IMPLEMENTATION_ADDRESS;

    if (!safeAddress || !proxyAdmin || !proxy || !newImplementation) {
        console.error('Usage: node scripts/submit-upgrade-to-safe.mjs <chain>');
        console.error('Required env (set in .env):');
        console.error('  SAFE_ADDRESS          (your multisig address)');
        console.error('  PROXY_ADMIN_ADDRESS  (ProxyAdmin contract)');
        console.error('  PROXY_ADDRESS        (DonationHandler proxy to upgrade)');
        console.error('  NEW_IMPLEMENTATION_ADDRESS  (from deploy:implementation)');
        console.error('  PROPOSER_PRIVATE_KEY or PROPOSER_PK  (Safe owner key)');
        console.error('  SAFE_API_KEY  (get at https://developer.safe.global)');
        console.error('  MAINNET_RPC (or <CHAIN>_RPC for the chain you use)');
        console.error('Optional: SAFE_TX_NONCE or 3rd CLI arg = Safe tx nonce (for queue ordering).');
        const missing = [];
        if (!safeAddress) missing.push('SAFE_ADDRESS');
        if (!proxyAdmin) missing.push('PROXY_ADMIN_ADDRESS');
        if (!proxy) missing.push('PROXY_ADDRESS');
        if (!newImplementation) missing.push('NEW_IMPLEMENTATION_ADDRESS');
        if (missing.length) console.error('Missing or empty:', missing.join(', '));
        process.exit(1);
    }

    const chainId = getChainId(chain);
    const rpcUrl = getRpcUrl(chain);
    const proposerPk = getProposerPrivateKey();
    const proposerAddress = new ethers.Wallet(proposerPk).address;

    const nonceRaw = process.argv[3] ?? process.env.SAFE_TX_NONCE;
    const nonce = nonceRaw != null && nonceRaw !== '' ? Number(nonceRaw) : undefined;
    if (nonceRaw != null && nonceRaw !== '' && (Number.isNaN(nonce) || nonce < 0 || !Number.isInteger(nonce))) {
        console.error('SAFE_TX_NONCE / nonce must be a non-negative integer.');
        process.exit(1);
    }

    // Calldata: upgrade(address proxy, address implementation)
    const iface = new ethers.Interface(['function upgrade(address proxy, address implementation)']);
    const data = iface.encodeFunctionData('upgrade', [proxy, newImplementation]);

    const safeTransactionData = {
        to: proxyAdmin,
        value: '0',
        data,
        operation: OperationType.Call,
    };

    (async() => {
        try {
            // Safe SDK expects RPC URL string (HttpTransport) or EIP-1193 provider, not ethers Provider
            const protocolKit = await Safe.init({
                provider: rpcUrl,
                signer: proposerPk,
                safeAddress,
            });

            // GS013: Safe requires success || safeTxGas != 0 || gasPrice != 0. If we omit these,
            // a reverted inner call causes the Safe to revert with GS013. Set safeTxGas so the
            // Safe doesn't wrap the failure; use enough for Safe overhead + ProxyAdmin.upgrade.
            const txOptions = {
                safeTxGas: '500000',
                gasPrice: '0',
            };
            if (nonce !== undefined) {
                txOptions.nonce = nonce;
            }
            const safeTransaction = await protocolKit.createTransaction({
                transactions: [safeTransactionData],
                options: txOptions,
            });
            const safeTxHash = await protocolKit.getTransactionHash(safeTransaction);
            const signature = await protocolKit.signHash(safeTxHash);

            const safeApiKey = (process.env.SAFE_API_KEY || '').trim();
            if (!safeApiKey) {
                throw new Error(
                    'SAFE_API_KEY is required. Get a free key at https://developer.safe.global and add SAFE_API_KEY=your_key to .env'
                );
            }
            const apiKit = new SafeApiKit({
                chainId,
                apiKey: safeApiKey,
            });

            await apiKit.proposeTransaction({
                safeAddress,
                safeTransactionData: safeTransaction.data,
                safeTxHash,
                senderAddress: proposerAddress,
                senderSignature: signature.data,
            });

            const slug = SAFE_APP_CHAIN_SLUG[chain ? chain.toLowerCase() : 'mainnet'] || 'eth';
            console.log('Proposal submitted to Safe Transaction Service.');
            if (nonce !== undefined) console.log('Nonce used:', nonce);
            console.log('Safe tx hash:', safeTxHash);
            console.log('View in Safe:', `https://app.safe.global/transactions/queue?safe=${slug}:${safeAddress}`);
        } catch (err) {
            console.error('Propose failed:', err.message || err);
            // Log API response body when present (e.g. 422 Unprocessable Content)
            const body = err?.response?.data ?? err?.data ?? err?.body;
            if (body && typeof body === 'object') {
                console.error('API response:', JSON.stringify(body, null, 2));
            } else if (body && typeof body === 'string') {
                console.error('API response:', body);
            }
            if (err?.message?.includes('Unprocessable') || err?.message?.includes('422')) {
                console.error('\nCommon causes: Safe at SAFE_ADDRESS may not exist on this chain, or proposer is not an owner of that Safe on this chain. Use the correct Safe address for Polygon.');
            }
            process.exit(1);
        }
    })();
}

main();
