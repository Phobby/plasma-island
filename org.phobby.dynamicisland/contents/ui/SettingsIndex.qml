/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Every setting of the settings window, for its search (SettingsSearch):
    where it is (page, folding part), its name, and the switch that shows it
    when it is only there while that is on (needs).

    Made by tools/settings-index from the pages: do not change it by hand
    (tools/run-tests fails while it differs from what the pages say).
*/
pragma Singleton
import QtQuick

QtObject {
    id: index

    // The pages, by file, with the names of the sidebar.
    readonly property var pages: ({
        configGeneral: Lang.i18n("General"),
        configAppearance: Lang.i18n("Appearance"),
        configLayout: Lang.i18n("Tabs"),
        configActivities: Lang.i18n("Activities"),
        configWeather: Lang.i18n("Weather"),
        configControls: Lang.i18n("Controls"),
        configTools: Lang.i18n("Tools"),
        configHabits: Lang.i18n("Habits"),
        configCalendar: Lang.i18n("Calendar"),
        configNotes: Lang.i18n("Notes"),
        configAi: Lang.i18n("AI"),
        configCloud: Lang.i18n("Cloud"),
        configCat: Lang.i18n("Cat"),
        configSuggestions: Lang.i18n("Suggestions"),
        configDiagnostics: Lang.i18n("Diagnostics")
    })
    readonly property var entries: [
        { key: "language", page: "configGeneral", label: Lang.i18n("Language:"), context: "", fold: "", needs: "" },
        { key: "showClock", page: "configGeneral", label: Lang.i18n("Show clock"), context: Lang.i18n("Idle:"), fold: "", needs: "" },
        { key: "clockFormat", page: "configGeneral", label: Lang.i18n("Time format:"), context: "", fold: "", needs: "" },
        { key: "showNotifications", page: "configGeneral", label: Lang.i18n("Show incoming notifications in the island"), context: Lang.i18n("Notifications:"), fold: "", needs: "" },
        { key: "response", page: "configGeneral", label: Lang.i18n("Response:"), context: "", fold: "", needs: "" },
        { key: "hoverDelay", page: "configGeneral", label: Lang.i18n("Expand after hovering:"), context: "", fold: Lang.i18n("Customize"), needs: "" },
        { key: "collapseDelay", page: "configGeneral", label: Lang.i18n("Collapse after leaving:"), context: "", fold: Lang.i18n("Customize"), needs: "" },
        { key: "eventDuration", page: "configGeneral", label: Lang.i18n("Transient events stay:"), context: "", fold: Lang.i18n("Customize"), needs: "" },
        { key: "notificationDuration", page: "configGeneral", label: Lang.i18n("Notifications stay:"), context: "", fold: Lang.i18n("Customize"), needs: "" },
        { key: "dotMode", page: "configGeneral", label: Lang.i18n("A click shrinks the island to a dot"), context: Lang.i18n("Click:"), fold: "", needs: "" },
        { key: "dotStart", page: "configGeneral", label: Lang.i18n("Start as:"), context: "", fold: Lang.i18n("Dot mode details"), needs: "dotMode" },
        { key: "dotSize", page: "configGeneral", label: Lang.i18n("Dot size:"), context: "", fold: Lang.i18n("Dot mode details"), needs: "dotMode" },
        { key: "dotHoverExpand", page: "configGeneral", label: Lang.i18n("Opens the island"), context: Lang.i18n("Hovering the dot:"), fold: Lang.i18n("Dot mode details"), needs: "dotMode" },
        { key: "dotEvents", page: "configGeneral", label: Lang.i18n("Events in dot mode:"), context: "", fold: Lang.i18n("Dot mode details"), needs: "dotMode" },
        { key: "dotCriticalExpand", page: "configGeneral", label: Lang.i18n("Always open for critical events (incoming call, alarm, low battery)"), context: "", fold: Lang.i18n("Dot mode details"), needs: "dotMode" },
        { key: "updateMode", page: "configGeneral", label: Lang.i18n("When there is one:"), context: "", fold: "", needs: "" },
        { key: "preferredPlayer", page: "configGeneral", label: Lang.i18n("Preferred player:"), context: "", fold: Lang.i18n("Details"), needs: "" },
        { key: "islandLayout", page: "configAppearance", label: Lang.i18n("Layout:"), context: "", fold: "", needs: "" },
        { key: "topMargin", page: "configAppearance", label: Lang.i18n("Distance from top:"), context: "", fold: "", needs: "islandLayout" },
        { key: "avoidPanels", page: "configAppearance", label: Lang.i18n("Place below top panels"), context: "", fold: "", needs: "islandLayout" },
        { key: "appearanceMode", page: "configAppearance", label: Lang.i18n("Look:"), context: "", fold: "", needs: "" },
        { key: "followSource", page: "configAppearance", label: Lang.i18n("Colours from:"), context: "", fold: "", needs: "" },
        { key: "look.scale", page: "configAppearance", label: Lang.i18n("Size:"), context: "", fold: "", needs: "" },
        { key: "look.opacity", page: "configAppearance", label: Lang.i18n("Opacity:"), context: "", fold: "", needs: "" },
        { key: "look.preset", page: "configAppearance", label: Lang.i18n("Ready-made looks"), context: "", fold: "", needs: "" },
        { key: "look.profile", page: "configAppearance", label: Lang.i18n("Profile:"), context: "", fold: Lang.i18n("Saved looks"), needs: "appearanceMode" },
        { key: "look.blur", page: "configAppearance", label: Lang.i18n("Blur:"), context: "", fold: Lang.i18n("Fine tuning"), needs: "" },
        { key: "look.offsetX", page: "configAppearance", label: Lang.i18n("Horizontal position:"), context: "", fold: Lang.i18n("Fine tuning"), needs: "" },
        { key: "look.radius", page: "configAppearance", label: Lang.i18n("Corner roundness:"), context: "", fold: Lang.i18n("Fine tuning"), needs: "" },
        { key: "look.background", page: "configAppearance", label: Lang.i18n("Background:"), context: "", fold: Lang.i18n("Fine tuning"), needs: "" },
        { key: "look.gradient", page: "configAppearance", label: Lang.i18n("Gradient colours:"), context: "", fold: Lang.i18n("Fine tuning"), needs: "" },
        { key: "look.control", page: "configAppearance", label: Lang.i18n("Buttons and controls:"), context: "", fold: Lang.i18n("Fine tuning"), needs: "" },
        { key: "look.buttonFill", page: "configAppearance", label: Lang.i18n("Button colour:"), context: "", fold: Lang.i18n("Fine tuning"), needs: "" },
        { key: "look.text", page: "configAppearance", label: Lang.i18n("Text colour:"), context: "", fold: Lang.i18n("Fine tuning"), needs: "" },
        { key: "look.border", page: "configAppearance", label: Lang.i18n("Border:"), context: "", fold: Lang.i18n("Fine tuning"), needs: "" },
        { key: "look.shadow", page: "configAppearance", label: Lang.i18n("Shadow:"), context: "", fold: Lang.i18n("Fine tuning"), needs: "" },
        { key: "notchColor", page: "configAppearance", label: Lang.i18n("Colour:"), context: "", fold: "", needs: "" },
        { key: "notchScreen", page: "configAppearance", label: Lang.i18n("Screen:"), context: "", fold: "", needs: "" },
        { key: "notchMaxWidth", page: "configAppearance", label: Lang.i18n("Width:"), context: "", fold: "", needs: "" },
        { key: "notchBorderEnabled", page: "configAppearance", label: Lang.i18n("Show an edge around the notch"), context: Lang.i18n("Notch border:"), fold: Lang.i18n("Notch details"), needs: "" },
        { key: "notchBorderWidth", page: "configAppearance", label: Lang.i18n("Border thickness:"), context: "", fold: Lang.i18n("Notch details"), needs: "notchBorderEnabled" },
        { key: "notchBorderColor", page: "configAppearance", label: Lang.i18n("Border colour:"), context: "", fold: Lang.i18n("Notch details"), needs: "notchBorderEnabled" },
        { key: "notchBorderOpacity", page: "configAppearance", label: Lang.i18n("Border opacity:"), context: "", fold: Lang.i18n("Notch details"), needs: "notchBorderEnabled" },
        { key: "notchEars", page: "configAppearance", label: Lang.i18n("Soften where it meets the edge (small curves outwards)"), context: Lang.i18n("Upper corners:"), fold: Lang.i18n("Notch details"), needs: "" },
        { key: "notchHeightMode", page: "configAppearance", label: Lang.i18n("Height:"), context: "", fold: Lang.i18n("Notch details"), needs: "" },
        { key: "notchHeight", page: "configAppearance", label: Lang.i18n("Height:"), context: "", fold: Lang.i18n("Notch details"), needs: "notchHeightMode" },
        { key: "notchOpenWidth", page: "configAppearance", label: Lang.i18n("Open it as wide too, where that is wider than the open island"), context: Lang.i18n("When open:"), fold: Lang.i18n("Notch details"), needs: "" },
        { key: "notchDodgeWindows", page: "configAppearance", label: Lang.i18n("Also for a window that reaches under it (moved up to the edge)"), context: Lang.i18n("Full screen:"), fold: Lang.i18n("Notch details"), needs: "" },
        { key: "notchDodgeSize", page: "configAppearance", label: Lang.i18n("Size there:"), context: "", fold: Lang.i18n("Notch details"), needs: "" },
        { key: "notchDodgeWidth", page: "configAppearance", label: Lang.i18n("Width there:"), context: "", fold: Lang.i18n("Notch details"), needs: "" },
        { key: "notchHideCat", page: "configAppearance", label: Lang.i18n("Hide the cat in the notch layout"), context: Lang.i18n("Cat:"), fold: Lang.i18n("Notch details"), needs: "catEnabled" },
        { key: "fullscreenMode", page: "configAppearance", label: Lang.i18n("In full screen, the island:"), context: "", fold: "", needs: "" },
        { key: "peekMaximized", page: "configAppearance", label: Lang.i18n("For maximised windows"), context: Lang.i18n("Also:"), fold: "", needs: "" },
        { key: "peekIdle", page: "configAppearance", label: Lang.i18n("On the desktop when nothing is going on, after"), context: "", fold: "", needs: "" },
        { key: "peekIdleDelay", page: "configAppearance", label: Lang.i18n("Waiting time on the desktop"), context: "", fold: "", needs: "peekIdle" },
        { key: "peekSize", page: "configAppearance", label: Lang.i18n("Part that shows:"), context: "", fold: Lang.i18n("Full-screen details"), needs: "" },
        { key: "peekDelay", page: "configAppearance", label: Lang.i18n("Opens after:"), context: "", fold: Lang.i18n("Full-screen details"), needs: "" },
        { key: "peekWidth", page: "configAppearance", label: Lang.i18n("Trigger width:"), context: "", fold: Lang.i18n("Full-screen details"), needs: "" },
        { key: "peekEvents", page: "configAppearance", label: Lang.i18n("Open in full screen too, for an incoming call"), context: Lang.i18n("Important events:"), fold: Lang.i18n("Full-screen details"), needs: "" },
        { key: "pageOrder", page: "configLayout", label: Lang.i18n("Tabs"), context: "", fold: "", needs: "" },
        { key: "showVolumeModule", page: "configLayout", label: Lang.i18n("Volume"), context: "", fold: "", needs: "" },
        { key: "systemView", page: "configLayout", label: Lang.i18n("System view:"), context: "", fold: "", needs: "" },
        { key: "splitIsland", page: "configActivities", label: Lang.i18n("Show a second activity in a separate bubble"), context: Lang.i18n("Split island:"), fold: "", needs: "" },
        { key: "keepMediaVisible", page: "configActivities", label: Lang.i18n("Keep playing media visible (album art takes the bubble if needed)"), context: "", fold: "", needs: "splitIsland" },
        { key: "trackDownloads", page: "configActivities", label: Lang.i18n("Show downloads that have no window of their own"), context: Lang.i18n("Download tracking:"), fold: "", needs: "" },
        { key: "showPowerEvents", page: "configActivities", label: Lang.i18n("Charging, battery and power profile"), context: Lang.i18n("System events"), fold: Lang.i18n("Events shown"), needs: "" },
        { key: "showBluetoothEvents", page: "configActivities", label: Lang.i18n("Bluetooth devices"), context: "", fold: Lang.i18n("Events shown"), needs: "" },
        { key: "showOsdEvents", page: "configActivities", label: Lang.i18n("Volume, brightness and audio output"), context: "", fold: Lang.i18n("Events shown"), needs: "" },
        { key: "showKeyboardEvents", page: "configActivities", label: Lang.i18n("Caps Lock, Num Lock and keyboard layout"), context: "", fold: Lang.i18n("Events shown"), needs: "" },
        { key: "showNetworkEvents", page: "configActivities", label: Lang.i18n("Wi-Fi, VPN and hotspot"), context: "", fold: Lang.i18n("Events shown"), needs: "" },
        { key: "showDndEvents", page: "configActivities", label: Lang.i18n("Do Not Disturb"), context: "", fold: Lang.i18n("Events shown"), needs: "" },
        { key: "showUnlock", page: "configActivities", label: Lang.i18n("\"Unlocked\" after the screen is unlocked"), context: "", fold: Lang.i18n("Events shown"), needs: "" },
        { key: "showThermalWarning", page: "configActivities", label: Lang.i18n("High temperature warning"), context: "", fold: Lang.i18n("Events shown"), needs: "" },
        { key: "showUpdates", page: "configActivities", label: Lang.i18n("Available updates"), context: "", fold: Lang.i18n("Events shown"), needs: "" },
        { key: "showRecording", page: "configActivities", label: Lang.i18n("Screen recording / sharing"), context: Lang.i18n("Live activities"), fold: Lang.i18n("Events shown"), needs: "" },
        { key: "showPrivacy", page: "configActivities", label: Lang.i18n("Microphone and camera indicators"), context: "", fold: Lang.i18n("Events shown"), needs: "" },
        { key: "showJobs", page: "configActivities", label: Lang.i18n("File transfers (Dolphin, KDE Connect, USB drives, downloads)"), context: "", fold: Lang.i18n("Events shown"), needs: "" },
        { key: "showKdeConnect", page: "configActivities", label: Lang.i18n("KDE Connect (calls, phone battery)"), context: "", fold: Lang.i18n("Events shown"), needs: "" },
        { key: "enableDbusApi", page: "configActivities", label: Lang.i18n("Activities from other programs (D-Bus, island-push)"), context: "", fold: Lang.i18n("Events shown"), needs: "" },
        { key: "priorityOrder", page: "configActivities", label: Lang.i18n("Highest first:"), context: "", fold: Lang.i18n("Priority"), needs: "" },
        { key: "lowBatteryThreshold", page: "configActivities", label: Lang.i18n("Low battery warning at:"), context: "", fold: Lang.i18n("Warning thresholds"), needs: "" },
        { key: "criticalBatteryThreshold", page: "configActivities", label: Lang.i18n("Critical warning at:"), context: "", fold: Lang.i18n("Warning thresholds"), needs: "" },
        { key: "deviceBatteryThreshold", page: "configActivities", label: Lang.i18n("Bluetooth device / phone low at:"), context: "", fold: Lang.i18n("Warning thresholds"), needs: "" },
        { key: "cpuTempThreshold", page: "configActivities", label: Lang.i18n("Warn when the CPU reaches:"), context: "", fold: Lang.i18n("Warning thresholds"), needs: "" },
        { key: "gpuTempThreshold", page: "configActivities", label: Lang.i18n("Warn when the GPU reaches:"), context: "", fold: Lang.i18n("Warning thresholds"), needs: "" },
        { key: "watchDownloads", page: "configActivities", label: Lang.i18n("Browser downloads (the download folder)"), context: Lang.i18n("Show:"), fold: Lang.i18n("Download tracking details"), needs: "trackDownloads" },
        { key: "trackPackages", page: "configActivities", label: Lang.i18n("Packages (apt, Discover / PackageKit)"), context: "", fold: Lang.i18n("Download tracking details"), needs: "trackDownloads" },
        { key: "trackGit", page: "configActivities", label: Lang.i18n("git clone"), context: "", fold: Lang.i18n("Download tracking details"), needs: "trackDownloads" },
        { key: "trackTools", page: "configActivities", label: Lang.i18n("Command-line downloaders (wget, curl, pip…)"), context: "", fold: Lang.i18n("Download tracking details"), needs: "trackDownloads" },
        { key: "trackBackground", page: "configActivities", label: Lang.i18n("Also what runs in the background (automatic updates, scripts without a terminal)"), context: "", fold: Lang.i18n("Download tracking details"), needs: "trackDownloads" },
        { key: "trackMinSeconds", page: "configActivities", label: Lang.i18n("Shown once it has lasted:"), context: "", fold: Lang.i18n("Download tracking details"), needs: "trackDownloads" },
        { key: "trackMinKilobytes", page: "configActivities", label: Lang.i18n("Command-line downloads from:"), context: "", fold: Lang.i18n("Download tracking details"), needs: "trackDownloads" },
        { key: "trackAnnounceEnd", page: "configActivities", label: Lang.i18n("Say so (\"Downloaded\", with the name, the size and the time it took)"), context: Lang.i18n("When it ends:"), fold: Lang.i18n("Download tracking details"), needs: "trackDownloads" },
        { key: "trackFolders", page: "configActivities", label: Lang.i18n("Watched folders:"), context: "", fold: Lang.i18n("Download tracking details"), needs: "trackDownloads" },
        { key: "trackSettleSeconds", page: "configActivities", label: Lang.i18n("Wait for the finished file:"), context: "", fold: Lang.i18n("Download tracking details"), needs: "trackDownloads" },
        { key: "trackCommandsAdded", page: "configActivities", label: Lang.i18n("Your own:"), context: "", fold: Lang.i18n("Download tracking details"), needs: "trackDownloads" },
        { key: "weatherLocation", page: "configWeather", label: Lang.i18n("Place:"), context: "", fold: "", needs: "" },
        { key: "weatherUnits", page: "configWeather", label: Lang.i18n("Show in:"), context: "", fold: "", needs: "" },
        { key: "showWeatherAlerts", page: "configWeather", label: Lang.i18n("Announce rain, snow and storms"), context: Lang.i18n("On the island:"), fold: "", needs: "" },
        { key: "controlTiles", page: "configControls", label: Lang.i18n("Buttons"), context: "", fold: "", needs: "" },
        { key: "timerSoundEnabled", page: "configTools", label: Lang.i18n("Play a sound when they go off"), context: Lang.i18n("Timer & alarm:"), fold: "", needs: "" },
        { key: "timerSound", page: "configTools", label: Lang.i18n("Sound file:"), context: "", fold: "", needs: "" },
        { key: "pomodoroWork", page: "configTools", label: Lang.i18n("Focus:"), context: "", fold: "", needs: "" },
        { key: "pomodoroShortBreak", page: "configTools", label: Lang.i18n("Short break:"), context: "", fold: "", needs: "" },
        { key: "pomodoroLongBreak", page: "configTools", label: Lang.i18n("Long break:"), context: "", fold: "", needs: "" },
        { key: "pomodoroRounds", page: "configTools", label: Lang.i18n("Long break after:"), context: "", fold: "", needs: "" },
        { key: "habitsReviewTime", page: "configHabits", label: Lang.i18n("Time:"), context: "", fold: "", needs: "" },
        { key: "habitsReminder", page: "configHabits", label: Lang.i18n("Ask on the island how the day went"), context: Lang.i18n("Reminder:"), fold: "", needs: "" },
        { key: "habitsColorSource", page: "configHabits", label: Lang.i18n("Colours:"), context: "", fold: "", needs: "" },
        { key: "calendarLeadMinutes", page: "configCalendar", label: Lang.i18n("Pin before the event:"), context: "", fold: "", needs: "" },
        { key: "calendarSound", page: "configCalendar", label: Lang.i18n("Play the alarm sound (chosen in the Tools tab)"), context: Lang.i18n("When an event starts:"), fold: "", needs: "" },
        { key: "calendarShowAllDay", page: "configCalendar", label: Lang.i18n("Show all-day events in the list"), context: Lang.i18n("Calendar page:"), fold: "", needs: "" },
        { key: "calendarLingerMinutes", page: "configCalendar", label: Lang.i18n("Keep after it ends:"), context: "", fold: Lang.i18n("Details"), needs: "" },
        { key: "calendarRefreshMinutes", page: "configCalendar", label: Lang.i18n("Update calendars:"), context: "", fold: Lang.i18n("Details"), needs: "" },
        { key: "calendarSources", page: "configCalendar", label: Lang.i18n("Connected calendars"), context: "", fold: "", needs: "" },
        { key: "notesDefault", page: "configNotes", label: Lang.i18n("Quick notes go to:"), context: "", fold: "", needs: "" },
        { key: "notesRefreshMinutes", page: "configNotes", label: Lang.i18n("Fetch notes:"), context: "", fold: "", needs: "" },
        { key: "notesResume", page: "configNotes", label: Lang.i18n("Carry on in the note that was being edited"), context: Lang.i18n("When the page opens:"), fold: "", needs: "" },
        { key: "notesSources", page: "configNotes", label: Lang.i18n("Connected notes apps"), context: "", fold: "", needs: "" },
        { key: "aiDefault", page: "configAi", label: Lang.i18n("Answers by default:"), context: "", fold: "", needs: "" },
        { key: "aiNotify", page: "configAi", label: Lang.i18n("Say “Answer ready” when an answer arrived while its page was not shown"), context: Lang.i18n("On the island:"), fold: "", needs: "" },
        { key: "aiKeepHistory", page: "configAi", label: Lang.i18n("Keep it in a file on this computer"), context: Lang.i18n("The chat:"), fold: "", needs: "" },
        { key: "aiMaxTokens", page: "configAi", label: Lang.i18n("Longest answer:"), context: "", fold: Lang.i18n("Limits"), needs: "" },
        { key: "aiMaxChars", page: "configAi", label: Lang.i18n("Longest question:"), context: "", fold: Lang.i18n("Limits"), needs: "" },
        { key: "aiSources", page: "configAi", label: Lang.i18n("What is connected"), context: "", fold: "", needs: "" },
        { key: "cloudIndicator", page: "configCloud", label: Lang.i18n("Show a cloud while something is syncing, and “Synced” when it is done"), context: Lang.i18n("On the island:"), fold: "", needs: "" },
        { key: "cloudAlerts", page: "configCloud", label: Lang.i18n("Storage nearly full, sign-in run out, cloud unreachable, sync error"), context: Lang.i18n("Alerts:"), fold: "", needs: "" },
        { key: "cloudConfirmUpload", page: "configCloud", label: Lang.i18n("Ask before every upload"), context: Lang.i18n("Uploading:"), fold: "", needs: "" },
        { key: "cloudWarnPercent", page: "configCloud", label: Lang.i18n("nearly full from"), context: "", fold: Lang.i18n("Details"), needs: "" },
        { key: "cloudCriticalPercent", page: "configCloud", label: Lang.i18n("full from"), context: "", fold: Lang.i18n("Details"), needs: "" },
        { key: "cloudAlertPauseHours", page: "configCloud", label: Lang.i18n("The same alert again:"), context: "", fold: Lang.i18n("Details"), needs: "" },
        { key: "cloudAutoFetchMB", page: "configCloud", label: Lang.i18n("Fetch for dragging:"), context: "", fold: Lang.i18n("Details"), needs: "" },
        { key: "cloudCacheMB", page: "configCloud", label: Lang.i18n("Cache:"), context: "", fold: Lang.i18n("Details"), needs: "" },
        { key: "cloudAliases", page: "configCloud", label: Lang.i18n("Clouds"), context: "", fold: "", needs: "" },
        { key: "catEnabled", page: "configCat", label: Lang.i18n("Show the cat beside the island"), context: Lang.i18n("Cat:"), fold: "", needs: "" },
        { key: "catSide", page: "configCat", label: Lang.i18n("Side:"), context: "", fold: "", needs: "catEnabled" },
        { key: "catSize", page: "configCat", label: Lang.i18n("Size:"), context: "", fold: "", needs: "catEnabled" },
        { key: "catFur", page: "configCat", label: Lang.i18n("Coat:"), context: "", fold: "", needs: "catEnabled" },
        { key: "catMusic", page: "configCat", label: Lang.i18n("Music: headphones, and it nods along"), context: Lang.i18n("Reactions:"), fold: Lang.i18n("Behaviour"), needs: "catEnabled" },
        { key: "catThoughts", page: "configCat", label: Lang.i18n("The AI and questions: a bubble beside its head"), context: "", fold: Lang.i18n("Behaviour"), needs: "catEnabled" },
        { key: "catEvents", page: "configCat", label: Lang.i18n("Events: it wakes up, looks, is glad when a timer runs out"), context: "", fold: Lang.i18n("Behaviour"), needs: "catEnabled" },
        { key: "catPetting", page: "configCat", label: Lang.i18n("Stroking: the pointer back and forth over it"), context: Lang.i18n("With the pointer:"), fold: Lang.i18n("Behaviour"), needs: "catEnabled" },
        { key: "catClicks", page: "configCat", label: Lang.i18n("Clicks: startled by one, angry at too many, or when woken"), context: "", fold: Lang.i18n("Behaviour"), needs: "catEnabled" },
        { key: "catNoAnger", page: "configCat", label: Lang.i18n("Never angry: every click is met with curiosity"), context: "", fold: Lang.i18n("Behaviour"), needs: "catEnabled" },
        { key: "catSulkSeconds", page: "configCat", label: Lang.i18n("It sulks for:"), context: "", fold: Lang.i18n("Behaviour"), needs: "catEnabled" },
        { key: "catSleepSeconds", page: "configCat", label: Lang.i18n("It falls asleep after:"), context: "", fold: Lang.i18n("Behaviour"), needs: "catEnabled" },
        { key: "catDot", page: "configCat", label: Lang.i18n("While the island is a dot:"), context: "", fold: Lang.i18n("Behaviour"), needs: "catEnabled" },
        { key: "catReduceMotion", page: "configCat", label: Lang.i18n("Reduce motion: still poses, nothing nods or floats"), context: Lang.i18n("Motion:"), fold: Lang.i18n("Behaviour"), needs: "catEnabled" },
        { key: "suggestionsEnabled", page: "configSuggestions", label: Lang.i18n("Suggest things at the right moment, and learn when that is welcome"), context: Lang.i18n("Suggestions:"), fold: "", needs: "" },
        { key: "suggestionLevel", page: "configSuggestions", label: Lang.i18n("How much it may interrupt:"), context: "", fold: "", needs: "suggestionsEnabled" },
        { key: "suggestionDailyCards", page: "configSuggestions", label: Lang.i18n("Cards a day, at most:"), context: "", fold: Lang.i18n("Customize"), needs: "suggestionsEnabled" },
        { key: "suggestionCooldownMinutes", page: "configSuggestions", label: Lang.i18n("A rule waits after a card:"), context: "", fold: Lang.i18n("Customize"), needs: "suggestionsEnabled" },
        { key: "suggestionGapMinutes", page: "configSuggestions", label: Lang.i18n("Between two cards:"), context: "", fold: Lang.i18n("Customize"), needs: "suggestionsEnabled" },
        { key: "suggestionHalfLifeDays", page: "configSuggestions", label: Lang.i18n("An answer counts half after:"), context: "", fold: Lang.i18n("Customize"), needs: "suggestionsEnabled" },
        { key: "commandPaths", page: "configDiagnostics", label: Lang.i18n("What the features need"), context: "", fold: "", needs: "" }
    ]

    // Lower case, without accents and the Turkish dotted/dotless i told apart: "Görünüm" is found by "gorunum".
    function fold(text: string): string {
        return String(text).replace(/İ/g, "i").replace(/I/g, "i").replace(/ı/g, "i").toLowerCase()
            .normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/[:…]/g, "");
    }
    function where(entry: var): string {
        const page = index.pages[entry.page] || entry.page;
        return entry.fold.length > 0 ? page + " › " + entry.fold : page;
    }
    function name(entry: var): string {
        const label = String(entry.label).replace(/:\s*$/, "");
        return entry.context.length > 0 ? String(entry.context).replace(/:\s*$/, "") + ": " + label : label;
    }
    // The entries that have every word of `text` in their name or place, the best first:
    // [{ key, page, label, where }].
    function find(text: string, limit: int): var {
        const words = fold(text).split(/\s+/).filter(w => w.length > 0);
        if (words.length === 0) return [];
        const found = [];
        for (const entry of index.entries) {
            const label = fold(index.name(entry)), place = fold(index.where(entry)), all = label + " " + place + " " + fold(entry.key);
            if (!words.every(w => all.indexOf(w) >= 0)) continue;
            const rank = label.startsWith(words[0]) ? 0 : words.every(w => label.indexOf(w) >= 0) ? 1 : 2;
            found.push({ rank: rank, key: entry.key, page: entry.page, needs: entry.needs, label: index.name(entry), where: index.where(entry) });
        }
        found.sort((a, b) => a.rank - b.rank);
        return found.slice(0, limit > 0 ? limit : found.length);
    }
}
