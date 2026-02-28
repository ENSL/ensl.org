// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "@rails/actioncable"
import "controllers"
import "@fortawesome/fontawesome-free"
import LocalTime from "local-time"
LocalTime.start()
document.addEventListener("turbo:morph", () => { LocalTime.run() })