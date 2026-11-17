
  1. JAIUSB - USB driver for DOS under Jemm

   JAIUSB is a fork of WinUSB, created as a JLM for Jemm. All Windows-specific
  things of WinUSB are removed. 
  


  2. Usage

   USB support for mass storage should be disabled in the BIOS. If the
  so-called "legacy support" is disabled and an USB keyboard is attached,
  be aware that you won't be able to navigate in a GRUB or MS-DOS boot menu,
  since JAIUSB isn't loaded yet.

   The driver consists of 2 parts that must be loaded in CONFIG.SYS:

  DEVICE=JLOAD.EXE JAIUCORE.DLL
  DEVICE=JAIUSB.SYS [Options]

  The lines must be placed behind the line that load Jemm386/JemmEx.


  3. Options for JAIUSB.SYS

  /R:n      drive letters reserved for USB disks (16 at most, default 4)
  /NOMSC    no mass storage
  /NOHID    no keyboard / mouse
  /NOKBC    no 8042 injection in DOS
  /V        verbose
  /D        debug log on
  /COM1     log to COM1
  /S        the driver log is copied to the screen
  /POLL     no controller interrupts, polling only (for IRQ problems)
  /NOPOLL   use controller interrupts, even if they're shared
  /NORELOC  do not move PCI resources from above 4 GB at boot
  /ALL4G    move every device below 4 GB at boot
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
            started


  4. Creating the binaries

   The tools to create the binaries are:

  a) Open Watcom
  b) JWasm
  c) JWlink
  d) h2incX

   Tool h2incX is to be found in the tools directory. It translates file
  winapi.h to winapi.inc, hence it's only needed if file winapi.h has been
  changed.
   Source file jlm/jlment.asm needs file JLM.INC, which is part of Jemm.


  5. License

   It's GPL v3, same as WINUSB.
