/**
 * Exhaustive end-to-end test for DS Token deployment + on-chain operations on devnet.
 *
 * Each deployment publishes a brand-new Move package with a unique symbol, so the
 * suite is fully re-runnable without on-chain state collisions. Tests are independent
 * — they never share a token. Failures include the deployed token address so the
 * tx can be inspected on a devnet explorer.
 *
 * Coverage axes:
 *   1.  Happy path — every optional field populated, every deployment assertion on-chain
 *   2.  Owners variants — with/without explicit owners (Master transfer vs. retention)
 *   3.  Compliance type variants — regulated vs. whitelisted
 *   4.  Rule registration — empty, single, all-rules
 *   5.  Country compliance — none, mixed regions
 *   6.  Metadata edge cases — decimals, long description
 *   7.  Additional roles array — issuer/exchange/transfer_agent fan-out
 *   8.  Negative paths — unsupported config, duplicate symbol, invalid identifier, role conflicts
 *   9.  Address-owned objects — UpgradeCap distribution (Sui RPC lookup)
 *   10. Investor lifecycle — register, addWallet, getInvestorDetails round-trip
 *   11. Token operations — issuance, transfer, burn, balance/supply assertions
 *   12. Pause semantics — pause blocks investor↔investor transfer; unpause restores
 *   13. Seize via issuer wallet — happy + non-issuer-wallet destination aborts
 *   14. Lockup enforcement — locked tokens cannot be transferred until release
 *   15. Authorization failure — signer who lost Master cannot pause
 */

import {
    AccreditedOnly,
    ADMIN_KEYPAIR,
    AuthorizedSecurities,
    BackdatingIssuance,
    ComplianceRules,
    CountryCompliance,
    CountryComplianceStatus,
    createDSToken,
    createWallet,
    DeploymentRequest,
    DSToken,
    FlowbackRestriction,
    ForceFullTransfer,
    HoldingLimits,
    Investors,
    InvestorLimits,
    LockupRestriction,
    Owners,
    Roles,
    Rules,
    SuiClient,
    Wallets,
} from '../src'
import { deploy } from '../src/sdk/utils/deploy'

const sender = ADMIN_KEYPAIR!.toSuiAddress()

// ====================== Helpers ======================

/** Build a symbol that is (a) globally unique across runs, (b) a valid Move identifier. */
function uniqueSymbol(prefix = 'e2e'): string {
    const stamp = Date.now().toString(36) + Math.random().toString(36).slice(2, 6)
    return `${prefix}_${stamp}`.toLowerCase()
}

/**
 * Build a deployment request from scratch — does NOT mutate any shared object.
 * (`test_utils.createTestToken` mutates a module-level `testTokenRequest`, which
 * is unsafe when multiple tests deploy with different configs.)
 */
function makeRequest(overrides: Partial<DeploymentRequest> = {}): DeploymentRequest {
    const symbol = overrides.tokenDescription?.symbol ?? uniqueSymbol()
    return {
        tokenDescription: {
            name: symbol,
            symbol,
            decimals: 6,
            type: 'standard',
            tokenMultiplier: '',
            iconUri: 'https://example.com/icon.png',
            description: 'e2e test token',
            ...overrides.tokenDescription,
        },
        complianceType: overrides.complianceType ?? 'regulated',
        lockManagerType: overrides.lockManagerType ?? 'investor',
        roles: overrides.roles ?? [],
        owners: overrides.owners,
        complianceRules: overrides.complianceRules,
        countriesComplianceStatuses: overrides.countriesComplianceStatuses,
    }
}

/** Token address comes back as `<packageId>::<moduleName>::<StructName>`. */
function assertTokenAddressShape(addr: string, symbol: string): void {
    const moduleName = symbol.toLowerCase()
    const structName = symbol.charAt(0).toUpperCase() + symbol.slice(1).toLowerCase()
    const pattern = new RegExp(`^0x[0-9a-fA-F]+::${moduleName}::${structName}$`)
    expect(addr).toMatch(pattern)
    const [packageId] = addr.split('::')
    // Sui object IDs are 32-byte hex (0x + 64 chars); leading zeros may be stripped.
    expect(packageId).toMatch(/^0x[0-9a-fA-F]{1,64}$/)
}

/** Register an investor with a known set of wallets — does NOT default to signer's address. */
async function registerInvestorExplicit(
    tokenAddress: string,
    investorId: string,
    wallets: string[]
): Promise<void> {
    const investors = new Investors(tokenAddress)
    const bytes = await investors.registerInvestor(investorId, sender)
    await SuiClient.executeMoveCallBytes(bytes, ADMIN_KEYPAIR!)
    for (const w of wallets) {
        const addBytes = await investors.addWallet(investorId, w, sender)
        await SuiClient.executeMoveCallBytes(addBytes, ADMIN_KEYPAIR!)
    }
}

/**
 * Wrap an async sequence so that a throw anywhere inside surfaces as a promise rejection
 * for `await expect(...).rejects.toThrow()`. Needed because `await fn()` placed inside
 * an `expect(...)` argument throws synchronously before reaching the matcher.
 */
function mustRevert(fn: () => Promise<unknown>): Promise<unknown> {
    return (async () => { await fn() })()
}

/** Build + sign + execute in one step (matches existing `executeTxFunc` pattern). */
async function exec(bytesPromise: Promise<string>): Promise<any> {
    const bytes = await bytesPromise
    return SuiClient.executeMoveCallBytes(bytes, ADMIN_KEYPAIR!)
}

/**
 * Direct RPC fetch — the "explorer" check. Returns the on-chain object data, or
 * throws if the object does not exist on devnet. Use to prove that an SDK call
 * actually wrote/created what it claims.
 */
async function fetchObject(objectId: string): Promise<any> {
    const resp = await SuiClient.getObject(objectId)
    if (!resp?.data) {
        throw new Error(`Object ${objectId} does not exist on chain`)
    }
    return resp.data
}

/**
 * Verify that every shared object the SDK derives for `tokenAddress` exists on chain
 * with a type that matches the expected Move type string. This is the "explorer"
 * check — a direct getObject lookup proving the deployment really wrote what its
 * downstream SDK view methods imply.
 */
