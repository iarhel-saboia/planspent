import { Controller } from "@hotwired/stimulus"

// Shows the chosen file name and accepts files dropped on the upload zone
export default class extends Controller {
  static targets = ["input", "zone", "name"]

  connect() {
    this.zoneTarget.addEventListener("dragover", this.dragover)
    this.zoneTarget.addEventListener("dragleave", this.dragleave)
    this.zoneTarget.addEventListener("drop", this.drop)
  }

  disconnect() {
    this.zoneTarget.removeEventListener("dragover", this.dragover)
    this.zoneTarget.removeEventListener("dragleave", this.dragleave)
    this.zoneTarget.removeEventListener("drop", this.drop)
  }

  show() {
    const file = this.inputTarget.files[0]
    if (file) this.nameTarget.textContent = file.name
  }

  dragover = (event) => {
    event.preventDefault()
    this.zoneTarget.classList.add("border-indigo-400")
  }

  dragleave = () => {
    this.zoneTarget.classList.remove("border-indigo-400")
  }

  drop = (event) => {
    event.preventDefault()
    this.dragleave()
    if (event.dataTransfer.files.length === 0) return
    this.inputTarget.files = event.dataTransfer.files
    this.show()
  }
}
