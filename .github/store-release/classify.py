#!/usr/bin/env python3
"""Turn a store's error text into the cause and the fix.

Apple and Google both answer a blocked release with a wall of text that names
a symptom and not a cause: an outstanding agreement comes back as a 403 from
`deliver`, a queued review as "you cannot create a new version of the App in
the current state", a keystore mismatch as a bare 400. Every entry in the
table below was a release that stopped, so the next one costs a minute of
reading instead of an evening of guessing.

This never decides anything: it annotates, writes the step summary and exits 0
(the step that actually failed has already failed). `transient` entries are
emitted as warnings, because re-running those is the fix.

Usage: classify.py --platform ios|android --log FILE [--log FILE ...]
Stdlib only.
"""

import argparse
import pathlib
import re
import sys

# (slug, severity, pattern, cause, fix)
# severity: "blocker" -> ::error, "transient" -> ::warning
APPLE = [
    (
        "agreement",
        "blocker",
        r"accept the latest|latest version of the (?:Program License|Paid Applications)"
        r"|Agreements, Tax, and Banking|updated agreements?|agreement.{0,40}not been accepted",
        "An App Store Connect agreement is outstanding. Apple blocks every upload and "
        "submission for the whole team until it is accepted.",
        "Open https://appstoreconnect.apple.com/business (Business, then Agreements) and accept "
        "what is listed. Only the Account Holder can; nobody else sees a useful error. "
        "The weekly store-readiness run exists to catch this on a Monday instead of on release night.",
    ),
    (
        "version-state",
        "blocker",
        r"cannot create a new version of the App in the current state"
        r"|app is in a state where a new version cannot be created",
        "A previous version is still queued or being reviewed, so Apple refuses a new App Store version.",
        "Run again with track=testflight: a TestFlight upload appends a build and touches no App "
        "Store version. Or clear the queue in App Store Connect: WAITING_FOR_REVIEW can be rejected "
        "(the upload step does it automatically), IN_REVIEW cannot be undone.",
    ),
    (
        "build-number-used",
        "blocker",
        r"bundle version must be higher|ITMS-4238|redundant binary"
        r"|bundle version .{0,20}already (?:been )?used|previously used",
        "That build number already exists for this app on App Store Connect.",
        "Build numbers here come from the clock, so a collision means something else uploaded a "
        "higher one (a laptop build). Re-run: the next second yields a new number. Never lower the scheme.",
    ),
    (
        "missing-compliance",
        "blocker",
        r"Missing Compliance|export compliance|usesNonExemptEncryption|ITSAppUsesNonExemptEncryption",
        "Apple is waiting for an export-compliance answer, so the build cannot be used.",
        "Set ITSAppUsesNonExemptEncryption in Info.plist (false for most apps; true plus an exemption "
        "if you ship non-exempt cryptography). Then no build ever waits for that question again.",
    ),
    (
        "certificate",
        "blocker",
        r"CSSMERR_TP_CERT_(?:REVOKED|EXPIRED)|Invalid Signature|no identity found"
        r"|certificate.{0,30}(?:expired|revoked)|errSecInternalComponent",
        "The Apple distribution certificate is expired, revoked, or not in the runner's keychain.",
        "Rotate APPLE_DISTRIBUTION_P12_B64 and APPLE_DISTRIBUTION_P12_PASSWORD "
        "(skills/store-release/references/secrets.md, Apple distribution certificate). "
        "Preflight warns 30 days before the expiry date.",
    ),
    (
        "provisioning",
        "blocker",
        r"ITMS-90161|Invalid Provisioning Profile|doesn't include signing certificate"
        r"|No profiles for .{0,60} were found|provisioning profile.{0,30}not found",
        "Apple would not issue or match a provisioning profile for this bundle id.",
        "The export runs with -allowProvisioningUpdates and the API key, so Apple normally creates the "
        "profile itself. A failure here is usually a bundle id that does not exist in this team, a "
        "capability enabled in the project but not on the App ID, or a key below App Manager.",
    ),
    (
        "auth",
        "blocker",
        r"NOT_AUTHORIZED|Authentication credentials are missing or invalid|401 Unauthorized"
        r"|Unable to authenticate with App Store Connect|The request is unauthorized",
        "App Store Connect refused the API key.",
        "The key id, the issuer id and the .p8 must come from the same key, and the key must still be "
        "active (App Store Connect, Users and Access, Integrations, Keys). A revoked key gives exactly this.",
    ),
    (
        "role",
        "blocker",
        r"FORBIDDEN_ERROR|does not have the required (?:role|permission)|Forbidden for this API key",
        "The API key authenticated but is not allowed to do this.",
        "The key needs the App Manager role for uploads and metadata (Admin for Xcode Cloud). "
        "Roles are set per key in App Store Connect, Users and Access, Integrations.",
    ),
    (
        "purpose-string",
        "blocker",
        r"ITMS-90683|Missing Purpose String",
        "A privacy-sensitive API is used without its usage description.",
        "Add the named NS*UsageDescription key to Info.plist. The error text names which one.",
    ),
    (
        "privacy-manifest",
        "blocker",
        r"ITMS-91053|missing API declaration|NSPrivacyAccessedAPITypes",
        "A required-reason API is used without a privacy manifest entry.",
        "Add or extend PrivacyInfo.xcprivacy. The error text names the API category.",
    ),
    (
        "version-rejected",
        "blocker",
        r"METADATA_REJECTED|DEVELOPER_REJECTED|Developer Rejected",
        "The App Store version sits in a rejected state that only the Console can clear.",
        "Open the version in App Store Connect, answer the reviewer or fix the metadata, and submit "
        "from there. Upload with submit off so the build lands without a new submission.",
    ),
    (
        "transporter",
        "transient",
        r"ITMS-90000|Unable to process app at this time due to a general error"
        r"|service is temporarily unavailable|timed out|Connection reset|50[234] (?:Gateway|Server)",
        "Apple's upload service failed in a way that says nothing about this build.",
        "Re-run the failed jobs. Already-uploaded platforms skip themselves, so a retry is cheap.",
    ),
]

