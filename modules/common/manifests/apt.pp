class common::apt ( $nonfree = false, $desktop = false, $kiosk = false ) {

  package { 'aptitude': }
  exec { 'aptitude update':
    refreshonly => true,
    require     => Package['aptitude'],
  }

  # remote package update management support
  package { [ 'apt-dater-host', 'imvirt' ]: }

  file {
    # provide sources.list
    '/etc/apt/sources.list':
      content => template('common/apt/sources.list.erb'),
      notify  => Exec['aptitude update'],
      before  => File['/etc/cron.daily/ocf-apt'],
    ;
    # update apt list, report missing updates, and clear apt cache and old config daily
    '/etc/cron.daily/ocf-apt':
      mode    => '0755',
      content => template('common/apt/ocf-apt.erb'),
      require => Package['aptitude'],
    ;
  }

  if $::architecture in ['amd64', 'i386'] {
    # provide puppetlabs sources.list
    file { '/etc/apt/sources.list.d/puppetlabs.list':
      content => "deb http://apt.puppetlabs.com/ ${::lsbdistcodename} main dependencies",
      notify  => Exec['aptitude update'],
      before  => File['/etc/cron.daily/ocf-apt'],
    }
    # trust puppetlabs GPG key
    exec { 'puppetlabs':
      command => 'wget -q https://apt.puppetlabs.com/pubkey.gpg -O- | apt-key add -',
      unless  => 'apt-key list | grep 4BD6EC30',
      notify  => Exec['aptitude update'],
      before  => File['/etc/cron.daily/ocf-apt'],
    }
  }

  if $::operatingsystem == 'Debian' and $desktop {
    # provide desktop sources.list
    file { '/etc/apt/sources.list.d/desktop.list':
      content => "deb http://www.deb-multimedia.org/ $::lsbdistcodename main non-free\ndeb http://mozilla.debian.net/ $::lsbdistcodename-backports iceweasel-release",
      notify  => Exec['aptitude update'],
      before  => File['/etc/cron.daily/ocf-apt'],
    }
    # trust debian-multimedia and mozilla.debian.net GPG key
    exec {
      'debian-multimedia':
        command => 'aptitude update && aptitude -o Aptitude::CmdLine::Ignore-Trust-Violations=true install deb-multimedia-keyring',
        unless  => 'dpkg -l deb-multimedia-keyring | grep ^ii',
        notify  => Exec['aptitude update'],
        require => [Package['aptitude'], File['/etc/apt/sources.list','/etc/apt/sources.list.d/desktop.list']],
        before  => File['/etc/cron.daily/ocf-apt'],
      ;
      'debian-mozilla':
        command => 'aptitude update && aptitude -o Aptitude::CmdLine::Ignore-Trust-Violations=true install pkg-mozilla-archive-keyring',
        unless  => 'dpkg -l pkg-mozilla-archive-keyring | grep ^ii',
        notify  => Exec['aptitude update'],
        require => [Package['aptitude'], File['/etc/apt/sources.list','/etc/apt/sources.list.d/desktop.list']],
        before  => File['/etc/cron.daily/ocf-apt'],
      ;
    }
  }

}