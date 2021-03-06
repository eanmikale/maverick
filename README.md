# Maverick

[![Join the chat at https://gitter.im/goodrobots/maverick](https://badges.gitter.im/goodrobots/maverick.svg)](https://gitter.im/goodrobots/maverick?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)
UAV Companion Computer System

Maverick is a system for creating, maintaining and controlling UAV Companion Computers.  The name Maverick reflects the initial main goal of interfacing Companion Computers to Flight Controllers through the Mavlink protocol, specifically ArduPilot (PX4 support planned).

Please see <a href='https://goodrobots.github.io/maverick/' target="maverick_docs">the documentation</a> for more info and how to install it.

What does Maverick do?

 - Downloadable, ready to flash, ready to fly images for Raspberry Pi (all models), NVidia Tegra TX1/TX2, Up (Up, Squared, Core), Odroid XU4, Intel Joule
 - Downloadable VM image for developers in OVA (Open Virtual Appliance) and Parallels formats, should run in VirtualBox, VMware, Parallels etc
 - Permissive MIT licensing, absolute minimum restrictions on opensource or commercial usage
 - Ability to bootstrap from any donor/vendor OS (only Debian/Ubuntu based OS supported so far, but possible to support any base OS) and create custom images
 - Single 'maverick' command provides system/network info, self updating, system configuration, service control
 - Self-contained, consistent software environments and versions across different platforms
 - Automatic detection and configuration of platform hardware and peripherals
 - Easy modular network configuration including managed wireless, monitor/injection, Host Access Point, Avahi, Dnsmasq, DHCP client/server, wifibroadcast
 - Built-in security, firewall, antivirus, scanners
 - Selective, modular Mavlink proxy, Dronekit and MAVROS configuration, supports MAVProxy, mavlink-router, cmavnode
 - Rich web-based IDE (Integrated Development Environment) - Cloud9
 - Full SITL environment with separate mavlink proxy, dronekit and MAVROS instances
 - Extensive consistent software components installed on all platforms - ROS Kinetic/Lunar, ROS2, Tensorflow 1.3, OpenCV 3.4, Gstreamer 1.12.4, FPV video (visiond, camera-streaming-daemon), Orb_slam2, RTABMAP, Aruco
 - ArduPllot development environment, compiled ArduPilot for SITL, everything necessary setup to compile and upload to Flight Controllers direct from companion computer
 - PX4 development environment, compiled PX4 for SITL, everything necessary setup to compile and upload to Flight Controllers direct from companion computer
 - Vision functions - automatic detection and configuration of attached digital cameras for FPV (visiond), Precision Landing with vision_landing, experimental collision avoidance with RealSense depth cameras, Thermal Image streaming with Seek Thermal and Flir One devices, experimental SLAM components ORB_SLAM2 and RTABMAP

<img src="" width="100%">
<img src="" width="100%">
