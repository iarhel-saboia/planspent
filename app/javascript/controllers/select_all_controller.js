import { Controller } from "@hotwired/stimulus"

// "Select all" checkbox for the import review list
export default class extends Controller {
  static targets = ["toggle", "item"]

  connect() {
    this.sync()
  }

  toggle() {
    this.itemTargets.forEach((item) => (item.checked = this.toggleTarget.checked))
  }

  sync() {
    const checked = this.itemTargets.filter((item) => item.checked).length
    this.toggleTarget.checked = checked === this.itemTargets.length
    this.toggleTarget.indeterminate = checked > 0 && checked < this.itemTargets.length
  }
}
