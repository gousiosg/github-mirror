class ghtorrent {
	package {'ruby':
		ensure => latest
	}

	package {'libmysqlclient-dev':
		ensure => latest
	}

	package {'daemontools':
		ensure => latest
	}

	package {'rubygems':
		ensure => latest
	}

	user {ghtorrent:
		ensure => present
	}

	package {'ghtorrent':
		ensure   => latest,
		provider => gem,
		require  => [
			Package['ruby'],
			Package['rubygems'],
			Package['rubygems'],
			Package['daemontools'],
			Package['mysql2'],
			User['ghtorrent']
		]
	}

	package {'mysql2':
		ensure   => latest,
		provider => gem,
		require  => [
			Package['ruby'],
			Package['rubygems'],
			Package['libmysqlclient-dev'],
		]
	}

	file {'/usr/local/etc/ghtorrent':
		ensure => directory
	}

	file {'/usr/local/etc/ghtorrent/run':
		ensure => link,
		require => [
			File['/usr/local/etc/ghtorrent'],
			Package['ghtorrent']
		],
		target => $nodetype ? {
			'retrieval' => '/var/lib/gems/1.8/bin/ght-data-retrieval',
			'mirror'    => '/var/lib/gems/1.8/bin/ght-mirror-events'
		}
	}

	file {'/usr/local/etc/ghtorrent/config.yaml':
		source   => 'puppet:///modules/ghtorrent/config.yaml.tmpl',
		require => File['/usr/local/etc/ghtorrent']
	}
}
