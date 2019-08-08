class maverick_network::wifibroadcast (
    $type = "svpcom",
    $tx_active = false,
    $rx_active = false,
) {
    
    if $type == "befinitiv" {
        ensure_packages(["libpcap-dev", "gcc", "make", "libcap2-bin"])
        
        oncevcsrepo { "git-wifibroadcast":
            gitsource   => "https://github.com/fnoop/wifibroadcast",
            dest        => "/srv/maverick/software/wifibroadcast",
            owner       => "mav",
            require     => [ Package["gcc"], Package["make"] ]
        } ->
        exec { "compile-wifibroadcast":
            command     => "/usr/bin/make all",
            creates     => "/srv/maverick/software/wifibroadcast/tx",
            user        => "mav",
            cwd         => "/srv/maverick/software/wifibroadcast",
        } ->
        file { "/srv/maverick/software/wifibroadcast/tx":
            mode        => "755",
            owner       => "mav",
            group       => "mav",
        } ->
        exec { "setcaps-wtx":
            command     => "/sbin/setcap cap_net_raw,cap_net_admin=eip /srv/maverick/software/wifibroadcast/tx",
            unless      => "/sbin/getcap /srv/maverick/software/wifibroadcast/tx |/bin/grep cap_net_admin",
        } ->
        exec { "copy-patched-9271-firmware":
            command     => "/bin/cp -f /srv/maverick/software/wifibroadcast/patches/AR9271/firmware/htc_9271.fw /lib/firmware",
            onlyif      => "/usr/bin/diff /srv/maverick/software/wifibroadcast/patches/AR9271/firmware/htc_9271.fw /lib/fimware/htc_9271.fw |/bin/grep differ",
        }
    } elsif $type == "svpcom" {
        ensure_packages(["libpcap-dev", "gcc", "make", "libcap2-bin", "libsodium-dev"])
        install_python_module { 'pip-pyroute2':
            pkgname     => 'pyroute2',
            ensure      => present,
        }

        # Install software
        if ! ("install_flag_wifibc" in $installflags) {
            oncevcsrepo { "git-wifibc":
                gitsource   => "https://github.com/svpcom/wifibroadcast.git",
                dest        => "/srv/maverick/var/build/wifibc",
                owner       => "mav",
                require     => [ Package["gcc"], Package["make"], Package["libsodium-dev"], Package["libpcap-dev"], Install_python_module["pip-pyroute2"], ]
            } ->
            exec { "compile-wifibc":
                command     => "/usr/bin/make",
                creates     => "/srv/maverick/var/build/wifibc/tx",
                user        => "root",
                cwd         => "/srv/maverick/var/build/wifibc",
            } ->
            file { ["/srv/maverick/software/wifibc", "/srv/maverick/software/wifibc/bin"]:
                ensure      => directory,
                owner       => "mav",
                group       => "mav",
                mode        => "0755",
            } ->
            exec { "install-wifibc":
                command     => "/bin/cp /srv/maverick/var/build/wifibc/wfb_[rt]x /srv/maverick/var/build/wifibc/wfb_keygen /srv/maverick/software/wifibc/bin",
                creates     => "/srv/maverick/software/wifibc/bin/wfb_keygen",
                user        => "mav",
                before      => [ Exec["wifibc-genkeys"], Exec["setcaps-wifibc_tx"] ],
            } ->
            file { "/srv/maverick/var/build/.install_flag_wifibc":
                ensure      => present,
                owner       => "mav",
                group       => "mav",
                mode        => "0644",
            }
        }
        
        exec { "setcaps-wifibc_tx":
            command     => "/sbin/setcap cap_net_raw,cap_net_admin=eip /srv/maverick/software/wifibc/bin/wfb_tx",
            unless      => "/sbin/getcap /srv/maverick/software/wifibc/bin/wfb_tx |/bin/grep cap_net_admin",
        }
        
        # Generate keys
        file { "/srv/maverick/data/network/wifibc":
            ensure      => directory,
            mode        => "755",
            owner       => "mav",
            group       => "mav",
        } ->
        exec { "wifibc-genkeys":
            command     => "/srv/maverick/software/wifibc/bin/wfb_keygen",
            creates     => "/srv/maverick/data/network/wifibc/gs.key",
            cwd         => "/srv/maverick/data/network/wifibc",
            user        => "mav",
        }
        
        # Install default config files
        file { "/srv/maverick/config/network/wifibc":
            ensure      => directory,
            mode        => "755",
            owner       => "mav",
            group       => "mav",
        } ->
        file { "/srv/maverick/config/network/wifibc/tx.conf":
            source      => "puppet:///modules/maverick_network/maverick-wifibc_tx.conf",
            owner       => "mav",
            group       => "mav",
            replace     => false,
        }
        file { "/srv/maverick/config/network/wifibc/rx.conf":
            source      => "puppet:///modules/maverick_network/maverick-wifibc_rx.conf",
            owner       => "mav",
            group       => "mav",
            replace     => false,
        }
        
        # Install wifibc service
        file { "/srv/maverick/software/maverick/bin/wifibc.sh":
            ensure      => symlink,
            target      => "/srv/maverick/software/maverick/manifests/maverick-modules/maverick_network/files/wifibc.sh",
            owner       => "mav",
            group       => "mav",
        } ->
        file { "/etc/systemd/system/maverick-wifibc_tx.service":
            source      => "puppet:///modules/maverick_network/maverick-wifibc_tx.service",
            owner       => root,
            group       => root,
            notify      => Exec["maverick-systemctl-daemon-reload"],
        } ->
        file { "/etc/systemd/system/maverick-wifibc_rx.service":
            source      => "puppet:///modules/maverick_network/maverick-wifibc_rx.service",
            owner       => root,
            group       => root,
            notify      => Exec["maverick-systemctl-daemon-reload"],
        }

        # Control tx service
        if $tx_active == true {
            service_wrapper { "maverick-wifibc_tx":
                ensure  => running,
                enable  => true,
                require => [ Exec["maverick-systemctl-daemon-reload"], Exec["setcaps-wifibc_tx"] ],
            }
        } else {
            service_wrapper { "maverick-wifibc_tx":
                ensure  => stopped,
                enable  => false,
                require => Exec["maverick-systemctl-daemon-reload"],
            }
        }
        
        # Control rx service
        if $rx_active == true {
            service { "maverick-wifibc_rx":
                ensure  => running,
                enable  => true,
                require => Exec["maverick-systemctl-daemon-reload"],
            }
        } else {
            service { "maverick-wifibc_rx":
                ensure  => stopped,
                enable  => false,
                require => Exec["maverick-systemctl-daemon-reload"],
            }
        }
    }

}
