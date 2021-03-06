require 'spec_helper'

describe 'mistral::wsgi::apache' do

  shared_examples_for 'apache serving mistral with mod_wsgi' do
    it { is_expected.to contain_service('httpd').with_name(platform_parameters[:httpd_service_name]) }
    it { is_expected.to contain_class('mistral::deps') }
    it { is_expected.to contain_class('mistral::params') }
    it { is_expected.to contain_class('apache') }
    it { is_expected.to contain_class('apache::mod::wsgi') }

    describe 'with default parameters' do

      it { is_expected.to contain_file("#{platform_parameters[:wsgi_script_path]}").with(
        'ensure'  => 'directory',
        'owner'   => 'mistral',
        'group'   => 'mistral',
        'require' => 'Package[httpd]'
      )}


      it { is_expected.to contain_file('mistral_wsgi').with(
        'ensure'  => 'file',
        'path'    => "#{platform_parameters[:wsgi_script_path]}/app",
        'source'  => platform_parameters[:wsgi_script_source],
        'owner'   => 'mistral',
        'group'   => 'mistral',
        'mode'    => '0644'
      )}
      it { is_expected.to contain_file('mistral_wsgi').that_requires("File[#{platform_parameters[:wsgi_script_path]}]") }

      it { is_expected.to contain_apache__vhost('mistral_wsgi').with(
        'servername'                  => 'some.host.tld',
        'ip'                          => nil,
        'port'                        => '8989',
        'docroot'                     => "#{platform_parameters[:wsgi_script_path]}",
        'docroot_owner'               => 'mistral',
        'docroot_group'               => 'mistral',
        'ssl'                         => 'true',
        'wsgi_daemon_process'         => 'mistral',
        'wsgi_daemon_process_options' => {
          'user'         => 'mistral',
          'group'        => 'mistral',
          'processes'    => '8',
          'threads'      => '1',
          'display-name' => 'mistral_wsgi',
        },
        'wsgi_process_group'          => 'mistral',
        'wsgi_script_aliases'         => { '/' => "#{platform_parameters[:wsgi_script_path]}/app" },
        'require'                     => 'File[mistral_wsgi]'
      )}
      it { is_expected.to contain_concat("#{platform_parameters[:httpd_ports_file]}") }
    end

    describe 'when overriding parameters using different ports' do
      let :params do
        {
          :servername                => 'dummy.host',
          :bind_host                 => '10.42.51.1',
          :port                      => 12345,
          :ssl                       => false,
          :wsgi_process_display_name => 'mistral',
          :workers                   => 37,
        }
      end

      it { is_expected.to contain_apache__vhost('mistral_wsgi').with(
        'servername'                  => 'dummy.host',
        'ip'                          => '10.42.51.1',
        'port'                        => '12345',
        'docroot'                     => "#{platform_parameters[:wsgi_script_path]}",
        'docroot_owner'               => 'mistral',
        'docroot_group'               => 'mistral',
        'ssl'                         => 'false',
        'wsgi_daemon_process'         => 'mistral',
        'wsgi_daemon_process_options' => {
            'user'         => 'mistral',
            'group'        => 'mistral',
            'processes'    => '37',
            'threads'      => '1',
            'display-name' => 'mistral',
        },
        'wsgi_process_group'          => 'mistral',
        'wsgi_script_aliases'         => { '/' => "#{platform_parameters[:wsgi_script_path]}/app" },
        'require'                     => 'File[mistral_wsgi]'
      )}

      it { is_expected.to contain_concat("#{platform_parameters[:httpd_ports_file]}") }
    end
  end

  on_supported_os({
    :supported_os   => OSDefaults.get_supported_os
  }).each do |os,facts|
    context "on #{os}" do
      let (:facts) do
        facts.merge!(OSDefaults.get_facts({
          :os_workers     => 8,
          :concat_basedir => '/var/lib/puppet/concat',
          :fqdn           => 'some.host.tld'
        }))
      end

      let(:platform_parameters) do
        case facts[:osfamily]
        when 'Debian'
          {
            :httpd_service_name => 'apache2',
            :httpd_ports_file   => '/etc/apache2/ports.conf',
            :wsgi_script_path   => '/usr/lib/cgi-bin/mistral',
            :wsgi_script_source => '/usr/bin/mistral-wsgi-api'
          }
        when 'RedHat'
          {
            :httpd_service_name => 'httpd',
            :httpd_ports_file   => '/etc/httpd/conf/ports.conf',
            :wsgi_script_path   => '/var/www/cgi-bin/mistral',
            :wsgi_script_source => '/usr/bin/mistral-wsgi-api'
          }

        end
      end
      it_configures 'apache serving mistral with mod_wsgi'
    end
  end
end
