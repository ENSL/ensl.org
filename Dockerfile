FROM       ruby:2.2

ENV RAILS_ENV production

# Add 'web' user which will run the application
RUN adduser web --home /home/web --shell /bin/bash --disabled-password --gecos ""

RUN apt-get update && apt-get -y upgrade
RUN apt-get -y install mysql-client libmysqlclient-dev memcached nodejs

# Separate Gemfile ADD so that `bundle install` can be cached more effectively

ADD Gemfile      /var/www/
ADD Gemfile.lock /var/www/
RUN chown -R web:web /var/www &&\
    mkdir -p /var/bundle &&\
    chown -R web:web /var/bundle

RUN bundle config github.https true
RUN su -c "cd /var/www && bundle install --path /var/bundle" -s /bin/bash -l web

# Add application source
ADD . /var/www
RUN chown -R web:web /var/www

USER web

# Precompile assets

WORKDIR /var/www
COPY .env /var/www/
RUN bundle install --path /var/bundle --jobs 4
#RUN bundle exec rake assets:precompile

USER root

# FIXME: move this to docker image
RUN apt-get install -y memcached
RUN service memcached start

#USER root

USER web
CMD ["/var/www/entry.sh"]
