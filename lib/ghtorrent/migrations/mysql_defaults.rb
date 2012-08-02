require 'sequel'

Sequel::MySQL.default_engine = 'InnoDB' if defined?(Sequel::MySQL)
Sequel::MySQL.default_charset = 'utf8'  if defined?(Sequel::MySQL)
Sequel::MySQL.default_collate = 'utf8_general_ci' if defined?(Sequel::MySQL)

