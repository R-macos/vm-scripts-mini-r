## VM Scripts

This repository contains a sample setup to illustrate how to
build R unattended using
[macosvm](https://github.com/s-u/macosvm).

### Initial setup

In the following we assume that your working directory is inside the
checkout of this repository and that you have downloaded `macosvm`
(see [macosvm releases](https://github.com/s-u/macosvm/releases))
and put it on your `PATH`.

First, you have to create a VM with your base macOS and
Command Line Tools. Most of this is described in the README of
[macosvm](https://github.com/s-u/macosvm), but here is the short
version:

1. Download the restore image for the macOS version you want to use.
   Note that is must be __same or lower__ than your host macOS version.
   For example, for macOS 14 (Sonoma) you can use
   
   ```
   curl -LO https://updates.cdn-apple.com/2024SummerFCS/fullrestores/062-52859/932E0A8F-6644-4759-82DA-F8FA8DEA806A/UniversalMac_14.6.1_23G93_Restore.ipsw
   ```

2. Restore the macOS into a new disk image:
   ```
   macosvm --disk disk.img,size=64g --aux aux.img \
     --restore UniversalMac_14.6.1_23G93_Restore.ipsw vm.json
   ```
   (You can prepend e.g. `-c6 -r8g` if you want to increase the number of
   cores to 6 and use 8Gb of RAM). The important part here is that the
   settings will be stored in the `vm.json` file.

3. Boot the new VM with GUI:
   ```
   macosvm -g vm.json
   ```
   Follow the Apple Setup Assistant and make sure you use the following
   (unless you want to change the scripts):
   1. create user with login `rbuild`
   2. once the setup is complete enable ssh ("System Settings" -> "Remote Login").
      It is typically wise to also enable "Screen Sharing" (makes administration
      easier, but the scripts don't care).
   3. install developer command line tools by opening the Terminal and typing:
      ```
      xcode-select --install
      ```
      and follow the on-screen instructions. You can check that they work e.g. by typing `make`.
   4. You can enable passwordless `sudo` for admins by typing the following in Terminal:
      ```
      sudo bash -c "echo '%admin ALL = (ALL) NOPASSWD: ALL' > /etc/sudoers.d/10admins"
      ```
      You will need this if you want the scripts to be fully autonomous.
   5. Add your ssh public key from your host user account to `~/.ssh/authorized_keys` on
      the VM so you can `ssh` into the VM without password.
    
  Once you're done with the setup, you can shutdown the VM (either from the top-left menu
  or with `sudo shutdown -h now` in Terminal).

### Testing

At this point you should have a nice, clean macOS VM image that can be used. You can test it by
running:

```
macosvm --ephemeral --script ./launch.sh vm.json
```

(or `./run.sh`) You should see it booting up something like this:

```
2025-11-05 19:46:44.331 macosvm[66388:4542531]  . cloning disk.img to ephemeral disk.img-clone-66388
2025-11-05 19:46:44.332 macosvm[66388:4542531]  . cloning aux.img to ephemeral aux.img-clone-66388
2025-11-05 19:46:44.374 macosvm[66388:4542531] Creating instance ...
[...]
2025-11-05 19:46:55.285 macosvm[66409:4542793] start completed err=nil
Waiting for IP address of 8a:2b:c2:9a:e2:ed.......

ssh -o StrictHostKeyChecking=accept-new rbuild@192.168.64.2
```

The last part is the `launch.sh` script telling you how to `ssh` into the newly created instance.
By adding `--ephemeral` we make sure that this is a throw-away instrance, i.e. all changes
will be discarded once the VM is shut down. Run the displayed `ssh` command on your host to login
into the VM. If you setup things correctly, it should give you a shell prompt inside the VM.
If it asks for a password, then you didn't create `~/.ssh/authorized_keys` properly in the VM
(to fix it, run `macosvm` without `--ephemeral` or `./run.sh -p`).
You can then shut down the VM with `sudo shutdown -h now`.

Note that you can always shutdown the VM ungracefully by pressing `<Ctrl><C>` in the Terminal
window on the host that launched `macosvm`.

### Build environment

TLDR; If you just want to run the build, skip this and read the next section.

The builds use one addtional feature of `macosvm` which is the ability to mount directories
on the host as volumes inside the VM. The script uses `--vol "$(pwd)/shared",automount` to
mount the `shared` directory as `/Volumes/My Shared Files` volume inside the VM. The
`setup.sh` script in the `shared` directory then sets up the system environment to include
all necessary pieces such as XQuartz, GNU Fortran, dependent libraries etc. Since the
volume is mounted, it allows even ephemeral VMs to pick up content and leave results
in the mounted volume. The `setup.sh` script caches downloaded content to speed up
installation in the next run.

If you plan to use the same tools more often, you can drop the `--ephemeral` flag, then
just run `setup.sh` inside the VM with the volume mounted and shut down the VM.
Subsequent runs will then already have the tools in the `disk.img`.

Finally, note that you can keep both a clean image and an image with tools around by first
creating a copy with
```
cp -c disk.img disk-clean.img
```
and then running the VM without `--ephemeral` to create a version of `disk.img` with
the tools. The `-c` flags tells `cp` to make a "clone" which is a "virtual" copy that
does not use any addtional space (at least on APFS), but won't change even if the
original file changes. You can roll back to the clean state if desired by using
`cp -c disk-clean.img disk.img`.

### Running the build

If all went well then you can run the build simply with
```
./run-build.sh
```
It mounts the `shared` directory as a volume in the VM, starts an ephemeral VM (i.e.,
it clones `disk.img` for the duration of the VM execution and removes it afterwards),
and when it is up starts `launch-build.sh` which waits until the VM is visible on
the network and the uses `ssh` to log into it to start the `run-arm64.sh` to call
`build.sh`. Note that passworless `ssh` from the host must work for this (see 3.v.
above).

The actual script that will be run on the VM is the one in `shared/build.sh` so
you can edit it as needed. It calls the `shared/setup.sh` script to setup the enviroment
first, then checks if the R sources are in `shared/R` (if not, it uses `svn` to
check out R-devel) and builds those with `make dist` in the `R-build-<ts>` directory,
copuing the resulting tar ball into `shared` on the host.
