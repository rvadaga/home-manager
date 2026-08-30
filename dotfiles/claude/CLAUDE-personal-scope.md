* **this repo is personal - never include work-specific content.** no employer names, internal hostnames, project names, team names, or any other work-identifying details in any file under `~/.config/home-manager/`. use generic placeholders in examples (e.g. `example.com`, `my-project`, `corp-cluster`). work config lives in `~/.config/work-home-manager/` exclusively.

# google docs / drive api access (personal)

free rest api access to google docs + drive is set up on the personal google account (rahul.vadaga@gmail.com; gcloud project `rvadaga-default-project`, docs + drive apis enabled, no billing). use it to create/edit native google docs programmatically. personal mac only.

* oauth client (desktop app) secret: `~/.config/secrets/gcloud-docs-oauth-client.json` (perms 600); the secret file itself is never committed.
* every rest call: `Authorization: Bearer $(gcloud auth application-default print-access-token)` + header `X-Goog-User-Project: rvadaga-default-project`.
* re-auth after the ~7-day testing-mode token expiry: `gcloud auth application-default login --client-id-file=~/.config/secrets/gcloud-docs-oauth-client.json --scopes=https://www.googleapis.com/auth/documents,https://www.googleapis.com/auth/drive.file,https://www.googleapis.com/auth/cloud-platform`
* auth gotchas: plain gcloud adc login is blocked for docs/drive scopes ("app is blocked") — must pass the own-client `--client-id-file`; and the oauth consent screen must list your email as a test user (owner ≠ test user).
* creating / formatting / editing docs: use the `editing-google-docs` skill (html-import creation, cleaning up import artifacts, verify-by-rendering). this note is just the personal access/auth facts.

# x api mcp

the `xapi` mcp server uses the nix-managed `xurl-mcp mcp https://api.x.com/mcp` bridge. its patch coordinates oauth2 refresh across concurrent claude and codex processes, reloads the shared token after taking the lock, replaces the auth file atomically, and opens a browser only when no token exists. the token is cached in `~/.xurl` and authorized as @rahul_vadaga.

* app credentials (client id + secret + app-only bearer token) are cached at `~/.config/secrets/x-mcp-oauth-client.env` (export lines, perms 600; never committed). the bearer token is also registered in xurl's local store through `xurl-mcp auth app-only -`, which reads the token from stdin.
* if the user-context token is ever revoked, re-auth with:
  ```bash
  source ~/.config/secrets/x-mcp-oauth-client.env && xurl-mcp auth oauth2
  ```
* full-archive post search is the exception: the hosted mcp's `search_posts_all` tool requires app-only auth and rejects the bridge's user-context token. the other tools use user-context auth. run the full-archive request from bash instead of adding a second mcp server, which would persist the token in settings.local.json:
  ```bash
  xurl-mcp --auth app "/2/tweets/search/all?query=<url-encoded>&max_results=10"
  ```
  keep `max_results` low because the api charges per post returned. set a spending limit in the developer console.
* the app-only bearer token comes from the developer console's app-only authentication section. if it is lost, regenerate it there, then register it in xurl's store from the secrets cache.
* the `x-docs` server at https://docs.x.com/mcp needs no auth.
