"""Latest published app release — bump this per release, then push (it deploys).

The `/app-version` endpoint serves this so installed apps prompt users to update.
DOWNLOAD_PATH is served by nginx on each server; the app resolves it against its
own API host (dev / prod each point at their own server's APK).

RELEASE CYCLE (keep these two in lock-step or you'll nag/lock out fresh installs):
  1. Bump `version:` in frontend/pubspec.yaml (e.g. 0.1.0+1 -> 0.1.1+2).
  2. Set LATEST_VERSION below to the SAME number (0.1.1).
  3. Push -> CI builds the APK at that version, publishes it as latest.apk, and
     deploys this backend. Older installs (< LATEST_VERSION) then see the update
     card; freshly-installed apps (== LATEST_VERSION) do not.
The two must be equal whenever there is *no* pending update — otherwise the login
gate would block every fresh install.
"""

# MUST equal the APK's versionName (the `version:` in frontend/pubspec.yaml).
LATEST_VERSION = "0.2.34"

# Where the APK is hosted (nginx serves this). Relative → the app builds the
# full URL from its API base, so dev and prod each use their own server.
DOWNLOAD_PATH = "/app/latest.apk"

# Shown as "What's new" on the update card.
NOTES = "New update available — bug fixes and improvements."

# True → the app blocks login until the user updates (for critical fixes).
MANDATORY = False
