import { Controller } from "@hotwired/stimulus"
import { Chart } from "chart.js"

// Marine win rate as a function of round length: a line over bars, where the
// bars are how many rounds each length bucket actually holds. Without them a
// 100% win rate off two rounds looks exactly like one off two hundred. Fed by
// Analysis::RoundLengthsController#index (see RoundLengthQuery).
const MARINE_COLOR = "#3b82f6"
const SAMPLE_COLOR = "rgba(148, 163, 184, 0.45)"

// Dashed reference line at the 50% mark, same idea as the map balance chart:
// above it the length favours marines, below it aliens.
const balanceLinePlugin = {
  id: "roundLengthBalanceLine",
  afterDatasetsDraw(chart) {
    const scale = chart.scales.winRate
    if (!scale) return

    const { ctx, chartArea } = chart
    const y = scale.getPixelForValue(50)

    ctx.save()
    ctx.strokeStyle = "rgba(0, 0, 0, 0.55)"
    ctx.setLineDash([4, 4])
    ctx.lineWidth = 1
    ctx.beginPath()
    ctx.moveTo(chartArea.left, y)
    ctx.lineTo(chartArea.right, y)
    ctx.stroke()
    ctx.restore()
  }
}

export default class extends Controller {
  static targets = ["canvas"]
  static values = { buckets: Array }

  connect() {
    this.chart = new Chart(this.canvasTarget, {
      type: "bar",
      data: {
        labels: this.bucketsValue.map((bucket) => bucket.label),
        datasets: [
          {
            type: "line",
            label: "Marine win %",
            yAxisID: "winRate",
            data: this.bucketsValue.map((bucket) => bucket.marine_win_percentage),
            borderColor: MARINE_COLOR,
            backgroundColor: MARINE_COLOR,
            spanGaps: true,
            tension: 0.25
          },
          {
            type: "bar",
            label: "Rounds",
            yAxisID: "rounds",
            data: this.bucketsValue.map((bucket) => bucket.rounds),
            backgroundColor: SAMPLE_COLOR,
            order: 2
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: { mode: "index", intersect: false },
        scales: {
          x: { title: { display: true, text: "Round length (minutes)" } },
          winRate: {
            position: "left",
            min: 0,
            max: 100,
            title: { display: true, text: "Marine win %" },
            ticks: { callback: (value) => `${value}%` }
          },
          rounds: {
            position: "right",
            beginAtZero: true,
            title: { display: true, text: "Rounds" },
            grid: { drawOnChartArea: false }
          }
        },
        plugins: {
          tooltip: {
            callbacks: {
              label: (context) =>
                context.dataset.yAxisID === "winRate"
                  ? `Marine win %: ${context.parsed.y === null ? "no data" : `${context.parsed.y.toFixed(1)}%`}`
                  : `Rounds: ${context.parsed.y}`
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
