import { Controller } from "@hotwired/stimulus"

// Makes any <table data-controller="sortable-table"> sortable by clicking
// its column headers, entirely client-side (no server round-trip). Mark
// each sortable <th> with a `data-sort-type` ("string" or "number")
// attribute, and give every <td> in that column a matching
// `data-sort-value` holding the raw comparable value -- see
// AnalysisHelper#sortable_table, which generates both. Rows with a blank
// data-sort-value always sort last, regardless of direction.
export default class extends Controller {
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
  }

  disconnect() {
    this.handlers.forEach((handler, header) => header.removeEventListener("click", handler))
  }

  get headers() {
    return Array.from(this.element.querySelectorAll("thead th[data-sort-type]"))
  }

  sortBy(header) {
    const direction = header.getAttribute("aria-sort") === "ascending" ? "descending" : "ascending"
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
  }

  compareCells(cellA, cellB, type, direction) {
    const rawA = cellA?.dataset.sortValue ?? ""
    const rawB = cellB?.dataset.sortValue ?? ""
    const ascending = direction === "ascending"

    if (type === "number") {
      const numA = rawA === "" ? null : parseFloat(rawA)
      const numB = rawB === "" ? null : parseFloat(rawB)
      if (numA === null || numB === null) return numA === numB ? 0 : numA === null ? 1 : -1
      return ascending ? numA - numB : numB - numA
    }

    if (rawA === "" || rawB === "") return rawA === rawB ? 0 : rawA === "" ? 1 : -1
    return ascending ? rawA.localeCompare(rawB) : rawB.localeCompare(rawA)
  }
}
