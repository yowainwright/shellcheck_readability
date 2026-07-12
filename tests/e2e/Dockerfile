FROM debian:13-slim

WORKDIR /opt/shellcheck-readability

COPY bin ./bin
COPY lib ./lib
COPY tests/e2e/shellcheck-readability-wrapper /usr/local/bin/shellcheck-readability
COPY tests/e2e/run-in-container.bash /usr/local/bin/shellcheck-readability-e2e

RUN chmod +x /usr/local/bin/shellcheck-readability \
  && chmod +x /usr/local/bin/shellcheck-readability-e2e

WORKDIR /tmp

ENTRYPOINT ["/usr/local/bin/shellcheck-readability-e2e"]
