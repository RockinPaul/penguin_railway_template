# PenguinHarness on Railway

[PenguinHarness](https://github.com/Prism-Shadow/penguin-harness) — an open-source multi-agent
platform where agents build, evaluate and optimize agent applications — running on Railway with its
whole data root on a volume, behind an admin password generated for your deployment.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/penguinharness)

## Service

| Service | Base | Public | Role |
|---|---|---|---|
| `penguin` | `hiyouga/penguinharness:0.2.11` | **yes** | The whole platform: web app, agent runtime, projects, terminals, traces. |

One service, one volume, no sidecar. The image is upstream's own, unmodified apart from the
environment and a guard in front of its entrypoint.

## Variables

| Variable | Default | Purpose |
|---|---|---|
| `PENGUIN_SEED_ADMIN_PASSWORD` | generated, 24 chars | Password for the built-in `admin` account, created on the first boot. Read it from the service variables after deploying. |
| `PORT` | `8080` | The port Railway's healthcheck probes and the domain targets. Leave it alone. |
| `HOST` | `::` | Baked. A dual-stack listener, so no relay is needed in front. |
| `PENGUIN_HOME` | `/data` | Baked. The data root, on the volume. |
| `PENGUIN_TRUST_PROXY` | `1` | Baked. Marks the session cookie `Secure` behind Railway's TLS edge. |
| `PENGUIN_UPDATE_CHECK` | `off` | Baked. The image is pinned, so an in-container update has nowhere to land. |

The deploy form asks for nothing you have to invent.

## First run

1. Copy `PENGUIN_SEED_ADMIN_PASSWORD` from the service's **Variables** tab.
2. Open the public domain and sign in as **`admin`**.
3. Add a model provider key from the **Models** page — any built-in preset, or any OpenAI-protocol
   endpoint. It is stored on the volume.

Change the admin password from the app once you are in. After that the claim-link path below is
closed permanently, and the variable no longer matters.

## Security

**The admin password is the point of this wrapper.** PenguinHarness authenticates everything except
its install probe, so it is not open by default — but with no password configured it generates a
random one and prints a claim link to the container log. On a laptop that is fine. On a public URL
it means the only way in is to read a deploy log, and until somebody does, the account is unclaimed.

So the password is a per-deployment `${{secret(24)}}`, the account is created and closed during the
first boot, and the container exits rather than start if the variable is missing or shorter than 12
characters. There is no path to a deployment in the weaker state.

Measured against a running instance, not taken from the docs:

- Every API route except `/api/install` returns **401** without a session — projects, sessions,
  settings, admin users, terminals.
- Sign-in returns **401** on a wrong password and **200** on the generated one. Failures are
  throttled per username with an exponentially growing delay, applied to unknown usernames too, so
  the endpoint is not a user-existence oracle.
- The session cookie comes back `HttpOnly; Secure; SameSite=Lax` with a 30-day lifetime.
- `/api/auth/claim` returns **401** with no token and with a wrong one.
- Upstream hashes the password with scrypt and rejects a short one *before* any insert, so a
  configuration typo cannot create a weak privileged account.

The honest caveat: this is an agent platform with terminals and a filesystem. The blast radius of the
URL is a shell in this container. Keep the generated password, and treat the link accordingly.

**One edge worth knowing.** While the admin password is still the one the template generated, a boot
whose configured value no longer matches the stored hash prints a one-time claim link to the deploy
log. That is an escape hatch, not a hole: rotating the variable leaves you a way in rather than
locking you out, and once you change the password in the app no claim link is ever minted again.

## What persists

The volume at `/data` is the entire data root: `web.db` (SQLite), the project workspaces, traces,
sessions, installed plugins, model credentials and the local API token. Verified by replacing the
container — the installation id, the written files and the sign-in all survived.

## Why it is shaped this way

- **Upstream's image, unmodified.** Its entrypoint already chowns only the top level of the data
  root, tolerates a mount that refuses chown, and `setpriv`s to uid 1000 *in place*, so tini keeps
  the server as its direct child and SIGTERM reaches it without a relay. There was nothing to
  improve, so the wrapper only adds the password guard in front.
- **`HOST=::` with no relay.** Node binds dual-stack on `::` — measured, one socket in `tcp6` with
  no separate v4 listener, and both `127.0.0.1` and `[::1]` answer — so unlike the Python services in
  this portfolio, no `socat` is needed.
- **`PORT` is a real variable.** Railway's healthcheck probes the port named by `PORT`, not the
  domain's target port, and the server reads it directly.
- **Healthcheck on `/api/install`.** Public by design, needs no session, returns only an
  installation id, and answers 200 with Railway's `Host: healthcheck.railway.app`.
- **`restartPolicyType: ALWAYS`.** A clean `SIGTERM` exits `0`, which `ON_FAILURE` would not restart.

## Upgrading

Bump `PENGUIN_VERSION` in the `Dockerfile` and push. Tags are multi-platform manifests covering
`linux/amd64` and `linux/arm64`; `latest` follows main, so pin a release deliberately.

## Licences

PenguinHarness is
[Apache-2.0](https://github.com/Prism-Shadow/penguin-harness/blob/main/LICENSE). The glue in this
repository is MIT.