async function verifyTokenObjectsOnChain(tokenAddress: string): Promise<void> {
    const { getTokenDetails } = await import('../src/sdk/token')
    const { Config } = await import('../src/sdk/utils/config')
    const details = getTokenDetails(tokenAddress)
    const pkg = Config.vars.PACKAGE_ID
    const expectations: { id: string; label: string; typeMatches: RegExp }[] = [
        { id: details.treasury,         label: 'Treasury',         typeMatches: new RegExp(`${pkg}::ds_token::Treasury<`) },
        { id: details.auth,             label: 'Auth',             typeMatches: new RegExp(`${pkg}::trust_service::Auth<`) },
        { id: details.investorInfo,     label: 'InvestorInfo',     typeMatches: new RegExp(`${pkg}::registry_service::InvestorInfo<`) },
        { id: details.complianceConfig, label: 'ComplianceConfig', typeMatches: new RegExp(`${pkg}::compliance_service::ComplianceConfig<`) },
        { id: details.currency,         label: 'Currency',         typeMatches: /::coin_registry::Currency</ },
    ]
    for (const { id, label, typeMatches } of expectations) {
        const obj = await fetchObject(id)
        const type: string = obj?.content?.type ?? obj?.type ?? ''
        if (!typeMatches.test(type)) {
            throw new Error(
                `[${label}] Object ${id} has type "${type}", expected to match ${typeMatches}`
            )
        }
    }
    // Also confirm the published package itself exists.
    const [packageId] = tokenAddress.split('::')
    await fetchObject(packageId)
}

/**
 * Deploy a DS token AND immediately prove its on-chain objects exist with the right
 * types via direct getObject lookups (the "explorer check"). Every successful deploy
 * call site in this suite uses this wrapper, so each of ~25 deployments produces
 * direct on-chain verification — not just SDK-view inferences.
 */
async function deployAndVerify(
    req: DeploymentRequest,
    signer = ADMIN_KEYPAIR!
): Promise<{ id: string }> {
    const result = await createDSToken(req, signer)
    await verifyTokenObjectsOnChain(result.id)
    return result
}

/** List `0x2::package::UpgradeCap` objects owned by `addr` whose `package` field equals `packageId`. */
async function findUpgradeCapsFor(addr: string, packageId: string): Promise<any[]> {
    const normalizedPkg = packageId.toLowerCase().replace(/^0x0*/, '0x')
    const matches: any[] = []
    let cursor: string | undefined = undefined
    let hasNextPage = true
    while (hasNextPage) {
        const resp: any = await SuiClient.client.listOwnedObjects({
            owner: addr,
            type: '0x2::package::UpgradeCap',
            include: { json: true },
            cursor,
        })
        for (const obj of resp.objects ?? []) {
            const objPkg = (obj.json?.package ?? '').toLowerCase().replace(/^0x0*/, '0x')
            if (objPkg === normalizedPkg) matches.push(obj)
        }
        hasNextPage = resp.hasNextPage
        cursor = resp.cursor ?? undefined
    }
    return matches
}

// ====================== Suite ======================

