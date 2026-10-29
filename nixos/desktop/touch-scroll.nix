# Pan the scrolling layout with a touchscreen drag.
#
# Hyprland has no touchscreen -> tape scroll: Touch.cpp only focuses and starts
# an edge workspace swipe, and the only tape mover is the touchpad-only
# `scroll_move` gesture. The `move` layout message exists though, so this reads
# the multitouch device passively — no grab, taps still reach Hyprland and apps
# — and turns a one-finger horizontal drag into `hl.dsp.layout("move +N")` on
# Hyprland's command socket. Vertical drags and anything with a second finger
# are left alone so in-app scrolling and pinch still work.
{ pkgs, ... }:
let
  script = pkgs.writeScript "touch-scroll" ''
    #!${pkgs.python3}/bin/python3
    import glob
    import os
    import socket
    import struct
    import sys
    import time

    DEVICE_NAME = "ELAN902C:00 04F3:406B"
    EVENT = struct.Struct("llHHi")  # struct input_event, 64-bit linux
    EV_SYN, EV_ABS = 0, 3
    MT_SLOT, MT_TRACKING_ID, MT_X, MT_Y = 0x2F, 0x39, 0x35, 0x36
    SYN_REPORT = (EV_SYN, 0)

    SCALE = 1.0        # px of tape per px of finger
    H_DEADZONE = 12    # px of travel before a gesture counts as a pan


    def log(msg):
        print(msg, file=sys.stderr, flush=True)


    def find_device():
        """The touchscreen's multitouch node, by name — event numbers move."""
        while True:
            for name in glob.glob("/sys/class/input/event*/device/name"):
                try:
                    if open(name).read().strip() != DEVICE_NAME:
                        continue
                except OSError:
                    continue
                node = "/dev/input/" + name.split("/")[4]
                caps = os.path.join(os.path.dirname(name), "capabilities", "abs")
                try:
                    words = [int(w, 16) for w in open(caps).read().split()]
                except OSError:
                    continue
                # MT_SLOT present == the multitouch node, not the duplicate stubs
                if len(words) > 0 and (words[0] >> MT_SLOT) & 1:
                    return node
            time.sleep(2)


    def find_socket():
        while True:
            paths = glob.glob(os.path.join(os.environ["XDG_RUNTIME_DIR"], "hypr", "*", ".socket.sock"))
            if paths:
                return max(paths, key=os.path.getmtime)
            time.sleep(2)


    def connect():
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.connect(find_socket())
        return sock


    def note_abs(state, code, val):
        if code == MT_SLOT:
            state["cur"] = val
            state["slots"].setdefault(val, [None, None, -1])
            return
        slot = state["slots"].setdefault(state["cur"], [None, None, -1])
        if code == MT_TRACKING_ID:
            slot[2] = val
        elif code == MT_X:
            slot[0] = val
        elif code == MT_Y:
            slot[1] = val


    def active_contacts(state):
        return [(s[0], s[1]) for s in state["slots"].values() if s[2] != -1 and s[0] is not None]


    def gesture_step(state, sock):
        """One SYN_REPORT: decide whether this gesture pans, and by how much."""
        contacts = active_contacts(state)
        if len(contacts) != 1:
            state.update(prev=None, mode=None, acc=[0, 0])
            return sock

        x, y = contacts[0]
        if state["prev"] is None:
            state["prev"] = (x, y)
            return sock

        dx, dy = x - state["prev"][0], y - state["prev"][1]
        state["prev"] = (x, y)
        state["acc"][0] += dx
        state["acc"][1] += dy

        if state["mode"] is None and max(abs(state["acc"][0]), abs(state["acc"][1])) > H_DEADZONE:
            state["mode"] = "pan" if abs(state["acc"][0]) > abs(state["acc"][1]) else "ignore"

        if state["mode"] != "pan" or not dx:
            return sock
        try:
            sock.sendall(('dispatch hl.dsp.layout("move %+d")\n' % int(dx * SCALE)).encode())
        except OSError:
            sock.close()
            sock = connect()
        return sock


    def main():
        dev_path = find_device()
        sock = connect()
        log("touch-scroll: %s -> %s" % (dev_path, sock.getsockname() if sock.getsockname() else "hypr socket"))
        state = {"slots": {}, "cur": 0, "prev": None, "mode": None, "acc": [0, 0]}

        while True:
            try:
                with open(dev_path, "rb") as dev:
                    while True:
                        data = dev.read(EVENT.size)
                        if len(data) != EVENT.size:
                            raise OSError("short read")
                        _s, _us, typ, code, val = EVENT.unpack(data)
                        if typ == EV_ABS:
                            note_abs(state, code, val)
                        elif (typ, code) == SYN_REPORT:
                            sock = gesture_step(state, sock)
            except OSError as exc:
                log("touch-scroll: reopening after %s" % exc)
                time.sleep(2)
                dev_path = find_device()
                sock = connect()


    if __name__ == "__main__":
        main()
  '';
in
{
  home-manager.users.rodrigo.systemd.user.services.touch-scroll = {
    Unit.Description = "Pan the scrolling layout with a touchscreen drag";
    Service = {
      ExecStart = script;
      Restart = "always";
      RestartSec = 2;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
