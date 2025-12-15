import {createTestToken} from "../../tests/test_utils";

export async function deployToken() {
    await createTestToken()
}

deployToken().then()