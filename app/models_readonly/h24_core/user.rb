# frozen_string_literal: true

class H24Core::User < H24Core::ApplicationRecord
  self.table_name = 'users'

  # Phone-only sign-ups get a placeholder address to satisfy the NOT NULL unique email column.
  TEMP_EMAIL_PREFIX = 'change@me'

  has_many :orders, class_name: '::Order', inverse_of: :user, dependent: nil
  has_one :cart_order, -> { cart }, class_name: '::Order', inverse_of: false, dependent: nil

  def contact_email
    email.presence unless email.to_s.start_with?(TEMP_EMAIL_PREFIX)
  end

  # The core keeps +380XXXXXXXXX, the pharmacy side keeps 380XXXXXXXXX.
  def phone_digits
    phone_number&.delete_prefix('+')
  end
end

# == Schema Information
#
# Table name: users
#
#  id                               :integer          not null, primary key
#  birth_date                       :date
#  confirmation_sent_at             :datetime
#  confirmation_token               :string
#  confirmed_at                     :datetime
#  deactivated                      :boolean
#  email                            :string           default(""), not null
#  encoded_otp_confirmation         :string
#  encrypted_password               :string           default(""), not null
#  first_name                       :string
#  gender                           :string
#  invitation_accepted_at           :datetime
#  invitation_created_at            :datetime
#  invitation_limit                 :integer
#  invitation_sent_at               :datetime
#  invitation_token                 :string
#  invitations_count                :integer          default(0)
#  invited_by_type                  :string
#  is_finished_sign_up              :boolean          default(FALSE)
#  last_name                        :string
#  mfa_current_type                 :string
#  mfa_period                       :integer          default(0), not null
#  mfa_web_passed_at                :datetime
#  middle_name                      :string
#  otp_confirmation_confirmed_at    :datetime
#  otp_confirmation_sended_at       :datetime
#  otp_confirmation_token           :string
#  otp_required                     :boolean          default(FALSE)
#  otp_type                         :string           default("sms")
#  password_changed_at              :datetime
#  password_expiry_alert_attempts   :integer          default(0)
#  password_expiry_alert_skipped_at :datetime
#  phone_number                     :string
#  provider                         :string           default("manual_sign_up")
#  remember_created_at              :datetime
#  reset_password_sent_at           :datetime
#  reset_password_token             :string
#  unconfirmed_email                :string
#  unconfirmed_phone_number         :string
#  created_at                       :datetime         not null
#  updated_at                       :datetime         not null
#  invitation_party_id              :integer
#  invited_by_id                    :integer
#  personality_id                   :integer
#  unique_mobile_session_id         :string
#  unique_session_id                :string
#
# Indexes
#
#  index_users_on_email                              (email) UNIQUE
#  index_users_on_invitation_token                   (invitation_token) UNIQUE
#  index_users_on_invitations_count                  (invitations_count)
#  index_users_on_invited_by_type_and_invited_by_id  (invited_by_type,invited_by_id)
#  index_users_on_phone_number                       (phone_number)
#  index_users_on_reset_password_token               (reset_password_token) UNIQUE
#
