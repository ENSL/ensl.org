# Development

Install instructions in INSTALL.md

## Startup

Just run and open http://localhost:4000/

    docker-compose -f docker-compose.dev.yml up`

## Tips

1. Everything should be running on containers.
1. If you need to run stuff on your host (eg. ruby, rubocop, bundle install etc) run all commands from the: `Dockerfile.dev`. It should setup identical setup for your machine.
1. Add docker container names to /etc/hosts. This makes it possible to run test from local machine without using the container since editor/IDE don't integrate with Docker so well.

    sudo echo `docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ensl_dev_db` db >> /etc/hosts

1. VS Code and RubyMine are great IDE's/editors.
1. To run VS Code plugin Ruby Test Explorer in docker container you need to create path to custom path, copy the formatter and it whines about
and it still fails a bit. https://github.com/connorshea/vscode-ruby-test-adapter/issues/21
1. Do not commit too much without testing. Also keep commits small for documentation and reversability issues.
1. You need to rebuild the docker image when you change gems.

## Best practices

1. https://nvie.com/posts/a-successful-git-branching-model/
1. https://github.com/rubocop-hq/ruby-style-guide
1. https://rails-bestpractices.com/
1. http://www.betterspecs.org/
1. https://github.com/rubocop-hq/rspec-style-guide
1. Run rubocop

## TODO issues for dev

1. Puma should be running (eg. spring), and if debugger is used it should be able to connect via docker-compose up

# Tags in code

FIXME, TODO, EXPLAIN, OBSOLETE

## Handy commands

Start:

    docker-compose -f docker-compose.dev.yml up -d --build`

Build or rebuild:

    docker-compose -f docker-compose.dev.yml build`

Debug:

    docker attach ensl_dev

To get inside docker web+test containers:

    docker-compose -f docker-compose.dev.yml exec -u root web /bin/bash`
    docker-compose -f docker-compose.dev.yml exec -u web web /bin/bash`
    docker-compose -f docker-compose.dev.yml exec -u root test /bin/bash`
    docker-compose -f docker-compose.dev.yml exec -u web test /bin/bash`

Restart the web container

    docker-compose -f docker-compose.dev.yml restart web`

Run some tests:

    docker-compose -f docker-compose.dev.yml exec -u web test bundle exec rspec`
    docker-compose -f docker-compose.dev.yml exec -u web test bundle exec rspec spec/controllers/shoutmsgs_controller_spec.rb`