# frozen_string_literal: true

# A change of the cart the user cannot make, or a cart that is not there: the code and the status of the answer, and
# what the user needs to know to go on.
class Orders::Carts::Refused < StandardError
  attr_reader :code, :status, :details, :retry_after

  def initialize(code, status:, details: nil, retry_after: nil)
    super(code.to_s)
    @code = code
    @status = status
    @details = details
    @retry_after = retry_after
  end
end
