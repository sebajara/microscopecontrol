# Overview

This is an example script for doing some simple general operations to
control a microscope via MicroManager within MATLAB. You may need to
adjust the naming of filters and illumination settings. Also our
brightfield illumination was controlled via a National Intrument, so the
commands are unlikely to be applicable. However I left it here in case
someone finds it useful.

The main script with examples are in [examples.m](examples.m). Also in
[livecontrol_aux.m](livecontrol_aux.m) is an auxiliary function for
doing LIVE imagining using a MATLAB figure and MATLAB timers.

## Intructions
* Install Micro-manager and set it up to recognize you microscope
  devices. Get the location of the most current configuration file.
* Install MATLAB. Check which version is supported to be interfaced with MicroManager.
* Check the configuration file for the naming of filter and illumination settings.

## Current setup:
The scripts were made for the following Microscopy settings: Nikon Ti-E
inverted microscope, a SpectraX Line engine (Lumencor), National
Instrument controlling Brightfield Illumination.


## Useful reasorces online
 * General intro [Micro-Manager_Programming_Guide](https://micro-manager.org/wiki/Micro-Manager_Programming_Guide)
 * Useful collection of scripts [Example_Beanshell_scripts](https://micro-manager.org/wiki/Example_Beanshell_scripts)
 * On Nikon perfect focus [Nikon-TI-Matlab](http://micro-manager.3463995.n2.nabble.com/Nikon-TI-Perfect-Focus-control-via-MATLAB-td7582188.html)
 * On saving log in OMERO format [Matlab-OMERO](https://gist.github.com/bramalingam/1d36f827add8f5342068)
