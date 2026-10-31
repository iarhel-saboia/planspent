import { Controller } from "@hotwired/stimulus"

// Collapses the sidebar to icons only; the state is kept in a cookie so the server renders it on the next page.
// Until the user toggles it, the state is "auto": collapsed on phones (Tailwind's md breakpoint), expanded otherwise.
export default class extends Controller {
  toggle() {
    const collapsed = !this.collapsed
    this.element.dataset.collapsed = collapsed
    document.cookie = `sidebar_collapsed=${collapsed ? 1 : 0}; path=/; max-age=31536000; samesite=lax`
  }

  get collapsed() {
    const state = this.element.dataset.collapsed
    if (state === "auto") return window.matchMedia("(max-width: 47.99rem)").matches
    return state === "true"
  }
}
