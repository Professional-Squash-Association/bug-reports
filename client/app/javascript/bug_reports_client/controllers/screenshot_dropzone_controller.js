// Drag-and-drop screenshot picker with small client-side previews.
// The hidden multiple file input remains the source of truth for form
// submission - this controller keeps input.files in sync with an internal
// DataTransfer store, so the server sees a perfectly normal file upload.
//
// Registered by the host's Stimulus loader as
// "bug-reports-client--screenshot-dropzone".
//
// Targets: zone (the drop area), input (hidden file input),
//          previews (thumbnail container), message (limit warnings)
// Values:  max (file limit), limitMessage (warning text, from i18n)
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["zone", "input", "previews", "message"]
  static values = {
    max: { type: Number, default: 5 },
    maxBytes: { type: Number, default: 10_485_760 },
    limitMessage: String,
    sizeMessage: String,
    // Classes toggled on the zone while a file is dragged over it. Dark
    // themes should override via the Stimulus value (space-separated).
    highlightClasses: { type: String, default: "border-slate-500 bg-slate-100" }
  }

  connect() {
    this.store = new DataTransfer()
  }

  disconnect() {
    this.revokePreviewUrls()
  }

  browse() {
    this.inputTarget.click()
  }

  keydown(event) {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault()
      this.browse()
    }
  }

  // Files chosen via the browse dialog are merged into the current selection
  // rather than replacing it, matching how dropping behaves.
  picked() {
    this.add(this.inputTarget.files)
  }

  dragover(event) {
    event.preventDefault()
    this.zoneTarget.classList.add(...this.highlightClassList())
  }

  dragleave() {
    this.zoneTarget.classList.remove(...this.highlightClassList())
  }

  highlightClassList() {
    return this.highlightClassesValue.split(/\s+/).filter(Boolean)
  }

  drop(event) {
    event.preventDefault()
    this.dragleave()
    this.add(event.dataTransfer.files)
  }

  add(fileList) {
    this.clearMessage()

    for (const file of Array.from(fileList)) {
      if (!file.type.startsWith("image/")) continue
      if (this.alreadySelected(file)) continue

      // Oversized files are refused here, at selection time - far better
      // than a server-side rejection after the user has submitted.
      if (file.size > this.maxBytesValue) {
        this.showMessage(this.sizeMessageValue.replace("%{filename}", file.name))
        continue
      }

      if (this.store.items.length >= this.maxValue) {
        this.showMessage(this.limitMessageValue)
        break
      }

      this.store.items.add(file)
    }

    this.sync()
  }

  remove(event) {
    const index = Number(event.currentTarget.dataset.index)
    const kept = new DataTransfer()

    Array.from(this.store.files).forEach((file, i) => {
      if (i !== index) kept.items.add(file)
    })

    this.store = kept
    this.clearMessage()
    this.sync()
  }

  // Keep input.files as the single submission source, then redraw previews.
  sync() {
    this.inputTarget.files = this.store.files
    this.renderPreviews()
  }

  renderPreviews() {
    this.revokePreviewUrls()
    this.previewsTarget.innerHTML = ""

    Array.from(this.store.files).forEach((file, index) => {
      const tile = document.createElement("div")
      tile.className = "relative"

      const img = document.createElement("img")
      img.src = URL.createObjectURL(file)
      img.alt = file.name
      img.className = "h-16 w-16 object-cover rounded-lg border border-slate-200"

      const removeButton = document.createElement("button")
      removeButton.type = "button"
      removeButton.dataset.index = index
      removeButton.dataset.action = "bug-reports-client--screenshot-dropzone#remove"
      removeButton.setAttribute("aria-label", `Remove ${file.name}`)
      removeButton.className = "absolute -top-1.5 -right-1.5 flex h-5 w-5 items-center justify-center rounded-full bg-slate-700 text-xs leading-none text-white hover:bg-slate-900"
      removeButton.textContent = "×"

      tile.appendChild(img)
      tile.appendChild(removeButton)
      this.previewsTarget.appendChild(tile)
    })
  }

  alreadySelected(file) {
    return Array.from(this.store.files).some((existing) =>
      existing.name === file.name && existing.size === file.size && existing.lastModified === file.lastModified
    )
  }

  revokePreviewUrls() {
    this.previewsTarget.querySelectorAll("img").forEach((img) => URL.revokeObjectURL(img.src))
  }

  showMessage(text) {
    if (this.hasMessageTarget) this.messageTarget.textContent = text
  }

  clearMessage() {
    if (this.hasMessageTarget) this.messageTarget.textContent = ""
  }
}
