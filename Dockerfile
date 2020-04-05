FROM ruby:2.6.5 AS ensl_development

ENV RAILS_ENV development

RUN adduser web --home /home/web --shell /bin/bash --disabled-password --gecos "" && \
    apt-get update && apt-get -y upgrade \
    && apt-get -y install \
        libmariadb-dev libmariadb-dev-compat \
        libssl-dev  \
        zlib1g-dev libreadline-dev libyaml-dev  \
        libxslt1-dev libxml2-dev \
        imagemagick libmagickwand-dev \
        nodejs \
        phantomjs \
        firefox-esr

# Separate Gemfile ADD so that `bundle install` can be cached more effectively
ADD Gemfile Gemfile.lock /var/www/

RUN gem install bundler && \
    mkdir -p /var/bundle && chown -R web:web /var/bundle && \
    chown -R web:web /var/www

WORKDIR /var/www
USER web

RUN bundle config github.https true && \
    bundle config set path '/var/bundle' && \
    bundle install --jobs 8

USER root

# ENTRYPOINT ["/bin/bash"]
# CMD ["/var/www/bin/script/entry.sh"]

# Staging

FROM ensl_development AS ensl_staging

ENV RAILS_ENV staging

USER root

ENTRYPOINT ["/bin/bash"]
CMD ["/var/www/bin/script/entry.sh"]

# Production

FROM ensl_development AS ensl_production

ENV RAILS_ENV production

ADD . /var/www

WORKDIR /var/www

RUN chown -R web:web /var/www

USER web
RUN bundle exec rake assets:precompile && \
    # Temporary fix for assets
    mv /var/www/public/assets /home/web/assets

ENTRYPOINT ["/bin/bash"]
CMD ["/var/www/bin/script/entry.sh"]
