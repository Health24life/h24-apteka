# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Seo::Redirects::Import do
  let(:config) { Seo::Config.new(front_base_url: 'https://apteka.h24.ua') }
  let(:admin) { create(:admin_user) }

  before { create(:catalog_category, slug: 'zneboliuvalni') }

  def import(csv) = described_class.call(csv, author: admin, config:)

  def csv(*rows, sep: ',') = ([ "стара адреса#{sep}нова адреса" ] + rows.map { it.join(sep) }).join("\n")

  describe 'a file without errors' do
    let!(:result) do
      import(csv(%w[/tovar/a /katalog/zneboliuvalni], %w[https://apteka.h24.ua/katalog/c/ /katalog/zneboliuvalni]))
    end

    it 'creates every redirect of the file', :aggregate_failures do
      expect(result).to have_attributes(ok?: true, created: 2)
      expect(Seo::Redirect.where(manual: true).pluck(:page_type, :slug)).to contain_exactly(%w[goods a], %w[category c])
    end

    it 'writes their history and cache', :aggregate_failures do
      expect(Seo::Version.where(item_type: 'Seo::Redirect', event: 'create', author: admin).count).to eq(2)
      expect(Seo::Redirects::Cache.target('goods', 'a')).to have_attributes(manual: true)
    end
  end

  it 'creates nothing when a row is wrong and names the line and the reason', :aggregate_failures do
    rows = Array.new(10) { |n| [ "/tovar/stara-#{n}", '/katalog/zneboliuvalni' ] }
    rows[3] = [ "/tovar/#{create(:catalog_goods).slug}", '/katalog/zneboliuvalni' ]

    expect(import(csv(*rows)).rows).to eq(4 => { source: :page_there })
    expect(Seo::Redirect.count).to eq(0)
  end

  it 'refuses both rows of the same old address', :aggregate_failures do
    rows = Array.new(7) { |n| [ "/tovar/stara-#{n}", '/katalog/zneboliuvalni' ] }
    rows[6] = %w[/TOVAR/stara-1/ /katalog/zneboliuvalni]

    expect(import(csv(*rows)).rows).to eq(2 => { source: :duplicate }, 7 => { source: :duplicate })
    expect(Seo::Redirect.count).to eq(0)
  end

  it 'reads a file Excel saved with semicolons and a byte order mark' do
    expect(import("﻿#{csv(%w[/tovar/a /katalog/zneboliuvalni], sep: ';')}")).to have_attributes(created: 1)
  end

  it 'refuses a file without rows, without both columns or above the limit', :aggregate_failures do
    expect(import(csv).error).to eq(:empty)
    expect(import("стара адреса\n/tovar/a").error).to eq(:columns)
    expect(import(csv(*Array.new(1_001) { |n| [ "/tovar/s-#{n}", '/' ] })).error).to eq(:too_many)
  end

  it 'creates nothing when another editor took an old address meanwhile', :aggregate_failures do
    allow(Seo::Redirect).to receive(:insert_all!).and_raise(ActiveRecord::RecordNotUnique)

    expect(import(csv(%w[/tovar/a /katalog/zneboliuvalni])).error).to eq(:conflict)
    expect(Seo::Version.count).to eq(0)
  end
end
