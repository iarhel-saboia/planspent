import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  open() {
    this.element.showModal()
    this.element.querySelector("[autofocus]")?.focus()
  }

  close() {
    this.element.close()
  }

  backdropClose(event) {
    if (event.target === this.element) this.close()
  }
}
