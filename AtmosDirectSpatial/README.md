# Atmos Direct Spatial — ADS-v1.0.0

Capture audio on the selected physical output and send its upmix to ten real
Windows spatial audio objects (5.1.4). The audio path does not create another
virtual sound device. Equalizer APO supplies the capture effect; the controller
runs the preserved upmix and spatial renderer in a separate process.

Windows x64, Equalizer APO 1.4.2 x64 and a spatial audio provider on the selected
output are required. Enable the provider that is appropriate for your hardware
before activating the controller. The installer does not install an audio
driver, change the default output or remove VB-CABLE.

The supported content is stereo or 5.1. An eight-channel carrier is accepted
when only one surround pair contains content. Full 7.1 content is passed through
and reported as unsupported by this version.

Extract the whole ZIP and run AtmosDirectSpatialSetup.exe as a normal user.
Select the physical output already associated with Equalizer APO in GFX/EFX.
The Configure Equalizer APO button opens Device Selector to prepare that
association. Use Install, Update installation or Uninstall in the setup.
Removal is also available in Windows Installed apps. If the plugin remains
loaded, close the applications playing audio and retry.
Open the installed controller as a normal user and use its verification action
before playing content. The controller starts with direct audio on each launch.
Its route check requires recent capture and successful object delivery before
allowing temporary suppression of the original audio. Pause returns to direct
audio and closes the objects.

Upgrades and removal preserve the original configuration backup and refuse to
overwrite unrecognized changes. Equalizer APO, its device association and
VB-CABLE are separate components and are not removed by this product.

The upmix derives spatial content from its input. It does not recover the
original authored object metadata of a stereo recording. Bit-identical DSP
results do not establish equal gain, latency or acoustic response through the
entire Windows/driver/hardware chain. See VALIDATION.md for tested scope.

This release uses distinct AtmosDirectSpatial names and ADS tags. Existing
AtmosKeepAlive releases, signatures and updater assets are preserved.
The source is maintained in a private repository; the public distribution
contains runtime files, setup/support scripts and documentation.

No separate LICENSE/COPYING file was present in the supplied source repository.
No replacement license has been invented for this release.
