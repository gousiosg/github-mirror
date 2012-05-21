/*

== Class: apt::clean
create a cronjob which will run "apt-get clean" once a month.

Arguments:
*$apt_clean_minutes*: cronjob minutes - default uses ip_to_cron from module "common"
*$apt_clean_hours*:   cronjob hours - default to 0
*$apt_clean_mday*:    cronjob monthday - default uses ip_to_cron from module "common"

Require:
- module common (http://github.com/camptocamp/puppet-common)

*/
class apt::clean {
  $minutes  = $apt_clean_minutes? {'' => ip_to_cron(1, 59), default => $apt_clean_minutes }
  $hours    = $apt_clean_hours?   {'' => "0", default => $apt_clean_hours }
  $monthday = $apt_clean_mday?    {'' => ip_to_cron(1, 28), default => $apt_clean_mday }

  cron {"cleanup APT cache - prevents diskfull":
    ensure   => present,
    command  => "apt-get clean",
    hour     => $hours,
    minute   => $minutes,
    monthday => $monthday,
  }
}
