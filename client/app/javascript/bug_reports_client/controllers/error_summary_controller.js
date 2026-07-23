// Scrolls the validation error box into view when a re-rendered form
// appears. Turbo preserves scroll position on 422 re-renders, so without
// this a user who submitted from the bottom of a long form never sees the
// errors at the top.
//
// Registered by the host's Stimulus loader as
// "bug-reports-client--error-summary".
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.scrollIntoView({ behavior: "smooth", block: "start" })
  }
}
