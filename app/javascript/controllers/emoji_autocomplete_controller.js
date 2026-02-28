import { Controller } from "@hotwired/stimulus"
import Tribute from "tributejs"

export default class extends Controller {
  async connect() {
    this.attachedInputs = []

    const values = await this.fetchEmojiValues()
    if (!values.length) {
      return
    }

    this.tribute = new Tribute({
      trigger: ":",
      values,
      allowSpaces: false,
      lookup: "key",
      fillAttr: "key",
      selectTemplate: (item) => {
        if (!item || !item.original) {
          return null
        }

        return `:${item.original.key}:`
      },
      menuItemTemplate: (item) => `${item.original.emoji} :${item.original.key}:`
    })

    this.hardenTributeSelection()

    this.attachToInputs()
    this.handleTurboLoad = () => this.attachToInputs()
    this.handleTurboRender = () => this.attachToInputs()
    this.handleTurboFrameLoad = () => this.attachToInputs()
    this.handleTurboBeforeStreamRender = () => setTimeout(() => this.attachToInputs(), 0)

    document.addEventListener("turbo:load", this.handleTurboLoad)
    document.addEventListener("turbo:render", this.handleTurboRender)
    document.addEventListener("turbo:frame-load", this.handleTurboFrameLoad)
    document.addEventListener("turbo:before-stream-render", this.handleTurboBeforeStreamRender)

    this.observeDomChanges()
  }

  disconnect() {
    if (this.handleTurboLoad) {
      document.removeEventListener("turbo:load", this.handleTurboLoad)
    }

    if (this.handleTurboRender) {
      document.removeEventListener("turbo:render", this.handleTurboRender)
    }

    if (this.handleTurboFrameLoad) {
      document.removeEventListener("turbo:frame-load", this.handleTurboFrameLoad)
    }

    if (this.handleTurboBeforeStreamRender) {
      document.removeEventListener("turbo:before-stream-render", this.handleTurboBeforeStreamRender)
    }

    if (this.mutationObserver) {
      this.mutationObserver.disconnect()
      this.mutationObserver = null
    }

    if (!this.tribute) {
      return
    }

    this.attachedInputs.forEach((input) => this.tribute.detach(input))
    this.attachedInputs = []
  }

  async fetchEmojiValues() {
    try {
      const response = await fetch("/emoji/shortcodes", {
        headers: { Accept: "application/json" }
      })

      if (!response.ok) {
        return []
      }

      return await response.json()
    } catch (_error) {
      return []
    }
  }

  attachToInputs() {
    if (!this.tribute) {
      return
    }

    const inputs = document.querySelectorAll("textarea, input.shout_input")

    inputs.forEach((input) => {
      if (input.dataset.emojiAutocompleteAttached === "1") {
        return
      }

      this.tribute.attach(input)
      input.dataset.emojiAutocompleteAttached = "1"
      this.attachedInputs.push(input)
    })

    this.attachedInputs = this.attachedInputs.filter((input) => input.isConnected)
  }

  hardenTributeSelection() {
    if (!this.tribute || typeof this.tribute.selectItemAtIndex !== "function") {
      return
    }

    const originalSelectItemAtIndex = this.tribute.selectItemAtIndex.bind(this.tribute)

    this.tribute.selectItemAtIndex = (index, originalEvent) => {
      const collection = this.tribute.current && this.tribute.current.collection
      const values = collection && collection.values

      if (!values || !values[index]) {
        return
      }

      return originalSelectItemAtIndex(index, originalEvent)
    }
  }

  observeDomChanges() {
    if (this.mutationObserver) {
      this.mutationObserver.disconnect()
    }

    this.mutationObserver = new MutationObserver((mutations) => {
      const hasRelevantNode = mutations.some((mutation) => {
        if (mutation.type !== "childList") {
          return false
        }

        return Array.from(mutation.addedNodes).some((node) => {
          if (!(node instanceof Element)) {
            return false
          }

          return node.matches("textarea, input.shout_input") || node.querySelector("textarea, input.shout_input")
        })
      })

      if (!hasRelevantNode) {
        return
      }

      this.attachToInputs()
    })

    this.mutationObserver.observe(document.body, { childList: true, subtree: true })
  }
}
