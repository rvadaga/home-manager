* **this repo is personal - never include work-specific content.** no employer names, internal hostnames, project names, team names, or any other work-identifying details in any file under `~/.config/home-manager/`. use generic placeholders in examples (e.g. `example.com`, `my-project`, `corp-cluster`). work config lives in `~/.config/work-home-manager/` exclusively.

# google docs / drive api access (personal)

free rest api access to google docs + drive is set up on the personal google account (rahul.vadaga@gmail.com; gcloud project `rvadaga-default-project`, docs + drive apis enabled, no billing). use it to create/edit native google docs programmatically. personal mac only.

* oauth client (desktop app) secret: `~/.config/secrets/gcloud-docs-oauth-client.json` (perms 600); the secret file itself is never committed.
* every rest call: `Authorization: Bearer $(gcloud auth application-default print-access-token)` + header `X-Goog-User-Project: rvadaga-default-project`.
* re-auth after the ~7-day testing-mode token expiry: `gcloud auth application-default login --client-id-file=~/.config/secrets/gcloud-docs-oauth-client.json --scopes=https://www.googleapis.com/auth/documents,https://www.googleapis.com/auth/drive.file,https://www.googleapis.com/auth/cloud-platform`
* auth gotchas: plain gcloud adc login is blocked for docs/drive scopes ("app is blocked") — must pass the own-client `--client-id-file`; and the oauth consent screen must list your email as a test user (owner ≠ test user).
* creating / formatting / editing docs: use the `editing-google-docs` skill (html-import creation, cleaning up import artifacts, verify-by-rendering). this note is just the personal access/auth facts.
