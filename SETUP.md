# One-time release setup (maintainer)

The app builds and runs out of the box. These steps are needed **once** for the auto-update + automated-release pipeline to function. They require secrets and repo settings, so they can't be automated.

## 1. Generate Sparkle EdDSA keys

Sparkle signs every released zip with an EdDSA private key. The matching public key is embedded in the app's `Info.plist` so installed copies can verify an update is authentic.

Download Sparkle's tools (match the version in `.github/workflows/release.yml`):

```sh
SPARKLE_VERSION=2.9.3
curl -sL "https://github.com/sparkle-project/Sparkle/releases/download/$SPARKLE_VERSION/Sparkle-$SPARKLE_VERSION.tar.xz" \
  | tar -xJ -C /tmp/
```

Generate a key pair:

```sh
/tmp/Sparkle-*/bin/generate_keys
```

This prints the **public key** to stdout and stores the **private key** in your login Keychain. Copy the public key into:

- `Sources/Modelbox/Resources/Info.plist.template` → replace the placeholder value of `SUPublicEDKey` (currently `REPLACE_WITH_SPARKLE_PUBLIC_KEY`).

Export the private key for CI:

```sh
/tmp/Sparkle-*/bin/generate_keys -x sparkle-private-key.txt
```

Copy the entire file contents and add it as a **GitHub Actions secret** named `SPARKLE_ED_PRIVATE_KEY` on this repo. Then delete the local copy:

```sh
rm sparkle-private-key.txt
```

> **Keep the private key safe.** If you lose it, currently-installed copies can no longer auto-update - they'll reject updates signed by any other key, and users would have to manually install a new build carrying a new `SUPublicEDKey`.

## 2. Enable GitHub Pages

`appcast.xml` (Sparkle's manifest) is served from this repo's `docs/` folder via GitHub Pages.

- Settings → Pages
- Source: **Deploy from a branch**
- Branch: `main` / folder `/docs`
- Save

The appcast URL becomes `https://mmurakaru.github.io/modelbox/appcast.xml` - which matches `SUFeedURL` in `Info.plist.template`.

## 3. Confirm the CI runner can build for macOS 26

The app targets macOS 26 / Swift 6.2. `release.yml` runs on `macos-15` and selects the newest installed Xcode, but a GitHub-hosted image only builds this successfully once it ships an Xcode with the **macOS 26 SDK and a Swift 6.2 toolchain**. Until then, either:

- pin the workflow to a runner image that includes it, or
- use a self-hosted macOS 26 runner.

Validate by pushing a throwaway pre-release tag and watching the `Release` workflow build `make bundle`.

## 4. (Optional) Make the first changeset

```sh
npm install
npx changeset
```

Pick a bump type and write a summary. Commit the resulting `.changeset/*.md` file. From here on, every PR with a user-visible change should ship with a changeset.

---

## How the pipeline runs end-to-end

1. PR ships with a changeset → merge to `main`.
2. `.github/workflows/changesets.yml` opens a "release" PR that bumps `package.json` + `Info.plist.template` (via `scripts/sync-version.mjs`) and updates `CHANGELOG.md`.
3. Maintainer merges that PR → changesets creates a `vX.Y.Z` tag.
4. Tag push fires `.github/workflows/release.yml`:
   - `make bundle` produces `Modelbox.app`
   - Sparkle-signs the zip with `SPARKLE_ED_PRIVATE_KEY`
   - `gh release create` uploads the signed zip
   - `scripts/append-appcast.mjs` adds a new `<item>` to `docs/appcast.xml`
   - commits the appcast back to `main`
5. Pages serves the new appcast within ~30 seconds.
6. Installed apps see the new version on their next daily check, or via Settings → Updates → "Check for Updates…".
