# frozen_string_literal: true

# Brings a phone typed by an admin to the stored 380XXXXXXXXX form. Anything that is not a whole Ukrainian number gives
# nil, so a search by a part of a number finds nothing instead of everything.
class Orders::PhoneNormalizer
  INTERNATIONAL = /\A380\d{9}\z/
  NATIONAL = /\A0\d{9}\z/

  def self.call(value)
    digits = value.to_s.gsub(/\D/, '')
    return digits if digits.match?(INTERNATIONAL)

    "38#{digits}" if digits.match?(NATIONAL)
  end
end
