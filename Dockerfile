FROM ruby:3.4.8 AS ensl_base
ARG TARGETARCH

ENV APP_PATH=/var/www
ENV WEB_UID=1000
ENV WEB_GID=1000
ENV NVM_DIR=/usr/local/nvm
ENV NVM_VERSION=0.39.6
ENV GEM_HOME=/var/bundle
ENV GEM_PATH=/var/bundle
ENV PATH=/var/bundle/bin:/usr/local/bundle/bin:${PATH}
ENV LD_LIBRARY_PATH=/opt/duckdb/lib:/usr/local/lib
ENV BUNDLE_WITHOUT=
ENV BUNDLE_WITH=
ENV BUNDLER_VERSION=4.0.6
ENV DUCKDB_VERSION=1.4.5
ENV YARN_VERSION=1.22.22

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ADD https://github.com/duckdb/duckdb/releases/download/v${DUCKDB_VERSION}/libduckdb-linux-${TARGETARCH}.zip /tmp/libduckdb.zip
ADD https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh /tmp/nvm-install.sh

RUN \
    # Add web
    adduser web --uid "$WEB_UID" --home /home/web --shell /bin/bash \
                --disabled-password --gecos "" && \
    apt-get update && apt-get -y upgrade && \
        # Dependencies
        apt-get -y install --no-install-recommends --upgrade \
            # Package rationale (kept alphabetically sorted for linting):
            # - build-essential, clang, libclang-dev:
            #   toolchain + clang headers for native gem extensions (notably commonmarker/CBindgen workflows).
            # - curl:
            #   general fetch/debug utility retained for runtime/admin scripts.
            # - ffmpeg:
            #   required by app/services/video_processing.rb and app/models/movie.rb for transcode/thumbnail work.
            # - imagemagick, libmagickwand-dev:
            #   required by carrierwave + rmagick (app/uploaders/image_uploader.rb includes CarrierWave::RMagick).
            # - libimage-exiftool-perl:
            #   file/media metadata extraction utility used by upload/media workflows.
            # - libmariadb-dev, libmariadb-dev-compat:
            #   required to compile and link the mysql2 gem.
            # - libreadline-dev, libssl-dev, libyaml-dev, zlib1g-dev:
            #   native build/runtime libs commonly required by Ruby and C-extension gems.
            # - libxml2-dev, libxslt1-dev:
            #   XML/XSLT native libs for nokogiri-family dependencies in the Rails stack.
            # - screen:
            #   runtime terminal multiplexer for long-running/manual admin sessions.
            # - unzip:
            #   required to unpack the downloaded DuckDB C API archive.
            # - vlc:
            #   required by app/models/movie.rb (VLC binary invocation for legacy conversion paths).
            build-essential clang curl ffmpeg imagemagick libclang-dev \
            libimage-exiftool-perl libmariadb-dev libmariadb-dev-compat \
            libmagickwand-dev libreadline-dev libssl-dev libxml2-dev \
            libxslt1-dev libyaml-dev screen unzip vlc zlib1g-dev && \
        rm -rf /var/lib/apt/lists/* && \
        # Install DuckDB C API artifacts from GitHub releases (no CLI).
        DUCKDB_ARCH="${TARGETARCH:-}" && \
        if [[ "$DUCKDB_ARCH" != "amd64" && "$DUCKDB_ARCH" != "arm64" ]]; then \
            echo "Unsupported architecture for DuckDB artifacts: $DUCKDB_ARCH"; exit 1; \
        fi && \
        mkdir -p /tmp/libduckdb /opt/duckdb/include /opt/duckdb/lib && \
        unzip -o /tmp/libduckdb.zip -d /tmp/libduckdb && \
        cp /tmp/libduckdb/duckdb.h /opt/duckdb/include/duckdb.h && \
        cp /tmp/libduckdb/libduckdb.so /opt/duckdb/lib/libduckdb.so && \
        ln -sf /opt/duckdb/lib/libduckdb.so /usr/local/lib/libduckdb.so && \
        ldconfig && \
        rm -rf /tmp/libduckdb /tmp/libduckdb.zip && \
    # Fix URI startup issue
    gem update --system && \
    # Install bundler and bundle path
    gem install bundler -v "$BUNDLER_VERSION" && \
    mkdir -p /var/bundle /usr/local/bundle && chown -R web:web /var/bundle /usr/local/bundle && \
    # Install nvm, Node (LTS) and yarn (installed via npm global)
    mkdir -p "$NVM_DIR" && \
    bash /tmp/nvm-install.sh && rm -f /tmp/nvm-install.sh && \
    # Make nvm available in this shell, install Node LTS and set default
    . "$NVM_DIR/nvm.sh" && \
    nvm install --lts && nvm alias default 'lts/*' && \
    NODE_VERSION=$(find "$NVM_DIR/versions/node" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -V | tail -n 1) && \
    ln -s "$NVM_DIR/versions/node/$NODE_VERSION/bin/node" /usr/local/bin/node && \
    ln -s "$NVM_DIR/versions/node/$NODE_VERSION/bin/npm" /usr/local/bin/npm && \
    ln -s "$NVM_DIR/versions/node/$NODE_VERSION/bin/npx" /usr/local/bin/npx && \
    # Make nvm available for all users/shells
    echo "export NVM_DIR=$NVM_DIR" > /etc/profile.d/nvm.sh && \
    echo "[ -s $NVM_DIR/nvm.sh ] && . $NVM_DIR/nvm.sh" >> /etc/profile.d/nvm.sh && \
    chown -R web:web "$NVM_DIR" && \
    # Install yarn
    npm install -g "yarn@${YARN_VERSION}" && \
    ln -s "$NVM_DIR/versions/node/$NODE_VERSION/bin/yarn" /usr/local/bin/yarn
    # Clean up
    # apt-get --purge autoremove && rm -rf /var/apt/lists/*

# Cache bundle installs
USER web
WORKDIR /var/www
COPY --chown=web Gemfile Gemfile.lock /var/www/

RUN bundle config set github.https true && \
    bundle config set path '/var/bundle' && \
    bundle config set build.duckdb '--with-duckdb-include=/opt/duckdb/include --with-duckdb-lib=/opt/duckdb/lib' && \
    bundle config unset without && \
    bundle config unset with && \
    bundle config set with 'test' && \
    bundle install --jobs 8

#
# Development (includes test dependencies)
#

FROM ensl_base AS ensl_development

ENV RAILS_ENV=development

# Test-only system packages
USER root
RUN apt-get update && apt-get -y install --no-install-recommends \
    # Required by VS Code terminal command sandboxing
    bubblewrap socat \
    # For timing test runs
    time && \
    rm -rf /var/lib/apt/lists/* && \
    # Install Linux system dependencies required by Playwright-managed browsers.
    # This does NOT download browser binaries.
    PLAYWRIGHT_VERSION=$(bundle exec ruby -e 'require "playwright"; print Playwright::COMPATIBLE_PLAYWRIGHT_VERSION') && \
    npx -y "playwright@$PLAYWRIGHT_VERSION" install-deps

USER web

# Download browser binaries via Node CLI (independent of Ruby gem).
# Chromium is downloaded once here; headless-shell is kept for CI/headless runs.
RUN PLAYWRIGHT_VERSION=$(bundle exec ruby -e 'require "playwright"; print Playwright::COMPATIBLE_PLAYWRIGHT_VERSION') && \
    npx -y "playwright@$PLAYWRIGHT_VERSION" install chromium chromium-headless-shell

#
# Production
#

FROM ensl_base AS ensl_production

ENV RAILS_ENV=production

# No need to copy files, using volume mounts in production
# ADD --chown=web . /var/www

# USER root
# RUN chown -R web:web /var/www
# USER web

# Generate rake secret
# RUN rake secret && rails credentials:edit --environment production

# Assets could be compiled here. Not used atm.

#
# Staging
#

FROM ensl_production AS ensl_staging

ENV RAILS_ENV=staging

# ENTRYPOINT ["/bin/bash"]
# CMD ["/var/www/bin/script/entry.sh"]

# Default target for local tooling and Dev Containers.
FROM ensl_development AS ensl_devcontainer