PLAY = [
    (
        "changes-not-sent",
        "blocker",
        r"changesNotSentForReview",
        "Play takes this app's changes for review only from the Console. It lands in that state "
        "after a rejection and stays until a human sends one release from the Console.",
        "The upload step re-uploads with changes_not_sent_for_review and reports it as held. Open "
        "Play Console, Publishing overview, and press Send for review. Do NOT re-run this job: that "
        "uploads a second build.",
    ),
    (
        "permission",
        "blocker",
        r"The caller does not have permission|does not have the Release|403.{0,40}(?:Forbidden|permission)",
        "The Play service account may not do this to this app.",
        "Play Console, Users and permissions: the service account needs Release to the track you are "
        "using (Release to production for production). Check the app is granted, not only the account.",
    ),
    (
        "version-code-used",
        "blocker",
        r"[Vv]ersion code \d+ has already been used|specifies a version code that has already been used",
        "That versionCode is already on Play, and a versionCode can never be reused or lowered.",
        "Codes here come from the clock, so re-running yields a new one. If a laptop build uploaded a "
        "higher code, that is the floor from now on.",
    ),
    (
        "upload-key",
        "blocker",
        r"signed with the wrong key|not signed (?:by|with) the (?:correct|upload) (?:certificate|key)"
        r"|upload certificate.{0,40}expected",
        "The AAB is signed with a key Play does not accept for this app.",
        "Compare the bundle's SHA1 with the registered upload key; the verify step does this before "
        "the upload when ANDROID_UPLOAD_KEY_SHA1 is set. A wrong ANDROID_KEYSTORE_B64 or key alias is "
        "the usual cause.",
    ),
    (
        "app-not-found",
        "blocker",
        r"Package not found|applicationNotFound"
        r"|project id used to call the Google Play Developer API has not been linked",
        "Play cannot see this package under the service account's project.",
        "Check package_name, and Play Console, Setup, API access: the Google Cloud project that owns "
        "the service account must be linked, and the account granted on this app.",
    ),
    (
        "draft-app",
        "blocker",
        r"Only releases with status draft may be created on draft app"
        r"|cannot be published.{0,40}draft",
        "The app has never been published, so Play only accepts draft releases.",
        "Upload with release_status=draft and publish the very first release by hand in Play Console. "
        "This pipeline is for the next version of an app that already shipped once.",
    ),
    (
        "app-content",
        "blocker",
        r"data safety|App content|content rating|declaration (?:is|was) (?:missing|incomplete)",
        "A Play Console questionnaire is incomplete, which blocks the release.",
        "Play Console, Policy, App content: finish the data safety form, content rating, ads and target "
        "audience declarations.",
    ),
    (
        "target-api",
        "blocker",
        r"target(?:Sdk|ing) API level|targetSdkVersion .{0,30}(?:must|at least)",
        "The bundle targets an API level Play no longer accepts for new releases.",
        "Raise targetSdk in the app module and rebuild. Play's deadlines move every year.",
    ),
    (
        "account",
        "blocker",
        r"developer account .{0,40}(?:not approved|suspended|terminated)",
        "The Play developer account itself is blocked.",
        "Nothing in CI can fix this. Check the account's email for Google's notice.",
    ),
    (
        "edit-conflict",
        "blocker",
        r"editAlreadyCommitted|Edit has already been committed|editExpired",
        "The Play edit was committed or expired before this upload finished.",
        "Usually two runs uploading at once. Check the concurrency group is keyed on the release and "
        "cancel-in-progress is false, then re-run.",
    ),
    (
        "transient",
        "transient",
        r"Rate Limit Exceeded|backendError|internalError|service is currently unavailable"
        r"|\b(?:429|500|502|503|504)\b",
        "Google answered with a rate limit or a server error, which says nothing about this build.",
        "Re-run the failed jobs.",
    ),
]


