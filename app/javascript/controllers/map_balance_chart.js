import { Controller } from "@hotwired/stimulus"
import { Chart } from "chart.js"

// Renders the marine-vs-alien win rate per map as a 100%-stacked horizontal
// bar chart: each map's bar splits into a marine share and an alien share
// that together always add up to 100%, so a perfectly balanced map shows an
// even split right at the middle dashed line. Fed by
// Analysis::MapsController#index (see MapBalanceQuery) via a JSON value
// attribute -- no extra AJAX round-trip needed for this small dataset.
const MARINE_COLOR = "#3b82f6"
const ALIEN_COLOR = "#f59e0b"

// Draws a dashed reference line at the 50% mark so it's obvious at a glance
// whether a map favors one side. Plain Chart.js plugin instead of pulling in
// the separate annotation plugin, since this is the only annotation needed.
const balanceLinePlugin = {
  id: "balanceLine",
  afterDraw(chart) {
    const scale = chart.scales.x
    const { ctx, chartArea } = chart
    const x = scale.getPixelForValue(50)

    ctx.save()
    ctx.strokeStyle = "rgba(0, 0, 0, 0.55)"
    ctx.setLineDash([4, 4])
    ctx.lineWidth = 1
    ctx.beginPath()
    ctx.moveTo(x, chartArea.top)
    ctx.lineTo(x, chartArea.bottom)
    ctx.stroke()
    ctx.restore()
  }
}

export default class extends Controller {
  static targets = ["canvas"]
  static values = { maps: Array }

  connect() {
    const labels = this.mapsValue.map((row) => row.map_name)

    this.chart = new Chart(this.canvasTarget, {
      type: "bar",
      data: {
        labels,
        datasets: [
          {
            label: "Marine wins %",
            data: this.mapsValue.map((row) => row.marine_win_percentage),
            backgroundColor: MARINE_COLOR
          },
          {
            label: "Alien wins %",
            data: this.mapsValue.map((row) => row.alien_win_percentage),
            backgroundColor: ALIEN_COLOR
          }
        ]
      },
      options: {
        indexAxis: "y",
        responsive: true,
        maintainAspectRatio: false,
        scales: {
          x: {
            stacked: true,
            min: 0,
            max: 100,
            ticks: { callback: (value) => `${value}%` }
          },
          y: { stacked: true }
        },
        plugins: {
          tooltip: {
            callbacks: {
              label: (context) => `${context.dataset.label}: ${context.parsed.x.toFixed(1)}%`
            }
          }
        }
      },
      plugins: [balanceLinePlugin]
    })
  }

  disconnect() {
    this.chart?.destroy()
  }
}
