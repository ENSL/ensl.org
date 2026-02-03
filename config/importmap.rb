# Pin npm packages by running ./bin/importmap

pin 'application', to: 'importmap_application.js'

# Standard importmap-rails pins (turbo-rails + actioncable)
pin '@hotwired/turbo-rails', to: 'turbo.min.js', preload: true
pin '@rails/actioncable', to: 'actioncable.js'
pin '@hotwired/stimulus', to: 'stimulus.min.js', preload: true

pin_all_from 'app/javascript/controllers', under: 'controllers'
