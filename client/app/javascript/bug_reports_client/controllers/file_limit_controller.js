// Validates the number of files selected in a file input. Shows a
// native-style validation message if the limit is exceeded.
//
// Registered by the host's Stimulus loader as "bug-reports-client--file-limit".
//
// Usage:
//   <div data-controller="bug-reports-client--file-limit"
//        data-bug-reports-client--file-limit-max-value="5">
//     <input type="file" multiple
//            data-bug-reports-client--file-limit-target="input"
//            data-action="change->bug-reports-client--file-limit#validate">
//   </div>
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]
  static values = { max: { type: Number, default: 5 } }

  validate() {
    const input = this.inputTarget
    const max = this.maxValue

    if (input.files.length > max) {
      input.setCustomValidity(`You can attach a maximum of ${max} images.`)
      input.reportValidity()
      input.value = ""
    } else {
      input.setCustomValidity("")
    }
  }
}
