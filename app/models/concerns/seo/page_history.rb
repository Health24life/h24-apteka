# frozen_string_literal: true

# The history of a record, kept on the card of the page it belongs to: an override, an SEO text or a redirect shows on
# its page, so the card reads one list instead of following every association.
module Seo::PageHistory
  extend ActiveSupport::Concern

  module ClassMethods
    # A touch changes no field an editor sees, so it leaves no version.
    def page_history(owner: ->(record) { record }, on: %i[create update destroy], **)
      has_paper_trail(on:, **, versions: { class_name: 'Seo::Version' }, meta: { owner: })
    end

    # A long text Mobility keeps in a translation row of its own; its changes show on the page as well.
    def translations_history(owner:)
      translation = const_get(:Translation)
      translation.include(Seo::PageHistory)
      translation.page_history(owner:)
    end

    # The changes of the page itself and of everything that belongs to it. They stay after the page is gone.
    def history_owner
      has_many :page_versions, class_name: 'Seo::Version', as: :owner, inverse_of: :owner, dependent: nil
    end
  end
end
