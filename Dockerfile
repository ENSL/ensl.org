FROM ruby:2.6.5 AS ensl_development

ENV RAILS_ENV development
ENV APP_PATH /var/www

RUN \
    # Add web
    adduser web --home /home/web --shell /bin/bash --disabled-password --gecos "" && \
    apt-get update && apt-get -y upgrade && \
    # Pre-dependencies
    apt-get -y install curl && \
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
      # For javascript gems
      nodejs \
      # For assets pipeline
      yarn \
      # For poltergeist
      phantomjs \
      firefox-esr && \
    # Install bundler and bundle path
    gem install bundler && \
    mkdir -p /var/bundle && chown -R web:web /var/bundle

# Separate Gemfile ADD so that `bundle install` can be cached more effectively
ADD --chown=web Gemfile Gemfile.lock /var/www/

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

# Assets are only compiled for production+
RUN bundle exec rake assets:precompile && \
    # FIXME: Temporary fix for assets
    # Move assets to a temp dir here and move them back in entry script
    cp -r /var/www/public/assets /home/web/assets

#
# Staging
#

FROM ensl_production AS ensl_staging

ENV RAILS_ENV staging

# ENTRYPOINT ["/bin/bash"]
# CMD ["/var/www/bin/script/entry.sh"]
