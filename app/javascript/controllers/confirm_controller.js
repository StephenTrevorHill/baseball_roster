import { Controller } from "@hotwired/stimulus"

// Usage:
// <form data-controller="confirm"
//       data-confirm-message-value="Remove Bo Bichette?"
//       data-action="submit->confirm#submit">
//   ...
// </form>
export default class extends Controller {
    static values = {
        message: String,
        confirmLabel: { type: String, default: "Remove" },
        cancelLabel: { type: String, default: "Cancel" },
    }

    submit(event) {
        if (this.element.dataset.confirmed === "1") return; // allow second pass

        event.preventDefault()
        this.#showModal({
            message: this.messageValue || "Are you sure?",
            confirmLabel: this.confirmLabelValue,
            cancelLabel: this.cancelLabelValue,
            onConfirm: () => {
                this.element.dataset.confirmed = "1"
                this.element.requestSubmit()
            }
        })
    }

    #showModal({ message, confirmLabel, cancelLabel, onConfirm }) {
        const overlay = document.createElement("div")
        overlay.style.position = "fixed"
        overlay.style.inset = "0"
        overlay.style.background = "rgba(0,0,0,0.45)"
        overlay.style.display = "flex"
        overlay.style.alignItems = "center"
        overlay.style.justifyContent = "center"
        overlay.style.zIndex = "9999"

        const modal = document.createElement("div")
        modal.role = "dialog"
        modal.ariaModal = "true"
        modal.style.background = "white"
        modal.style.padding = "20px"
        modal.style.borderRadius = "12px"
        modal.style.minWidth = "300px"
        modal.style.maxWidth = "90vw"
        modal.style.boxShadow = "0 10px 30px rgba(0,0,0,0.2)"

        const text = document.createElement("div")
        text.textContent = message
        text.style.marginBottom = "16px"
        text.style.fontSize = "16px"

        const row = document.createElement("div")
        row.style.display = "flex"
        row.style.gap = "8px"
        row.style.justifyContent = "flex-end"

        const cancelBtn = document.createElement("button")
        cancelBtn.type = "button"
        cancelBtn.textContent = cancelLabel
        cancelBtn.className = "btn"

        const okBtn = document.createElement("button")
        okBtn.type = "button"
        okBtn.textContent = confirmLabel
        okBtn.className = "btn btn-danger"

        cancelBtn.addEventListener("click", () => document.body.removeChild(overlay))
        overlay.addEventListener("click", (e) => { if (e.target === overlay) document.body.removeChild(overlay) })
        okBtn.addEventListener("click", () => {
            document.body.removeChild(overlay)
            onConfirm && onConfirm()
        })

        row.append(cancelBtn, okBtn)
        modal.append(text, row)
        overlay.append(modal)
        document.body.append(overlay)
        okBtn.focus()
    }
}