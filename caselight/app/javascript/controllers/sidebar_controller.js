import { Controller } from "@hotwired/stimulus"

// Collapsible navigation rail; remembers state across visits.
export default class extends Controller {
  static targets = ["label", "rail", "collapseIcon"]

  connect() {
    if (localStorage.getItem("caselight:sidebar") === "collapsed") this.apply(true)
  }

  toggle() {
    const collapsed = !this.railTarget.classList.contains("w-16")
    this.apply(collapsed)
    localStorage.setItem("caselight:sidebar", collapsed ? "collapsed" : "open")
  }

  apply(collapsed) {
    this.railTarget.classList.toggle("w-56", !collapsed)
    this.railTarget.classList.toggle("w-16", collapsed)
    this.labelTargets.forEach((el) => el.classList.toggle("hidden", collapsed))
    if (this.hasCollapseIconTarget) this.collapseIconTarget.classList.toggle("rotate-180", collapsed)
  }
}
