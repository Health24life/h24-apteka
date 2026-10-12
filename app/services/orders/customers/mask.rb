# frozen_string_literal: true

# The client as the order list shows them: enough to recognise an order, not enough to read the client's data off the
# screen. The order card shows the data in full.
module Orders::Customers::Mask
  SHOWN_HEAD = 3
  SHOWN_TAIL = 4

  def self.phone(value)
    return unless value
    return if value.empty?
    return '*' * value.length if value.length <= SHOWN_HEAD + SHOWN_TAIL

    "#{value[0, SHOWN_HEAD]}#{'*' * (value.length - SHOWN_HEAD - SHOWN_TAIL)}#{value[-SHOWN_TAIL..]}"
  end

  # Not `name`: that would hide Module#name, which Rails and error messages rely on.
  def self.person(first_name, last_name)
    return unless first_name

    first = first_name.strip
    return if first.empty?

    initial = last_name.to_s.strip[0]
    initial ? "#{first} #{initial}." : first
  end
end
