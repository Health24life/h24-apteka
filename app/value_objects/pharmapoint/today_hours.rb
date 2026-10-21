# frozen_string_literal: true

# A drugstore's hours today and whether it is open at the moment of the answer, as the partner worked them out.
class Pharmapoint::TodayHours < Data.define(:from, :to, :open, :round_the_clock); end
