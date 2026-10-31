import { Controller } from "@hotwired/stimulus"

// Toggles dark mode on <html>; the choice is kept in a cookie so the server renders it on the next page
export default class extends Controller {
  toggle() {
    const dark = document.documentElement.classList.toggle("dark")
    document.cookie = `theme=${dark ? "dark" : "light"}; path=/; max-age=31536000; samesite=lax`
  }
}
