/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The kinds of sources the AI tab can be connected to. Adding one is an
    entry here and, if it speaks a protocol of its own, a file beside this one
    with AiProvider as its root.

      name       shown on its card
      driver     the file of its provider (in this folder)
      where      "cli"     a command on this computer that asks its own service
                 "device"  a model server on this computer: nothing leaves it
                 "remote"  a service on the internet
      key        it needs a key (kept in KDE Wallet, never in the settings)
      server     its address; needsServer = the user gives it
      probe      looked for by itself when the tab has nothing connected
      paid       using it may cost money (said on its card)
      keyUrl     where a key is made (shown, opened only when asked)
*/
import QtQuick
import ".."

QtObject {
    property var kinds: ({})
    // The order the cards are shown in.
    property var order: []

    function kind(name: string): var { return kinds[name] || null; }
}
