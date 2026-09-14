import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "option"]

  connect() {
    this.updateOptions()
  }

  updateOptions() {
    const prefix = this.inputTarget.value.match(/^(.*\+)[^+]*$/)?.[1] || ""
    this.optionTargets.forEach((option) => {
      option.value = `${prefix}${option.dataset.token}`
    })
  }
}