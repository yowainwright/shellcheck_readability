FROM debian:13-slim

WORKDIR /opt/shellcheck-legibility

COPY bin ./bin
COPY lib ./lib
COPY tests/e2e/shellcheck-legibility-wrapper /usr/local/bin/shellcheck-legibility
COPY tests/e2e/run-in-container.bash /usr/local/bin/shellcheck-legibility-e2e

RUN chmod +x /usr/local/bin/shellcheck-legibility \
  && chmod +x /usr/local/bin/shellcheck-legibility-e2e

WORKDIR /tmp

ENTRYPOINT ["/usr/local/bin/shellcheck-legibility-e2e"]