describe('DeployDSToken E2E (devnet, exhaustive)', () => {
    beforeAll(async () => {
        // Idempotent: re-deploys SDK infra only if Pub.devnet.toml is stale.
        await deploy(ADMIN_KEYPAIR!)
    })

    // ---------- 1. Happy path ----------

    describe('happy path: every option populated', () => {
        const symbol = uniqueSymbol('happy')
        const tokenOwner = createWallet().toSuiAddress()
        const transferAgent = createWallet().toSuiAddress()
        const redemption = createWallet().toSuiAddress()
        const omnibus = createWallet().toSuiAddress()
        const issuer = createWallet().toSuiAddress()
        const exchange = createWallet().toSuiAddress()
        const extraTA = createWallet().toSuiAddress()

        const owners: Owners = {
            tokenOwner,
            walletRegistrarOwner: transferAgent,
            walletRegistrarOwnerType: createWallet().toSuiAddress(),
            redemptionAddress: redemption,
            omnibusTBEAddress: omnibus,
        }

        const complianceRules: ComplianceRules = {
            forceAccredited: true,
            forceAccreditedUS: false,
            blockFlowbackEndTime: 1_900_000_000_000,
            forceFullTransfer: true,
            worldWideForceFullTransfer: false,
            minimumHoldingsPerInvestor: '100',
            maximumHoldingsPerInvestor: '1000000',
            minUSTokens: '50',
            minEUTokens: '30',
            totalInvestorsLimit: 2000,
            minimumTotalInvestors: 10,
            usInvestorsLimit: 500,
            usAccreditedInvestorsLimit: 300,
            nonAccreditedInvestorsLimit: 200,
            jpInvestorsLimit: 100,
            euRetailInvestorsLimit: 150,
            maxUSInvestorsPercentage: 40,
            authorizedSecurities: '10000000',
            disallowBackDating: true,
            usLockPeriod: 31_536_000_000,
            nonUSLockPeriod: 15_768_000_000,
        }

        const countries: CountryComplianceStatus[] = [
            { countryName: 'US', complianceStatus: 'us' },
            { countryName: 'GR', complianceStatus: 'eu' },
            { countryName: 'JP', complianceStatus: 'jp' },
            { countryName: 'NK', complianceStatus: 'forbidden' },
        ]

        let tokenAddress: string

        it('deploys end-to-end with no errors', async () => {
            const req = makeRequest({
                tokenDescription: {
                    name: symbol,
                    symbol,
                    decimals: 6,
                    type: 'standard',
                    tokenMultiplier: '',
                    iconUri: 'https://example.com/icon.png',
                    description: 'happy-path full deployment',
                },
                owners,
                complianceRules,
                countriesComplianceStatuses: countries,
                roles: [
                    { address: issuer, role: 'issuer' },
                    { address: exchange, role: 'exchange' },
                    { address: extraTA, role: 'transfer_agent' },
                ],
            })

            const result = await deployAndVerify(req, ADMIN_KEYPAIR!)
            tokenAddress = result.id
            assertTokenAddressShape(tokenAddress, symbol)
        })

        it('proves every derived shared object exists on chain (Treasury, Auth, InvestorInfo, ComplianceConfig, Currency) — explorer check', async () => {
            await verifyTokenObjectsOnChain(tokenAddress)
        })

        it('transfers Master to tokenOwner (signer ends with no role)', async () => {
            const roles = new Roles(tokenAddress)
            await expect(roles.getRole(tokenOwner)).resolves.toBe('master')
            await expect(roles.getRole(sender)).resolves.toBe('none')
        })

        it('assigns walletRegistrarOwner as TransferAgent and extras from roles[]', async () => {
            const roles = new Roles(tokenAddress)
            await expect(roles.getRole(transferAgent)).resolves.toBe('transfer_agent')
            await expect(roles.getRole(extraTA)).resolves.toBe('transfer_agent')
            await expect(roles.getRole(issuer)).resolves.toBe('issuer')
            await expect(roles.getRole(exchange)).resolves.toBe('exchange')
        })

        it('registers every compliance rule on chain', async () => {
            await expect(new AccreditedOnly(tokenAddress).exists(sender)).resolves.toBe(true)
            await expect(new FlowbackRestriction(tokenAddress).exists(sender)).resolves.toBe(true)
            await expect(new ForceFullTransfer(tokenAddress).exists(sender)).resolves.toBe(true)
            await expect(new HoldingLimits(tokenAddress).exists(sender)).resolves.toBe(true)
            await expect(new InvestorLimits(tokenAddress).exists(sender)).resolves.toBe(true)
            await expect(new AuthorizedSecurities(tokenAddress).exists(sender)).resolves.toBe(true)
            await expect(new BackdatingIssuance(tokenAddress).exists(sender)).resolves.toBe(true)
            await expect(new LockupRestriction(tokenAddress).exists(sender)).resolves.toBe(true)
        })

        it('persists rule values that survive the round-trip', async () => {
            const stored = await new Rules(tokenAddress).getRules()
            expect(stored.forceAccredited).toBe(true)
            expect(stored.forceAccreditedUS).toBe(false)
            expect(stored.blockFlowbackEndTime).toBe(1_900_000_000_000)
            expect(stored.disallowBackDating).toBe(true)
            expect(stored.usLockPeriod).toBe(31_536_000_000)
            expect(stored.nonUSLockPeriod).toBe(15_768_000_000)
            expect(stored.totalInvestorsLimit).toBe(2000)
            expect(stored.maxUSInvestorsPercentage).toBe(40)
            expect(stored.authorizedSecurities).toBe('10000000')
            expect(stored.minimumHoldingsPerInvestor).toBe('100')
            expect(stored.maximumHoldingsPerInvestor).toBe('1000000')
        })

        it('persists country compliance for every configured country', async () => {
            const cc = new CountryCompliance(tokenAddress)
            await expect(cc.get('US', sender)).resolves.toBe('us')
            await expect(cc.get('GR', sender)).resolves.toBe('eu')
            await expect(cc.get('JP', sender)).resolves.toBe('jp')
            await expect(cc.get('NK', sender)).resolves.toBe('forbidden')
        })

        it('returns "none" for unset countries', async () => {
            const cc = new CountryCompliance(tokenAddress)
            await expect(cc.get('FR', sender)).resolves.toBe('none')
        })

        it('exposes the metadata that was submitted', async () => {
            const meta = await new DSToken(tokenAddress).getMetadata(sender)
            expect(meta.symbol).toBe(symbol)
            expect(meta.decimals).toBe(6)
            expect(meta.description).toBe('happy-path full deployment')
        })
    })

    // ---------- 2. Owners variants ----------

    describe('owners variants', () => {
        it('without owners: signer retains Master role', async () => {
            const symbol = uniqueSymbol('noown')
            const result = await deployAndVerify(makeRequest({
                tokenDescription: { name: symbol, symbol, decimals: 6, type: 'standard', tokenMultiplier: '', iconUri: '', description: 'no owners' },
            }), ADMIN_KEYPAIR!)
            assertTokenAddressShape(result.id, symbol)

            const roles = new Roles(result.id)
            await expect(roles.getRole(sender)).resolves.toBe('master')
        })

        it('with tokenOwner === signer: signer keeps Master (no service-owner transfer)', async () => {
            const symbol = uniqueSymbol('selfown')
            const owners: Owners = {
                tokenOwner: sender, // intentionally the same address as signer
                walletRegistrarOwner: createWallet().toSuiAddress(),
            }
            const result = await deployAndVerify(makeRequest({
                tokenDescription: { name: symbol, symbol, decimals: 6, type: 'standard', tokenMultiplier: '', iconUri: '', description: 'self-owned' },
                owners,
            }), ADMIN_KEYPAIR!)

            const roles = new Roles(result.id)
            await expect(roles.getRole(sender)).resolves.toBe('master')
            await expect(roles.getRole(owners.walletRegistrarOwner)).resolves.toBe('transfer_agent')
        })
    })

    // ---------- 3. Compliance type variant ----------

    describe('compliance type variants', () => {
        it('whitelisted deploys successfully', async () => {
            const symbol = uniqueSymbol('wl')
            const result = await deployAndVerify(makeRequest({
                complianceType: 'whitelisted',
                tokenDescription: { name: symbol, symbol, decimals: 6, type: 'standard', tokenMultiplier: '', iconUri: '', description: 'whitelisted' },
            }), ADMIN_KEYPAIR!)
            assertTokenAddressShape(result.id, symbol)
        })
    })

    // ---------- 4. Rule registration variants ----------

    describe('compliance-rule registration variants', () => {
        it('with no complianceRules: zero rules registered on chain', async () => {
            const symbol = uniqueSymbol('norul')
            const result = await deployAndVerify(makeRequest({
                tokenDescription: { name: symbol, symbol, decimals: 6, type: 'standard', tokenMultiplier: '', iconUri: '', description: 'no rules' },
            }), ADMIN_KEYPAIR!)

            await expect(new AccreditedOnly(result.id).exists(sender)).resolves.toBe(false)
            await expect(new FlowbackRestriction(result.id).exists(sender)).resolves.toBe(false)
            await expect(new ForceFullTransfer(result.id).exists(sender)).resolves.toBe(false)
            await expect(new HoldingLimits(result.id).exists(sender)).resolves.toBe(false)
            await expect(new InvestorLimits(result.id).exists(sender)).resolves.toBe(false)
            await expect(new AuthorizedSecurities(result.id).exists(sender)).resolves.toBe(false)
            await expect(new BackdatingIssuance(result.id).exists(sender)).resolves.toBe(false)
            await expect(new LockupRestriction(result.id).exists(sender)).resolves.toBe(false)
        })

        it('with a single AccreditedOnly rule: only that rule is registered', async () => {
            const symbol = uniqueSymbol('one')
            const result = await deployAndVerify(makeRequest({
                tokenDescription: { name: symbol, symbol, decimals: 6, type: 'standard', tokenMultiplier: '', iconUri: '', description: 'one rule' },
                complianceRules: { forceAccredited: true },
            }), ADMIN_KEYPAIR!)

            await expect(new AccreditedOnly(result.id).exists(sender)).resolves.toBe(true)
            await expect(new FlowbackRestriction(result.id).exists(sender)).resolves.toBe(false)
            await expect(new InvestorLimits(result.id).exists(sender)).resolves.toBe(false)
            await expect(new LockupRestriction(result.id).exists(sender)).resolves.toBe(false)
            await expect(new HoldingLimits(result.id).exists(sender)).resolves.toBe(false)
            await expect(new BackdatingIssuance(result.id).exists(sender)).resolves.toBe(false)
            await expect(new ForceFullTransfer(result.id).exists(sender)).resolves.toBe(false)
            await expect(new AuthorizedSecurities(result.id).exists(sender)).resolves.toBe(false)
        })
    })

    // ---------- 5. Country compliance variant ----------

    describe('country compliance variants', () => {
        it('with no countries configured: get() returns "none" for arbitrary country', async () => {
            const symbol = uniqueSymbol('nocty')
            const result = await deployAndVerify(makeRequest({
                tokenDescription: { name: symbol, symbol, decimals: 6, type: 'standard', tokenMultiplier: '', iconUri: '', description: 'no countries' },
            }), ADMIN_KEYPAIR!)

            const cc = new CountryCompliance(result.id)
            await expect(cc.get('US', sender)).resolves.toBe('none')
            await expect(cc.get('JP', sender)).resolves.toBe('none')
        })
    })

    // ---------- 6. Metadata edge cases ----------

    describe('metadata edge cases', () => {
        it('decimals=0 is preserved on chain', async () => {
            const symbol = uniqueSymbol('dec0')
            const result = await deployAndVerify(makeRequest({
                tokenDescription: { name: symbol, symbol, decimals: 0, type: 'standard', tokenMultiplier: '', iconUri: '', description: 'zero decimals' },
            }), ADMIN_KEYPAIR!)
            const meta = await new DSToken(result.id).getMetadata(sender)
            expect(meta.decimals).toBe(0)
        })

        it('long description with unicode is preserved', async () => {
            const symbol = uniqueSymbol('uni')
            const desc = 'A security token with unicode: αβγ ✨ 漢字 — ' + 'x'.repeat(200)
            const result = await deployAndVerify(makeRequest({
                tokenDescription: { name: symbol, symbol, decimals: 6, type: 'standard', tokenMultiplier: '', iconUri: '', description: desc },
            }), ADMIN_KEYPAIR!)
            const meta = await new DSToken(result.id).getMetadata(sender)
            expect(meta.description).toBe(desc)
        })
    })

    // ---------- 7. Additional roles fan-out ----------

    describe('roles[] fan-out', () => {
        it('assigns each (address, role) in request.roles distinctly', async () => {
            const symbol = uniqueSymbol('multi')
            const issuerA = createWallet().toSuiAddress()
            const issuerB = createWallet().toSuiAddress()
            const exchangeA = createWallet().toSuiAddress()
            const taA = createWallet().toSuiAddress()

            const result = await deployAndVerify(makeRequest({
                tokenDescription: { name: symbol, symbol, decimals: 6, type: 'standard', tokenMultiplier: '', iconUri: '', description: 'multi-role' },
                roles: [
                    { address: issuerA, role: 'issuer' },
                    { address: issuerB, role: 'issuer' },
                    { address: exchangeA, role: 'exchange' },
                    { address: taA, role: 'transfer_agent' },
                ],
            }), ADMIN_KEYPAIR!)

            const roles = new Roles(result.id)
            await expect(roles.getRole(issuerA)).resolves.toBe('issuer')
            await expect(roles.getRole(issuerB)).resolves.toBe('issuer')
            await expect(roles.getRole(exchangeA)).resolves.toBe('exchange')
            await expect(roles.getRole(taA)).resolves.toBe('transfer_agent')
        })
    })

    // ---------- 8. Negative cases ----------

    describe('negative paths', () => {
        it('rejects unsupported lockManagerType before publishing', async () => {
            const req = makeRequest({
                lockManagerType: 'wallet', // not 'investor'
                tokenDescription: { name: 'nope', symbol: 'nope', decimals: 6, type: 'standard', tokenMultiplier: '', iconUri: '', description: '' },
            })
            await expect(createDSToken(req, ADMIN_KEYPAIR!)).rejects.toThrow(/not_implemented.*wallet/)
        })

        it('rejects unsupported complianceType before publishing', async () => {
            const req = makeRequest({
                complianceType: 'notRegulated', // not 'regulated' | 'whitelisted'
                tokenDescription: { name: 'nope2', symbol: 'nope2', decimals: 6, type: 'standard', tokenMultiplier: '', iconUri: '', description: '' },
            })
            await expect(createDSToken(req, ADMIN_KEYPAIR!)).rejects.toThrow(/not_implemented.*notRegulated/)
        })

        it('rejects an invalid Move identifier (symbol starting with a digit)', async () => {
            const req = makeRequest({
                tokenDescription: { name: '1bad', symbol: '1bad', decimals: 6, type: 'standard', tokenMultiplier: '', iconUri: '', description: '' },
            })
            await expect(createDSToken(req, ADMIN_KEYPAIR!)).rejects.toThrow(/not a valid Move identifier/)
        })

        it('two deployments with the same symbol produce distinct packages (no coin-registry collision)', async () => {
            // Each deployment publishes a fresh Move package, so the registered Currency<T>
            // type differs by packageId. The symbol is reused without conflict.
            const symbol = uniqueSymbol('dup')
            const first = await deployAndVerify(makeRequest({
                tokenDescription: { name: symbol, symbol, decimals: 6, type: 'standard', tokenMultiplier: '', iconUri: '', description: '' },
            }), ADMIN_KEYPAIR!)
            const second = await deployAndVerify(makeRequest({
                tokenDescription: { name: symbol, symbol, decimals: 6, type: 'standard', tokenMultiplier: '', iconUri: '', description: '' },
            }), ADMIN_KEYPAIR!)

            assertTokenAddressShape(first.id, symbol)
            assertTokenAddressShape(second.id, symbol)

            const firstPkg = first.id.split('::')[0]
            const secondPkg = second.id.split('::')[0]
            expect(firstPkg).not.toBe(secondPkg)
        })

        it('aborts when a roles[] entry conflicts with the signer who already holds Master', async () => {
            const symbol = uniqueSymbol('rolex')
            // Signer keeps Master (no `owners`), then roles[] re-assigns signer as Issuer.
            // On chain: trust_service::internal_assign_role aborts with EDirectRoleToRoleChange.
            const req = makeRequest({
                tokenDescription: { name: symbol, symbol, decimals: 6, type: 'standard', tokenMultiplier: '', iconUri: '', description: '' },
                roles: [{ address: sender, role: 'issuer' }],
            })
            await expect(createDSToken(req, ADMIN_KEYPAIR!)).rejects.toThrow(
                /EDirectRoleToRoleChange|Direct role to role change/
            )
        })
    })

    // ---------- 9. Address-owned objects (UpgradeCap distribution) ----------

    describe('on-chain object ownership', () => {
        it('transfers the UpgradeCap to tokenOwner when owners are specified, leaving signer with none', async () => {
            const symbol = uniqueSymbol('upown')
            const tokenOwner = createWallet().toSuiAddress()
            const req = makeRequest({
                tokenDescription: { name: symbol, symbol, decimals: 6, type: 'standard', tokenMultiplier: '', iconUri: '', description: '' },
                owners: { tokenOwner, walletRegistrarOwner: createWallet().toSuiAddress() },
            })
            const { id } = await deployAndVerify(req, ADMIN_KEYPAIR!)
            const packageId = id.split('::')[0]

            const ownerCaps = await findUpgradeCapsFor(tokenOwner, packageId)
            expect(ownerCaps.length).toBe(1)

            const senderCaps = await findUpgradeCapsFor(sender, packageId)
            expect(senderCaps.length).toBe(0)
        })

        it('leaves the UpgradeCap with the signer when no owners are specified', async () => {
            const symbol = uniqueSymbol('upself')
            const req = makeRequest({
                tokenDescription: { name: symbol, symbol, decimals: 6, type: 'standard', tokenMultiplier: '', iconUri: '', description: '' },
            })
            const { id } = await deployAndVerify(req, ADMIN_KEYPAIR!)
            const packageId = id.split('::')[0]

            const senderCaps = await findUpgradeCapsFor(sender, packageId)
            expect(senderCaps.length).toBe(1)
        })
    })

    // ---------- 10. Investor lifecycle ----------

    describe('investor lifecycle', () => {
        let tokenAddress: string
        let investors: Investors
        const investorId = 'inv-' + uniqueSymbol('id').slice(4)
        const walletA = createWallet().toSuiAddress()
        const walletB = createWallet().toSuiAddress()

        beforeAll(async () => {
            const symbol = uniqueSymbol('inv')
            const { id } = await deployAndVerify(makeRequest({
                tokenDescription: { name: symbol, symbol, decimals: 6, type: 'standard', tokenMultiplier: '', iconUri: '', description: '' },
            }), ADMIN_KEYPAIR!)
            tokenAddress = id
            investors = new Investors(tokenAddress)
        })

        it('registers a new investor and exposes empty defaults', async () => {
            const bytes = await investors.registerInvestor(investorId, sender)
            await SuiClient.executeMoveCallBytes(bytes, ADMIN_KEYPAIR!)

            await expect(investors.isInvestor(investorId, sender)).resolves.toBe(true)
            const details = await investors.getInvestorDetails(investorId)
            expect(details.id).toBe(investorId)
            expect(details.totalBalance).toBe('0')
            expect(details.wallets).toEqual([])
        })

        it('binds two wallets to the investor and persists them in order', async () => {
            for (const w of [walletA, walletB]) {
                const bytes = await investors.addWallet(investorId, w, sender)
                await SuiClient.executeMoveCallBytes(bytes, ADMIN_KEYPAIR!)
            }
            await expect(investors.isWallet(walletA, sender)).resolves.toBe(true)
            await expect(investors.isWallet(walletB, sender)).resolves.toBe(true)
            await expect(investors.getInvestorIdByWallet(walletA, sender)).resolves.toBe(investorId)
            await expect(investors.getInvestorIdByWallet(walletB, sender)).resolves.toBe(investorId)

            const details = await investors.getInvestorDetails(investorId)
            expect(details.wallets).toContain(walletA)
            expect(details.wallets).toContain(walletB)
        })

        it('rejects re-adding a wallet already bound to this investor', async () => {
            await expect(
                mustRevert(() => exec(investors.addWallet(investorId, walletA, sender)))
            ).rejects.toThrow(/EWalletAlreadyExists|already registered/)
        })
    })

    // ---------- 11. Token operations (issuance, transfer, burn) ----------

    describe('token operations: issue / transfer / burn', () => {
        let tokenAddress: string
        let dsToken: DSToken
        let investors: Investors
        // walletA MUST equal the signer's address: `account::send_balance` aborts
        // with ENotOwner if the signer is not the owner of the from-account.
        const walletA = sender
        const walletB = createWallet().toSuiAddress()

        beforeAll(async () => {
            const symbol = uniqueSymbol('ops')
            const { id } = await deployAndVerify(makeRequest({
                tokenDescription: { name: symbol, symbol, decimals: 6, type: 'standard', tokenMultiplier: '', iconUri: '', description: '' },
            }), ADMIN_KEYPAIR!)
            tokenAddress = id
            dsToken = new DSToken(tokenAddress)
            investors = new Investors(tokenAddress)
            await registerInvestorExplicit(tokenAddress, 'investorA', [walletA])
            await registerInvestorExplicit(tokenAddress, 'investorB', [walletB])
        })

        it('starts with zero total supply', async () => {
            await expect(dsToken.getTotalIssued()).resolves.toBe('0')
        })

        it('issues 1,000,000 to investorA and reflects it in supply + balances', async () => {
            await exec(dsToken.issueNoAccount(sender, walletA, 1_000_000n, 0, 'initial', [], [], Date.now()))
            await expect(dsToken.getTotalIssued()).resolves.toBe('1000000')
            const detailsA = await investors.getInvestorDetails('investorA')
            expect(detailsA.totalBalance).toBe('1000000')
        })

        it('issues another 250,000 to investorA — totals accumulate, not overwrite', async () => {
            await exec(dsToken.issueNoAccount(sender, walletA, 250_000n, 0, 'top-up', [], [], Date.now()))
            await expect(dsToken.getTotalIssued()).resolves.toBe('1250000')
            const detailsA = await investors.getInvestorDetails('investorA')
            expect(detailsA.totalBalance).toBe('1250000')
        })

        it('transfers 400,000 from investorA → investorB, updating both balances', async () => {
            await exec(dsToken.transfer(sender, walletA, walletB, 400_000n))
            const detailsA = await investors.getInvestorDetails('investorA')
            const detailsB = await investors.getInvestorDetails('investorB')
            expect(detailsA.totalBalance).toBe('850000')
            expect(detailsB.totalBalance).toBe('400000')
            // Total supply unchanged by transfer.
            await expect(dsToken.getTotalIssued()).resolves.toBe('1250000')
        })

        it('burns 200,000 from investorA — supply and balance both decrease', async () => {
            await exec(dsToken.burn(sender, walletA, 200_000n, 'audit'))
            await expect(dsToken.getTotalIssued()).resolves.toBe('1050000')
            const detailsA = await investors.getInvestorDetails('investorA')
            expect(detailsA.totalBalance).toBe('650000')
        })
    })

    // ---------- 12. Pause semantics ----------

    describe('pause / unpause', () => {
        let tokenAddress: string
        let dsToken: DSToken
        const walletA = sender // signer must own the from-account
        const walletB = createWallet().toSuiAddress()

        beforeAll(async () => {
            const symbol = uniqueSymbol('pse')
            const { id } = await deployAndVerify(makeRequest({
                tokenDescription: { name: symbol, symbol, decimals: 6, type: 'standard', tokenMultiplier: '', iconUri: '', description: '' },
            }), ADMIN_KEYPAIR!)
            tokenAddress = id
            dsToken = new DSToken(tokenAddress)
            await registerInvestorExplicit(tokenAddress, 'pA', [walletA])
            await registerInvestorExplicit(tokenAddress, 'pB', [walletB])
            await exec(dsToken.issueNoAccount(sender, walletA, 1_000_000n, 0, '', [], [], Date.now()))
        })

        it('starts unpaused', async () => {
            await expect(dsToken.isPaused(sender)).resolves.toBe(false)
        })

        it('pauses and exposes isPaused === true', async () => {
            await exec(dsToken.pause(sender))
            await expect(dsToken.isPaused(sender)).resolves.toBe(true)
        })

        it('investor↔investor transfer aborts while paused', async () => {
            await expect(
                mustRevert(() => exec(dsToken.transfer(sender, walletA, walletB, 100_000n)))
            ).rejects.toThrow(/ETreasuryPaused|paused/i)
        })

        it('unpauses and the same transfer now succeeds', async () => {
            await exec(dsToken.unpause(sender))
            await expect(dsToken.isPaused(sender)).resolves.toBe(false)
            await exec(dsToken.transfer(sender, walletA, walletB, 100_000n))
            const investors = new Investors(tokenAddress)
            const detailsB = await investors.getInvestorDetails('pB')
            expect(detailsB.totalBalance).toBe('100000')
        })
    })

    // ---------- 13. Seize via issuer wallet ----------

    describe('seize requires an issuer wallet destination', () => {
        let tokenAddress: string
        let dsToken: DSToken
        let wallets: Wallets
        // walletA holds the seized-from balance; using sender keeps the existing
        // pattern (issuance creates a PAS account here) so the clawback resolves.
        const walletA = sender
        const issuerWallet = createWallet().toSuiAddress()
        // Use a wallet that exists on chain as an investor wallet (has a PAS account)
        // but is NOT an issuer wallet — so the Move-side validate_seize aborts cleanly
        // instead of failing at SDK-side PAS account resolution.
        const regularInvestorWallet = createWallet().toSuiAddress()

        beforeAll(async () => {
            const symbol = uniqueSymbol('seize')
            const { id } = await deployAndVerify(makeRequest({
                tokenDescription: { name: symbol, symbol, decimals: 6, type: 'standard', tokenMultiplier: '', iconUri: '', description: '' },
            }), ADMIN_KEYPAIR!)
            tokenAddress = id
            dsToken = new DSToken(tokenAddress)
            wallets = new Wallets(tokenAddress)
            await registerInvestorExplicit(tokenAddress, 'seizeA', [walletA])
            await registerInvestorExplicit(tokenAddress, 'seizeC', [regularInvestorWallet])
            await exec(dsToken.issueNoAccount(sender, walletA, 1_000_000n, 0, '', [], [], Date.now()))
            // Give regularInvestorWallet a small balance so its PAS account exists.
            await exec(dsToken.issueNoAccount(sender, regularInvestorWallet, 1n, 0, '', [], [], Date.now()))
            await exec(wallets.addIssuerWallet(issuerWallet, sender))
        })

        it('reports the issuer wallet flag correctly', async () => {
            await expect(wallets.isIssuerWallet(issuerWallet, sender)).resolves.toBe(true)
            await expect(wallets.isIssuerWallet(regularInvestorWallet, sender)).resolves.toBe(false)
        })

        it('seizes 300,000 from investorA → issuer wallet, decreasing investor balance', async () => {
            await exec(dsToken.seize(sender, walletA, issuerWallet, 300_000n, 'regulatory'))
            const investors = new Investors(tokenAddress)
            const detailsA = await investors.getInvestorDetails('seizeA')
            expect(detailsA.totalBalance).toBe('700000')
            // Total supply unaffected by seize (tokens move, not burned).
            await expect(dsToken.getTotalIssued()).resolves.toBe('1000001')
        })

        it('aborts when the seize destination is not an issuer wallet', async () => {
            await expect(
                mustRevert(() => exec(dsToken.seize(sender, walletA, regularInvestorWallet, 50_000n, 'illegal dest')))
            ).rejects.toThrow(/ENotIssuerWallet|issuer/i)
        })
    })

    // ---------- 14. Lockup enforcement ----------

    describe('lockup restriction', () => {
        let tokenAddress: string
        let dsToken: DSToken
        const walletA = sender // signer must own from-account for transfer
        const walletB = createWallet().toSuiAddress()
        const farFuture = Date.now() + 10 * 365 * 24 * 60 * 60 * 1000 // +10y

        beforeAll(async () => {
            const symbol = uniqueSymbol('lock')
            const { id } = await deployAndVerify(makeRequest({
                tokenDescription: { name: symbol, symbol, decimals: 6, type: 'standard', tokenMultiplier: '', iconUri: '', description: '' },
                // Registering LockupRestriction is what activates per-issuance lock enforcement.
                complianceRules: { usLockPeriod: 0, nonUSLockPeriod: 0 },
            }), ADMIN_KEYPAIR!)
            tokenAddress = id
            dsToken = new DSToken(tokenAddress)
            await registerInvestorExplicit(tokenAddress, 'lockA', [walletA])
            await registerInvestorExplicit(tokenAddress, 'lockB', [walletB])
            // Issue 1,000,000 of which 600,000 is locked until far future.
            await exec(dsToken.issueNoAccount(
                sender, walletA, 1_000_000n, 0, 'partly-locked', [600_000n], [farFuture], Date.now()
            ))
        })

        it('rejects a transfer of an amount that exceeds the unlocked balance', async () => {
            // Unlocked = 1,000,000 - 600,000 = 400,000. Attempting 500,000 must fail.
            await expect(
                mustRevert(() => exec(dsToken.transfer(sender, walletA, walletB, 500_000n)))
            ).rejects.toThrow()
        })

        it('accepts a transfer that stays within the unlocked balance', async () => {
            await exec(dsToken.transfer(sender, walletA, walletB, 400_000n))
            const investors = new Investors(tokenAddress)
            const detailsB = await investors.getInvestorDetails('lockB')
            expect(detailsB.totalBalance).toBe('400000')
            const detailsA = await investors.getInvestorDetails('lockA')
            expect(detailsA.totalBalance).toBe('600000') // exactly the locked remainder
        })
    })

    // ---------- 15. Authorization failure ----------

    describe('authorization', () => {
        it('signer who lost Master cannot pause the token', async () => {
            const symbol = uniqueSymbol('auth')
            const newMaster = createWallet().toSuiAddress()
            const { id } = await deployAndVerify(makeRequest({
                tokenDescription: { name: symbol, symbol, decimals: 6, type: 'standard', tokenMultiplier: '', iconUri: '', description: '' },
                owners: { tokenOwner: newMaster, walletRegistrarOwner: createWallet().toSuiAddress() },
            }), ADMIN_KEYPAIR!)

            // Sanity check: original signer no longer holds Master.
            const roles = new Roles(id)
            await expect(roles.getRole(sender)).resolves.toBe('none')
            await expect(roles.getRole(newMaster)).resolves.toBe('master')

            // Attempting to pause as the (now unauthorized) original signer must abort.
            const dsToken = new DSToken(id)
            await expect(
                mustRevert(() => exec(dsToken.pause(sender)))
            ).rejects.toThrow(/ENotAuthorized|not authorized/i)
        })
    })

    // ---------- 16. Master role switch (setServiceOwner) ----------

    describe('master switch via setServiceOwner', () => {
        let tokenAddress: string
        let packageId: string
        const newMaster = createWallet().toSuiAddress()

        beforeAll(async () => {
            // Deploy with signer retaining Master (no `owners`), so we can test the
            // post-deployment transfer flow separately from the deployment-time owner setup.
            const symbol = uniqueSymbol('switch')
            const { id } = await deployAndVerify(makeRequest({
                tokenDescription: { name: symbol, symbol, decimals: 6, type: 'standard', tokenMultiplier: '', iconUri: '', description: '' },
            }), ADMIN_KEYPAIR!)
            tokenAddress = id
            packageId = id.split('::')[0]
        })

        it('starts with the signer as Master and owning the UpgradeCap', async () => {
            const roles = new Roles(tokenAddress)
            await expect(roles.getRole(sender)).resolves.toBe('master')
            const senderCaps = await findUpgradeCapsFor(sender, packageId)
            expect(senderCaps.length).toBe(1)
        })

        it('transfers Master + UpgradeCap to a new address via setServiceOwner', async () => {
            const roles = new Roles(tokenAddress)
            await exec(roles.setServiceOwner(newMaster, sender))

            await expect(roles.getRole(newMaster)).resolves.toBe('master')
            await expect(roles.getRole(sender)).resolves.toBe('none')

            const newMasterCaps = await findUpgradeCapsFor(newMaster, packageId)
            expect(newMasterCaps.length).toBe(1)
            const senderCapsAfter = await findUpgradeCapsFor(sender, packageId)
            expect(senderCapsAfter.length).toBe(0)
        })

        it('the demoted signer can no longer pause the token (lost Master ability)', async () => {
            const dsToken = new DSToken(tokenAddress)
            await expect(
                mustRevert(() => exec(dsToken.pause(sender)))
            ).rejects.toThrow(/ENotAuthorized|not authorized/i)
        })
    })

    // ---------- 17. Transfer-blocking compliance rules ----------
    //
    // Each rule gets its own deployment so failures point at the exact rule under test.
    // Pattern: deploy with the rule registered → set up two investors with relevant attributes
    // → issue → attempt the violating transfer (must abort) → attempt a compliant transfer
    // (must succeed). walletA = sender so the signer owns the from-account.

    describe('transfer compliance rules', () => {
        // ----- HoldingLimits: max -----
        describe('HoldingLimits — max', () => {
            let dsToken: DSToken
            let investors: Investors
            const walletA = sender
            const walletB = createWallet().toSuiAddress()

            beforeAll(async () => {
                const symbol = uniqueSymbol('hmax')
                const { id } = await deployAndVerify(makeRequest({
                    tokenDescription: { name: symbol, symbol, decimals: 6, type: 'standard', tokenMultiplier: '', iconUri: '', description: '' },
                    complianceRules: {
                        minimumHoldingsPerInvestor: '0',
                        maximumHoldingsPerInvestor: '1000',
                    },
                }), ADMIN_KEYPAIR!)
                dsToken = new DSToken(id)
                investors = new Investors(id)
                await registerInvestorExplicit(id, 'hmaxA', [walletA])
                await registerInvestorExplicit(id, 'hmaxB', [walletB])
                // Leave headroom — the max check is inclusive (issuing balance==max aborts).
                // A=700, B=800; both strictly under max(1000).
                await exec(dsToken.issueNoAccount(sender, walletA, 700n, 0, '', [], [], Date.now()))
                await exec(dsToken.issueNoAccount(sender, walletB, 800n, 0, '', [], [], Date.now()))
            })

            it('blocks a transfer that would push the recipient over maximumHoldingsPerInvestor', async () => {
                // B(800) + 300 = 1100 > max(1000) → must abort.
                await expect(
                    mustRevert(() => exec(dsToken.transfer(sender, walletA, walletB, 300n)))
                ).rejects.toThrow(/EAboveMaxHolding|maximum/i)
            })

            it('accepts a transfer that keeps the recipient strictly below the max', async () => {
                // B(800) + 100 = 900 < max(1000) → must succeed.
                await exec(dsToken.transfer(sender, walletA, walletB, 100n))
                const detailsB = await investors.getInvestorDetails('hmaxB')
                expect(detailsB.totalBalance).toBe('900')
            })
        })

        // ----- HoldingLimits: min -----
        describe('HoldingLimits — min', () => {
            let dsToken: DSToken
            const walletA = sender
            const walletB = createWallet().toSuiAddress()

            beforeAll(async () => {
                const symbol = uniqueSymbol('hmin')
                const { id } = await deployAndVerify(makeRequest({
                    tokenDescription: { name: symbol, symbol, decimals: 6, type: 'standard', tokenMultiplier: '', iconUri: '', description: '' },
                    complianceRules: {
                        minimumHoldingsPerInvestor: '500',
                        maximumHoldingsPerInvestor: '10000',
                    },
                }), ADMIN_KEYPAIR!)
                dsToken = new DSToken(id)
                await registerInvestorExplicit(id, 'hminA', [walletA])
                await registerInvestorExplicit(id, 'hminB', [walletB])
                // A=2000, B=1000; both above the min.
                await exec(dsToken.issueNoAccount(sender, walletA, 2_000n, 0, '', [], [], Date.now()))
                await exec(dsToken.issueNoAccount(sender, walletB, 1_000n, 0, '', [], [], Date.now()))
            })

            it('blocks a transfer that would leave the sender below minimumHoldingsPerInvestor (and non-zero)', async () => {
                // A(2000) - 1700 = 300 < min(500) and != 0 → must abort.
                await expect(
                    mustRevert(() => exec(dsToken.transfer(sender, walletA, walletB, 1_700n)))
                ).rejects.toThrow()
            })
        })

        // ----- ForceFullTransfer -----
        describe('ForceFullTransfer', () => {
            let dsToken: DSToken
            let investors: Investors
            const walletA = sender
            const walletB = createWallet().toSuiAddress()

            beforeAll(async () => {
                const symbol = uniqueSymbol('full')
                const { id } = await deployAndVerify(makeRequest({
                    tokenDescription: { name: symbol, symbol, decimals: 6, type: 'standard', tokenMultiplier: '', iconUri: '', description: '' },
                    complianceRules: {
                        forceFullTransfer: false,
                        worldWideForceFullTransfer: true, // applies to all transfers
                    },
                }), ADMIN_KEYPAIR!)
                dsToken = new DSToken(id)
                investors = new Investors(id)
                await registerInvestorExplicit(id, 'fullA', [walletA])
                await registerInvestorExplicit(id, 'fullB', [walletB])
                await exec(dsToken.issueNoAccount(sender, walletA, 1_000n, 0, '', [], [], Date.now()))
            })

            it('blocks a partial transfer when force-full is on', async () => {
                await expect(
                    mustRevert(() => exec(dsToken.transfer(sender, walletA, walletB, 500n)))
                ).rejects.toThrow()
            })

            it('accepts a transfer of the full balance', async () => {
                await exec(dsToken.transfer(sender, walletA, walletB, 1_000n))
                const detailsB = await investors.getInvestorDetails('fullB')
                expect(detailsB.totalBalance).toBe('1000')
                const detailsA = await investors.getInvestorDetails('fullA')
                expect(detailsA.totalBalance).toBe('0')
            })
        })

        // ----- AccreditedOnly -----
        describe('AccreditedOnly', () => {
            let dsToken: DSToken
            let investors: Investors
            const walletA = sender
            const walletB = createWallet().toSuiAddress()

            beforeAll(async () => {
                const symbol = uniqueSymbol('accr')
                const { id } = await deployAndVerify(makeRequest({
                    tokenDescription: { name: symbol, symbol, decimals: 6, type: 'standard', tokenMultiplier: '', iconUri: '', description: '' },
                    complianceRules: { forceAccredited: true },
                }), ADMIN_KEYPAIR!)
                dsToken = new DSToken(id)
                investors = new Investors(id)
                // Register A as accredited and B as non-accredited.
                await exec(investors.registerInvestor('accrA', sender))
                await exec(investors.addWallet('accrA', walletA, sender))
                await exec(investors.updateInvestor('accrA', '', [], [
                    { name: 2 /* ACCREDITED */, status: 1 /* APPROVED */, expiry: 0 },
                ], sender))
                await exec(investors.registerInvestor('accrB', sender))
                await exec(investors.addWallet('accrB', walletB, sender))
                // B has no accredited attribute.
                await exec(dsToken.issueNoAccount(sender, walletA, 1_000n, 0, '', [], [], Date.now()))
            })

            it('blocks a transfer to a non-accredited investor when forceAccredited is on', async () => {
                await expect(
                    mustRevert(() => exec(dsToken.transfer(sender, walletA, walletB, 100n)))
                ).rejects.toThrow()
            })
        })
    })
})
