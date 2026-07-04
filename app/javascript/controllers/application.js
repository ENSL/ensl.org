import { Application } from "@hotwired/stimulus"

// Start the shared Stimulus app used by the controller registry.
export const application = Application.start()

// Keep Stimulus quiet in normal use and expose it for debugging if needed.
application.debug = false
window.Stimulus = application
