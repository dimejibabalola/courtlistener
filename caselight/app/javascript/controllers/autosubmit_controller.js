import { Controller } from "@hotwired/stimulus"

// Live faceting: submit the filter form when any control changes.
export default class extends Controller {
  submit() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.element.requestSubmit(), 150)
  }

  disconnect() {
    clearTimeout(this.timer)
  }
}
