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
      quiet      offered only when it was found (no card that says "not found")
      texts      a command's own words: { notice, auth, tools, version, missing }
                 (see AiBackend.noticeText and problemText); Claude Code's are there
      paid       using it may cost money (said on its card)
      keyUrl     where a key is made (shown, opened only when asked)
      prefer     the model taken when the service lists it and none was chosen
      keyCheck   a path that tells whether the key is valid, where the list of
                 models does not
      limitField the name the longest answer is sent under, if not max_tokens
      modelOptional  it has a model of its own choice; one need not be named
      install    the command that installs it (shown to be copied, never run)
      command    its program's name, to tell "not installed" from "not running"
      start      the command that starts it (shown to be copied, never run)
      examples   addresses to go by, for a kind whose server the user names
*/
import QtQuick
import ".."

QtObject {
    property var kinds: ({
        // Claude Code, already signed in on this computer: asked through its command, with every
        // tool switched off (see ClaudeCli.js). `install` is only ever shown, never run.
        "claude-cli": { name: "Claude Code", driver: "ClaudeCliProvider.qml", where: "cli", probe: true, modelOptional: true,
                        install: "curl -fsSL https://claude.ai/install.sh | bash" },
        // Antigravity's command, already signed in on this computer. It cannot be started without
        // its tools: what keeps them unused, and what is not as tight as with Claude Code, is in
        // AntigravityProvider.qml, and the notice says it before the first question.
        "antigravity-cli": { name: "Antigravity", driver: "AntigravityProvider.qml", where: "cli", probe: true, quiet: true, modelOptional: true,
                             command: "agy", texts: {
            notice: Lang.i18n("What you write here is sent to Google, through the Antigravity on this computer and the account it is signed in with. Every question uses up some of that account's usage and is kept in Antigravity's own history. Antigravity cannot be started without its tools: it is stopped the moment it reaches for one."),
            auth: Lang.i18n("Antigravity is not signed in. Run “agy” in a terminal, sign in, then ask again."),
            tools: Lang.i18n("Antigravity reached for a tool. It was stopped at once; this box only takes text answers."),
            version: Lang.i18n("This Antigravity would use its tools without asking, so it is not used."),
            missing: Lang.i18n("Antigravity could not be started.") } },
        // A model on this computer: no account, no key, nothing leaves the device. Ollama is looked
        // for by itself (its command, and whether it answers); it is never started from here.
        "ollama": { name: "Ollama", driver: "OpenAiProvider.qml", where: "device", probe: true, server: "http://localhost:11434/v1",
                    command: "ollama", install: "curl -fsSL https://ollama.com/install.sh | sh", start: "ollama serve" },
        // Other model servers, looked for at the address each one listens on unless told otherwise;
        // offered only while one answers there with a list of models.
        "lmstudio": { name: "LM Studio", driver: "OpenAiProvider.qml", where: "device", probe: true, quiet: true, server: "http://localhost:1234/v1" },
        "llamacpp": { name: "llama.cpp", driver: "OpenAiProvider.qml", where: "device", probe: true, quiet: true, server: "http://127.0.0.1:8080/v1" },
        "jan": { name: "Jan", driver: "OpenAiProvider.qml", where: "device", probe: true, quiet: true, server: "http://localhost:1337/v1" },
        "koboldcpp": { name: "KoboldCpp", driver: "OpenAiProvider.qml", where: "device", probe: true, quiet: true, server: "http://localhost:5001/v1" },
        // Any other server that speaks the OpenAI protocol, at the address the user gives.
        "local": { name: Lang.i18n("Local model server"), driver: "OpenAiProvider.qml", where: "device", needsServer: true,
                   examples: "LM Studio  http://localhost:1234/v1\nllama.cpp  http://127.0.0.1:8080/v1" },
        // Services with a key of the user's own. The addresses were checked against the services
        // themselves (each answers there, and refuses a wrong key) in October 2026.
        "anthropic": { name: "Anthropic API", driver: "AnthropicProvider.qml", where: "remote", key: true, paid: true,
                       server: "https://api.anthropic.com", prefer: "claude-opus-5-5", keyUrl: "https://platform.claude.com/settings/keys" },
        "openai": { name: "OpenAI", driver: "OpenAiProvider.qml", where: "remote", key: true, paid: true,
                    server: "https://api.openai.com/v1", keyUrl: "https://platform.openai.com/account/api-keys" },
        // (its list of models is open to anyone: the key is asked about at /key)
        "openrouter": { name: "OpenRouter", driver: "OpenAiProvider.qml", where: "remote", key: true, paid: true,
                        server: "https://openrouter.ai/api/v1", keyCheck: "/key", keyUrl: "https://openrouter.ai/keys" },
        "groq": { name: "Groq", driver: "OpenAiProvider.qml", where: "remote", key: true, paid: true,
                  server: "https://api.groq.com/openai/v1", keyUrl: "https://console.groq.com/keys" },
        // (Google's OpenAI-compatible address)
        "gemini": { name: "Google Gemini", driver: "OpenAiProvider.qml", where: "remote", key: true, paid: true,
                    server: "https://generativelanguage.googleapis.com/v1beta/openai", keyUrl: "https://aistudio.google.com/apikey" },
        // Any other service that speaks the OpenAI protocol, at the address the user gives.
        "compatible": { name: Lang.i18n("Another service"), driver: "OpenAiProvider.qml", where: "remote", key: true, paid: true, needsServer: true }
    })
    // The order the cards are shown in.
    property var order: ["claude-cli", "antigravity-cli", "ollama", "lmstudio", "llamacpp", "jan", "koboldcpp", "local", "anthropic", "openai", "openrouter", "groq", "gemini", "compatible"]

    function kind(name: string): var { return kinds[name] || null; }
}
