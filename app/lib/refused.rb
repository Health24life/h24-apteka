# frozen_string_literal: true

# A request the API refuses: the code and the status of the answer, what the front needs to know to go on, and, for a
# refusal over a limit, when to ask again. ApiController turns it into the answer.
class Refused < StandardError
  attr_reader :code, :status, :details, :retry_after

  def initialize(code, status:, details: nil, retry_after: nil)
    super(code.to_s)
    @code = code
    @status = status
    @details = details
    @retry_after = retry_after
  end
end
