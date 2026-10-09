# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::Visibility::Changer do
  let(:admin) { create(:admin_user) }
  let(:comments) { ActiveAdmin::Comment.where(resource: record) }

  def switch(hidden:, reason: nil) = described_class.call(record:, hidden:, reason:, admin:)

  shared_examples 'a hideable record' do
    it 'hides the record with a reason and leaves a comment by the admin', :aggregate_failures do
      expect(switch(hidden: true, reason: ' скарга на опис ')).to eq(:changed)
      expect(record.reload.hidden).to be(true)
      expect(comments.sole).to have_attributes(author: admin, namespace: 'admin',
                                               body: 'Приховано з вітрини. Причина: скарга на опис')
    end

    it 'refuses to hide without a reason and changes nothing', :aggregate_failures do
      expect([ nil, '', '   ' ].map { switch(hidden: true, reason: it) }).to all(eq(:reason_required))
      expect(record.reload.hidden).to be(false)
      expect(comments).to be_empty
    end
  end

  context 'with a goods group' do
    let(:record) { create(:catalog_goods_group) }

    it_behaves_like 'a hideable record'

    it 'leaves the hidden flag of its goods as it was' do
      goods = create(:catalog_goods, goods_group: record)

      expect { switch(hidden: true, reason: 'дубль') }.not_to(change { goods.reload.hidden })
    end
  end

  context 'with goods' do
    let(:record) { create(:catalog_goods) }

    it_behaves_like 'a hideable record'

    it 'leaves the withdrawn flag as it was' do
      record.update!(withdrawn: true)

      expect { switch(hidden: true, reason: 'дубль') }.not_to(change { record.reload.withdrawn })
    end

    it 'leaves the hidden flag of its group as it was' do
      expect { switch(hidden: true, reason: 'дубль') }.not_to(change { record.goods_group.reload.hidden })
    end
  end

  context 'with a drugstore' do
    let(:record) { create(:catalog_drugstore) }

    it_behaves_like 'a hideable record'
  end

  context 'with a hidden record' do
    let(:record) { create(:catalog_goods, hidden: true) }

    it 'brings it back without a reason', :aggregate_failures do
      expect(switch(hidden: false)).to eq(:changed)
      expect(record.reload.hidden).to be(false)
      expect(comments.sole.body).to eq('Повернуто на вітрину')
    end

    it 'keeps the reason for bringing it back when one is given' do
      switch(hidden: false, reason: 'помилка')

      expect(comments.sole.body).to eq('Повернуто на вітрину. Причина: помилка')
    end

    it 'changes nothing and comments nothing when asked to hide it again', :aggregate_failures do
      expect(switch(hidden: true, reason: 'ще раз')).to eq(:unchanged)
      expect(comments).to be_empty
    end
  end

  it 'changes nothing and comments nothing when asked to show a record that is shown', :aggregate_failures do
    record = create(:catalog_drugstore)

    expect(described_class.call(record:, hidden: false, reason: nil, admin:)).to eq(:unchanged)
    expect(ActiveAdmin::Comment.where(resource: record)).to be_empty
  end
end
