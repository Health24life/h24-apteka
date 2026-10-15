# frozen_string_literal: true

# Takes a filter off the section for good. Its address then answers 410 or, when the editor names a page, leads there
# by a manual redirect. A target the redirect could not lead to leaves the filter as it was, so the address never
# answers 410 against the editor's choice.
class Seo::Filters::Remove
  Result = Seo::Redirects::Manual::Result

  def self.call(filter:, target: nil, config: Seo::Config.current)
    target = target.to_s.strip.presence
    error = target && Seo::Redirects::Manual.target_error(target, config:)
    return Result.new(redirect: nil, errors: { target: error }) if error

    result = Result.new(redirect: nil, errors: {})
    filter.transaction do
      filter.remove!
      result = redirect(filter, target, config) if target
      raise ActiveRecord::Rollback unless result.ok?
    end
    result
  end

  # The address answers 410 only once the filter is removed, so only then may a redirect lead from it.
  def self.redirect(filter, target, config)
    Seo::Redirects::Manual.call(source: Seo::Pages::Path.new(config).record(filter), target:, config:)
  end

  private_class_method :redirect
end
