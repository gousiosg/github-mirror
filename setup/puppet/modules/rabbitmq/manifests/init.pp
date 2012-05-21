class rabbitmq {
	apt::sources_list {"rabbitMQ":
	  ensure  => present,
	  content => "deb http://www.rabbitmq.com/debian/ testing main",
	}

	apt::key {"Rabbit":
		source  => "http://www.rabbitmq.com/rabbitmq-signing-key-public.asc",
	}
	
	package {'rabbitmq-server/testing':
		ensure => latest
	}
	
	exec {'user':
		command => 'rabbitmqctl add_user ghtorrent ghtorrent && rabbitmqctl set_permissions -p / ghtorrent ".*" ".*" ".*" && rabbitmq-plugins enable rabbitmq_management && rabbitmqctl set_user_tags ghtorrent administrator',
		onlyif => "sh -c '! rabbitmqctl list_users | grep ghtorrent'",
		logoutput => on_failure
	}
}
