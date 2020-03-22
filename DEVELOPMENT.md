# Development

Install instructions in INSTALL.md

1. Everything should be running on containers.
1. If you need to run stuff on your host (eg. ruby, rubocop, bundle install etc) run all commands from the: `Dockerfile.dev`. It should setup identical setup for your machine.
1. Add docker container names to /etc/hosts. This makes it possible to run test from local machine without using the container since editor/IDE don't integrate with Docker so well.
    
    sudo echo `docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ensl_dev_db` db >> /etc/hosts
1. To run VS Code plugin Ruby Test Explorer in docker container you need to create path to custom 

This is just random tips for development. Not a full documentation.

# Handy commands

    docker-compose -f docker-compose.dev.yml exec -u web web /bin/bash`
    docker-compose -f docker-compose.dev.yml exec -u web test /bin/bash`
    docker-compose -f docker-compose.dev.yml restart web`
    docker-compose -f docker-compose.dev.yml exec -u web test bundle exec rspec`
    docker-compose -f docker-compose.dev.yml exec -u web test bundle exec rspec spec/controllers/shoutmsgs_controller_spec.rb`
    docker-compose -f docker-compose.dev.yml run --rm selenium