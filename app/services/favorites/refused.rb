# frozen_string_literal: true

# A change of a list the user cannot make: the code and the status of the answer, and what the front needs to know.
class Favorites::Refused < StandardError
  attr_reader :code, :status, :details

  def initialize(code, status:, details: nil)
    super(code.to_s)
    @code = code
    @status = status
    @details = details
  end
end
