"""Latest published app release — bump this per release, then push (it deploys).

The `/app-version` endpoint serves this so installed apps prompt users to update.
DOWNLOAD_PATH is served by nginx on each server; the app resolves it against its
own API host (dev / prod each point at their own server's APK).
"""

# Bump on every release (should match the APK's versionName in pubspec.yaml).
LATEST_VERSION = "0.1.1"

# Where the APK is hosted (nginx serves this). Relative → the app builds the
# full URL from its API base, so dev and prod each use their own server.
DOWNLOAD_PATH = "/app/latest.apk"

# Shown as "What's new" on the update card.
NOTES = "New update available — bug fixes and improvements."

# True → the app blocks login until the user updates (for critical fixes).
MANDATORY = False
