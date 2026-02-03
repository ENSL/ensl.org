import { Application } from "@hotwired/stimulus"

export const application = Application.start()

application.debug = false
window.Stimulus = application
