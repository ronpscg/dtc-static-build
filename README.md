# dtc (Device Tree Compiler) static executables and a script to build them

All works well and checks out, very easy to follow. Did not invest too much effort on it, sort of combined the other static build projects, and code from PscgBuildOS
This is different than most of the other builds, as it uses Meson.

Supported archs:
- x86_64
- i686
- aarch64
- arm
- armhf
- riscv64
- loongarch64

## Notes about i386
Only cross compiling, not doing the -m32 thing
