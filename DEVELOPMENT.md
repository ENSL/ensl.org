# Development

This is just random tips for development. Not a full documentation.

# Handy commands

`docker-compose -f docker-compose.dev.yml exec -u web web /bin/bash`
`docker-compose -f docker-compose.dev.yml exec -u web test /bin/bash`
`docker-compose -f docker-compose.dev.yml restart web`
`docker-compose -f docker-compose.dev.yml exec -u web test bundle exec rspec`
`docker-compose -f docker-compose.dev.yml exec -u web test bundle exec rspec spec/controllers/shoutmsgs_controller_spec.rb`