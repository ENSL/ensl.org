import { Controller } from "@hotwired/stimulus"
import { Chart } from "chart.js"

const ACCOUNT_COLOR = "#2563eb"
const AVERAGE_SKILL_COLOR = "#0f766e"
const TOP_SKILL_COLOR = "#dc2626"
const SKILL_PER_PLAYER_COLOR = "#16a34a"

export default class extends Controller {
  static targets = ["accountsCanvas", "roundsCanvas", "skillPerPlayerCanvas"]
  static values = { accounts: Array, roundSkill: Array, skillPerPlayer: Array }

  connect() {
    this.accountsChart = new Chart(this.accountsCanvasTarget, {
      type: "bar",
      data: {
        labels: this.accountsValue.map((row) => row.country_name),
        datasets: [{ label: "ENSL players", data: this.accountsValue.map((row) => row.players), backgroundColor: ACCOUNT_COLOR }]
      },
      options: this.horizontalBarOptions("Players")
    })

    if (this.hasRoundsCanvasTarget) {
      this.roundsChart = new Chart(this.roundsCanvasTarget, {
        type: "bar",
        data: {
          labels: this.roundSkillValue.map((row) => row.country_name),
          datasets: [
            { label: "Average DL skill", data: this.roundSkillValue.map((row) => row.average_skill), backgroundColor: AVERAGE_SKILL_COLOR },
            { label: "Top 10 average DL skill", data: this.roundSkillValue.map((row) => row.top_ten_average_skill), borderColor: TOP_SKILL_COLOR, backgroundColor: TOP_SKILL_COLOR, type: "line" }
          ]
        },
        options: this.roundsOptions()
      })
    }

    if (this.hasSkillPerPlayerCanvasTarget) {
      this.skillPerPlayerChart = new Chart(this.skillPerPlayerCanvasTarget, {
        type: "bar",
        data: {
          labels: this.skillPerPlayerValue.map((row) => row.country_name),
          datasets: [{ label: "Average DL skill / player", data: this.skillPerPlayerValue.map((row) => row.skill_per_player), backgroundColor: SKILL_PER_PLAYER_COLOR }]
        },
        options: this.horizontalBarOptions("Average DL skill / player")
      })
    }
  }

  disconnect() {
    this.accountsChart?.destroy()
    this.roundsChart?.destroy()
    this.skillPerPlayerChart?.destroy()
  }

  horizontalBarOptions(title) {
    return {
      indexAxis: "y",
      responsive: true,
      maintainAspectRatio: false,
      scales: { x: { beginAtZero: true, title: { display: true, text: title } } },
      plugins: { legend: { display: false } }
    }
  }

  roundsOptions() {
    return {
      indexAxis: "y",
      responsive: true,
      maintainAspectRatio: false,
      interaction: { mode: "index", intersect: false },
      scales: { x: { beginAtZero: true, title: { display: true, text: "DL skill" } } }
    }
  }
}