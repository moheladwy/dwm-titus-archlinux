#!/usr/bin/env python3
"""Publish a minimal StatusNotifierItem on the session bus for tray tests.

Like many Electron and KDE applications, the item registers with the watcher
once at startup (unless --no-register) and never again, even when the watcher
changes owner. --plain publishes a connection with no item at all.
"""

import argparse
import sys

from gi.repository import Gio, GLib

ITEM_XML = """
<node>
  <interface name="org.kde.StatusNotifierItem">
    <property name="Category" type="s" access="read"/>
    <property name="Id" type="s" access="read"/>
    <property name="Title" type="s" access="read"/>
    <property name="Status" type="s" access="read"/>
    <property name="IconName" type="s" access="read"/>
    <property name="ItemIsMenu" type="b" access="read"/>
    <method name="Activate"><arg name="x" type="i" direction="in"/><arg name="y" type="i" direction="in"/></method>
  </interface>
</node>
"""


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--id", required=True)
    parser.add_argument("--name", help="well-known bus name to own")
    parser.add_argument("--no-register", action="store_true")
    parser.add_argument("--plain", action="store_true")
    parser.add_argument("--ready", required=True, help="file that receives the unique name")
    args = parser.parse_args()

    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    if not args.plain:
        values = {
            "Category": GLib.Variant("s", "ApplicationStatus"),
            "Id": GLib.Variant("s", args.id),
            "Title": GLib.Variant("s", args.id),
            "Status": GLib.Variant("s", "Active"),
            "IconName": GLib.Variant("s", "application-x-executable"),
            "ItemIsMenu": GLib.Variant("b", False),
        }
        interface = Gio.DBusNodeInfo.new_for_xml(ITEM_XML).interfaces[0]
        bus.register_object(
            "/StatusNotifierItem",
            interface,
            lambda *call: call[-1].return_value(None),
            lambda _c, _s, _p, _i, prop: values.get(prop),
            None,
        )
    if args.name:
        result = bus.call_sync(
            "org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus",
            "RequestName", GLib.Variant("(su)", (args.name, 4)),
            GLib.VariantType("(u)"), Gio.DBusCallFlags.NONE, -1, None)
        if result.unpack()[0] != 1:
            sys.exit("could not own " + args.name)
    if not args.plain and not args.no_register:
        bus.call_sync(
            "org.kde.StatusNotifierWatcher", "/StatusNotifierWatcher",
            "org.kde.StatusNotifierWatcher", "RegisterStatusNotifierItem",
            GLib.Variant("(s)", (args.name or bus.get_unique_name(),)),
            None, Gio.DBusCallFlags.NONE, -1, None)
    with open(args.ready, "w", encoding="utf-8") as ready:
        ready.write(bus.get_unique_name() + "\n")
    GLib.MainLoop().run()


if __name__ == "__main__":
    main()
