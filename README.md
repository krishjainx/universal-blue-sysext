# Sysext Toolbox

The Sysext Toolbox is a collection of utilities designed to facilitate the integration of dynamically linked binaries with `systemd-sysext` across various systems.

## Features

- **uhaul.sh**: Utilizes `patchelf` to modify libraries and binaries, creating independent ELF binaries compatible across different distributions and compilation environments. Note: This script is scheduled for deprecation.

## Current Projects

- **OCI-Sysext Integration**: Enhancing the capability of converting OCI images to systemd-sysext format. Current pull requests include:
  - [Patching libraries and binaries](https://github.com/89luca89/oci-sysext/pull/2) (WIP): Addresses segmentation faults due to interpreter issues.
  - [Improving oci-sysext to handle optional image sources](https://github.com/89luca89/oci-sysext/pull/1).

- Basically with oci-sysext -> makes sysexts out of OCI images by creating a raw file with it. we can get the OCI image rootfs, then change all the prefixes for the libraries and binaries in it to something like /usr/sysext/myprefix, and dump the rootfs over to that location in the sysext, thatll make it so the OCI archive turns into a sysext without colliding with the hosts' libraries


A good way to wrap your  head around this is think of it as a go tool (without bash footguns):


```
podman pull cgr.dev/chainguard/wolfi-base
podman run --name my_cool_container cgr.dev/chainguard/wolfi-base
podman stop my_cool_container
podman export my_cool_container -o awesome.tar
mkdir awesomerootfs
tar xf awesome.tar -C awesomerootfs
mkdir awesomerootfs/usr/lib/extension-release.d/extension-release.my_sysext.sysext
cat <<EOF
ID=_any
EXTENSION_RELOAD_MANAGER=1
ARCHITECTURE="x86_64"
EOF > awesomerootfs/usr/lib/extension-release.d/extension-release.my_sysext.sysext
mksquashfs awesomerootfs my_sysext.raw.sysext -root-mode 755 -all-root -no-hardlinks -exit-on-error -progress -action "chmod(755)@true"
mv my_sysext.raw.sysext /var/lib/extensions
systemd-sysext merge
```


Want to deprecate:

- uhaul (go tool)  -> patches binaries so that they will be portable wherever they run. uhaul is now implemented as a script,
- bext (go tool) -> manages sysexts (quite literally a CRUD application) + builds nix-based sysexts. SELinux integration doesn't work. Dealbraker. will be replaced by importctl in systemd 256 + can be a script. its just a CRUD for managing sysexts. let's delete the repo. archive it..  bext does not necessarily use nix, its just a plugin that makes sysexts with nix using the docker.io/library/nixos:latest container. Bext is pretty much just a CRUD and can be easily implemented with some shell scripts, there is no unique thing I cant do without GO or a special app for all the management in bext, I believe it might be kind of useful if  we could integrate other plugins into it (like oci-sysext), but there really is no reason to not just have shell scripts or something simpler for the functionality that it provides. Importctl is pretty much just an implementation detail,
- sysext (bakery) - unnecessary


How Nix works:

- Instead of having everything in /usr, they just put all the data in specific paths in the /nix/store path, and since they dont share any paths with the host system they achieve portability thoughout any distros... and thats pretty much what we want with systemd-sysext(s), right?
- The bext cli just mounts /usr/store through systemd-sysext, bind-mounts that to /nix/store and sets up a custom folder for all the binaries exposed by the nix packages
- And everything seems to work pretty much fine! I tested out many applications like VSCode, Emacs, Vim, and they seem to work fine with that approach
- I believe we could do something similar to that with oci-sysext, by just changing the ELF prefixes for the binaries in the OCIs to something other than the hosts' /usr 
- A lot like nix does with their packages



cc/ @89luca89 @bketelsen @KyleGospo @m2Giles @tulilirockz


