# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'schema annotations' do # rubocop:disable RSpec/DescribeClass
  def annotated_files
    Rails.root.glob('{app/models,spec/models,spec/factories}/**/*.rb').filter_map do |path|
      text = path.read
      table = text[/^# Table name: (\w+)/, 1]
      [ path, table, text.scan(/^#  (\w+)\s+:/).flatten ] if table
    end
  end

  def translated_attributes(table)
    Rails.application.eager_load!
    model = ApplicationRecord.descendants.find { it.table_name == table }
    model.respond_to?(:translated_attribute_names) ? model.translated_attribute_names.map(&:to_s) : []
  end

  def stray_columns
    annotated_files.filter_map do |path, table, listed|
      allowed = ActiveRecord::Base.connection.columns(table).map(&:name) + translated_attributes(table)
      extra = listed - allowed
      "#{path.relative_path_from(Rails.root)}: #{extra.join(', ')}" if extra.any?
    end
  end

  it 'finds annotated files' do
    expect(annotated_files).not_to be_empty
  end

  it 'lists only table columns and translated attributes, never translation table columns' do
    expect(stray_columns).to be_empty
  end
end
