# frozen_string_literal: true

# Pin npm packages by running ./bin/importmap

pin 'application', to: 'importmap_application.js'

pin '@hotwired/turbo-rails', to: 'turbo.min.js', preload: true
pin '@rails/actioncable', to: 'actioncable.js'
pin '@hotwired/stimulus', to: 'https://ga.jspm.io/npm:@hotwired/stimulus@3.2.2/dist/stimulus.js', preload: true
pin '@fortawesome/fontawesome-free',
    to: 'https://cdn.jsdelivr.net/npm/@fortawesome/fontawesome-free@6.7.2/js/all.min.js', preload: true
pin 'tributejs', to: 'https://cdnjs.cloudflare.com/ajax/libs/tributejs/5.1.3/tribute.esm.js', preload: true

pin 'local-time' # @3.0.3

pin_all_from 'app/javascript/controllers', under: 'controllers'
