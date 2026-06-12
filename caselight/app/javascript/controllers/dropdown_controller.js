import { Controller } from "@hotwired/stimulus"

// Accessible disclosure menu: toggles a panel, closes on outside click / Esc.
export default class extends Controller {
  static targets = ["panel", "button"]

  connect() {
    this.close = this.close.bind(this)
    this.onKeydown = this.onKeydown.bind(this)
  }

  toggle(event) {
    event.stopPropagation()
    this.panelTarget.classList.contains("hidden") ? this.open() : this.close()
  }

  open() {
    this.panelTarget.classList.remove("hidden")
    this.buttonTarget?.setAttribute("aria-expanded", "true")
    document.addEventListener("click", this.close)
    document.addEventListener("keydown", this.onKeydown)
  }

  close() {
    this.panelTarget.classList.add("hidden")
    if (this.hasButtonTarget) this.buttonTarget.setAttribute("aria-expanded", "false")
    document.removeEventListener("click", this.close)
    document.removeEventListener("keydown", this.onKeydown)
  }

  onKeydown(event) {
    if (event.key === "Escape") this.close()
  }

  stop(event) {
    event.stopPropagation()
  }

  disconnect() {
    document.removeEventListener("click", this.close)
    document.removeEventListener("keydown", this.onKeydown)
  }
}
