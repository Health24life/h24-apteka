# frozen_string_literal: true

# An address an editor types: a path of the front or a full URL on the front's host. Gives the path as the front would
# normalise it, in lower case, without a trailing slash and without the query, or the reason it is not an address of
# the section.
class Seo::Pages::Address
  class Result < Data.define(:path, :error)
    def ok? = error.nil?
  end

  def self.call(input, config: Seo::Config.current)
    text = input.to_s.strip
    return failure(:blank) if text.empty?

    uri = URI.parse(text)
    error = error_of(uri, text, config)
    error ? failure(error) : Result.new(path: uri.path.to_s.downcase.sub(%r{/+\z}, '').presence || '/', error: nil)
  rescue URI::InvalidURIError
    failure(:invalid)
  end

  def self.error_of(uri, text, config)
    return text.start_with?('/') ? nil : :invalid unless uri.host
    return :invalid unless uri.is_a?(URI::HTTP)

    :other_host unless uri.host.to_s.casecmp?(URI.parse(config.front_base_url!).host.to_s)
  end

  def self.failure(error) = Result.new(path: nil, error:)

  private_class_method :error_of, :failure
end
