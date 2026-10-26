# URepo ISOs

The purpose of this repository is to build up to date ISOs for some distros on a monthly basis. This is because these distros may not update their official downloads frequently, and having more up to date images can reduce updating friction after a fresh install. 

These distros may be supported by URepo packages, or may not and just be at request of the URepo community for convenience.

Currently builds x86_64 base images for:

- Void Linux (glibc and musl), using [void-mklive](https://github.com/void-linux/void-mklive).
- Chimera Linux, using [chimera-live](https://github.com/chimera-linux/chimera-live).

These use the upstream base image presets. No extra URepo packages are added. Each release includes SHA256 checksums and the upstream tool commit used for each image.

They will always be available for download [here](https://github.com/UniversalRepository/isos/releases/latest).
