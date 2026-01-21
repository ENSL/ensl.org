FROM ruby:3.2.5 AS ensl_development

ENV RAILS_ENV development
ENV APP_PATH /var/www
ENV WEB_UID 1000
ENV WEB_GID 1000
ENV NVM_DIR /usr/local/nvm
ENV GEM_HOME /var/bundle
ENV GEM_PATH /var/bundle
ENV PATH /var/bundle/bin:/usr/local/bundle/bin:${PATH}

RUN \
    # Add web
    adduser web --uid $WEB_UID --home /home/web --shell /bin/bash --disabled-password --gecos "" && \
    apt-get update && apt-get -y upgrade && \
    # Pre-dependencies
    apt-get -y install curl build-essential && \
    # Yarn repo
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
    # Dependencies
    apt-get -y install --upgrade \
      # For MySQL/MariaDB
      libmariadb-dev libmariadb-dev-compat \
      # SSL libs
      libssl-dev  \
      # zlib, readline and libyaml
      zlib1g-dev libreadline-dev libyaml-dev  \
      # For nogokiri
      libxslt1-dev libxml2-dev \
      # For carrierwave/rmagick
      imagemagick libmagickwand-dev \
      # For poltergeist
      # phantomjs \
      firefox-esr \
      # For apparition
      chromium chromium-driver && \
    # Fix URI startup issue && \
    gem update --system && \
    # Install bundler and bundle path
    gem install bundler && \
    mkdir -p /var/bundle /usr/local/bundle && chown -R web:web /var/bundle /usr/local/bundle && \
    # Install nvm, Node (LTS) and yarn (installed via npm global)
    mkdir -p $NVM_DIR && \
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.6/install.sh | bash && \
    # Make nvm available in this shell, install Node LTS and set default
    . $NVM_DIR/nvm.sh && \
    nvm install --lts && nvm alias default 'lts/*' && \
    NODE_VERSION=$(ls -1 $NVM_DIR/versions/node | tail -n 1) && \
    ln -s $NVM_DIR/versions/node/$NODE_VERSION/bin/node /usr/local/bin/node && \
    ln -s $NVM_DIR/versions/node/$NODE_VERSION/bin/npm /usr/local/bin/npm && \
    npm install -g yarn && \
    ln -s $NVM_DIR/versions/node/$NODE_VERSION/bin/yarn /usr/local/bin/yarn && \
    # Make nvm available for all users/shells
    echo "export NVM_DIR=$NVM_DIR" > /etc/profile.d/nvm.sh && \
    echo "[ -s $NVM_DIR/nvm.sh ] && . $NVM_DIR/nvm.sh" >> /etc/profile.d/nvm.sh && \
    chown -R web:web $NVM_DIR
    # Clean up
    # apt-get --purge autoremove && rm -rf /var/apt/lists/*

# Separate Gemfile ADD so that `bundle install` can be cached more effectively
#ADD --chown=web Gemfile Gemfile.lock /var/www/
ADD --chown=web Gemfile /var/www/

USER web
WORKDIR /var/www

RUN bundle config github.https true && \
    bundle config set path '/var/bundle' && \
    bundle install --jobs 8

#
# Production
#

FROM ensl_development AS ensl_production

ENV RAILS_ENV production

ADD --chown=web . /var/www

# USER root
# RUN chown -R web:web /var/www
# USER web

# Generate rake secret
# RUN rake secret && rails credentials:edit --environment production

# Assets are only compiled for production+
#RUN bundle exec rake assets:precompile && \
    # FIXME: Temporary fix for assets
    # Move assets to a temp dir here and move them back in entry script
#    cp -r /var/www/public/assets /home/web/assets

#
# Staging
#

FROM ensl_production AS ensl_staging

ENV RAILS_ENV staging

# ENTRYPOINT ["/bin/bash"]
# CMD ["/var/www/bin/script/entry.sh"]
