# frozen_string_literal: true

# `as: :rich_text`: a Trix editor over a hidden field (app/javascript/admin/rich_text.js). Without JavaScript the
# hidden field still carries the stored HTML, so the form submits the same value.
class RichTextInput < Formtastic::Inputs::StringInput
  def to_html
    input_wrapping do
      label_html <<
        builder.hidden_field(method, input_html_options) <<
        template.content_tag('trix-editor', nil, input: input_html_options[:id], class: 'trix-content')
    end
  end
end
