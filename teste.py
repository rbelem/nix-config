import usb
import usb.core
for dev in usb.core.find(find_all=True):
    print(dev)
