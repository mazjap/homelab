// 4play render browser. History off, per 4get docs/configure.md.
// Do NOT enable permanent private browsing: 4play needs containers.
user_pref("browser.privatebrowsing.autostart", false);
user_pref("places.history.enabled", false);
user_pref("browser.formfill.enable", false);
user_pref("browser.download.manager.addToRecentDocs", false);
user_pref("privacy.history.custom", true);

// Headless box: no session restore, no startup pages, no crash nags.
user_pref("browser.startup.page", 0);
user_pref("browser.startup.homepage", "about:blank");
user_pref("browser.newtabpage.enabled", false);
user_pref("browser.sessionstore.resume_from_crash", false);
user_pref("browser.tabs.warnOnClose", false);
user_pref("browser.warnOnQuitShortcut", false);
user_pref("toolkit.startup.max_resumed_crashes", -1);
user_pref("browser.aboutwelcome.enabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);

// Contextual identities (containers) are what 4play uses per proxy.
user_pref("privacy.userContext.enabled", true);
