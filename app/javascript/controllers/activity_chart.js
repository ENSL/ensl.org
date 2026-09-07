import { Controller } from "@hotwired/stimulus"
import { Chart } from "chart.js"

// Rounds started per hour of day, collapsed across the whole week -- the bar
// chart under the weekday/hour heatmap on /analysis/activity. Fed by
// Analysis::ActivityController#index (see RoundActivityQuery) as a plain
// 24-element array, hour 0 first.
export default class extends Controller {
  static targets = ["canvas"]
  static values = { hours: Array }

  connect() {
    this.chart = new Chart(this.canvasTarget, {
      type: "bar",
      data: {
        labels: this.hoursValue.map((_count, hour) => `${String(hour).padStart(2, "0")}:00`),
        datasets: [
          {
            label: "Rounds",
            data: this.hoursValue,
            backgroundColor: "#3b82f6"
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        scales: {
          y: { beginAtZero: true, title: { display: true, text: "Rounds" } }
        },
        plugins: { legend: { display: false } }
      }
    })
  }

  disconnect() {
    this.chart?.destroy()
  }
}
