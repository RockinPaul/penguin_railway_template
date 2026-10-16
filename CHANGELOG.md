# Changelog

## 2026-10-16 — PenguinHarness 0.2.16

- `PENGUIN_VERSION` 0.2.11 → 0.2.16 (`hiyouga/penguinharness:0.2.16`). The wrapper is unchanged: upstream's entrypoint, user and data root are the same.
- **Security fix: model keys no longer leak to gateways (0.2.15).** A model entry with no `api_key` used to fall back to `OPENAI_API_KEY` / `ANTHROPIC_API_KEY` from the environment whatever its base URL, so a keyless row in a gateway group (OpenRouter, TokenDance, `custom`, `vllm` and similar) sent your own vendor key to that gateway. Environment keys now apply only to the vendor's own endpoint. This template sets no provider keys; if you added them as service variables for a gateway row, give that row its own key on the Models page.
- Also security-related: sign-in gates are mounted on each protected route group (a path no group serves answers 404 instead of 401), a sign-in for an unknown username costs the same as for a known one, and a revoked session lands on the login page.
- Since 0.2.13, a failed or used-up sign-in link redirects to the login page instead of answering 401. It still sets no session.

### Upgrading an existing deployment

Back up the volume first; some upgrades rewrite files on it once and cannot be undone:

- A project's `.project_config.toml` is rewritten on its first read when it stores a model `client_type` the new model layer no longer accepts, or a base URL or key that the rows of a group share (moved to the group's `[providers.<id>]`).
- The data root's `plugins.json` is no longer read; each Project asks for its plugins again on the Plugins page.
- Tickets still in the old `# Ticket:` header format are reported as invalid.
- CLI session commands moved under `penguin session` (`ls`, `log`, `input`).

Verified locally with the template's Dockerfile and entrypoint: a 0.2.11 volume with a project and a file in it upgraded in place, the generated admin password still signed in and a wrong one got 401, the project and its file were there, the server ran as uid 1000, routes answered 401 without a session, and the session cookie stayed `HttpOnly; Secure; SameSite=Lax` behind an HTTPS proxy. Rotating `PENGUIN_SEED_ADMIN_PASSWORD` while the password is still the generated one still prints a one-time claim link and keeps the old password valid. A fresh 0.2.16 deploy creates the admin account on first boot and prints no claim link, and the container still refuses to start without the variable.
