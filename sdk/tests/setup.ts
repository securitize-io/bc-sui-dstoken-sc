import { PublishSingleton, Config } from '../src'
import fs from 'fs'
import path from 'path'

beforeAll(async () => {
    PublishSingleton.cleanPubFile()
    const publishedToml = path.join(Config.vars.PACKAGE_PATH, 'Published.toml')
    if (fs.existsSync(publishedToml)) {
        fs.unlinkSync(publishedToml)
    }
})