def annotate(kind: str, title: str, body: str) -> None:
    escaped = body.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
    print(f"::{kind} title={title}::{escaped}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--platform", required=True, choices=["ios", "android"])
    parser.add_argument("--log", action="append", default=[])
    parser.add_argument("--summary", default=None, help="step summary file (default $GITHUB_STEP_SUMMARY)")
    args = parser.parse_args()

    text = ""
    for name in args.log:
        path = pathlib.Path(name)
        if path.is_file():
            text += path.read_text(encoding="utf-8", errors="replace")
    if not text.strip():
        print("::notice::No store log to read, so there is nothing to explain.")
        return 0

    table = APPLE if args.platform == "ios" else PLAY
    store = "App Store Connect" if args.platform == "ios" else "Google Play"
    hits = []
    for slug, severity, pattern, cause, fix in table:
        if re.search(pattern, text, re.IGNORECASE):
            hits.append((slug, severity, cause, fix))

    lines = [f"### What {store} actually said", ""]
    if not hits:
        annotate(
            "notice",
            "Unrecognised store error",
            f"No entry in the {store} table matches this failure. Read the step's log, then add the "
            f"pattern to shared/store-release/scripts/classify.py so the "
            f"next person does not "
            f"have to: that table is the institutional memory.",
        )
        lines += [
            "No known pattern matched. Read the failing step's log and add the case to "
            "`shared/store-release/scripts/classify.py`.",
            "",
        ]
    for slug, severity, cause, fix in hits:
        kind = "error" if severity == "blocker" else "warning"
        annotate(kind, f"{store}: {slug}", f"{cause}\n\nFix: {fix}")
        lines += [f"**{slug}** ({severity})", "", f"{cause}", "", f"*Fix:* {fix}", ""]

    summary = args.summary or __import__("os").environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as handle:
            handle.write("\n".join(lines) + "\n")

    first = hits[0][0] if hits else ""
    output = __import__("os").environ.get("GITHUB_OUTPUT")
    if output:
        with open(output, "a", encoding="utf-8") as handle:
            handle.write(f"cause={first}\n")
            handle.write(f"transient={'true' if hits and all(h[1] == 'transient' for h in hits) else 'false'}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
