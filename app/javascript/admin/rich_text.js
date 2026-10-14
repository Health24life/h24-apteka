// Trix for the SEO text and the text of a static page. The editor offers only what the server keeps
// (Seo::Texts::Sanitize): paragraphs, h2 and h3, bold, italics, lists, quotes and links to a path of the
// section or to a site over HTTPS. Files and pictures are refused. The server cleans the text again, so this
// only spares the editor a surprise.
import "trix"

const { config } = window.Trix

// A paragraph per Enter, as the front lays the text out, instead of Trix's divs joined by line breaks.
config.blockAttributes.default.tagName = "p"
config.blockAttributes.default.breakOnReturn = true
// The page's own title is the h1, so the text starts its headings from h2.
config.blockAttributes.heading1.tagName = "h2"
config.blockAttributes.heading3 = { tagName: "h3", terminal: true, breakOnReturn: true, group: false }

// A path of the section or an address over HTTPS, as the server keeps them.
const LINK_PATTERN = "/(?!/).*|https://.+"

const button = (attribute, label, extra = "") =>
  `<button type="button" class="trix-button ${extra}" data-trix-attribute="${attribute}" title="${label}" tabindex="-1">${label}</button>`

config.toolbar.getDefaultHTML = () => `
  <div class="trix-button-row">
    <span class="trix-button-group trix-button-group--text-tools" data-trix-button-group="text-tools">
      ${button("bold", "Жирний", "trix-button--icon trix-button--icon-bold")}
      ${button("italic", "Курсив", "trix-button--icon trix-button--icon-italic")}
      <button type="button" class="trix-button trix-button--icon trix-button--icon-link" data-trix-attribute="href"
              data-trix-action="link" data-trix-key="k" title="Посилання" tabindex="-1">Посилання</button>
    </span>
    <span class="trix-button-group trix-button-group--block-tools" data-trix-button-group="block-tools">
      ${button("heading1", "H2", "trix-button--text")}
      ${button("heading3", "H3", "trix-button--text")}
      ${button("quote", "Цитата", "trix-button--icon trix-button--icon-quote")}
      ${button("bullet", "Маркований список", "trix-button--icon trix-button--icon-bullet-list")}
      ${button("number", "Нумерований список", "trix-button--icon trix-button--icon-number-list")}
    </span>
    <span class="trix-button-group-spacer"></span>
    <span class="trix-button-group trix-button-group--history-tools" data-trix-button-group="history-tools">
      <button type="button" class="trix-button trix-button--icon trix-button--icon-undo" data-trix-action="undo"
              data-trix-key="z" title="Скасувати" tabindex="-1">Скасувати</button>
      <button type="button" class="trix-button trix-button--icon trix-button--icon-redo" data-trix-action="redo"
              data-trix-key="shift+z" title="Повторити" tabindex="-1">Повторити</button>
    </span>
  </div>
  <div class="trix-dialogs" data-trix-dialogs>
    <div class="trix-dialog trix-dialog--link" data-trix-dialog="href" data-trix-dialog-attribute="href">
      <div class="trix-dialog__link-fields">
        <input type="text" name="href" class="trix-input trix-input--dialog" pattern="${LINK_PATTERN}"
               placeholder="/katalog/... або https://..." aria-label="Адреса посилання"
               data-trix-validate-href required data-trix-input>
        <div class="trix-button-group">
          <input type="button" class="trix-button trix-button--dialog" value="Додати" data-trix-method="setAttribute">
          <input type="button" class="trix-button trix-button--dialog" value="Прибрати" data-trix-method="removeAttribute">
        </div>
      </div>
      <p class="trix-dialog__hint">Шлях розділу, що починається з «/», або адреса з «https://».</p>
    </div>
  </div>`

// Neither a picked file nor a dropped or pasted picture becomes part of the text.
document.addEventListener("trix-file-accept", (event) => event.preventDefault())
document.addEventListener("trix-attachment-add", (event) => event.attachment.remove())
