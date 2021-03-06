class ocf_puppet::puppetmaster {
  package {
    ['puppetserver', 'puppet-lint']:;
  }

  service { 'puppetserver':
    enable  => true,
    require => Package['puppetserver'],
  }

  # Set correct memory limits on puppetserver so that it doesn't run out
  augeas { '/etc/default/puppetserver':
    context => '/files/etc/default/puppetserver',
    changes => [
      "set JAVA_ARGS '\"-Xms1g -Xmx1g -XX:MaxPermSize=512m\"'",
    ],
    require => Package['puppetserver'],
    notify  => Service['puppetserver'],
  }

  $docker_private_hosts = union(keys(lookup('mesos_masters')), lookup('mesos_slaves'))

  file {
    '/etc/puppetlabs/puppet/fileserver.conf':
      content => template('ocf_puppet/fileserver.conf.erb'),
      require => Package['puppetserver'],
      notify  => Service['puppetserver'];

    '/etc/puppetlabs/puppet/tagmail.conf':
      source  => 'puppet:///modules/ocf_puppet/tagmail.conf',
      require => Package['puppetserver'],
      notify  => Service['puppetserver'];

    '/etc/puppetlabs/puppetserver/conf.d/webserver.conf':
      source  => 'puppet:///modules/ocf_puppet/webserver.conf',
      require => Package['puppetserver'],
      notify  => Service['puppetserver'];

    '/opt/share/puppet/ldap-enc':
      mode    => '0755',
      source  => 'puppet:///modules/ocf_puppet/ldap-enc',
      require => File['/opt/share/puppet'];

    '/etc/puppetlabs/puppet/puppet.conf':
      content => template('ocf_puppet/puppet.conf.erb'),
      require => Package['puppet-agent'];

    ['/opt/puppet', '/opt/puppetlabs/scripts', '/opt/puppetlabs/shares']:
      ensure  => directory,
      require => Package['puppetserver'];

    '/opt/puppetlabs/shares/private':
      mode    => '0400',
      owner   => puppet,
      group   => puppet,
      recurse => true,
      require => File['/opt/puppetlabs/shares'];

    '/opt/puppetlabs/scripts/update-prod':
      source  => 'puppet:///modules/ocf_puppet/update-prod',
      mode    => '0755';

    # These are just links to the new locations, but keep them for staff to use
    # since they are much more convenient to type.
    '/opt/puppet/env':
      ensure  => symlink,
      target  => '/etc/puppetlabs/code/environments',
      require => Package['puppetserver'];

    '/opt/puppet/shares':
      ensure  => symlink,
      target  => '/opt/puppetlabs/shares',
      require => Package['puppetserver'];
  }
}
