FROM ruby:2.4.9

ENV RAILS_ENV production

# Add 'web' user which will run the application
RUN adduser web --home /home/web --shell /bin/bash --disabled-password --gecos ""

RUN apt-get update && apt-get -y upgrade \
    && apt-get -y install \
        libmariadb-dev libmariadb-dev-compat \
        libssl-dev  \
        zlib1g-dev libreadline-dev libyaml-dev  \
        libxslt1-dev libxml2-dev \
        imagemagick libmagickwand-dev \
        nodejs \
        firefox-esr

# Separate Gemfile ADD so that `bundle install` can be cached more effectively
ADD Gemfile Gemfile.lock /var/www/

RUN gem install bundler && \
    mkdir -p /var/bundle && chown -R web:web /var/bundle && chown -R web:web /var/www

WORKDIR /var/www
USER web

RUN bundle config github.https true && \
    bundle config set path '/var/bundle' && \
    bundle install --jobs 8 && \
    bundle exec rake assets:precompile

USER root

# Temporary fix for assets
RUN mv /var/www/public/assets /home/web/assets

CMD ["/var/www/script/entry.sh"]
