# Development

Install instructions in INSTALL.md

## Bassic commands for development

Load env variables:

    source script/env.sh .env .env.development

Start:

    docker-compose up --build development`

Build or rebuild:

    docker-compose build`

Debug:

    docker attach ensl_development

To get inside docker web+test containers:

    docker-compose exec -u root development /bin/bash`
    docker-compose exec -u web development /bin/bash`
    docker-compose exec -u root test /bin/bash`
    docker-compose exec -u web test /bin/bash`

Restart the web container

    docker-compose restart web`

Run some tests:

    docker-compose exec -u web test bundle exec rspec`
    docker-compose exec -u web test bundle exec rspec spec/controllers/shoutmsgs_controller_spec.rb`

## Unresolved issues

There are some unresolved issues to setup dev env.

1. Make sure tmp, tmp/sockets, tmp/pids and log exist.
1. Make sure docker has access to its dirs. You might have to `sudo chown -R 999:999 for` for `db/data` if you have permission issues with docker.

## Tips

1. If you need to run stuff on your host (eg. ruby, rubocop, bundle install etc) run all commands from the: `Dockerfile.dev`. It should setup identical setup for your machine.
1. Add docker container names to /etc/hosts. This makes it possible to run test from local machine without using the container since editor/IDE don't integrate with Docker so well.

    sudo echo `docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ensl_dev_db` db >> /etc/hosts

1. VS Code and RubyMine are great IDE's/editors.
1. To run VS Code plugin Ruby Test Explorer in docker container you need to create path to custom path, copy the formatter and it whines about and it [still fails a bit](https://github.com/connorshea/vscode-ruby-test-adapter/issues/21).
1. Do not commit too much without testing. Also keep commits small for documentation and reversability issues.
1. You need to rebuild the docker image when you change gems.

## Design of ENSL Application

Read this to understand design decisions and follow them!

1. Env variables should be used everywhere and loaded from .env* files using Dotenv
1. Everything should be running on containers.
1. Docker-compose is the heart of deployment
1. Dockerfile should contain the gems and prebuilt assets for production
1. The app contents are added to the docker image *on build* but it is mounted as **volume**. It will override the Dockerfile content.

## Tags in code

FIXME, TODO, EXPLAIN, OBSOLETE

## TODO issues for dev

1. Puma should be running (eg. spring), and if debugger is used it should be able to connect via docker-compose up
1. Should directories exist?
1. docker-compose has some .env specific vars and then

## Best practices

Take a look at these before writing anything.

1. https://nvie.com/posts/a-successful-git-branching-model/
1. https://docs.docker.com/develop/develop-images/dockerfile_best-practices/
1. https://github.com/rubocop-hq/ruby-style-guide
1. https://rails-bestpractices.com/
1. http://www.betterspecs.org/
1. https://github.com/rubocop-hq/rspec-style-guide
1. Run rubocop
