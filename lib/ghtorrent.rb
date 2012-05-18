#require 'ghtorrent-old/ghtorrent-old'

module GHTorrent
  VERSION = 0.1
end

require 'ghtorrent/command'

require 'ghtorrent/utils'
require 'ghtorrent/logging'
require 'ghtorrent/settings'
require 'ghtorrent/api_client'
require 'ghtorrent/call_stack'

require 'ghtorrent/adapters/base_adapter'
require 'ghtorrent/adapters/mongo_persister'
require 'ghtorrent/adapters/noop_persister'

require 'ghtorrent/persister'
require 'ghtorrent/retriever'

require 'ghtorrent/ghtorrent'