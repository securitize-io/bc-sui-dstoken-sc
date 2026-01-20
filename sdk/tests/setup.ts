import {PublishSingleton} from "../src";
import {deployPas} from "../src/sdk/deploy_pas";


beforeAll(async () => {
    PublishSingleton.cleanPubFile()
    await deployPas() // TODO: Delete when pas is deployed in MVR
})
