import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.boundToggle = this.toggleFromEvent.bind(this)
    this.element.addEventListener("click", this.boundToggle)
  }

  disconnect() {
    this.element.removeEventListener("click", this.boundToggle)
  }

  toggleFromEvent(event) {
    const row = event.target.closest("tr.expand-row")
    if (!row || !this.element.contains(row)) return
    if (event.target.closest("a, button, input, select, textarea, [data-no-toggle]")) return

    const detailId = row.getAttribute("data-expand-target")
    const detailRow = document.getElementById(detailId)
    if (!detailRow) return

    const expanded = row.getAttribute("aria-expanded") === "true"
    row.setAttribute("aria-expanded", expanded ? "false" : "true")
    detailRow.classList.toggle("is-open", !expanded)
  }
}
