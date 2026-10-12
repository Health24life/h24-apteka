# frozen_string_literal: true

# The SQL a block sends, without schema lookups and transaction control, to pin how many statements a save takes.
module QueryLog
  IGNORED = /\A\s*(?:BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE SAVEPOINT|ROLLBACK TO SAVEPOINT)\b/

  def self.capture(&)
    statements = []
    callback = lambda do |*, payload|
      statements << payload[:sql] unless payload[:name] == 'SCHEMA' || payload[:sql].match?(IGNORED)
    end
    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record', &)
    statements
  end

  def self.inserts_into(statements, table) = statements.count { it.start_with?(%(INSERT INTO "#{table}")) }
end
