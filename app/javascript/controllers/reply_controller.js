import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "toggle"]

  toggle(event) {
    event.preventDefault()
    this.closeOthers()
    this.formTarget.hidden = !this.formTarget.hidden
    this.toggleTarget.classList.toggle("hidden", !this.formTarget.hidden)
    if (!this.formTarget.hidden) {
      this.formTarget.querySelector("textarea")?.focus()
    }
  }

  closeOthers() {
    this.element.closest(".comments")
      ?.querySelectorAll("[data-controller='reply']")
      .forEach((other) => {
        if (other === this.element) return
        const form = other.querySelector("[data-reply-target='form']")
        const toggle = other.querySelector("[data-reply-target='toggle']")
        if (form) form.hidden = true
        if (toggle) toggle.classList.remove("hidden")
      })
  }
}
