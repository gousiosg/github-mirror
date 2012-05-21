class mysql {
	package {'mysql-server':
		ensure => latest
	}
	package {'mysql-client':
		ensure => latest
	}

	exec {'mysql::user':
		command => 'mysql -u root -P "" -e "create user \'ghtorrent\'@\'localhost\' identified by \'ghtorrent\'; create database ghtorrent; GRANT ALL PRIVILEGES ON ghtorrent.* to ghtorrent@\'localhost\'; flush privileges;"',
		onlyif => "sh -c '! mysql -u root -P \"\" -e \"select user from mysql.user;\" | grep ghtorrent'",
		logoutput => on_failure
	}
}
