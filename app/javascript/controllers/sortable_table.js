import { Controller } from "@hotwired/stimulus"

// Makes any <table data-controller="sortable-table"> sortable by clicking
// its column headers. The selected column is stored in the URL so it survives
// reloads and filter changes. Mark each sortable <th> with a `data-sort-type`
// ("string" or "number") attribute, and give every <td> in that column a
// matching `data-sort-value` holding the raw comparable value -- see
// AnalysisHelper#sortable_table, which generates both. Rows with a blank
// data-sort-value always sort last, regardless of direction.
export default class extends Controller {
  static values = {
    defaultKey: String,
    defaultDirection: { type: String, default: "ascending" }
  }

  connect() {
    this.handlers = new Map()

    this.headers.forEach((header) => {
      header.classList.add("sortable-table-header")

      const indicator = document.createElement("span")
      indicator.className = "sortable-table-indicator"
      indicator.setAttribute("aria-hidden", "true")
      header.append(" ", indicator)

      const handler = () => this.sortBy(header)
      header.addEventListener("click", handler)
      this.handlers.set(header, handler)
    })

    const defaultHeader = this.headers.find((header) => header.dataset.sortKey === this.defaultKeyValue)
    if (defaultHeader) {
      this.sortBy(defaultHeader, this.defaultDirectionValue, false)
      this.syncFilterForms(defaultHeader.dataset.sortKey, this.defaultDirectionValue)
    }
  }

  disconnect() {
    this.handlers.forEach((handler, header) => header.removeEventListener("click", handler))
  }

  get headers() {
    return Array.from(this.element.querySelectorAll("thead th[data-sort-type]"))
  }

  sortBy(header, direction = null, updateUrl = true) {
    direction ||= header.getAttribute("aria-sort") === "ascending" ? "descending" : "ascending"
    const columnIndex = Array.from(header.parentElement.children).indexOf(header)
    const type = header.dataset.sortType || "string"

    this.headers.forEach((other) => {
      other.removeAttribute("aria-sort")
      other.querySelector(".sortable-table-indicator").textContent = ""
    })
    header.setAttribute("aria-sort", direction)
    header.querySelector(".sortable-table-indicator").textContent = direction === "ascending" ? "▲" : "▼"

    const tbody = this.element.querySelector("tbody")
    const rows = Array.from(tbody.rows)
    rows.sort((rowA, rowB) => this.compareCells(rowA.cells[columnIndex], rowB.cells[columnIndex], type, direction))
    rows.forEach((row) => tbody.append(row))

    if (updateUrl) this.updateQueryParams(header.dataset.sortKey, direction)
  }

  updateQueryParams(sort, direction) {
    const url = new URL(window.location)
    url.searchParams.set("sort", sort)
    url.searchParams.set("direction", direction)
    window.history.replaceState({}, "", url)

    this.syncFilterForms(sort, direction)
  }

  syncFilterForms(sort, direction) {
    this.filterForms.forEach((form) => {
      this.setHiddenInput(form, "sort", sort)
      this.setHiddenInput(form, "direction", direction)
    })
  }

  get filterForms() {
    return Array.from(this.element.closest(".box")?.querySelectorAll('form[method="get"]') || [])
  }

  setHiddenInput(form, name, value) {
    let input = form.querySelector(`input[type="hidden"][name="${name}"]`)
    if (!input) {
      input = document.createElement("input")
      input.type = "hidden"
      input.name = name
      form.append(input)
    }
    input.value = value
  }

  compareCells(cellA, cellB, type, direction) {
    const rawA = cellA?.dataset.sortValue ?? ""
    const rawB = cellB?.dataset.sortValue ?? ""
    const blankOrder = this.compareBlankValues(rawA, rawB)

    if (blankOrder !== null) return blankOrder
    if (type === "number") return this.compareNumbers(rawA, rawB, direction)

    return this.compareStrings(rawA, rawB, direction)
  }

  compareBlankValues(rawA, rawB) {
    if (rawA === "" && rawB === "") return 0
    if (rawA === "") return 1
    if (rawB === "") return -1

    return null
  }

  compareNumbers(rawA, rawB, direction) {
    const numberA = parseFloat(rawA)
    const numberB = parseFloat(rawB)

    return direction === "ascending" ? numberA - numberB : numberB - numberA
  }

  compareStrings(rawA, rawB, direction) {
    return direction === "ascending" ? rawA.localeCompare(rawB) : rawB.localeCompare(rawA)
  }
}
