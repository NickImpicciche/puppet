# Install and configure Docker.
#
# The admin group *must* only contain trusted users (e.g. staff), as Docker
# containers can be used to compromise the host in many scenarios (e.g.
# mounting local filesystems, messing with network interfaces, more readily
# exploiting kernel bugs, etc.).
#
# Containers are helpful for testing things. For example:
#   docker run -ti debian:jessie bash
#
class ocf::packages::docker($admin_group = undef) {
  class { 'ocf::packages::docker::apt':
    stage => first,
  }

  package {
    'docker.io':
      ensure  => purged;
  }

  if $::lsbdistcodename != 'jessie' {
    package {
      ['aufs-dkms', 'aufs-tools']:
        ensure => purged;
    }
  }

  # Don't install AUFS stuff
  ocf::repackage {
    'docker-engine':
      recommends => false,
      require    => Package['docker.io'];
  }

  exec { 'docker-socket-update':
    command     => 'systemctl restart docker.socket',
    refreshonly => true,
    require     => Exec['systemd-reload'],  # which is triggered by ocf::systemd::override
  }

  if $admin_group != undef {
    ocf::systemd::override { 'set-docker-socket-group':
      unit    => 'docker.socket',
      content => "[Socket]\nSocketGroup=${admin_group}\n",
      require => Package['docker-engine'],
      notify  => Exec['docker-socket-update'];
    }
  }

  # temporary
  if $::lsbdistcodename != 'jessie' {
    ensure_resource('service', 'docker', {'provider' => 'systemd'})
    file {
      '/etc/systemd/system/docker.service.d/cmd.conf':
        ensure  => absent,
        require => Package['aufs-dkms', 'aufs-tools'],
    } ~> Exec['systemd-reload'] ~> Service['docker']
  }

  cron {
    'clean-old-docker-containers':
      # days is intentionally plural
      command => "docker ps -a --filter status=exited | grep -E 'Exited \\([0-9]+\\) [0-9]+ (days|weeks?|months?|years?) ago' | awk '{print \$1}' | chronic xargs -r docker rm",
      hour    => 1,
      minute  => 3;

    'clean-old-created-docker-containers':
      # days is intentionally plural
      command => "docker ps -a --filter status=created | grep -E '(days|weeks?|months?|years?) ago' | awk '{print \$1}' | chronic xargs -r docker rm",
      hour    => 1,
      minute  => 5;

    'clean-docker-images':
      # TODO: use docker image prune -a --filter until=<timestamp> when on 17.04+
      # Chronic doesn't work well here because docker rmi likes to raise errors
      # about images still linked to containers
      command => 'docker images -q --filter dangling=true | xargs -r docker rmi > /dev/null 2>&1',
      hour    => 1,
      minute  => 17;

    'clean-docker-volumes':
      command => 'chronic docker volume prune -f',
      hour    => 1,
      minute  => 25;
  }
}
