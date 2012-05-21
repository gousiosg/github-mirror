class mongodb {
	apt::sources_list {"mongodb":
	  ensure  => present,
	  content => "deb http://downloads-distro.mongodb.org/repo/debian-sysvinit dist 10gen",
	}

	apt::key {"7F0CEB10":
		source  => "http://keyserver.ubuntu.com:11371/pks/lookup?op=get&search=0x9ECBEC467F0CEB10",
	}
	
	package {'mongodb-10gen':
		ensure => latest
	}

	file {'/tmp/mongo-acct':
		content => "
			db.addUser('ghtorrent', 'ghtorrent');
			use github;
			db.addUser('ghtorrent', 'ghtorrent');
			",
		ensure => present
	}

	exec {'account':
		command => 'mongo admin </tmp/mongo-acct',
		refreshonly => true,
		logoutput => on_failure,
		subscribe => File['/tmp/mongo-acct']
	}
}
