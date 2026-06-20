#!/usr/bin/env python3

import usb.core
import usb.util

USB_ENTRY_OUT = 0x01
USB_ENTRY_IN = 0x82 
CTRL_IN = 0xc0
CTRL_OUT = 0x40
IMG_WIDTH = 80
IMG_HEIGHT = 64

# find our device
dev = usb.core.find(idVendor=0x2df0, idProduct=0x0003)

# was it found?
if dev is None:
	raise ValueError('Device not found')

# set the active configuration. With no arguments, the first
# configuration will be the active one
dev.set_configuration()

# get an endpoint instance
cfg = dev.get_active_configuration()
intf = cfg[(0,0)]

#####################################################
#												   #
#####################################################

# First set of operations
dev.write(USB_ENTRY_OUT, b'\x4f\x80')
dev.ctrl_transfer(CTRL_IN, 204, 0x0000, 0, (0, 0, 0, 0))
dev.ctrl_transfer(CTRL_OUT, 202, 0x0002, 3, ())

dev.write(USB_ENTRY_OUT, b'\xa9\x4f\x80')
dev.ctrl_transfer(CTRL_IN, 204, 0x0000, 0, (0, 0, 0, 0))
dev.ctrl_transfer(CTRL_OUT, 202, 0x0003, 3, ())

dev.write(USB_ENTRY_OUT, b'\xa8\xb9\x00')
dev.read(USB_ENTRY_IN, 67)
dev.ctrl_transfer(CTRL_OUT, 202, 0x0002, 4, ())

dev.write(USB_ENTRY_OUT, b'\xa9\x50\x12\x00')
dev.ctrl_transfer(CTRL_IN, 204, 0x0000, 0, (0, 0, 0, 0))
dev.ctrl_transfer(CTRL_OUT, 202, 0x0002, 4, ())

dev.write(USB_ENTRY_OUT, b'\xa9\x5f\x00\x00')
dev.ctrl_transfer(CTRL_IN, 204, 0x0000, 0, (0, 0, 0, 0))
dev.ctrl_transfer(CTRL_OUT, 202, 0x0002, 4, ())

dev.write(USB_ENTRY_OUT, b'\xa9\x4e\x02\x00')
dev.ctrl_transfer(CTRL_IN, 204, 0x0000, 0, (0, 0, 0, 0))
dev.ctrl_transfer(CTRL_OUT, 202, 0x0002, 4, ())

dev.write(USB_ENTRY_OUT, b'\xa9\x60\x21\x00')
dev.ctrl_transfer(CTRL_IN, 204, 0x0000, 0, (0, 0, 0, 0))
dev.ctrl_transfer(CTRL_OUT, 202, 0x0002, 4, ())

dev.write(USB_ENTRY_OUT, b'\xa9\x61\x70\x00')
dev.ctrl_transfer(CTRL_IN, 204, 0x0000, 0, (0, 0, 0, 0))
dev.ctrl_transfer(CTRL_OUT, 202, 0x0002, 4, ())

dev.write(USB_ENTRY_OUT, b'\xa9\x62\x00\x21')
dev.ctrl_transfer(CTRL_IN, 204, 0x0000, 0, (0, 0, 0, 0))
dev.ctrl_transfer(CTRL_OUT, 202, 0x0002, 4, ())

dev.write(USB_ENTRY_OUT, b'\xa9\x63\x00\x21')
dev.ctrl_transfer(CTRL_IN, 204, 0x0000, 0, (0, 0, 0, 0))
dev.ctrl_transfer(CTRL_OUT, 202, 0x0002, 4, ())

dev.write(USB_ENTRY_OUT, b'\xa9\x64\x04\x08')
dev.ctrl_transfer(CTRL_IN, 204, 0x0000, 0, (0, 0, 0, 0))
dev.ctrl_transfer(CTRL_OUT, 202, 0x0002, 4, ())

