import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { enabled: Boolean }

  connect() {
    this.connected = true
    this.attempts = 0
    this.insertFileListener = this.insertFile.bind(this)
    window.addEventListener("article:file-added", this.insertFileListener)
    if (this.enabledValue) this.enable()
  }

  disconnect() {
    this.connected = false
    window.removeEventListener("article:file-added", this.insertFileListener)
    window.clearTimeout(this.retryTimer)
    this.editor?.remove()
  }

  enabledValueChanged(enabled) {
    if (!this.connected) return

    if (enabled) {
      this.enable()
    } else {
      this.disable()
    }
  }

  enable() {
    this.element.classList.add("article-editor-loading")
    this.initializing = false
    this.attempts = 0
    this.initializeEditor()
  }

  disable() {
    window.clearTimeout(this.retryTimer)
    const textarea = this.element.querySelector("textarea.tinymce")
    const editor = textarea && window.tinymce?.get(textarea.id)
    if (editor) {
      editor.save()
      editor.remove()
    }
    this.editor = null
    this.initializing = false
    this.element.classList.remove("article-editor-loading")
  }

  initializeEditor() {
    if (typeof window.tinymce === "undefined" || typeof window.TinyMCERails === "undefined") {
      this.retryInitialization()
      return
    }

    const textarea = this.element.querySelector("textarea.tinymce")
    if (!textarea) return

    const existingEditor = window.tinymce.get(textarea.id)
    if (existingEditor) {
      this.activateEditor(existingEditor)
      return
    }

    if (this.initializing) {
      this.retryTimer = window.setTimeout(() => this.initializeEditor(), 50)
      return
    }

    this.initializing = true
    window.TinyMCERails.initialize("articles", {
      selector: `#${textarea.id}`,
      setup: (editor) => {
        editor.on("init", () => this.activateEditor(editor))
        editor.on("change input undo redo", () => {
          window.dispatchEvent(new CustomEvent("article:content-changed"))
        })
      }
    })
    this.retryTimer = window.setTimeout(() => this.initializeEditor(), 50)
  }

  retryInitialization() {
    this.attempts += 1
    if (this.attempts >= 200) {
      this.element.classList.remove("article-editor-loading")
      return
    }

    this.retryTimer = window.setTimeout(() => this.initializeEditor(), 50)
  }

  insertFile(event) {
    const { url, title, image } = event.detail
    const textarea = this.element.querySelector("textarea.tinymce")
    const editor = this.editor || window.tinymce?.get(textarea?.id)
    if (!editor) {
      this.insertMarkdownFile(textarea, { url, title, image })
      return
    }

    const escapedUrl = editor.dom.encode(url)
    const escapedTitle = editor.dom.encode(title)
    const html = image
      ? `<img src="${escapedUrl}" alt="${escapedTitle}">`
      : `<a href="${escapedUrl}">${escapedTitle}</a>`

    editor.insertContent(html)
    editor.focus()
  }

  insertMarkdownFile(textarea, { url, title, image }) {
    if (!textarea) return

    const escapedTitle = title.replace(/([\\\[\]])/g, "\\$1")
    const escapedUrl = url.replace(/([\\()])/g, "\\$1")
    const markdown = image
      ? `![${escapedTitle}](${escapedUrl})`
      : `[${escapedTitle}](${escapedUrl})`
    const selectionStart = textarea.selectionStart
    const selectionEnd = textarea.selectionEnd

    textarea.setRangeText(markdown, selectionStart, selectionEnd, "end")
    textarea.dispatchEvent(new Event("input", { bubbles: true }))
    textarea.focus()
  }

  activateEditor(editor) {
    this.editor = editor
    this.element.classList.remove("article-editor-loading")
  }
}