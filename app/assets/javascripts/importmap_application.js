// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "@rails/actioncable"
import "controllers"
import LocalTime from "local-time"

// Do not block app boot if CDN-hosted icon script fails to load.
import("@fortawesome/fontawesome-free").catch(() => {})

LocalTime.start()
document.addEventListener("turbo:morph", () => { LocalTime.run() })