dev.write(USB_ENTRY_OUT, b'\xa9\x65\x85\x08')
dev.ctrl_transfer(CTRL_IN, 204, 0x0000, 0, (0, 0, 0, 0))
dev.ctrl_transfer(CTRL_OUT, 202, 0x0002, 4, ())

dev.write(USB_ENTRY_OUT, b'\xa9\x66\x0d\x00')
dev.ctrl_transfer(CTRL_IN, 204, 0x0000, 0, (0, 0, 0, 0))
dev.ctrl_transfer(CTRL_OUT, 202, 0x0002, 4, ())

dev.write(USB_ENTRY_OUT, b'\xa9\x67\x10\x00')
dev.ctrl_transfer(CTRL_IN, 204, 0x0000, 0, (0, 0, 0, 0))
dev.ctrl_transfer(CTRL_OUT, 202, 0x0002, 4, ())

dev.write(USB_ENTRY_OUT, b'\xa9\x68\x00\x0c')
dev.ctrl_transfer(CTRL_IN, 204, 0x0000, 0, (0, 0, 0, 0))
dev.ctrl_transfer(CTRL_OUT, 202, 0x0002, 4, ())

dev.write(USB_ENTRY_OUT, b'\xa9\x68\x00\x0c')
dev.ctrl_transfer(CTRL_IN, 204, 0x0000, 0, (0, 0, 0, 0))
dev.ctrl_transfer(CTRL_OUT, 202, 0x0002, 4, ())

dev.write(USB_ENTRY_OUT, b'\xa9\x6b\x11\x70')
dev.ctrl_transfer(CTRL_IN, 204, 0x0000, 0, (0, 0, 0, 0))
dev.ctrl_transfer(CTRL_OUT, 202, 0x0002, 4, ())

dev.write(USB_ENTRY_OUT, b'\xa9\x6c\x00\x0e')
dev.ctrl_transfer(CTRL_IN, 204, 0x0000, 0, (0, 0, 0, 0))
dev.ctrl_transfer(CTRL_OUT, 202, 0x0002, 4, ())

dev.write(USB_ENTRY_OUT, b'\xa9\x09\x00\x00')
dev.ctrl_transfer(CTRL_IN, 204, 0x0000, 0, (0, 0, 0, 0))
dev.ctrl_transfer(CTRL_OUT, 219, 0x0001, 1, ())
dev.ctrl_transfer(CTRL_IN, 218, 0x00fe, 0, (0, 0x44))
dev.ctrl_transfer(CTRL_IN, 218, 0x00ff, 0, (0, 0))
dev.ctrl_transfer(CTRL_OUT, 202, 0x0002, 4, ())

dev.write(USB_ENTRY_OUT, b'\xa9\x5d\x3d\x00')
dev.ctrl_transfer(CTRL_IN, 204, 0x0000, 0, (0, 0, 0, 0))
dev.ctrl_transfer(CTRL_OUT, 202, 0x0002, 4, ())

dev.write(USB_ENTRY_OUT, b'\xa9\x51\xa8\x01')
dev.ctrl_transfer(CTRL_IN, 204, 0x0000, 0, (0, 0, 0, 0))
dev.ctrl_transfer(CTRL_OUT, 202, 0x0002, 4, ())

dev.write(USB_ENTRY_OUT, b'\xa9\x03\x00')
dev.ctrl_transfer(CTRL_IN, 204, 0x0000, 0, (0, 0, 0, 0))
dev.ctrl_transfer(CTRL_OUT, 202, 0x0002, 4, ())

dev.write(USB_ENTRY_OUT, b'\xa9\x38\x01\x00')
dev.ctrl_transfer(CTRL_IN, 204, 0x0000, 0, (0, 0, 0, 0))
dev.ctrl_transfer(CTRL_OUT, 202, 0x0002, 4, ())

dev.write(USB_ENTRY_OUT, b'\xa9\x10\x60\x00')
dev.ctrl_transfer(CTRL_IN, 204, 0x0000, 0, (0, 0, 0, 0))
dev.ctrl_transfer(CTRL_OUT, 202, 0x0002, 4, ())

