# frozen_string_literal: true

class Provider < ApplicationRecord
  KINDS = %w[external own].freeze
  CODE_FORMAT = /\A[a-z][a-z0-9_]*\z/

  # Adapters and credentials are looked up by code, so it never changes.
  attr_readonly :code

  enum :kind, KINDS.index_with(&:itself), validate: true

  has_many :sync_runs, inverse_of: :provider, dependent: :restrict_with_exception
  has_many :provider_links, inverse_of: :provider, dependent: :restrict_with_exception
  has_many :orders, inverse_of: :provider, dependent: :restrict_with_exception

  validates :code, presence: true, uniqueness: true, format: { with: CODE_FORMAT }
  validates :name, presence: true

  scope :enabled, -> { where(active: true) }
end

# == Schema Information
#
# Table name: providers
#
#  id                :bigint           not null, primary key
#  active            :boolean          default(TRUE), not null
#  code              :string           not null
#  kind              :string           not null
#  name              :string           not null
#  supports_delivery :boolean          default(FALSE), not null
#  supports_e_recipe :boolean          default(FALSE), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_providers_on_code  (code) UNIQUE
#
# Check Constraints
#
#  providers_kind_check  (kind::text = ANY (ARRAY['external'::character varying, 'own'::character varying]::text[]))
#
