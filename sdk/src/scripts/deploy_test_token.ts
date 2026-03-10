import {createTestToken} from "../../tests/test_utils";

export async function deployToken() {
    const tokenId = await createTestToken()
    return `Token deployed with tokenAddress: ${tokenId}`
}

deployToken().then(console.log).catch(console.error)