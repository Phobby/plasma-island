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
      modelOptional  it has a model of its own choice; one need not be named
      install    the command that installs it (shown to be copied, never run)
*/
import QtQuick
import ".."

QtObject {
    property var kinds: ({
        // Claude Code, already signed in on this computer: asked through its command, with every
        // tool switched off (see ClaudeCli.js). `install` is only ever shown, never run.
        "claude-cli": { name: "Claude Code", driver: "ClaudeCliProvider.qml", where: "cli", probe: true, modelOptional: true,
                        install: "curl -fsSL https://claude.ai/install.sh | bash" }
    })
    // The order the cards are shown in.
    property var order: ["claude-cli"]

    function kind(name: string): var { return kinds[name] || null; }
}
