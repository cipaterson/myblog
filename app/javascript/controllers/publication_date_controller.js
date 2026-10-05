import { Controller } from "@hotwired/stimulus"

// The publication date is only meaningful for a published post, so the field
// stays hidden until "Published" is ticked. The form renders the correct state
// server-side; this only keeps the two in sync as the checkbox is toggled.
export default class extends Controller {
  static targets = [ "toggle", "field" ]

  connect() {
    this.sync = this.sync.bind(this)
    this.toggleTarget.addEventListener("change", this.sync)
    this.sync()
  }

  disconnect() {
    this.toggleTarget.removeEventListener("change", this.sync)
  }

  sync() {
    this.fieldTarget.hidden = !this.toggleTarget.checked
  }
}
