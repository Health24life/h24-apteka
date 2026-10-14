# frozen_string_literal: true

require 'csv'

# Manual redirects from a CSV file an editor uploads: a header row and two columns, the old address and the new one,
# separated by commas or by semicolons as Excel saves them. All or nothing: every row is checked first, and only a file
# without a single bad row is written, in one statement for the redirects and one for their history, so no explicit
# transaction is needed. The history and the cache are written by hand, as a bulk insert skips the callbacks.
class Seo::Redirects::Import
  LIMIT = 1_000
  BOM = "\uFEFF"
  # Rows of data are counted from 1, after the header, as the report names them.
  FIRST_LINE = 1

  class Result < Data.define(:created, :error, :rows)
    def ok? = error.nil? && rows.empty?
  end

  def self.call(content, author: nil, config: Seo::Config.current) = new(author, config).call(content)

  def initialize(author, config)
    @author = author
    @config = config
  end

  def call(content)
    headers, lines = parse(content)
    return failure(:unreadable) unless headers && lines
    return failure(:columns) if headers.size < 2
    return failure(:empty) if lines.empty?
    return failure(:too_many) if lines.size > LIMIT

    redirects, rows = check(lines)
    rows.any? ? Result.new(created: 0, error: nil, rows:) : write(redirects)
  end

  private

  # The names of the columns and the rows of data.
  def parse(content)
    text = content.to_s.dup.force_encoding(Encoding::UTF_8).delete_prefix(BOM)
    return unless text.valid_encoding?

    header = text.lines.first.to_s
    col_sep = header.count(';') > header.count(',') ? ';' : ','
    names = CSV.parse_line(header, col_sep:).to_a.compact
    [ names, CSV.new(text, headers: true, skip_blanks: true, col_sep:).each.to_a ]
  rescue CSV::MalformedCSVError
    nil
  end

  # The redirects of a file without errors, and the errors by line otherwise.
  def check(lines)
    # @type var rows: Hash[Integer, Hash[Symbol, Symbol]]
    rows = {}
    # @type var seen: Hash[String, Integer]
    seen = {}
    # @type var redirects: Array[Seo::Redirect]
    redirects = []
    lines.each.with_index(FIRST_LINE) { |row, line| add_row(row, line, rows:, seen:, redirects:) }
    [ redirects, rows ]
  end

  def add_row(row, line, rows:, seen:, redirects:)
    result = Seo::Redirects::Manual.call(source: row[0], target: row[1], save: false, config: @config)
    redirect = result.redirect
    return rows[line] = result.errors unless redirect

    mark_duplicate(rows, seen, line, redirect)
    redirects << redirect
  end

  # A second row from the same old address spoils both.
  def mark_duplicate(rows, seen, line, redirect)
    key = "#{redirect.page_type}/#{redirect.slug}"
    first = seen[key]
    return seen[key] = line unless first

    rows[first] = rows[line] = { source: :duplicate }
  end

  def write(redirects)
    now = Time.current
    # Callbacks are skipped on purpose: every row passed the model's rules above, and the history and the cache follow.
    inserted = Seo::Redirect.insert_all!(redirects.map { redirect_row(it, now) }, returning: %i[id]) # rubocop:disable Rails/SkipsModelValidations
    ids = inserted.rows.flatten
    stored = Seo::Redirect.where(id: ids).to_a
    Seo::Version.insert_all!(stored.map { version_row(it, now) }) # rubocop:disable Rails/SkipsModelValidations
    stored.each { Seo::Redirects::Cache.write(it, config: @config) }
    Result.new(created: stored.size, error: nil, rows: {})
  rescue ActiveRecord::RecordNotUnique
    failure(:conflict)
  end

  def redirect_row(redirect, now)
    { manual: true, page_type: redirect.page_type, slug: redirect.slug, redirectable_type: redirect.redirectable_type,
      redirectable_id: redirect.redirectable_id, created_at: now }
  end

  # The same version PaperTrail would write for the creation of each redirect.
  def version_row(redirect, now)
    { item_type: Seo::Redirect.polymorphic_name, item_id: redirect.id, event: 'create', whodunnit: @author&.id&.to_s,
      object_changes: redirect.attributes.transform_values { [ nil, it ] }, owner_type: redirect.redirectable_type,
      owner_id: redirect.redirectable_id, author_type: @author&.class&.polymorphic_name, author_id: @author&.id,
      created_at: now }
  end

  def failure(error) = Result.new(created: 0, error:, rows: {})
end
