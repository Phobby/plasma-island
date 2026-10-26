// SPDX-License-Identifier: GPL-2.0-or-later
// Where the island lives: its repository, in one place. A copy published under another name
// changes OWNER and REPOSITORY here; the theme catalog (ThemeFile.js), the version check
// (SelfUpdateProvider.qml) and every "how to install it" link (RequirementCatalog.qml) follow.
// (contents/scripts/island-update.sh and metadata.json carry the address of their own.)
.pragma library

const OWNER = "Phobby";
const REPOSITORY = "plasma-island";
const BRANCH = "main";

// The repository's page, and its files as raw.githubusercontent.com serves them.
const REPO_URL = "https://github.com/" + OWNER + "/" + REPOSITORY;
const RAW_URL = "https://raw.githubusercontent.com/" + OWNER + "/" + REPOSITORY + "/" + BRANCH;
// Where the full installation (with the native module) is explained, and where problems are told.
const INSTALL_URL = REPO_URL + "#installation";
const ISSUES_URL = REPO_URL + "/issues";
// The clone and install, as one line to copy.
const INSTALL_COMMAND = "git clone " + REPO_URL + ".git && cd " + REPOSITORY + " && ./install.sh && systemctl --user restart plasma-plasmashell";
