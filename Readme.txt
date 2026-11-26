
  1. About JAIUSB
  
    JAIUSB is a USB driver for DOS, a fork of WinUSB. It needs Jemm386/JemmEx
   to run, since it's a so-called Jemm Loadable Module (JLM). Compared to
   WinUSB, there are the following benefits:

   - the driver runs in the memory context of Jemm, while WinUSB runs
     as VCPI client in another context; memory context switching requires
     CPU time.
   - while waiting for a device, JAIUSB is able to callout to v86-mode;
     no timer interrupts will get lost.
   - DOS conventional memory usage is significantly reduced to about 2.5 kb.
   - for JLM there exist a PL0 debugger, so JAIUSB can be easily debugged
     in case of problems.


  2. Installation

   The driver consists of 2 parts that must be loaded in CONFIG.SYS:

  DEVICE=JLOAD.EXE JAIUCORE.DLL
  DEVICE=JAIUSB.SYS [Options]

  The lines must be placed behind the line that loads Jemm386/JemmEx.


  3. Commandline Options for JAIUSB.SYS

  /R:n      drive letters reserved for USB disks (16 at most). If this
            option isn't given, 2 drive letters are reserved, but may
            increase if more disks are attached.
  /NOMSC    disables mass storage support
  /NOHID    no keyboard / mouse support
  /NOKBC    no 8042 injection in DOS; should be set if a PS/2 keyboard
            is attached, but unable to send key codes.
  /V        verbose
  /D        debug log on
  /COM1     log to COM1
  /S        the driver log is copied to the screen
  /POLL     no controller interrupts, polling only (for IRQ problems)
  /NOPOLL   controllers will use interrupts, even if they're shared. In this
            mode JAIUSB will use less CPU resources; IOW, if no problems
            arise with this setting, it's the recommended one.
  /NORELOC  do not move PCI resources from above 4 GB at boot
  /ALL4G    move every PCI device below 4 GB at boot
  /NOXHCI   leave controllers of that kind to the BIOS
  /NOEHCI   leave controllers of that kind to the BIOS
  /NOOHCI   leave controllers of that kind to the BIOS
  /NOUHCI   leave controllers of that kind to the BIOS 
  /NOROUTE  do not route the EHCI ports to xHCI on Intel 7 / 8 / 9 series
  /NOI2C    no I2C touchpads / touch screens
  /NOTP     PS/2 touchpads stay in their mouse mode, no SMBus
  /NOSMB    touchpads on PS/2 only, not on SMBus
  /NOTB     no USB4 / Thunderbolt host support
  /NOTBPCIE no PCIe tunnels (no NVMe and dock xHCI, USB3 only)
  /NOTBUSB  no USB3 tunnels on USB4 links
  /PCIHP    watch every hot-plug capable PCIe port, Thunderbolt or not
            (ExpressCard, PCIe slots)
  /NVME
  /NONVME   NVMe controllers behind tunnels: also take over the one the BIOS
            started.


  4. Hints

   If USB support for mass storage is enabled in the BIOS, JAIUSB will
  adopt the drive letters of the USB disks mounted by the BIOS. Hot-plugin
  won't work for such disks. OTOH, the drives are known to disk interrupt 13h,
  so FDISK will see them and they can be partitioned.
   DOS sees "BIOS disks" as fixed disks - so one should be aware that, as
  default, MS SmartDrive will cache both read and write accesses. 

   If the so-called "legacy support" is disabled and no PS/2 keyboard is
  attached, be aware that you won't be able to navigate in a GRUB or MS-DOS
  boot menu, since USB keyboards will work only after JAIUSB has been loaded.

   Partitions that DOS cannot handle ( NTFS, exFAT ) get a drive letter. DOS
  will see them as a tiny FAT16 readonly disk, the label will tell the file
  system.


  5. JAIInfo

   This tool displays JAIUSB's current status. It may also be used for a
   "safe" removal of USB sticks. Run "jaiinfo -?" to see its options.


  6. Creating the binaries

   The tools to create the binaries are:

  a) Open Watcom
  b) JWasm
  c) JWlink
  d) h2incX

   Tool h2incX is to be found in the tools directory. It translates file
  winapi.h to winapi.inc, hence it's only needed if file winapi.h has been
  changed. It's a Win32 binary, but may run in DOS with the help of the HX
  DOS extender.


  7. License

   It's GPL v3, same as WinUSB.

