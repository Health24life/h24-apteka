# frozen_string_literal: true

# A goods group with its release forms.
class Pharmapoint::GoodsGroup < Data.define(:external_id, :name, :included_to_offers, :producer, :goods_name,
                                            :atc_class, :categories, :goods)
end
