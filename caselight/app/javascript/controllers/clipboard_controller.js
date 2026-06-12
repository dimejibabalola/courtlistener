import { Controller } from "@hotwired/stimulus"

// Copy-with-citation. Reads the text from a data value or a source target.
export default class extends Controller {
  static targets = ["source", "feedback"]
  static values = { text: String }

  async copy(event) {
    event.preventDefault()
    const text = this.textValue || this.sourceTarget?.innerText || ""
    await navigator.clipboard.writeText(text.trim())
    if (this.hasFeedbackTarget) {
      this.feedbackTarget.classList.remove("hidden")
      setTimeout(() => this.feedbackTarget.classList.add("hidden"), 1500)
    }
  }
}
