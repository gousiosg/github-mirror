class apt::backports {
  
  apt::sources_list{"backports":
    ensure  => present,
    content => $operatingsystem ? {
      Debian => "deb http://backports.debian.org/debian-backports ${lsbdistcodename}-backports main contrib non-free\n",
      Ubuntu => "deb http://archive.ubuntu.com/ubuntu ${lsbdistcodename}-backports main universe multiverse restricted\n",
    }
  }
  
  apt::preferences {"${lsbdistcodename}-backports":
    ensure => present,
    package => "*",
    pin => "release a=${lsbdistcodename}-backports",
    priority => 400,
  }
  
  case $lsbdistid {
    "Debian" : {
      apt::key {"16BA136C":
        ensure => absent,
        source  => "http://backports.org/debian/archive.key",
      }
    }
  }
}
