// Swaps the form fields based on the selected report type: bugs and feature
// requests collect different information, so only the matching group is shown.
// The hidden group's inputs are disabled so they neither submit nor block
// `required` validation. Readonly (closed) reports keep their disabled state.
//
// Registered by the host's Stimulus loader as "bug-reports-client--report-type".
//
// Usage (radio cards - a select or hidden input also works as the target):
//   <form data-controller="bug-reports-client--report-type"
//         data-bug-reports-client--report-type-readonly-value="false">
//     <input type="radio" value="bug" data-bug-reports-client--report-type-target="type"
//            data-action="change->bug-reports-client--report-type#toggle">
//     <div data-bug-reports-client--report-type-target="bugFields">...</div>
//     <div data-bug-reports-client--report-type-target="featureFields">...</div>
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["type", "bugFields", "featureFields", "summary"]
  static values = { readonly: Boolean, bugSummary: String, featureSummary: String }

  connect() {
    this.toggle()
  }

  toggle() {
    const isFeature = this.currentType() === "feature"
    if (this.hasFeatureFieldsTarget) this.applyGroup(this.featureFieldsTarget, isFeature)
    if (this.hasBugFieldsTarget) this.applyGroup(this.bugFieldsTarget, !isFeature)

    if (this.hasSummaryTarget) {
      this.summaryTarget.placeholder = isFeature ? this.featureSummaryValue : this.bugSummaryValue
    }
  }

  // The type targets are either radio cards (one per type) or a single
  // select/hidden input - support both so hosts can restyle freely.
  currentType() {
    const radios = this.typeTargets.filter((input) => input.type === "radio")
    if (radios.length > 0) {
      const checked = radios.find((radio) => radio.checked)
      return checked ? checked.value : "bug"
    }
    return this.typeTargets[0]?.value
  }

  applyGroup(group, show) {
    group.classList.toggle("hidden", !show)
    if (this.readonlyValue) return

    group.querySelectorAll("input, select, textarea").forEach((input) => {
      input.disabled = !show
    })
  }
}
