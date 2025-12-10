# Publishing Guide

This SDK uses [Changesets](https://github.com/changesets/changesets) for version management and publishing to private npm registries.

## Setup

Set your authentication token as an environment variable:
   ```bash
   export NPM_TOKEN=your_api_token_here
   ```

## Workflow

### 1. Create a changeset

When you make changes, create a changeset to document them:

```bash
pnpm changeset
```

This will prompt you to:
- Select the type of change (patch, minor, major)
- Write a summary of the changes

### 2. Version the package

When ready to release, update the version based on changesets:

```bash
pnpm run version
```

This will:
- Consume all changesets
- Update the package version in `package.json`
- Update the CHANGELOG.md

### 3. Publish to registry

Publish the package to your private registry:

```bash
NPM_TOKEN=your_token pnpm publish
```

This will:
- Build the package
- Publish to the configured registry

## Quick Commands

- `pnpm changeset` - Create a new changeset
- `pnpm version` - Apply changesets and bump version
- `pnpm release` - Build and publish to registry
- `pnpm build` - Build the package only
- `pnpm dev` - Build in watch mode

## Example Workflow

```bash
# 1. Make your changes to the code
# ...

# 2. Create a changeset
pnpm changeset
# Choose "patch" for bug fixes, "minor" for features, "major" for breaking changes
# Write a description of your changes

# 3. Commit the changeset
git add .
git commit -m "Add new feature"

# 4. When ready to release, version the package
pnpm version

# 5. Commit the version bump
git add .
git commit -m "Version bump"

# 6. Publish
NPM_TOKEN=your_token pnpm release

# 7. Push to git
git push
```

## Publishing to Different Registries

### GitHub Packages

```bash
# .npmrc
registry=https://npm.pkg.github.com
//npm.pkg.github.com/:_authToken=${NPM_TOKEN}
```

### npm Registry

```bash
# .npmrc
registry=https://registry.npmjs.org/
//registry.npmjs.org/:_authToken=${NPM_TOKEN}
```

### Custom Private Registry

```bash
# .npmrc
registry=https://your-registry.com
//your-registry.com/:_authToken=${NPM_TOKEN}
```
