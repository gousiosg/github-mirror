node default {
  include common
  include apt
  include mongodb
  include rabbitmq
  include mysql
  include ghtorrent
}

# Class dependencies
Class['common'] -> Class['apt']

Class['apt'] -> Class['mongodb']
Class['apt'] -> Class['rabbitmq']

Class['mongodb'] -> Class['ghtorrent']
Class['rabbitmq'] -> Class['ghtorrent']
Class['mysql'] -> Class['ghtorrent']
