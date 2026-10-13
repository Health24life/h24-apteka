# frozen_string_literal: true

# The sitemap in an S3-compatible bucket such as MinIO, under the `sitemaps/` prefix that is open for anonymous reading.
# The generator writes each file to a local directory first and uploads it from there.
class Seo::Sitemaps::Storage::Bucket
  def initialize(settings)
    require 'aws-sdk-s3'
    @s3 = settings
    @bucket = settings.bucket.to_s
    @staging = Dir.mktmpdir('sitemap')
  end

  def public_path = @staging

  def adapter = SitemapGenerator::AwsSdkAdapter.new(@bucket, **client_options)

  # Removes the objects of the earlier runs that the new index no longer lists.
  def prune(keep)
    keys = client.list_objects_v2(bucket: @bucket, prefix: Seo::Sitemaps::Storage::PREFIX).contents.map(&:key)
    stale = keys.reject { keep.include?(File.basename(it)) }
    return if stale.empty?

    client.delete_objects(bucket: @bucket, delete: { objects: stale.map { { key: it } } })
  end

  private

  # MinIO addresses a bucket by path, not by subdomain.
  def client_options
    { endpoint: @s3.endpoint, region: @s3.region, access_key_id: @s3.access_key_id,
      secret_access_key: @s3.secret_access_key, force_path_style: true }
  end

  def client = @client ||= Aws::S3::Client.new(**client_options)
end
