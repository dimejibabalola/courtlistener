import { Controller } from "@hotwired/stimulus"

// AI assistant thread: keep scrolled to the latest message, show a pending
// indicator while the grounded answer is generated.
export default class extends Controller {
  static targets = ["messages", "input", "pending"]

  connect() {
    this.scrollToBottom()
    this.observer = new MutationObserver(() => {
      this.scrollToBottom()
      this.hidePending()
    })
    if (this.hasMessagesTarget) this.observer.observe(this.messagesTarget, { childList: true, subtree: true })
  }

  submit() {
    if (this.hasPendingTarget) this.pendingTarget.classList.remove("hidden")
    if (this.hasInputTarget) setTimeout(() => (this.inputTarget.value = ""), 10)
  }

  hidePending() {
    if (this.hasPendingTarget) this.pendingTarget.classList.add("hidden")
  }

  scrollToBottom() {
    if (this.hasMessagesTarget) this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
  }

  disconnect() {
    this.observer?.disconnect()
  }
}
