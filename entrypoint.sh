#!/bin/sh
set -eu

# ---------------------------------------------------------------------------
# Fail closed when the admin password was never pinned
# ---------------------------------------------------------------------------
# PenguinHarness authenticates every route except the install probe, so it is
# not open by default. What it does when no password is configured is mint a
# first-login link and print it to the container log — fine on a laptop, poor
# on a public URL, where it means the only way in is to read a deploy log and
# the account sits unclaimed until someone does.
#
# This template generates the password instead, so the account exists the
# moment the first boot finishes and the credential is in the Variables tab.
# Refusing to start without one keeps that true: there is no path to a
# deployment whose admin account is waiting in a log line.
#
# Upstream enforces the length itself and exits before any insert, so this
# check exists for the message rather than the policy.
if [ -z "${PENGUIN_SEED_ADMIN_PASSWORD:-}" ]; then
    echo "FATAL: PENGUIN_SEED_ADMIN_PASSWORD is empty." >&2
    echo "  It is the password for the built-in 'admin' account, created on the" >&2
    echo "  first boot. Without it the server prints a one-time claim link to" >&2
    echo "  this log instead, and this deployment is reachable at a public URL." >&2
    echo "  The template generates one; read it from the service variables." >&2
    exit 1
fi
if [ "$(printf '%s' "${PENGUIN_SEED_ADMIN_PASSWORD}" | wc -c)" -lt 12 ]; then
    echo "FATAL: PENGUIN_SEED_ADMIN_PASSWORD is shorter than 12 characters." >&2
    echo "  The sign-in endpoint is reachable from the public domain the moment" >&2
    echo "  the account exists. The template generates a 24-character value." >&2
    exit 1
fi

echo "penguin: data root ${PENGUIN_HOME:-/data}, listening on [::]:${PORT:-8080}"
echo "penguin: sign in as 'admin' with PENGUIN_SEED_ADMIN_PASSWORD from the service variables"

# Hand back to upstream's entrypoint, which prepares the data root and execs the
# server as uid 1000 in place.
exec /usr/local/bin/penguin-entrypoint "$@"
