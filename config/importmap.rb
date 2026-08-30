# frozen_string_literal: true

# Pin npm packages by running ./bin/importmap

pin 'application', to: 'importmap_application.js'

pin '@hotwired/turbo-rails', to: 'turbo.min.js', preload: true
pin '@rails/actioncable', to: 'actioncable.js'
pin '@rails/request.js', to: 'https://cdn.jsdelivr.net/npm/@rails/request.js@0.0.13/dist/requestjs.min.js'
pin '@hotwired/stimulus', to: 'https://ga.jspm.io/npm:@hotwired/stimulus@3.2.2/dist/stimulus.js', preload: true
pin '@fortawesome/fontawesome-free',
    to: 'https://cdn.jsdelivr.net/npm/@fortawesome/fontawesome-free@6.7.2/js/all.min.js', preload: true
pin '@simplewebauthn/browser', to: 'https://cdn.jsdelivr.net/npm/@simplewebauthn/browser@13.3.0/esm/index.js', preload: true
pin 'tributejs', to: 'https://cdnjs.cloudflare.com/ajax/libs/tributejs/5.1.3/tribute.esm.js', preload: true
pin 'chart.js', to: 'https://cdn.jsdelivr.net/npm/chart.js@4.4.7/auto/+esm'

pin 'local-time' # @3.0.3

pin_all_from 'app/javascript/controllers', under: 'controllers'
pin_all_from 'app/javascript/lib', under: 'lib'
