class maverick_analysis::grafana (
    $webport = "6790",
    $host = "127.0.0.1",
    $rootpath = "/analysis/grafana/",
    $grafana_version = "5.1.0",
    $grafana_firewall_rules = false,
    $mav_password = 'e35f84e5859dfe5dfe2a9f6ed2086884c3a5e41d206c6e704b48cf45a0dda574ad85b4e9362e8d89eee3eb82e7ef34528ea4',
    $mav_salt = 'ry48G1ZHyi',
    # $mav_password = 'wingman',
    $admin_user = 'admin',
    # To reset the admin hash: grafana-cli -d admin reset-admin-password theneedforspeed --config=/srv/maverick/config/analysis/grafana.ini from /usr/share/grafana
    $admin_hash = '6eade3d424af57a87cb455d6577a7d92746517db17deda6b73fd40f22850b4491e6513d22763d9891d2a9206e8c61c9da3d6',
    $admin_salt = 'WwOYa3P4rc',
    $admin_rand = 'slhNQwWHa7',
    # $admin_password = 'theneedforspeed',
    $admin_password = 'admin',
    $active = true,
) {

    if $active == true {
    
        ensure_packages(["sqlite3"])
    
        file { ["/srv/maverick/data/analysis/grafana", "/srv/maverick/data/analysis/grafana/dashboards", "/srv/maverick/data/analysis/grafana/logs", "/srv/maverick/data/analysis/grafana/provisioning", "/srv/maverick/data/analysis/grafana/provisioning/datasources", "/srv/maverick/data/analysis/grafana/provisioning/dashboards", "/srv/maverick/var/log/analysis/grafana"]:
            ensure      => directory,
            mode        => "755",
            owner       => "mav",
            group       => "mav",
        }
        file { "/srv/maverick/software/grafana":
            ensure      => absent,
            force       => true,
        }
    
        if $joule_present == "yes" {
            $_dashboard = "system-dashboard-joule.json"
        } elsif $raspberry_present == "yes" {
            $_dashboard = "system-dashboard-raspberry.json"
        } else {
            $_dashboard = "system-dashboard-generic.json"
        }
    
        if $raspberry_present == "yes" or $tegra_present == "yes" {
            # If we're on tegra, need to do a bit of hackery
            if $tegra_present == "yes" {
                exec { "tegra-armhf":
                    command     => "/usr/bin/dpkg --add-architecture armhf && apt update",
                    unless      => "/usr/bin/dpkg --print-foreign-architectures |grep armhf",
                    notify      => Exec["apt_update"],
                }
            }
            $manage_package_repo = false
            # Don't use autodetect above, because we want OS images to be compatible with Zero
            $package_source = "https://dl.bintray.com/fg2it/deb-rpi-1b/main/g/grafana_${grafana_version}_armhf.deb"
            $install_method = "package"
        } else {
            $manage_package_repo = true
            $package_source = undef
            $install_method = "repo"
        }
        file { "/etc/systemd/system/maverick-grafana.service":
            owner       => "root",
            group       => "root",
            mode        => "644",
            source      => "puppet:///modules/maverick_analysis/grafana.service",
            notify      => Exec["maverick-systemctl-daemon-reload"],
        } ->
        class { "::grafana": 
            cfg_location        => "/srv/maverick/config/analysis/grafana.ini",
            cfg => {
                app_mode => 'production',
                paths   => {
                    data            => "/srv/maverick/data/analysis/grafana",
                    logs            => "/srv/maverick/data/analysis/grafana/logs",
                    plugins         => "/srv/maverick/data/analysis/grafana/plugins",
                    provisioning    => "/srv/maverick/data/analysis/grafana/provisioning",
                
                },
                server   => {
                  http_port     => $webport,
                  root_url      => "%(protocol)s://%(domain)s:${rootpath}",
                },
                users    => {
                  allow_sign_up => false,
                },
          },
          data_dir              => "/srv/maverick/data/analysis/grafana",
          install_method        => $install_method,
          manage_package_repo   => $manage_package_repo,
          package_source        => $package_source,
          service_name          => "maverick-grafana",
          version               => $grafana_version,
        } ->
        service_wrapper { "grafana":
            ensure      => "stopped",
            enable      => false,
        } ->
        service_wrapper { "grafana-server":
            ensure      => "stopped",
            enable      => false,
        } ->
        http_conn_validator { 'grafana-postdelay' :
            host    => $host,
            port    => $webport,
            use_ssl => false,
            test_url => '/public/img/grafana_icon.svg',
        } ->
        # Create maverick org in grafana
        exec { "grafana-maverickorg":
            unless          => "/usr/bin/sqlite3 /srv/maverick/data/analysis/grafana/grafana.db 'select * from main.org' |grep Maverick",
            command         => "/bin/sleep 10; /usr/bin/sqlite3 /srv/maverick/data/analysis/grafana/grafana.db \"insert into main.org values(10,0,'Maverick','','','','','','','','2017-06-20 11:02:55','2017-06-20 11:15:51')\"", # sleep is to give grafana enough time to fire up and release the db
            user            => "mav",
        } ->
        # Delete old mav user
        exec { "grafana-deloldmavuser":
            onlyif          => "/usr/bin/sqlite3 /srv/maverick/data/analysis/grafana/grafana.db 'select * from main.user where id=10' |grep mav",
            command         => "/usr/bin/sqlite3 /srv/maverick/data/analysis/grafana/grafana.db \"delete from main.user where id=10\"",
            user            => "mav",
        } ->
        # Create mav user in grafana
        exec { "grafana-mavuser":
            unless          => "/usr/bin/sqlite3 /srv/maverick/data/analysis/grafana/grafana.db 'select * from main.user' |grep mav",
            command         => "/usr/bin/sqlite3 /srv/maverick/data/analysis/grafana/grafana.db \"insert into main.user values(100,0,'mav','mav','Maverick User','${mav_password}','${mav_salt}','yICOZzT82L','',10,0,0,'','2017-06-21 12:54:43','2017-06-21 12:54:43',1,'2017-06-21 12:54:43')\"",
            user            => "mav",
        } ->
        # Link mav user to org
        exec { "grafana-linkmav":
            unless          => "/usr/bin/sqlite3 /srv/maverick/data/analysis/grafana/grafana.db 'select * from main.org_user where org_id=\"10\" and user_id=\"100\"' |grep Viewer",
            command         => "/usr/bin/sqlite3 /srv/maverick/data/analysis/grafana/grafana.db \"insert into main.org_user values('100','10','100','Viewer','2017-06-21 13:43:38','2017-06-21 13:43:38')\"",
            user            => "mav",
        }
    
        # Deploy the provisioning config
        file { "/srv/maverick/data/analysis/grafana/provisioning/datasources/influx.yaml":
            source          => "puppet:///modules/maverick_analysis/grafana-influx.yaml",
            owner           => "mav",
            group           => "mav",
            notify          => Service["maverick-grafana"],
        }
        file { "/srv/maverick/data/analysis/grafana/provisioning/dashboards/dashboards.yaml":
            source          => "puppet:///modules/maverick_analysis/grafana-dashboards.yaml",
            owner           => "mav",
            group           => "mav",
            notify          => Service["maverick-grafana"],
        }
        
        # Deploy provisioning dashboards
        file { "/srv/maverick/data/analysis/grafana/dashboards/system_dashboard.json":
            content         => template("maverick_analysis/${_dashboard}"),
            owner           => "mav",
            group           => "mav",
        }
        file { "/srv/maverick/data/analysis/grafana/dashboards/flight-dashboard-ardupilot.json":
            content         => template("maverick_analysis/flight-dashboard-ardupilot.json"),
            owner           => "mav",
            group           => "mav",
        }
        file { "/srv/maverick/data/analysis/grafana/dashboards/flight-ekf2-ardupilot.json":
            content         => template("maverick_analysis/flight-ekf2-ardupilot.json"),
            owner           => "mav",
            group           => "mav",
        }
        file { "/srv/maverick/data/analysis/grafana/dashboards/flight-ekf3-ardupilot.json":
            content         => template("maverick_analysis/flight-ekf3-ardupilot.json"),
            owner           => "mav",
            group           => "mav",
        }
        file { "/srv/maverick/data/analysis/grafana/dashboards/flight-ekf2ekf3-ardupilot.json":
            content         => template("maverick_analysis/flight-ekf2ekf3-ardupilot.json"),
            owner           => "mav",
            group           => "mav",
        }
        file { "/srv/maverick/data/analysis/grafana/dashboards/mavexplorer-mavgraphs.json":
            content         => template("maverick_analysis/mavexplorer-mavgraphs.json"),
            owner           => "mav",
            group           => "mav",
        }
    
        /*
        # Delete old admin user
        exec { "grafana-deloldadminuser":
            onlyif          => "/usr/bin/sqlite3 /srv/maverick/data/analysis/grafana/grafana.db 'select * from main.user where id=1' |grep admin",
            command         => "/usr/bin/sqlite3 /srv/maverick/data/analysis/grafana/grafana.db \"delete from main.user where id=1\"",
            user            => "mav",
        } ->
        # Create admin user in grafana
        exec { "grafana-adminuser":
            unless          => "/usr/bin/sqlite3 /srv/maverick/data/analysis/grafana/grafana.db 'select * from main.user' |grep admin",
            command         => "/usr/bin/sqlite3 /srv/maverick/data/analysis/grafana/grafana.db \"insert into main.user values(101,0,'${admin_user}','${admin_user}','Maverick Admin','${admin_hash}','${admin_salt}','${admin_rand}','',10,1,0,'','2017-06-21 12:54:43','2017-06-21 12:54:43',1,'2017-06-21 12:54:43')\"",
            user            => "mav",
        } ->
        # Link admin user to org
        exec { "grafana-linkadmin":
            unless          => "/usr/bin/sqlite3 /srv/maverick/data/analysis/grafana/grafana.db 'select * from main.org_user where org_id=\"10\" and user_id=\"101\"' |grep Admin",
            command         => "/usr/bin/sqlite3 /srv/maverick/data/analysis/grafana/grafana.db \"insert into main.org_user values('101','10','101','Admin','2017-06-21 13:43:38','2017-06-21 13:43:38')\"",
            user            => "mav",
        } ->
        */
    
        /*
        ### NEW - Not working yet
        exec { "grafana-reset-admin-password":
            command         => "/usr/sbin/grafana-cli -d admin reset-admin-password ${admin_password} --config=/srv/maverick/config/analysis/grafana.ini",
            #unless          => "",
            cwd             => "/usr/share/grafana",
        } ->
        grafana_organization { 'maverick':
            grafana_url      => "http://${host}:${webport}",
            grafana_user     => $admin_user,
            grafana_password => $admin_password,
        } ->
        grafana_user { 'mav':
            grafana_url      => "http://${host}:${webport}",
            grafana_user      => $admin_user,
            grafana_password  => $admin_password,
            full_name         => 'Maverick User',
            password          => $mav_password,
        }
        */
        
        if defined(Class["::maverick_web"]) {
            nginx::resource::location { "web-analysis-graphs":
                location    => "/analysis/grafana/",
                proxy       => "http://localhost:${webport}/",
                server      => getvar("maverick_web::server_fqdn"),
                require     => [ Class["maverick_gcs::fcs"], Class["nginx"] ],
            }
        }
    
        if $grafana_firewall_rules == true {
            if defined(Class["::maverick_security"]) {
                maverick_security::firewall::firerule { "grafana":
                    ports       => $webport,
                    ips         => lookup("firewall_ips"),
                    proto       => "tcp"
                }
            }
        }
    } else {
        service { 'maverick-grafana':
            ensure => stopped,
            enable => false,
        }
    }
}
