import { Controller } from "@hotwired/stimulus"

// Opens the page's shared "link to a goal" dialog for one entry
export default class extends Controller {
  static values = { url: String, goal: String, description: String }

  open() {
    const dialog = document.getElementById("goal_link_modal")
    if (!dialog) return

    const form = dialog.querySelector("form")
    form.action = this.urlValue
    form.querySelector("select").value = this.goalValue
    dialog.querySelector("[data-goal-link-description]").textContent = this.descriptionValue
    this.application.getControllerForElementAndIdentifier(dialog, "modal")?.open()
  }
}
