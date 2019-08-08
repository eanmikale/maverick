class maverick_ros (
    $installtype = "auto",
    $distribution = "auto",
    $buildtype = "ros_comm", # ROS core variant, ros_comm is base without GUI, can also be desktop, desktop_full.  mobile and perception variants useful for drones.  desktop_full includes everything.
    $binarytype = ["ros-kinetic-perception", "ros-kinetic-viz"], # Binary packages install type, can be ros-kinetic-ros-base, ros-kinetic-desktop, ros-kinetic-desktop-full, ros-kinetic-viz, ros-kinetic-perception
    $builddir = "/srv/maverick/var/build/ros_catkin_ws",
    $installdir = "/srv/maverick/software/ros",
    $module_mavros = true,
    $module_opencv = false,
    $ros2 = false,
) {
    
    # If installtype is set then use it and skip autodetection
    if $installtype == "native" {
        if $ros_installed == "no" { 
            notice("ROS: Native installation requested")
        }
        $_installtype = "native"
    } elsif $installtype == "source" {
        if $ros_installed == "no" {
            notice("ROS: Source installation requested")
        }
        $_installtype = "source"
    # First try and determine build type based on OS and architecture
    } elsif $installtype == "auto" {
        case $::operatingsystem {
            "Ubuntu": {
                case $::lsbdistcodename {
                    "wily": {
                        $autodist = "kinetic"
                        case $architecture {
                            "amd64", "i386": { $_installtype = "native" }
                            default: { $_installtype = "source" }
                        }
                    }
                    "xenial": {
                        $autodist = "kinetic"
                        case $architecture {
                            "amd64", "i386", "armhf", "arm64", "aarch64": { $_installtype = "native" }
                            default: { $_installtype = "source" }
                        }
                    }
                    "yakkety": {
                        $autodist = "lunar"
                        case $architecture {
                            "amd64": { $_installtype = "native" }
                            default: { $_installtype = "source" }
                        }
                    }
                    "zesty": {
                        $autodist = "lunar"
                        case $architecture {
                            "amd64": { $_installtype = "native" }
                            default: { $_installtype = "source" }
                        }
                    }
                    "bionic": {
                        $autodist = "melodic"
                        case $architecture {
                            # "amd64", "armhf", "arm64": { $_installtype = "native" }
                            "amd64", "armhf", "arm64": { $_installtype = "source" }
                            default: { $_installtype = "source" }
                        }
                    }
                    default: {
                        $autodist = undef
                        $_installtype = undef
                    }
                }
            }
            "Debian": {
                case $::operatingsystemmajrelease {
                    # For Debian OS use version number instead of codename, for derivatives like rasbian and ubilinux
                    "8": { # jessie
                        $autodist = "kinetic"
                        case $::architecture {
                            "amd64", "arm64": { $_installtype = "native" }
                            default: { $_installtype = "source" }
                        }
                    }
                    "9": { # stretch
                        case $::raspberry_present {
                            "yes": { $autodist = "kinetic" }
                            default: { $autodist = "lunar" }
                        }
                        case $::architecture {
                            "amd64", "arm64": { $_installtype = "native" }
                            default: { $_installtype = "source" }
                        }
                    }
                    default: {
                        $autodist = undef
                        $_installtype = undef
                    }
                }
            }
        }
        if $_installtype == "native" and $ros_installed == "no" {
            notice("ROS: supported platform detected for ${autodist} distribution, using native packages")
        } elsif $_installtype == "source" and $ros_installed == "no" {
            notice("ROS: unsupported platform for ${autodist} distribution, installing from source")
        }
    } else {
        $_installtype = false
    }
    
    if $distribution == "auto" and $installtype == "auto" {
        $_distribution = $autodist
    } else {
        $_distribution = $distribution
    }
    
    if $installtype and $_distribution {
        # Install dependencies
        ensure_packages(["dirmngr"])
        ensure_packages(["libpoco-dev", "libyaml-cpp-dev"])
        # Work out distro name
        if $::lsbdistid == "ubilinux" and $::lsbmajdistrelease == "4" {
            $_distro = "stretch"
        } else {
            $_distro = $::lsbdistcodename
        }
        # Create symlink to usual vendor install directory
        file { ["/opt", "/opt/ros"]:
            ensure      => directory,
            mode        => "755",
            owner       => "root",
            group       => "root",
        } ->
        file { ["${installdir}", "${installdir}/${_distribution}"]:
            ensure      => directory,
            owner       => "mav",
            group       => "mav",
            mode        => "755",
        } ->
        file { "/opt/ros/${_distribution}":
            ensure      => link,
            target      => "${installdir}/${_distribution}",
            force       => true,
        } ->
        file { "${installdir}/current":
            ensure      => link,
            target      => "${installdir}/${_distribution}",
            force       => true,
        } ->
        file { "/opt/ros/current":
            ensure      => link,
            target      => "${installdir}/${_distribution}",
            force       => true,
        } ->
        # Remove compromised ROS repo key
        exec { "ros-repo-badkey":
            command     => "/usr/bin/apt-key del '421C 365B D9FF 1F71 7815  A389 5523 BAEE B01F A116'",
            onlyif      => "/usr/bin/apt-key list -k |/bin/grep 'A389 5523 BAEE B01F A116'",
            require     => Package["dirmngr"],
        } ->
        # Install ROS bootstrap from ros.org packages
        exec { "ros-repo-key":
            command     => "/usr/bin/apt-key adv --keyserver 'hkp://keyserver.ubuntu.com:80' --recv-key C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654",
            unless      => "/usr/bin/apt-key list -k |/bin/grep 'C1CF 6E31 E6BA DE88 68B1  72B4 F42E D6FB AB17 C654'",
            require     => Package["dirmngr"],
            notify      => Exec["ros_apt_update"],            
        } ->
        exec { "ros-repo":
            command     => "/bin/echo \"deb http://packages.ros.org/ros/ubuntu ${_distro} main\" > /etc/apt/sources.list.d/ros-latest.list",
            unless      => "/bin/grep '${_distro}' /etc/apt/sources.list.d/ros-latest.list",
            notify      => Exec["ros_apt_update"],
        } ->
        exec { "ros_apt_update":
            command     => "/usr/bin/apt update",
            refreshonly => true,
        } ->
        package { ["python-rosdep", "python-catkin-tools"]:
            ensure      => installed,
            require     => Exec["apt_update"],
        }
        /*
        $wstool_package = $::operatingsystem ? {
            'Ubuntu'        => 'python-wstool',
            'Debian'        => 'python-wstools',
        }
        package { "python-wstool":
            name        => $wstool_package
        }
        */
        ensure_packages(["python-wstool", "python-wstools"])
    }

    # Install from ros repos
    if $_installtype == "native" {
        package { ["ros-${_distribution}-perception", "ros-${_distribution}-viz", "ros-${_distribution}-mavros", "ros-${_distribution}-mavros-extras", "ros-${_distribution}-mavros-msgs", "ros-${_distribution}-test-mavros"]:
            ensure      => installed,
            require     => [ Exec["apt_update"], Package["python-rosdep"], File["/opt/ros/${_distribution}"], ],
        } ->
        # Download latest geographiclib install script
        exec { "download_geoinstall":
            command         => "/usr/bin/wget -O /srv/maverick/software/ros/${_distribution}/lib/mavros/install_geographiclib_datasets.master.sh https://raw.githubusercontent.com/mavlink/mavros/master/mavros/scripts/install_geographiclib_datasets.sh",
            creates         => "/srv/maverick/software/ros/${_distribution}/lib/mavros/install_geographiclib_datasets.master.sh",
        } ->
        # Install mavros geographiclib dependencies
        exec { "mavros_geoinstall":
            command         => "/bin/bash /srv/maverick/software/ros/${_distribution}/lib/mavros/install_geographiclib_datasets.master.sh >/srv/maverick/var/log/build/ros.mavros_geoinstall.out 2>&1",
            creates         => "/usr/share/GeographicLib/geoids/egm96-5.pgm",
        } ->
        # Initialize rosdep
        exec { "rosdep-init":
            command         => "/usr/bin/rosdep init",
            creates         => "/etc/ros/rosdep/sources.list.d/20-default.list",
        } ->
        exec { "rosdep-update":
            user            => "mav",
            command         => "/usr/bin/rosdep update",
            creates         => "/srv/maverick/.ros/rosdep/sources.cache",
        } ->
        file { "/etc/profile.d/30-ros-env.sh":
            ensure      => present,
            mode        => "644",
            owner       => "root",
            group       => "root",
            content     => "source /opt/ros/${_distribution}/setup.bash",
        }
        # Install python3 packages
        package { ["python3-rospkg-modules", "python3-catkin-pkg-modules"]:
            ensure      => present,
        }

    # Build from source
    } elsif $_installtype == "source" {

        # Force osdistro for raspberry
        if $raspberry_present == "yes" {
            $_osdistro = "--os=debian:${::lsbdistcodename}"
        } else {
            $_osdistro = ""
        }

        if ! ("install_flag_ros" in $installflags) {
            file { "${builddir}":
                ensure      => directory,
                owner       => "mav",
                group       => "mav",
                mode        => "755",
            }
            
            $buildparallel = ceiling((1 + $::processorcount) / 2) # Restrict build parallelization to roughly processors/2 if raspberry
            ensure_packages(["build-essential"])
            # Install ros install packages
            package {["python-rosinstall", "python-rosinstall-generator"]:
                require         => Exec["ros-repo"]
            } ->
            # Initialize rosdep
            exec { "rosdep-init":
                command         => "/usr/bin/rosdep init",
                creates         => "/etc/ros/rosdep/sources.list.d/20-default.list",
                require         => [ Package["python-rosdep"], Package["python-wstool"], Package["python-rosinstall"], Package["python-rosinstall-generator"] ],
            } ->
            exec { "rosdep-update":
                user            => "mav",
                command         => "/usr/bin/rosdep update",
                creates         => "/srv/maverick/.ros/rosdep/sources.cache",
                require         => Package["python-rosdep"]
            } ->
            exec { "catkin_rosinstall":
                environment     => ["CMAKE_PREFIX_PATH=/srv/maverick/software/opencv"],
                command         => "/usr/bin/rosinstall_generator ${buildtype} --rosdistro ${_distribution} --deps --tar > ${_distribution}-${buildtype}.rosinstall && /usr/bin/wstool init -j${buildparallel} src ${_distribution}-${buildtype}.rosinstall",
                cwd             => "${builddir}",
                user            => "mav",
                creates         => "${builddir}/src/.rosinstall"
            } ->
            exec { "catkin_make":
                environment     => ["CMAKE_PREFIX_PATH=/srv/maverick/software/opencv"],
                command         => "/usr/bin/rosdep install --from-paths src --ignore-src --rosdistro ${_distribution} -y ${_osdistro} && ${builddir}/src/catkin/bin/catkin_make_isolated --install --install-space ${installdir}/${_distribution} -DCMAKE_BUILD_TYPE=Release -j${buildparallel}",
                cwd             => "${builddir}",
                user            => "mav",
                creates         => "${installdir}/${_distribution}/lib/rosbag/topic_renamer.py",
                timeout         => 0,
                require         => File["${installdir}/${_distribution}"]
            } ->
            file { "/etc/profile.d/30-ros-env.sh":
                ensure      => present,
                mode        => "644",
                owner       => "root",
                group       => "root",
                content     => "source /opt/ros/${_distribution}/setup.bash",
            } ->
            file { "/srv/maverick/var/build/.install_flag_ros":
                ensure      => present,
            }
        }
        
        if ! ("install_flag_ros_opencv" in $installflags) {
            if $module_opencv == true {
                # Add opencv to the existing workspace through vision_opencv package
                exec { "ws_add_opencv":
                    command         => "/usr/bin/rosinstall_generator vision_opencv --rosdistro ${_distribution} --deps --wet-only --tar >${_distribution}-vision_opencv-wet.rosinstall && /usr/bin/wstool merge -t src ${_distribution}-vision_opencv-wet.rosinstall && /usr/bin/wstool update -t src",
                    cwd             => "${builddir}",
                    user            => "mav",
                    creates         => "${builddir}/src/vision_opencv",
                    timeout         => 0,
                    environment => ["PKG_CONFIG_PATH=/srv/maverick/software/gstreamer/lib/pkgconfig:/srv/maverick/software/opencv/lib/pkgconfig"],
                    require         => [ Package["libpoco-dev"], Exec["catkin_make"] ],
                } ->
                exec { "catkin_make_vision_opencv":
                    command         => "${builddir}/src/catkin/bin/catkin_make_isolated --install --install-space ${installdir}/${_distribution} -DCMAKE_BUILD_TYPE=Release -j${buildparallel}",
                    cwd             => "${builddir}",
                    user            => "mav",
                    creates         => "${installdir}/${_distribution}/lib/libopencv_optflow3.so",
                    environment => ["PKG_CONFIG_PATH=/srv/maverick/software/gstreamer/lib/pkgconfig:/srv/maverick/software/opencv/lib/pkgconfig"],
                    timeout         => 0,
                    require         => File["${installdir}/${_distribution}"]
                } ->
                file { "/srv/maverick/var/build/.install_flag_ros_opencv":
                    ensure      => present,
                }
            }
        }
        
        if ! ("install_flag_ros_mavros" in $installflags) {
            if $module_mavros == true {
                if "install_flag_ros" in $installflags {
                    $_mavros_deps = undef
                } else {
                    $_mavros_deps = Exec["catkin_make"]
                }
                # Add mavros to the existing workspace, this also installs mavlink package as dependency
                exec { "ws_add_mavros":
                    # command         => "/usr/bin/rosinstall_generator --upstream mavros --rosdistro ${_distribution} --wet-only --tar >${_distribution}-mavros-wet.rosinstall && /usr/bin/rosinstall_generator visualization_msgs --rosdistro ${_distribution} --deps --wet-only --tar >>${_distribution}-mavros-wet.rosinstall && /usr/bin/rosinstall_generator mavlink --rosdistro ${_distribution} --deps --wet-only --tar >>${_distribution}-mavros-wet.rosinstall && /usr/bin/rosinstall_generator tf --rosdistro ${_distribution} --deps --wet-only --tar >>${_distribution}-mavros-wet.rosinstall && /usr/bin/rosinstall_generator geographic_msgs --rosdistro ${_distribution} --deps --wet-only --tar >>${_distribution}-mavros-wet.rosinstall && /usr/bin/rosinstall_generator control_toolbox --rosdistro ${_distribution} --deps --wet-only --tar >>${_distribution}-mavros-wet.rosinstall && /usr/bin/rosinstall_generator urdf --rosdistro ${_distribution} --deps --wet-only --tar >>${_distribution}-mavros-wet.rosinstall && /usr/bin/rosinstall_generator nav_msgs --rosdistro ${_distribution} --deps --wet-only --tar >>${_distribution}-mavros-wet.rosinstall && /usr/bin/rosinstall_generator eigen_conversions --rosdistro ${_distribution} --deps --wet-only --tar >>${_distribution}-mavros-wet.rosinstall && /usr/bin/rosinstall_generator diagnostic_msgs --rosdistro ${_distribution} --deps --wet-only --tar >>${_distribution}-mavros-wet.rosinstall && /usr/bin/rosinstall_generator tf2_eigen --rosdistro ${_distribution} --deps --wet-only --tar >>${_distribution}-mavros-wet.rosinstall && /usr/bin/wstool merge --merge-keep -y -t src ${_distribution}-mavros-wet.rosinstall && /usr/bin/wstool update -t src",
                    command         => "/usr/bin/rosinstall_generator --upstream mavros --rosdistro ${_distribution} --wet-only --tar >${_distribution}-mavros-wet.rosinstall && /usr/bin/rosinstall_generator mavlink control_toolbox urdf eigen_conversions diagnostic_updater diagnostic_msgs geometry_msgs nav_msgs sensor_msgs geographic_msgs visualization_msgs tf tf2_eigen --rosdistro ${_distribution} --deps --wet-only --tar >>${_distribution}-mavros-wet.rosinstall && /usr/bin/wstool merge --merge-keep -y -t src ${_distribution}-mavros-wet.rosinstall && /usr/bin/wstool update -t src",
                    # command         => "/usr/bin/rosinstall_generator --upstream mavros --rosdistro ${_distribution} --deps --tar >${_distribution}-mavros.rosinstall && /usr/bin/wstool merge --merge-keep -t src ${_distribution}-mavros.rosinstall -y && /usr/bin/wstool update -t src",
                    cwd             => "${builddir}",
                    user            => "mav",
                    creates         => "${builddir}/src/mavros",
                    environment => ["PKG_CONFIG_PATH=/srv/maverick/software/gstreamer/lib/pkgconfig:/srv/maverick/software/opencv/lib/pkgconfig"],
                    timeout         => 0,
                    require         => $_mavros_deps, 
                } ->
                exec { "catkin_make_mavros":
                    # Note must only use -j1 otherwise we get compiler errors
                    command         => "/usr/bin/rosdep install --from-paths src --ignore-src --rosdistro ${_distribution} -y $_osdistro && ${builddir}/src/catkin/bin/catkin_make_isolated --install --install-space ${installdir}/${_distribution} -DCMAKE_BUILD_TYPE=Release -j1 >/srv/maverick/var/log/build/ros.mavros.install.out 2>&1",
                    cwd             => "${builddir}",
                    user            => "mav",
                    creates         => "${installdir}/${_distribution}/lib/libmavros.so",
                    environment => ["PKG_CONFIG_PATH=/srv/maverick/software/gstreamer/lib/pkgconfig:/srv/maverick/software/opencv/lib/pkgconfig"],
                    timeout         => 0,
                    require         => File["${installdir}/${_distribution}"]
                } ->
                # Install mavros geographiclib dependencies
                exec { "mavros_geoinstall":
                    command         => "/bin/bash /srv/maverick/software/ros/${_distribution}/lib/mavros/install_geographiclib_datasets.sh >/srv/maverick/var/log/build/ros.mavros_geoinstall.out 2>&1",
                    creates         => "/usr/share/GeographicLib/geoids/egm96-5.pgm",
                } ->
                file { "/srv/maverick/var/build/.install_flag_ros_mavros":
                    ensure      => present,
                }
            }
        }

    }
    
    if $installtype and $_distribution {
        # Install rosmaster systemd manifest.  Note it's not activated here, other modules will call the rosmaster define
        file { "/etc/systemd/system/maverick-rosmaster@.service":
            ensure          => present,
            source          => "puppet:///modules/maverick_ros/maverick-rosmaster@.service",
            owner           => "root",
            group           => "root",
            mode            => "644",
            notify          => Exec["maverick-systemctl-daemon-reload"],
        }
        # Create directory for ros config
        file { "/srv/maverick/config/ros":
            ensure          => directory,
            owner           => "mav",
            group           => "mav",
            mode            => "755",
        }
        # Create a symlink to rosmaster launch script
        file { "/srv/maverick/software/maverick/bin/rosmaster.sh":
            ensure      => link,
            target      => "/srv/maverick/software/maverick/manifests/maverick-modules/maverick_ros/files/rosmaster.sh",
        }
        
        # Create log directories
        file { ["/srv/maverick/var/log/ros", "/srv/maverick/var/log/ros/fc", "/srv/maverick/var/log/ros/sitl"]:
            ensure      => directory,
            mode        => "755",
            owner       => "mav",
            group       => "mav",
        }
    
        # Install mavros systemd manifest.  Like rosmaster, it's not activated here but used by mavros define
        file { "/etc/systemd/system/maverick-mavros@.service":
            source      => "puppet:///modules/maverick_ros/maverick-mavros@.service",
            owner       => "root",
            group       => "root",
            mode        => "644",
            notify      => Exec["maverick-systemctl-daemon-reload"],
        }
        # Create a symlink to mavros launch script
        file { "/srv/maverick/software/maverick/bin/mavros.sh":
            ensure      => link,
            target      => "/srv/maverick/software/maverick/manifests/maverick-modules/maverick_ros/files/mavros.sh",
        }
    }

    if $ros2 == true {
        class { "maverick_ros::ros2": }
    }
}
