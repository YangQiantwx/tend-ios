# Tend

Tend is a native SwiftUI iOS demo for brief wellbeing check-ins and guided movement or mindfulness practices. It stores records as local JSON and runs without an account or server.

## What you can do

- Complete three scheduled check-ins each day, or start an extra check-in. Six questions cover distress, willingness, fatigue, pain, physical function, and available time.
- Choose from a movement option and a mindfulness option. Save suggestions for later, bookmark practices, skip, or repeat a previous practice.
- Follow written steps and spoken guides with a pausable timer. Completion is self-reported; helpfulness ratings and notes are optional.
- Explore daily ratings and practice history in Journey. Charts distinguish scheduled and extra check-ins and leave missing observations empty.
- Adjust reminder times, spoken guidance, and the Ocean or Forest theme. Review and export your local records.
- Walk through a simulated Fitbit connection and save support messages on the device.

## Run

Use Xcode 27 or later with an iOS Simulator runtime. The app targets iOS 18 and later. The checked-in Xcode project is ready to open; no package installation is needed to run the app.

```sh
open Tend.xcodeproj
```

Select the **Tend** scheme, choose an installed iPhone simulator, and press Run. For a physical device, select your signing team and enable code signing in the target's build settings.

To build from the command line:

```sh
xcodebuild -project Tend.xcodeproj -scheme Tend \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

`project.yml` is the XcodeGen project definition. After adding files or changing target settings, regenerate the project with `xcodegen generate`.

## Tests

Run the Foundation-only model, persistence, scheduling, and analysis tests with:

```sh
swift test
```

For UI tests, list the installed destinations and replace `SIMULATOR_UDID` with one of their simulator IDs:

```sh
xcodebuild -project Tend.xcodeproj -scheme Tend -showdestinations
xcodebuild test -project Tend.xcodeproj -scheme Tend \
  -destination 'platform=iOS Simulator,id=SIMULATOR_UDID' \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO
```

The UI tests use a separate `UITests` data directory. Their reset option does not erase the normal app's records.

## Demo walkthrough

1. Finish the welcome screens, then open a scheduled check-in on **Today**. Answer all six questions to see the two suggested practices.
2. Choose **Save for later**, return to Today, and reopen the suggestion from **Saved for later**. Suggestions expire after one hour in this demo; bookmarked practices remain saved.
3. Start a practice. Try pause and resume, then end it and record whether you completed it. Leave feedback blank or add a rating and note. Complete another practice from the same check-in to demonstrate both options.
4. Open **Journey** to inspect the new records, chart selections, and repeat-practice action.
5. Open **Settings → Fitbit**, connect the demo, and sync sample data. Disconnect to show the connection state change.
6. Open **Q&A → Ask the study team**. Write and save a message, reopen it, edit it, and try Share. Saving does not send a message; the system share sheet lets you choose a destination.
7. Open **Settings → Study data & export** to inspect and share a JSON snapshot.

To demonstrate charts with several days of illustrative records, add `--uitesting --seed-journey` under **Edit Scheme → Run → Arguments** in a Debug build. Add `--reset-test-data` for a fresh fixture, then remove it to keep changes between launches. Fixture records are explicitly labeled and isolated from ordinary app data. Remove all three arguments to return to the normal app.

## Data and configuration

`Tend/Resources/study-config.json` defines the reminder defaults, practice content, durations, and provisional suggestion rules. Changes are validated before loading. Existing reminder choices are retained when defaults change.

The app saves committed records to `study-data.json` and unfinished check-ins to `check-in-draft.json` inside its application container. Writes are atomic; the UI updates after a successful save. Exports contain the configuration and stored records.

The suggestion rules, one-hour save window, practice scripts, and study schedule are demonstration settings. They are not an approved clinical protocol. Fitbit readings are synthetic, never collected from a device, and never used to choose practices. Support requests stay local unless you explicitly share them through another app; Tend has no delivery or reply service. Account sign-in, production research services, and exercise videos are not included. Observation labels in the data preview are descriptive calculations, not trained predictions or evidence of treatment benefit.

Notifications are local and require permission. The app schedules a rolling window of up to 20 days within the configured study period and refreshes it when opened. Scheduled requests do not establish delivery or reading.

The analysis preview uses seven preceding calendar days of scheduled responses to calculate a historical median; current and future answers are excluded. A same-day transition compares adjacent scheduled slots against the median frozen before the first response. Missing endpoints stay unknown. The demo uses week 1 to build history, weeks 2–6 as the development period, and weeks 7–8 as held out. These phase boundaries are implemented in `ResearchAnalysis.swift`; they do not train or evaluate a model.

## Code layout

| Directory | Responsibility |
| --- | --- |
| `Tend/App` | App lifecycle, navigation, committed state, and test fixtures |
| `Tend/Core` | Data models, rules, analysis, scheduling, and JSON persistence |
| `Tend/Design` | Theme tokens, shared controls, and vector artwork |
| `Tend/Features` | SwiftUI screens organized by feature |
| `Tend/Services` | Notifications and audio playback |
| `Tend/Resources` | App assets, configuration, and spoken guides |
| `Tests` | Core and Simulator UI tests |
| `scripts` | Audio generation and verification |

## Audio and licensing

The spoken guides use Pocket TTS with the licensed Alba stock voice. Bundled recordings play offline; a missing, invalid, or outdated recording falls back to the device voice. Generation instructions, model revisions, and voice attribution are in [the audio README](Tend/Resources/Audio/README.md). After setting up that Python environment, check audio coverage, script hashes, and AAC decoding on macOS with `../tend-audio-env/bin/python scripts/verify_audio.py`.

See [LICENSE](LICENSE) for the application code license. The generated audio has a separate [CC BY 4.0 license](Tend/Resources/Audio/CC-BY-4.0.txt); retain its attribution when redistributing it.
