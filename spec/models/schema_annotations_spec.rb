# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'schema annotations' do # rubocop:disable RSpec/DescribeClass
  def annotated_files
    Rails.root.glob('{app/models,spec/models,spec/factories}/**/*.rb').filter_map do |path|
      text = path.read
      table = text[/^# Table name: (\w+)/, 1]
      [path, table, text.scan(/^#  (\w+)\s+:/).flatten] if table
    end
  end

  def stray_columns
    annotated_files.filter_map do |path, table, listed|
      extra = listed - ActiveRecord::Base.connection.columns(table).map(&:name)
      "#{path.relative_path_from(Rails.root)}: #{extra.join(', ')}" if extra.any?
    end
  end

  it 'finds annotated files' do
    expect(annotated_files).not_to be_empty
  end

  it 'lists only columns that exist on the annotated table' do
    expect(stray_columns).to be_empty
  end
end
