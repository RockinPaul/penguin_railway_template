# PenguinHarness — multi-agent auto-dev platform
# https://github.com/Prism-Shadow/penguin-harness
#
# Upstream's own image is used as-is: it already runs the server as uid 1000,
# chowns only the top level of the data root, and execs in place through
# setpriv so tini keeps the server as its direct child and SIGTERM reaches it
# without a relay. None of that needs replacing.
#
# The wrapper adds exactly one thing upstream cannot: a guard that refuses to
# start a public deployment whose admin password was never pinned. Without
# PENGUIN_SEED_ADMIN_PASSWORD the server mints a first-login link and prints it
# to the container log, which is a reasonable default on a laptop and a poor one
# on a URL anybody can reach.
ARG PENGUIN_VERSION=0.2.11
FROM hiyouga/penguinharness:${PENGUIN_VERSION}

USER root

# HOST=:: is a genuine dual-stack listener on Node's runtime — measured, one
# socket in tcp6 with no separate v4 listener, and both 127.0.0.1 and [::1]
# answer — so Railway's edge and the IPv6-only private network are served from
# the same socket with no socat in front.
#
# PORT is the port Railway's healthcheck probes and the public domain targets,
# and the server reads it directly.
#
# PENGUIN_TRUST_PROXY makes the session cookie Secure behind Railway's
# TLS-terminating edge. PENGUIN_UPDATE_CHECK is off because the image is pinned:
# an in-container update has nowhere to land, and the lookup is a needless call
# to GitHub on every page load.
ENV HOST=:: \
    PORT=8080 \
    PENGUIN_HOME=/data \
    PENGUIN_TRUST_PROXY=1 \
    PENGUIN_UPDATE_CHECK=off

COPY --chmod=755 entrypoint.sh /usr/local/bin/railway-entrypoint

EXPOSE 8080

# tini stays PID 1, the guard runs as root, and upstream's entrypoint still does
# the volume preparation and the drop to uid 1000.
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/railway-entrypoint"]
CMD ["penguin", "server"]