dev.write(USB_ENTRY_OUT, b'\xa9\x3b\x14\x00')
dev.ctrl_transfer(CTRL_IN, 204, 0x0000, 0, (0, 0, 0, 0))
dev.ctrl_transfer(CTRL_OUT, 202, 0x0002, 4, ())

dev.write(USB_ENTRY_OUT, b'\xa9\x3d\xff\x0f')
dev.ctrl_transfer(CTRL_IN, 204, 0x0000, 0, (0, 0, 0, 0))
dev.ctrl_transfer(CTRL_OUT, 202, 0x0002, 4, ())

dev.write(USB_ENTRY_OUT, b'\xa9\x26\x30\x00')
dev.ctrl_transfer(CTRL_IN, 204, 0x0000, 0, (0, 0, 0, 0))
dev.ctrl_transfer(CTRL_OUT, 202, 0x0002, 4, ())

dev.write(USB_ENTRY_OUT, b'\xa9\x2f\xf6\xff')
dev.ctrl_transfer(CTRL_IN, 204, 0x0000, 0, (0, 0, 0, 0))
dev.ctrl_transfer(CTRL_OUT, 202, 0x0002, 4, ())

dev.write(USB_ENTRY_OUT, b'\xa9\x09\x00\x00')
dev.ctrl_transfer(CTRL_IN, 204, 0x0000, 0, (0, 0, 0, 0))
dev.ctrl_transfer(CTRL_OUT, 202, 0x0002, 3, ())

dev.write(USB_ENTRY_OUT, b'\xa9\x0c\x00')
dev.ctrl_transfer(CTRL_IN, 204, 0x0000, 0, (0, 0, 0, 0))
dev.ctrl_transfer(CTRL_OUT, 202, 0x0003, 4, ())

dev.write(USB_ENTRY_OUT, b'\xa8\x20\x00\x00')
dev.read(USB_ENTRY_IN, 68)
dev.ctrl_transfer(CTRL_OUT, 219, 0x0007, 0, ())
dev.ctrl_transfer(CTRL_OUT, 202, 0x0002, 3, ())
dev.write(USB_ENTRY_OUT, b'\xa9\x04\x00')
dev.ctrl_transfer(CTRL_IN, 204, 0x0000, 0, (0, 0, 0, 0))

# Initialization done, now wait for finger
print ("Init done")
finger_on_sensor = False
while not finger_on_sensor:
	val = dev.ctrl_transfer(CTRL_IN, 218, 0x0007, 0, 2)
	finger_on_sensor = val[1]

