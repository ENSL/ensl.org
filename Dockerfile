FROM       ruby:2.2

ENV RAILS_ENV production

# Add 'web' user which will run the application
RUN adduser web --home /home/web --shell /bin/bash --disabled-password --gecos ""

RUN apt-get update && apt-get -y upgrade
RUN apt-get -y install mysql-client libmysqlclient-dev memcached nodejs
RUN service memcached start

# Separate Gemfile ADD so that `bundle install` can be cached more effectively

ADD Gemfile      /var/www/
ADD Gemfile.lock /var/www/
RUN chown -R web:web /var/www &&\
    mkdir -p /var/bundle &&\
    chown -R web:web /var/bundle

RUN su -c "bundle config github.https true; cd /var/www && bundle install --path /var/bundle --jobs 4" -s /bin/bash -l web

# Add application source
ADD . /var/www
RUN chown -R web:web /var/www

# Precompile assets
WORKDIR /var/www
USER web
RUN bundle config github.https true; cd /var/www && bundle install --path /var/bundle --jobs 4
RUN bundle exec rake assets:precompile && mv /var/www/public/assets /var/www/assets_tmp

# for debug
# USER root

CMD ["/var/www/entry.sh"]
