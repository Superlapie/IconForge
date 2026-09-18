#!/usr/bin/env python3
"""Small XDND source used by the native GUI E2E test.

It intentionally speaks the X11 drag-and-drop protocol directly so the test
does not call Godot's signal or an internal GUI helper by hand.
"""

from __future__ import annotations

import sys
import time
from pathlib import Path
from urllib.parse import quote

try:
    from Xlib import X, Xatom, display, protocol
    from Xlib.protocol import event
except ImportError as error:  # pragma: no cover - environment diagnostic
    raise SystemExit(
        "GUI_NATIVE_DND_DEPENDENCY_MISSING: install python-xlib for the "
        "native X11 drag/drop proof"
    ) from error


def send_client_message(target, message_type: int, values: list[int]) -> None:
    message = protocol.event.ClientMessage(
        window=target,
        client_type=message_type,
        data=(32, values),
    )
    target.send_event(message, propagate=False)


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: x11-drag-source.py TARGET_WINDOW_ID SOURCE_PATH", file=sys.stderr)
        return 2
    target_id = int(sys.argv[1], 0)
    source_path = Path(sys.argv[2]).resolve()
    if not source_path.is_file():
        print(f"source does not exist: {source_path}", file=sys.stderr)
        return 2

    xdnd_aware = None
    xdnd_type_list = None
    xdnd_selection = None
    xdnd_enter = None
    xdnd_position = None
    xdnd_drop = None
    xdnd_status = None
    xdnd_finished = None
    xdnd_action_copy = None
    uri_atom = None
    utf8_atom = None

    dpy = display.Display()
    root = dpy.screen().root
    target = dpy.create_resource_object("window", target_id)
    xdnd_aware = dpy.intern_atom("XdndAware")
    xdnd_type_list = dpy.intern_atom("XdndTypeList")
    xdnd_selection = dpy.intern_atom("XdndSelection")
    xdnd_enter = dpy.intern_atom("XdndEnter")
    xdnd_position = dpy.intern_atom("XdndPosition")
    xdnd_drop = dpy.intern_atom("XdndDrop")
    xdnd_status = dpy.intern_atom("XdndStatus")
    xdnd_finished = dpy.intern_atom("XdndFinished")
    xdnd_action_copy = dpy.intern_atom("XdndActionCopy")
    uri_atom = dpy.intern_atom("text/uri-list")
    utf8_atom = dpy.intern_atom("UTF8_STRING")

    target_aware = target.get_full_property(xdnd_aware, X.AnyPropertyType)
    if target_aware is None:
        print("target window does not advertise XdndAware", file=sys.stderr)
        return 1

    source = root.create_window(
        0,
        0,
        1,
        1,
        0,
        X.CopyFromParent,
        X.InputOutput,
        X.CopyFromParent,
    )
    source.change_property(xdnd_type_list, Xatom.ATOM, 32, [uri_atom, utf8_atom])
    source.map()
    source.set_selection_owner(xdnd_selection, X.CurrentTime)
    dpy.flush()

    # XDND version 5; bit 0 tells the target to read the offered types from
    # XdndTypeList on the source window.
    send_client_message(target, xdnd_enter, [source.id, (5 << 24) | 1, 0, 0, 0])
    dpy.flush()
    time.sleep(0.05)

    geometry = target.get_geometry()
    translated = target.translate_coords(root, geometry.width // 2, geometry.height // 2)
    root_x, root_y = translated.x, translated.y
    packed_position = ((int(root_x) & 0xFFFF) << 16) | (int(root_y) & 0xFFFF)
    send_client_message(target, xdnd_position, [source.id, 0, packed_position, X.CurrentTime, xdnd_action_copy])
    dpy.flush()
    time.sleep(0.05)
    send_client_message(target, xdnd_drop, [source.id, 0, 0, X.CurrentTime, 0])
    dpy.flush()

    # Godot reads the returned property as a C string, so include the
    # terminator in addition to the XDND-mandated CRLF line ending.
    uri_payload = ("file://" + quote(str(source_path)) + "\r\n\0").encode("utf-8")
    deadline = time.monotonic() + 10.0
    got_request = False
    got_status = False
    got_finished = False
    requested_targets: list[str] = []
    while time.monotonic() < deadline:
        if dpy.pending_events() == 0:
            time.sleep(0.01)
            continue
        received = dpy.next_event()
        if received.type == X.SelectionRequest:
            got_request = True
            requested_targets.append(dpy.get_atom_name(received.target))
            property_atom = received.property if received.property != X.NONE else received.target
            if received.selection == xdnd_selection and received.target in (uri_atom, utf8_atom):
                requestor = dpy.create_resource_object("window", received.requestor)
                requestor.change_property(property_atom, received.target, 8, list(uri_payload))
                notify = event.SelectionNotify(
                    time=received.time,
                    requestor=received.requestor,
                    selection=received.selection,
                    target=received.target,
                    property=property_atom,
                )
                requestor.send_event(notify, propagate=False)
                dpy.flush()
        elif received.type == X.ClientMessage:
            if received.client_type == xdnd_status:
                got_status = True
            elif received.client_type == xdnd_finished:
                got_finished = True
                break

    source.destroy()
    dpy.flush()
    if not got_request:
        print("XDND_SELECTION_REQUEST_MISSING", file=sys.stderr)
        return 1
    if not got_status:
        print("XDND_STATUS_MISSING", file=sys.stderr)
        return 1
    if not got_finished:
        print("XDND_FINISHED_MISSING", file=sys.stderr)
        return 1
    print(f"XDND_PASS status={got_status} selection_request={got_request} finished={got_finished} targets={requested_targets}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
