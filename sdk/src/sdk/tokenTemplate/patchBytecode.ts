import { update_identifiers } from '@mysten/move-bytecode-template'

export type PatchedTokenTemplate = {
    /** Patched Move bytecode ready to hand to `tx.publish`. */
    bytecode: Uint8Array
    /** Lowercased symbol — becomes the on-chain module name. */
    moduleName: string
    /** Capitalized symbol — becomes the on-chain struct (type) name. */
    structName: string
}

/**
 * Patch the placeholder identifiers in the compiled `token_template` bytecode
 * so the published package exposes a unique module + type per deployment.
 *
 * The keys passed to `update_identifiers` are the *current* identifiers in
 * the compiled bytecode (`token_template` and `TOKEN_TEMPLATE`), regardless
 * of what we want to rename them to. Both must be passed in a single call so
 * the patched binary remains internally consistent.
 *
 * No `update_constants` call is needed: token metadata (name, symbol, decimals,
 * description, icon URL) still flows as runtime arguments to `create_ds_token`,
 * so nothing is baked into the constant pool.
 */
export function patchTokenTemplate(
    bytecode: Uint8Array,
    tokenSymbol: string
): PatchedTokenTemplate {
    const moduleName = tokenSymbol.toLowerCase()
    const structName =
        tokenSymbol.charAt(0).toUpperCase() + tokenSymbol.slice(1).toLowerCase()

    // Move identifiers must match [a-zA-Z_][a-zA-Z0-9_]*. Validating here
    // surfaces a clear error before we attempt to publish a malformed package.
    if (!/^[a-z_][a-z0-9_]*$/.test(moduleName)) {
        throw new Error(
            `Invalid token symbol "${tokenSymbol}": lowercased form "${moduleName}" is not a valid Move identifier`
        )
    }

    const patched = update_identifiers(bytecode, {
        token_template: moduleName,
        TOKEN_TEMPLATE: structName,
    })

    return { bytecode: patched, moduleName, structName }
}
