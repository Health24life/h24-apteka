# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationPolicy do
  subject(:policy) { described_class.new(build(:admin_user), AdminUser) }

  it 'allows every action by default' do
    expect(%i[index? show? create? new? update? edit? destroy?].map { policy.public_send(it) }).to all(be(true))
  end

  it 'resolves the scope to all records' do
    admin = create(:admin_user)

    expect(described_class::Scope.new(admin, AdminUser).resolve).to contain_exactly(admin)
  end
end
