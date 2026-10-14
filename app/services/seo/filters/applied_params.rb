# frozen_string_literal: true

# The parameters of a filter as the badges of its page: each search parameter it keeps, named in Ukrainian, with the
# names of the records it points at, in the order of the parameters and of the ids. An id whose record is gone, as after
# a merge of duplicates, is left out rather than shown bare.
class Seo::Filters::AppliedParams
  class Value < Data.define(:id, :name); end

  class Param < Data.define(:key, :name, :values)
    def to_h = { key:, name:, values: values.map(&:to_h) }
  end

  def self.call(filter)
    Seo::Filter::PARAMS.filter_map do |key, model|
      ids = Array(filter.params[key])
      names = names_of(model, ids)
      values = ids.filter_map { |id| (name = names[id]) && Value.new(id:, name:) }
      Param.new(key:, name: I18n.t(key, scope: 'seo.filters.params', locale: :uk), values:) if values.any?
    end
  end

  # The producer's name is a plain column; the other records keep theirs in a jsonb of languages.
  def self.names_of(model, ids)
    return {} if ids.empty?

    name = model == Catalog::Producer ? :name : Arel.sql("#{model.table_name}.name->>'uk'")
    model.where(id: ids).pluck(:id, name).to_h
  end

  private_class_method :names_of
end
