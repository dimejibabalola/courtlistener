import { Controller } from "@hotwired/stimulus"

// Highlight-and-annotate: select text inside the opinion, the floating
// button captures the quote into the annotation form.
export default class extends Controller {
  static targets = ["text", "button", "quoteField", "form", "preview"]

  check() {
    const selection = window.getSelection()
    const text = selection?.toString().trim()
    if (text && text.length > 3 && this.textTarget.contains(selection.anchorNode)) {
      const rect = selection.getRangeAt(0).getBoundingClientRect()
      const host = this.element.getBoundingClientRect()
      this.buttonTarget.style.top = `${rect.top - host.top - 38}px`
      this.buttonTarget.style.left = `${Math.max(rect.left - host.left, 8)}px`
      this.buttonTarget.classList.remove("hidden")
      this.pendingQuote = text.slice(0, 1000)
    } else {
      this.buttonTarget.classList.add("hidden")
    }
  }

  capture(event) {
    event.preventDefault()
    this.quoteFieldTarget.value = this.pendingQuote || ""
    if (this.hasPreviewTarget) this.previewTarget.textContent = this.pendingQuote || ""
    this.buttonTarget.classList.add("hidden")
    this.formTarget.classList.remove("hidden")
    this.formTarget.querySelector("textarea")?.focus()
  }

  cancel(event) {
    event.preventDefault()
    this.formTarget.classList.add("hidden")
  }
}
