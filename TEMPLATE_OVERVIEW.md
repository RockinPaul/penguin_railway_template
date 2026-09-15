# Deploy and Host PenguinHarness on Railway

[PenguinHarness](https://github.com/Prism-Shadow/penguin-harness) is an open-source multi-agent
platform for building agent applications: you describe what you want in a sentence, and its agents
scaffold, write, evaluate and optimize the app, with every model request visible in a Trace view.
It is normally a local-first desktop or CLI tool.

This template runs the same server on Railway with its whole data root on a volume, behind an admin
account whose password is generated for your deployment. One service, one volume, a public domain,
and nothing to fill in on the deploy form.

## About Hosting PenguinHarness

The server is one Node process that serves the web app, the agent runtime, the project workspaces,
the terminals and the SQLite database underneath them. Everything it owns lives in a single data
root, so putting a volume at `/data` is the whole persistence story: projects, traces, sessions,
installed plugins, model credentials and the agent's own working tree.

Authentication is on by default here, which is worth stating plainly because it is unusual. Every
route except the install probe answers 401 without a session. What upstream does when no password is
configured is print a one-time claim link to the container log, which is a sensible default on a
laptop and a poor one on a public URL. So this template generates the admin password instead and the
container refuses to start without one — the account exists the moment the first deploy finishes,
and the credential is in the Variables tab rather than in a log line.

Models are yours to choose. The app ships presets for DeepSeek, Kimi, GLM, Qwen, GPT, Gemini, Claude
and others, and any OpenAI-protocol endpoint works, so nothing is proxied through a third party. You
add a key from the Models page after signing in, and it is stored on the volume.

## Why Deploy PenguinHarness on Railway?

- **The agents keep working when you close your laptop.** Long optimization runs and benchmark loops
  are exactly the workload that should not live on a machine that sleeps.
- **One service, no assembly.** No database, no queue, no second container — SQLite on the volume.
- **Reachable from anywhere.** The same workspace from a desktop browser, a phone, or a borrowed
  machine, rather than one computer.
- **A real Linux box to build in.** The agents get a persistent workspace with `git` and `curl`, on
  a host that is already the kind of environment the apps they write will run on.
- **It survives redeploys.** Projects, traces, plugins and credentials are all on the volume.

## Common Use Cases

- Turning a one-sentence description into a runnable agent application, then iterating on it from
  anywhere.
- Long self-evolution runs: an agent benchmarks itself, finds the lost points and ships the next
  version, with a snapshot before every round.
- A shared team workspace where agent projects, traces and skills outlive any one laptop.
- Data-analysis and research agents that need to keep running for hours against your own model keys.
- A hosted place to try the built-in plugin suites — software development, agent development, agent
  company — without installing anything locally.

## Dependencies for PenguinHarness Hosting

- An API key for at least one model provider. Any OpenAI-protocol endpoint works, alongside the
  built-in presets.
- Nothing else: no database, no external services, no accounts.

### Deployment Dependencies

- Upstream project: <https://github.com/Prism-Shadow/penguin-harness> (Apache-2.0), image
  `hiyouga/penguinharness:0.2.11`.
- Upstream documentation: <https://penguin.ooo/docs/>.
- Template source: <https://github.com/RockinPaul/penguin_railway_template> (MIT).

### Implementation Details

**After deploying:** copy `PENGUIN_SEED_ADMIN_PASSWORD` from the service's Variables tab, open the
public domain and sign in as **`admin`**. Then add a model provider key from the Models page.

**How the admin password is handled, and why.** PenguinHarness creates its built-in admin account on
the first boot. Left to itself it generates a random password and prints a claim link to the
container log, so the only way into a fresh deployment would be to open the deploy logs and find it,
and until someone did, the account would sit unclaimed on a public URL. This template pins the
password to a per-deployment `${{secret(24)}}` instead: the account is created and closed during the
first boot, and the value is visible in the Variables tab the moment the deploy finishes. The
container exits rather than start if the variable is missing or too short, so there is no path to an
instance in the weaker state. Upstream hashes it with scrypt before any insert and enforces its own
minimum length, and the sign-in endpoint throttles failures per user with an exponentially growing
delay that applies to unknown usernames too.

Change the password from the app once you are in. After that the claim-link path is closed
permanently, and rotating the variable has no effect on an existing deployment. If you rotate it
*before* changing the password in the app, the next boot prints a claim link to the deploy logs
rather than locking you out.

**Security.** Measured against a running instance: every API route except `/api/install` returns 401
without a session, sign-in returns 401 on a wrong password, and the session cookie comes back
`HttpOnly; Secure; SameSite=Lax` because `PENGUIN_TRUST_PROXY` is set for Railway's TLS-terminating
edge. The honest caveat: this is an agent platform with terminals and a filesystem, so the blast
radius of the URL is a shell in this container. Keep the generated password and treat the link like
an SSH session into a dev box.

**Notes.** `PORT` is 8080 and the server reads it directly; Railway's healthcheck probes that port
and the domain targets it, so leave it alone. Health is `/api/install`, which is public by design and
returns only an installation id. The update check is disabled because the image is pinned — upgrade
by bumping `PENGUIN_VERSION` and redeploying.

## Licences

PenguinHarness is Apache-2.0. The template's glue is MIT.
