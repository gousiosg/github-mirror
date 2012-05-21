define apt::preferences($ensure="present", $package="", $pin, $priority) {

  $pkg = $package ? {
    "" => $name,
    default => $package,
  }

  $fname = regsubst($name, '\.', '-', 'G')

  # apt support preferences.d since version >= 0.7.22
  if ($lsbdistid == "Debian" and versioncmp($lsbdistrelease, "6.0") >= 0) or
     ($lsbdistid == "Ubuntu" and versioncmp($lsbdistrelease, "10.04") >= 0) {
    file {"/etc/apt/preferences.d/$fname":
      ensure  => $ensure,
      owner   => root,
      group   => root,
      mode    => 644,
      content => template("apt/preferences.erb"),
      before  => Exec["apt-get_update"],
      notify  => Exec["apt-get_update"],
    }
  }
  else {
    common::concatfilepart { $fname:
      ensure  => $ensure,
      manage  => true,
      file    => "/etc/apt/preferences",
      content => template("apt/preferences.erb"),
      before  => Exec["apt-get_update"],
      notify  => Exec["apt-get_update"],
    }
  }

}
