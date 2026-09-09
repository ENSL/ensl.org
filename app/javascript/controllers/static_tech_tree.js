import { Controller } from "@hotwired/stimulus"
import mermaid from "mermaid"

export default class extends Controller {
  static targets = ["graph", "tooltip"]
  static values = { diagram: String, nodes: Object }

  connect() {
    mermaid.initialize({ startOnLoad: false, securityLevel: "strict", theme: "base", flowchart: { useMaxWidth: true, htmlLabels: false } })
    requestAnimationFrame(() => this.renderDiagram())
  }

  async renderDiagram() {
    const { svg } = await mermaid.render("marine-tech-requirements", this.diagramValue)
    this.graphTarget.innerHTML = svg
    this.addNodes()
  }

  addNodes() {
    const namespace = "http://www.w3.org/2000/svg"

    Object.entries(this.nodesValue).forEach(([nodeId, nodeData]) => {
      const node = this.graphTarget.querySelector(`[id^="flowchart-${nodeId}-"]`)
      if (!node || nodeId === "start") return

      const title = document.createElementNS(namespace, "title")
      title.textContent = nodeData.label
      node.prepend(title)
      if (nodeData.icon) {
        const background = document.createElementNS(namespace, "rect")
        background.setAttribute("x", "-24")
        background.setAttribute("y", "-24")
        background.setAttribute("width", "48")
        background.setAttribute("height", "48")
        background.setAttribute("rx", "3")
        background.setAttribute("fill", "#000")
        background.style.setProperty("fill", "#000", "important")
        background.setAttribute("class", "tech-requirements__icon-background")
        node.insertBefore(background, node.querySelector(".label"))

        const image = document.createElementNS(namespace, "image")
        image.setAttribute("href", nodeData.icon)
        image.setAttribute("x", "-20")
        image.setAttribute("y", "-20")
        image.setAttribute("width", "40")
        image.setAttribute("height", "40")
        image.setAttribute("class", "tech-requirements__icon")
        node.insertBefore(image, node.querySelector(".label"))
      }
      node.addEventListener("pointerenter", (event) => this.showTooltip(event, nodeId, nodeData))
      node.addEventListener("pointermove", (event) => this.positionTooltip(event))
      node.addEventListener("pointerleave", () => this.hideTooltip())
    })
  }

  showTooltip(event, nodeId, nodeData) {
    this.showObservedEdges(nodeId, nodeData)
    this.tooltipTarget.replaceChildren()
    const title = document.createElement("strong")
    title.textContent = nodeData.label
    this.tooltipTarget.append(title)

    if (!nodeData.stats) {
      this.addLine("Building-event data is not tracked yet.")
    } else {
      this.addResult("Overall", nodeData.stats.overall, true)
      nodeData.stats.positions.forEach((result) => this.addResult(`${this.positionName(result.position)} research`, result))
      if (nodeData.stats.next_choices.length) {
        const heading = document.createElement("b")
        heading.textContent = "Best observed next research"
        this.tooltipTarget.append(heading)
        nodeData.stats.next_choices.forEach((choice) => this.addLine(`${choice.label}: ${choice.win_ratio.toFixed(1)}% win`))
      }
    }

    this.tooltipTarget.hidden = false
    this.positionTooltip(event)
  }

  addResult(label, result, includeReachRate = false) {
    if (!result) return

    const detail = includeReachRate ? `${result.reach_rate.toFixed(1)}% reach` : `${result.rounds.toLocaleString()} samples`
    this.addLine(`${label}: ${result.win_ratio.toFixed(1)}% win · ${detail}`)
  }

  addLine(text) {
    const line = document.createElement("span")
    line.textContent = text
    this.tooltipTarget.append(line)
  }

  positionName(position) {
    return ["", "First", "Second", "Third"][position] || `${position}th`
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
    this.graphTarget.querySelector(".tech-requirements__observed-edges")?.remove()
  }

  showObservedEdges(nodeId, nodeData) {
    this.graphTarget.querySelector(".tech-requirements__observed-edges")?.remove()
    if (!nodeData.stats?.next_choices.length) return

    const svg = this.graphTarget.querySelector("svg")
    const namespace = "http://www.w3.org/2000/svg"
    const overlay = document.createElementNS(namespace, "g")
    overlay.setAttribute("class", "tech-requirements__observed-edges")
    const source = this.svgPointForNode(svg, nodeId)
    if (!source) return

    nodeData.stats.next_choices.forEach((choice) => {
      const target = this.svgPointForNode(svg, choice.key)
      if (!target) return

      const path = document.createElementNS(namespace, "path")
      path.setAttribute("d", `M ${source.x} ${source.y} L ${target.x} ${target.y}`)
      path.setAttribute("class", "tech-requirements__observed-edge")
      overlay.append(path)

      const label = document.createElementNS(namespace, "text")
      label.setAttribute("x", (source.x + target.x) / 2)
      label.setAttribute("y", (source.y + target.y) / 2 - 5)
      label.setAttribute("class", "tech-requirements__observed-edge-label")
      label.textContent = `${choice.win_ratio.toFixed(1)}%`
      overlay.append(label)
    })
    svg.append(overlay)
  }

  svgPointForNode(svg, nodeId) {
    const node = this.graphTarget.querySelector(`[id^="flowchart-${nodeId}-"]`)
    if (!node) return null

    const bounds = node.getBoundingClientRect()
    const point = svg.createSVGPoint()
    point.x = bounds.left + bounds.width / 2
    point.y = bounds.top + bounds.height / 2
    return point.matrixTransform(svg.getScreenCTM().inverse())
  }
}