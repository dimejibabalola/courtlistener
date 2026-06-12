import { Controller } from "@hotwired/stimulus"

// Drafting editor: contenteditable surface with a formatting toolbar, a
// hidden field kept in sync for form submission, and "Insert" which fetches
// a grounded paragraph from the drafting assistant.
export default class extends Controller {
  static targets = ["surface", "field", "tone", "insertButton"]
  static values = { generateUrl: String, documentSlug: String }

  connect() {
    this.sync()
  }

  format(event) {
    event.preventDefault()
    const command = event.params.command
    const value = event.params.value || null
    this.surfaceTarget.focus()
    document.execCommand(command, false, value)
    this.sync()
  }

  sync() {
    if (this.hasFieldTarget) this.fieldTarget.value = this.surfaceTarget.innerHTML
  }

  async insert(event) {
    event.preventDefault()
    if (!this.generateUrlValue) return
    const button = this.hasInsertButtonTarget ? this.insertButtonTarget : null
    if (button) { button.disabled = true; button.dataset.label = button.textContent; button.textContent = "…" }
    try {
      const tone = this.hasToneTarget ? this.toneTarget.value : "neutral"
      const response = await fetch(this.generateUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
        },
        body: JSON.stringify({ document_slug: this.documentSlugValue, tone })
      })
      if (response.ok) {
        const data = await response.json()
        const p = document.createElement("p")
        p.textContent = data.paragraph
        this.surfaceTarget.appendChild(p)
        this.sync()
        this.surfaceTarget.dispatchEvent(new Event("input", { bubbles: true }))
      }
    } finally {
      if (button) { button.disabled = false; button.textContent = button.dataset.label }
    }
  }

  // Debounced autosave for persisted drafts (form with data-editor-target="field").
  autosave() {
    this.sync()
    clearTimeout(this.saveTimer)
    this.saveTimer = setTimeout(() => {
      this.element.closest("form")?.requestSubmit()
    }, 1200)
  }

  disconnect() {
    clearTimeout(this.saveTimer)
  }
}
