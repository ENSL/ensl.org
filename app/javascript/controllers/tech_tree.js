import { Controller } from "@hotwired/stimulus"
import mermaid from "mermaid"

export default class extends Controller {
  static targets = ["graph", "tooltip"]
  static values = { diagram: String, icons: Object }

  connect() {
    mermaid.initialize({ startOnLoad: false, securityLevel: "strict", theme: "base", flowchart: { useMaxWidth: true, htmlLabels: false } })
    requestAnimationFrame(() => this.renderDiagram())
  }

  async renderDiagram() {
    const { svg } = await mermaid.render("marine-tech-tree", this.diagramValue)
    this.graphTarget.innerHTML = svg
    this.addResearchIcons()
  }

  addResearchIcons() {
    const namespace = "http://www.w3.org/2000/svg"

    Object.entries(this.iconsValue).forEach(([nodeId, research]) => {
      const node = this.graphTarget.querySelector(`[id^="flowchart-${nodeId}-"]`)
      if (!node) return

      const title = document.createElementNS(namespace, "title")
      title.textContent = research.label
      node.prepend(title)
      node.addEventListener("pointerenter", (event) => this.showTooltip(event, research))
      node.addEventListener("pointermove", (event) => this.positionTooltip(event))
      node.addEventListener("pointerleave", () => this.hideTooltip())
      if (!research.icon) return

      const background = document.createElementNS(namespace, "rect")
      background.setAttribute("x", "-48")
      background.setAttribute("y", "-24")
      background.setAttribute("width", "48")
      background.setAttribute("height", "48")
      background.setAttribute("rx", "3")
      background.style.setProperty("fill", "#000", "important")
      background.setAttribute("class", "tech-tree__icon-background")
      node.insertBefore(background, node.querySelector(".label"))

      const image = document.createElementNS(namespace, "image")
      image.setAttribute("href", research.icon)
      image.setAttribute("x", "-44")
      image.setAttribute("y", "-20")
      image.setAttribute("width", "40")
      image.setAttribute("height", "40")
      image.setAttribute("class", "tech-tree__icon")
      node.insertBefore(image, node.querySelector(".label"))

      const label = node.querySelector(".label")
      label.setAttribute("transform", "translate(7, -12)")
    })
  }

  showTooltip(event, research) {
    this.tooltipTarget.replaceChildren()
    const title = document.createElement("strong")
    title.textContent = research.label
    this.tooltipTarget.append(title)

    this.addLine(`${research.winRatio.toFixed(1)}% win`)
    this.addLine(`${research.rounds.toLocaleString()} samples`)
    this.addLine(`${research.reachRate.toFixed(1)}% reach`)
    this.tooltipTarget.hidden = false
    this.positionTooltip(event)
  }

  addLine(text) {
    const line = document.createElement("span")
    line.textContent = text
    this.tooltipTarget.append(line)
  }

  positionTooltip(event) {
    const margin = 16
    const { width, height } = this.tooltipTarget.getBoundingClientRect()
    const left = Math.min(event.clientX + margin, window.innerWidth - width - margin)
    const top = Math.min(event.clientY + margin, window.innerHeight - height - margin)
    this.tooltipTarget.style.left = `${Math.max(margin, left)}px`
    this.tooltipTarget.style.top = `${Math.max(margin, top)}px`
  }

  hideTooltip() {
    this.tooltipTarget.hidden = true
  }
}