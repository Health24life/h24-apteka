# frozen_string_literal: true

# The drugstores around a place that have a SKU, with its price there and the packs they have, for the user to pick the
# drugstore of the cart. Asked live of every enabled provider that knows the SKU; only drugstores of the directory that
# are shown and have a price for the SKU are listed, with their static data from the directory. When no provider
# answers, the answer is the failure.
class Orders::Offers::Nearby
  SORTS = %w[price distance].freeze

  # A drugstore of the list: the directory's record, the provider's live answer and what it has of the SKU.
  class Row < Data.define(:drugstore, :offer, :line, :opens_at)
    delegate :id,
             :name,
             :brand,
             :address,
             :drugstore_legal_entity_name,
             :drugstore_legal_entity_code,
             :phone,
             :mobile_phone,
             :week_working_hours,
             :work_with_reimbursement,
             to: :drugstore
    delegate :distance, :open_now, to: :offer
    delegate :price, :available_quantity, to: :line
  end

  # The SKU the list is asked for: neither it nor its group hidden by an operator or withdrawn by the sync.
  def self.find_goods(id)
    Catalog::Goods
      .joins(:goods_group)
      .where(hidden: false, withdrawn: false, goods_group: { hidden: false, withdrawn: false })
      .find_by(id:)
  end

  def self.call(goods, location:, sort: 'price', reimbursement: false, user_id: nil)
    new(goods, location:, sort:, reimbursement:, user_id:).call
  end

  def initialize(goods, location:, sort:, reimbursement:, user_id:)
    @goods = goods
    @location = location
    @sort = sort
    @reimbursement = reimbursement
    @user_id = user_id
  end

  def call
    answers = adapters.map { it.nearby(@goods, @location) }
    failures = answers.filter_map { it if it.is_a?(Orders::Offers::Failure) }
    return failure(failures) if failures.size == answers.size

    sorted(rows(answers.flat_map { it.is_a?(Orders::Offers::Failure) ? [] : it }))
  end

  private

  def adapters
    @goods.providers.enabled.order(:id).filter_map { Orders::Offers::Adapters.for(it, user_id: @user_id) }
  end

  # Busy when every provider refused for its limit, with the shortest wait; unavailable otherwise, or with none asked.
  def failure(failures)
    busy = failures.any? && failures.all?(&:rate_limited?)
    return Orders::Offers::Failure.new(reason: :unavailable, retry_after: nil) unless busy

    Orders::Offers::Failure.new(reason: :rate_limited, retry_after: failures.filter_map(&:retry_after).min)
  end

  def rows(offers)
    unknown = offers.count { it.drugstore_id.nil? }
    Rails.logger.info("Pharmacy offers: #{unknown} drugstores missing from the directory") if unknown.positive?

    listed = offers.select { priced?(it) }
    drugstores = shown_drugstores(listed.filter_map(&:drugstore_id))
    listed.filter_map { row(it, drugstores) }
  end

  def priced?(offer)
    line = offer.line_for(@goods.id)
    (offer.drugstore_id && line&.fulfilled && line.price.present?) || false
  end

  def row(offer, drugstores)
    drugstore_id = offer.drugstore_id
    drugstore = drugstores[drugstore_id] if drugstore_id
    line = offer.line_for(@goods.id)
    return unless drugstore && line && (!@reimbursement || drugstore.work_with_reimbursement)

    Row.new(drugstore:, offer:, line:, opens_at: Orders::Offers::OpeningTime.call(offer, drugstore.week_working_hours))
  end

  def shown_drugstores(ids)
    Catalog::Drugstore.where(id: ids, hidden: false, withdrawn: false).includes(:address, :brand).index_by(&:id)
  end

  # By price, the nearer first among equal prices; or by distance, the cheaper first among equal ones. An unknown
  # distance goes last.
  def sorted(rows)
    far = Float::INFINITY
    rows.sort_by do |row|
      distance = row.distance || far
      @sort == 'distance' ? [ distance, row.price ] : [ row.price, distance ]
    end
  end
end
