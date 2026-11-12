
  1. JAIUSB - USB driver for DOS under Jemm

  JAIUSB is a fork of WINUSB, created as a JLM for Jemm. All Windows-specific
  things of WINUSB are removed. USB legacy support in BIOS should be disabled
  for this driver.


  2. Usage

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
  /NORELOC  do not move PCI resources from above 4 GB at boot
  /ALL4G    move every device below 4 GB at boot
  /NOPS2    leave the PS/2 mouse to DOS and the BIOS
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

  4. License

  It's GPL v2, same as WINUSB.
