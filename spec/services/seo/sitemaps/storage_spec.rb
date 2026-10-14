# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Seo::Sitemaps::Storage do
  let(:s3) do
    Seo::Config::S3.new(bucket: 'apteka-public', endpoint: 'https://minio.example', region: 'us-east-1',
                        access_key_id: 'key', secret_access_key: 'secret')
  end

  def config(**settings) = Seo::Config.new(front_base_url: 'https://apteka.h24.ua', **settings)

  it 'keeps the sitemap in a directory by default', :aggregate_failures do
    storage = described_class.for(config(sitemap_dir: '/data/seo'))

    expect(storage).to be_a(described_class::Files)
    expect(storage.public_path).to eq('/data/seo')
    expect(storage.adapter).to be_a(SitemapGenerator::FileAdapter)
  end

  it 'uploads the sitemap to a bucket when the environment says s3', :aggregate_failures do
    storage = described_class.for(config(sitemap_storage: 's3', sitemap_s3: s3))

    expect(storage).to be_a(described_class::Bucket)
    expect(storage.adapter).to be_a(SitemapGenerator::AwsSdkAdapter)
  end

  it 'refuses a storage it does not know' do
    expect { described_class.for(config(sitemap_storage: 'ftp')) }
      .to raise_error(Seo::Config::MissingSetting, /SEO_SITEMAP_STORAGE/)
  end

  it 'refuses the bucket storage without a bucket' do
    expect { described_class.for(config(sitemap_storage: 's3', sitemap_s3: s3.with(bucket: nil))) }
      .to raise_error(Seo::Config::MissingSetting, /SEO_SITEMAP_S3_BUCKET/)
  end

  describe described_class::Bucket do
    let(:listed) { %w[sitemap.xml.gz goods.xml.gz goods2.xml.gz].map { { key: "sitemaps/#{it}" } } }
    let(:client) { Aws::S3::Client.new(stub_responses: { list_objects_v2: { contents: listed } }) }

    before do
      require 'aws-sdk-s3'
      allow(Aws::S3::Client).to receive(:new).and_return(client)
    end

    it 'removes the objects the new index no longer lists' do
      described_class.new(s3).prune(%w[sitemap.xml.gz goods.xml.gz])

      deleted = client.api_requests.find { it[:operation_name] == :delete_objects }
      expect(deleted[:params][:delete][:objects]).to eq([ { key: 'sitemaps/goods2.xml.gz' } ])
    end

    context 'when the listing takes more than one page' do
      let(:pages) do
        [ { contents: [ { key: 'sitemaps/goods3.xml.gz' } ], is_truncated: true, next_continuation_token: 'more' },
          { contents: [ { key: 'sitemaps/goods4.xml.gz' } ], is_truncated: false } ]
      end

      before { client.stub_responses(:list_objects_v2, pages) }

      it 'goes through every page' do
        described_class.new(s3).prune(%w[sitemap.xml.gz])

        deleted = client.api_requests.select { it[:operation_name] == :delete_objects }
        expect(deleted.flat_map { it[:params][:delete][:objects] }.pluck(:key))
          .to contain_exactly('sitemaps/goods3.xml.gz', 'sitemaps/goods4.xml.gz')
      end
    end

    it 'removes its local copy once done' do
      storage = described_class.new(s3)

      expect { storage.cleanup }.to change { File.exist?(storage.public_path) }.from(true).to(false)
    end
  end
end
