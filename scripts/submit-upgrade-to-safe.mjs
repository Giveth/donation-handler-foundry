#!/usr/bin/env node

/**
 * Submit the DonationHandler upgrade proposal to the Safe Transaction Service.
 * Uses PROPOSER_PRIVATE_KEY (or PROPOSER_PK) from env. Proposer must be a Safe owner.
 *
 * Usage:
 *   node scripts/submit-upgrade-to-safe.mjs <chain>
 *   PROXY_ADMIN_ADDRESS=0x... PROXY_ADDRESS=0x... NEW_IMPLEMENTATION_ADDRESS=0x... SAFE_ADDRESS=0x... node scripts/submit-upgrade-to-safe.mjs base
 *
 * Required env: PROPOSER_PRIVATE_KEY (or PROPOSER_PK), SAFE_ADDRESS, PROXY_ADMIN_ADDRESS, PROXY_ADDRESS, NEW_IMPLEMENTATION_ADDRESS,
 *               and <CHAIN>_RPC (e.g. BASE_RPC for chain=base).
 */

// Env: source .env before running, or use node -r dotenv/config
import Safe from '@safe-global/protocol-kit';
import SafeApiKit from '@safe-global/api-kit';
import { OperationType } from '@safe-global/types-kit';
import { ethers } from 'ethers';

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
    const url = process.env[envKey];
    if (!url) throw new Error(`Missing ${envKey} in .env`);
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
        console.error('Required env: SAFE_ADDRESS, PROXY_ADMIN_ADDRESS, PROXY_ADDRESS, NEW_IMPLEMENTATION_ADDRESS');
        console.error('Required env: PROPOSER_PRIVATE_KEY (or PROPOSER_PK) — proposer must be a Safe owner');
        console.error('Required env: <CHAIN>_RPC (e.g. BASE_RPC)');
        process.exit(1);
    }

    const chainId = getChainId(chain);
    const rpcUrl = getRpcUrl(chain);
    const proposerPk = getProposerPrivateKey();
    const proposerAddress = new ethers.Wallet(proposerPk).address;

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
            const provider = new ethers.JsonRpcProvider(rpcUrl);
            const protocolKit = await Safe.init({
                provider,
                signer: proposerPk,
                safeAddress,
            });

            const safeTransaction = await protocolKit.createTransaction({
                transactions: [safeTransactionData],
            });
            const safeTxHash = await protocolKit.getTransactionHash(safeTransaction);
            const signature = await protocolKit.signHash(safeTxHash);

            const apiKit = new SafeApiKit({
                chainId,
                ...(process.env.SAFE_API_KEY && { apiKey: process.env.SAFE_API_KEY }),
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
            console.log('Safe tx hash:', safeTxHash);
            console.log('View in Safe:', `https://app.safe.global/transactions/queue?safe=${slug}:${safeAddress}`);
        } catch (err) {
            console.error('Propose failed:', err.message || err);
            process.exit(1);
        }
    })();
}

main();
