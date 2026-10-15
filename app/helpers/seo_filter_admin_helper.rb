# frozen_string_literal: true

# The pieces of the admin screens of SEO filters: the state of a filter, its parameters and the inputs of its form.
module SeoFilterAdminHelper
  # A published filter that selects no goods has a page closed to search engines.
  def self.empty?(filter) = filter.published? && Seo::Filters::Goods.call(filter).none?

  # The state of a filter; a published one that selects no goods says so beside its state.
  def seo_filter_state(filter)
    state = 'draft'
    state = 'published' if filter.published?
    state = 'removed' if filter.removed?
    label = t(state, scope: 'admin.seo_filters.states')
    SeoFilterAdminHelper.empty?(filter) ? "#{label} · #{t('admin.seo_filters.empty')}" : label
  end

  def seo_filter_applied_params(filter)
    lines = Seo::Filters::AppliedParams.call(filter).map { "#{it.name}: #{it.values.map(&:name).join(', ')}" }
    lines.empty? ? '—' : safe_join(lines, tag.br)
  end

  SEO_FILTER_PARAMS = Struct.new(*Seo::Filter::PARAMS.keys.map(&:to_sym))

  # The parameters of a filter as an object the form reads each of them from, as the selects of the form need.
  def seo_filter_params_form(filter)
    params = filter.params.is_a?(Hash) ? filter.params : {}
    SEO_FILTER_PARAMS.new(*Seo::Filter::PARAMS.keys.map { params[it] })
  end

  # Categories and producers are many, so their selects search; the other dictionaries are short lists.
  def seo_filter_param_input(key)
    input = { as: :tom_select, multiple: true, required: false, label: t(key, scope: 'seo.filters.params') }
    case key
    when 'category_id' then input.merge(ajax: { resource: Catalog::Category })
    when 'producer_id' then input.merge(ajax: { resource: Seo::Filter, collection_name: :producers })
    else input.merge(ajax: false, collection: Seo::Filter::PARAMS.fetch(key).all.map { [ it.name_uk, it.id ] }.sort)
    end
  end
end
