# frozen_string_literal: true

# First fill of the catalog: queues a fetch for every goods group id of a list file, one id to a line, through the
# same queue as the on-demand fetch. A line that is not an id is skipped with a message and the rest goes on.
class Catalog::Sync::TopList
  ID_FORMAT = /\A\h{32}\z/
  class Result < Data.define(:enqueued, :present, :failed, :messages); end

  def self.call(path) = new(path).call

  def initialize(path)
    @path = path
  end

  def call
    tally = { enqueued: 0, present: 0, failed: 0 }
    # @type var messages: Array[String]
    messages = []
    File.foreach(@path).with_index(1) do |line, number|
      outcome = queue(line.strip, number, messages)
      tally[outcome] += 1
    end
    Result.new(enqueued: tally[:enqueued], present: tally[:present], failed: tally[:failed], messages:)
  end

  private

  def queue(id, number, messages)
    unless ID_FORMAT.match?(id)
      messages << "line #{number}: #{id.empty? ? 'empty line' : "'#{id}' is not a goods group id"}, skipped"
      return :failed
    end

    Catalog::Sync::Pull.enqueue(:goods_group, id) == :enqueued ? :enqueued : :present
  end
end
