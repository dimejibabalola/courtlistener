import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { timeout: { type: Number, default: 4500 } }

  connect() {
    this.timer = setTimeout(() => this.dismiss(), this.timeoutValue)
  }

  dismiss() {
    this.element.classList.add("opacity-0", "translate-y-1")
    setTimeout(() => this.element.remove(), 250)
  }

  disconnect() {
    clearTimeout(this.timer)
  }
}