# Give commands to start scanning
print("Finger on sensor")
dev.ctrl_transfer(CTRL_OUT, 202, 0x0003, 3, ())
dev.write(USB_ENTRY_OUT, b'\xa8\x08\x00')
dev.read(USB_ENTRY_IN, 67)
dev.write(USB_ENTRY_OUT, b'\xa9\x09\x00\x00')
dev.ctrl_transfer(CTRL_IN, 204, 0x0000, 0, 4)
dev.ctrl_transfer(CTRL_OUT, 202, 0x0003, 4, ())
dev.write(USB_ENTRY_OUT, b'\xa8\x3e\x00\x00')
dev.read(USB_ENTRY_IN, 68)
dev.ctrl_transfer(CTRL_OUT, 202, 0x0002, 4, ())
dev.write(USB_ENTRY_OUT, b'\xa9\x03\x00\x00')
dev.ctrl_transfer(CTRL_IN, 204, 0x0000, 0, 4)
dev.ctrl_transfer(CTRL_OUT, 202, 0x0003, 4, ())
dev.write(USB_ENTRY_OUT, b'\xa8\x20\x00\x00')
dev.read(USB_ENTRY_IN, 68)
dev.ctrl_transfer(CTRL_OUT, 202, 0x0002, 3, ())
dev.write(USB_ENTRY_OUT, b'\xa9\x0d\x00')
dev.ctrl_transfer(CTRL_IN, 204, 0x0000, 0, 4)
dev.ctrl_transfer(CTRL_OUT, 202, 0x0002, 4, ())
dev.write(USB_ENTRY_OUT, b'\xa9\x10\x00\x01')
dev.ctrl_transfer(CTRL_IN, 204, 0x0000, 0, 4)
dev.ctrl_transfer(CTRL_OUT, 202, 0x0002, 4, ())
dev.write(USB_ENTRY_OUT, b'\xa9\x26\x00\x00')
dev.ctrl_transfer(CTRL_IN, 204, 0x0000, 0, 4)
dev.ctrl_transfer(CTRL_OUT, 202, 0x0002, 4, ())
dev.write(USB_ENTRY_OUT, b'\xa9\x09\x00\x00')
dev.ctrl_transfer(CTRL_IN, 204, 0x0000, 0, 4)
dev.ctrl_transfer(CTRL_OUT, 202, 0x0002, 3, ())
dev.write(USB_ENTRY_OUT, b'\xa9\x0c\x00')
dev.ctrl_transfer(CTRL_IN, 204, 0x0000, 0, 4)
dev.ctrl_transfer(CTRL_OUT, 202, 0x0003, 4, ())
dev.write(USB_ENTRY_OUT, b'\xa8\x20\x00\x00')
dev.read(USB_ENTRY_IN, 68)
dev.ctrl_transfer(CTRL_OUT, 202, 0x0002, 4, ())
dev.write(USB_ENTRY_OUT, b'\xa9\x51\x88\x01')
dev.ctrl_transfer(CTRL_IN, 204, 0x0000, 0, 4)
dev.ctrl_transfer(CTRL_OUT, 202, 0x0002, 4, ())
dev.write(USB_ENTRY_OUT, b'\xa9\x04\x00\x00')
dev.ctrl_transfer(CTRL_IN, 204, 0x0000, 0, 4)
dev.ctrl_transfer(CTRL_OUT, 202, 0x0002, 4, ())
dev.write(USB_ENTRY_OUT, b'\xa9\x09\x00\x00')
dev.ctrl_transfer(CTRL_IN, 204, 0x0000, 0, 4)
dev.ctrl_transfer(CTRL_OUT, 202, 0x0003, 5123, ())
dev.write(USB_ENTRY_OUT, bytearray.fromhex("a8060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"))

print("trying to capture image")

IMAGE_ARRAY = []
for _ in range(0, 19):
	IMAGE_ARRAY.append(dev.read(USB_ENTRY_IN, 320))
	dev.write(USB_ENTRY_OUT, bytearray.fromhex("00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"))
IMAGE_ARRAY.append(dev.read(USB_ENTRY_IN, 320))
dev.ctrl_transfer(CTRL_OUT, 202, 0x0002, 4, ())

dev.write(USB_ENTRY_OUT, b'\xa9\x09\x00\x00')
dev.ctrl_transfer(CTRL_IN, 204, 0x0000, 0, 4)
dev.ctrl_transfer(CTRL_OUT, 202, 0x0003, 4, ())
dev.write(USB_ENTRY_OUT, b'\xa8\x3e\x00\x00')
dev.read(USB_ENTRY_IN, 68)
dev.ctrl_transfer(CTRL_OUT, 202, 0x0003, 4, ())
dev.write(USB_ENTRY_OUT, b'\xa8\x3e\x00\x00')
dev.read(USB_ENTRY_IN, 68)
dev.ctrl_transfer(CTRL_OUT, 202, 0x0002, 3, ())
dev.write(USB_ENTRY_OUT, b'\xa9\x0d\x00')
dev.ctrl_transfer(CTRL_IN, 204, 0x0000, 0, 4)
dev.ctrl_transfer(CTRL_OUT, 202, 0x0001, 0, ())

# Write image
f = open("finger.pgm", 'wb')
f.write(bytearray("P5 "+str(IMG_WIDTH)+" "+str(IMG_HEIGHT)+" 255\n",'utf-8'))
for i in IMAGE_ARRAY:
	f.write(bytearray(i))
f.close()
print("written to finger.pgm")
