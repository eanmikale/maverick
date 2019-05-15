class maverick_dev::ardupilot (
    $ardupilot_source = "https://github.com/ArduPilot/ardupilot.git",
    $ardupilot_setupstream = true,
    $ardupilot_upstream = "https://github.com/ArduPilot/ardupilot.git",
    $ardupilot_branch = "master", # eg. master, Copter-3.3, ArduPlane-release
    $ardupilot_board = "px4-v4",
    $ardupilot_buildsystem = "waf", # waf (Copter >=3.4) or make (Copter <3.3)
    $ardupilot_all_vehicles = {"copter" => "arducopter", "plane" => "arduplane", "rover" => "ardurover", "sub" => "ardusub", "heli" => "arducopter-heli", "antennatracker" => "antennatracker"},
    $ardupilot_vehicle = "copter", # copter, plane or rover
    $sitl, # passed from init.pp
    $armeabi_packages = false, # needed to cross-compile firmware for actual FC boards
    $install_jsbsim = true,
    $jsbsim_source = "http://github.com/JSBSim-Team/jsbsim.git",
) {
    
    # Install ardupilot from git
    oncevcsrepo { "git-ardupilot":
        gitsource   => $ardupilot_source,
        dest        => "/srv/maverick/code/ardupilot",
        revision	=> $ardupilot_branch,
        submodules  => true,
    }
    ensure_packages(["make", "gawk", "g++", "zip", "genromfs", "python-empy", "python-future"])
    if $armeabi_packages == true {
        if $::operatingsystem == "Ubuntu" and versioncmp($::operatingsystemmajrelease, "18") >= 0 {
            ensure_packages(["gcc-arm-none-eabi", "binutils-arm-none-eabi", "gdb-multiarch", "libnewlib-arm-none-eabi", "libstdc++-arm-none-eabi-newlib"], {'ensure'=>'present'})
        } else {
            ensure_packages(["gcc-arm-none-eabi", "binutils-arm-none-eabi", "gdb-arm-none-eabi", "libnewlib-arm-none-eabi", "libstdc++-arm-none-eabi-newlib"], {'ensure'=>'present'})
        }
    }
    
    # If a custom ardupilot repo is specified, configure the upstream automagically
    exec { "ardupilot_setupstream":
        command     => "/usr/bin/git remote add upstream ${ardupilot_upstream}",
        unless      => "/usr/bin/git remote -v | /bin/grep -i ${ardupilot_upstream}",
        cwd         => "/srv/maverick/code/ardupilot",
        require     => Oncevcsrepo["git-ardupilot"],
    }
    
    # Compile SITL
    if $sitl and $ardupilot_buildsystem == "waf" {
        # Compile all vehicle types by default for waf build
        $ardupilot_all_vehicles.each |String $vehicle, String $buildfile| {
            maverick_dev::fwbuildwaf { "sitl_waf_${vehicle}":
                require     => [ Oncevcsrepo["git-ardupilot"], Exec["ardupilot_setupstream"], Package["python-future"] ],
                board       => "sitl",
                vehicle     => $vehicle,
                buildfile   => $buildfile,
            }
        }
    } elsif $sitl and $ardupilot_buildsystem == "make" {
        if $ardupilot_vehicle == "copter" {
            $ardupilot_type = "ArduCopter"
        } elsif $ardupilot_vehicle == "plane" {
            $ardupilot_type = "ArduPlane"
        } elsif $ardupilot_vehicle == "rover" {
            $ardupilot_type = "ArduRover"
        } elsif $ardupilot_vehicle == "sub" {
            $ardupilot_type = "ArduSub"
        } elsif $ardupilot_vehicle == "antennatracker" {
            $ardupilot_type = "AntennaTracker"
        }
        fwbuildmake { "sitl_${ardupilot_vehicle}": 
            require     => [ Oncevcsrepo["git-ardupilot"], Exec["ardupilot_setupstream"] ],
            board       => "sitl",
            build       => $ardupilot_type,
        }
    }

    # Compile jsbsim and install service, for plane
    if $install_jsbsim and ! ("install_flag_jsbsim" in $installflags) {
        ensure_packages(["libexpat1-dev"])
        oncevcsrepo { "git-jsbsim":
            gitsource   => $jsbsim_source,
            dest        => "/srv/maverick/var/build/jsbsim",
        } ->
        file { '//srv/maverick/var/build/jsbsim/build':
            ensure      => directory,
            owner       => "mav",
            group       => "mav",
        } ->
        exec { "jsbsim-cmake":
            command     => "/usr/bin/cmake -DCMAKE_INSTALL_PREFIX=/srv/maverick/software/jsbsim  ..",
            cwd         => "/srv/maverick/var/build/jsbsim/build",
            creates     => "/srv/maverick/var/build/jsbsim/build/Makefile",
            user        => "mav",
            require     => Package["libexpat1-dev"],
        } ->
        exec { "jsbsim-make":
            command     => "/usr/bin/make",
            timeout     => 0,
            cwd         => "/srv/maverick/var/build/jsbsim/build",
            creates     => "/srv/maverick/var/build/jsbsim/build/src/JSBSim",
            user        => "mav",
        } ->
        exec { "jsbsim-makeinstall":
            command     => "/usr/bin/make install",
            cwd         => "/srv/maverick/var/build/jsbsim/build",
            creates     => "/srv/maverick/software/jsbsim/bin/JSBSim",
            user        => "mav",
        } ->
        file { "/srv/maverick/software/jsbsim/bin":
            ensure      => directory,
            owner       => "mav",
            group       => "mav",
        } ->
        exec { "jsbsim-cpbin":
            command     => "/bin/cp /srv/maverick/var/build/jsbsim/build/src/JSBSim /srv/maverick/software/jsbsim/bin",
            creates     => "/srv/maverick/software/jsbsim/bin/JSBSim",
        } ->
        file { "/srv/maverick/var/build/.install_flag_jsbsim":
            ensure      => file,
            owner       => "mav",
            group       => "mav",
            mode        => "644",
        }
    }

}
