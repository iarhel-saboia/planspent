import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { dialog: String }

  open() {
    const dialog = document.getElementById(this.dialogValue)
    this.application.getControllerForElementAndIdentifier(dialog, "modal")?.open()
  }
}
