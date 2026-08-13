# Code Signing with SignPath Foundation (free for OSS)

SignPath Foundation signs Windows executables **for free** for open source projects
(`https://signpath.org`). Their certificate is stored on an HSM — you never hold a
private key — and their GitHub App verifies the binary was built from your public
repository before signing.

Win-Optimizer-Pro ships with a ready-to-use signing workflow
(`.github/workflows/sign.yml`). You only need to apply once and add the secrets.

## Why sign?

Without a certificate, Windows shows the "Unknown publisher" SmartScreen warning on
every fresh download. A signed installer shows `SignPath Foundation` as publisher and
removes the "Unrecognized app" prompt for most users.

## 1. Apply to the SignPath Foundation

Requirements:

- Public repository with an OSI-approved license (this repo: MIT) ✔
- Public GitHub Actions CI (this repo: `.github/workflows/ci.yml`) ✔
- Installer published as a free GitHub Release ✔
- Repository must not contain malware or security-circumvention code

Apply at: https://signpath.org/foundation/application (select "GitHub.com" as the
trusted build system). Approval usually takes a few days.

## 2. Create the SignPath project & policy

Once approved, in the SignPath.io console:

1. Add the **GitHub.com** trusted build system and install the **SignPath GitHub App**
   on `karan5028ji/Win-Optimizer-Pro`.
2. Create a **project** for this repo and link the GitHub connector to it.
3. Create a **signing policy** for releases.
4. Copy the **Organization ID**, **Project slug**, and **Signing policy slug**.

## 3. Add repository secrets

Settings → Secrets and variables → Actions:

| Secret | Value |
| --- | --- |
| `SIGNPATH_API_TOKEN` | An API token from SignPath.io (submitter permission) |
| `SIGNPATH_ORGANIZATION_ID` | Your SignPath organization ID |
| `SIGNPATH_PROJECT_SLUG` | Your SignPath project slug |
| `SIGNPATH_SIGNING_POLICY_SLUG` | Your signing policy slug |

## 4. Sign a release

After publishing a release (e.g. `v2.1.4`), run the **Sign Release (SignPath)**
workflow manually with that tag. It downloads the unsigned installer from the
release, submits it to SignPath, re-signs the Tauri updater `.sig` over the now
signed bytes, and uploads the signed installer back to the same release.

```text
Actions → Sign Release (SignPath) → Run workflow → enter tag → Run
```

The signing workflow only runs the SignPath steps when the secrets above exist, so
releases remain buildable even before signing is configured.

## Notes

- Only run the signing workflow on a **tagged release** — not on the default branch.
- The updater `.sig` must cover the exact shipped bytes, which is why the workflow
  re-signs it after Authenticode signing.
- Do not commit any signing credentials to the repository.
