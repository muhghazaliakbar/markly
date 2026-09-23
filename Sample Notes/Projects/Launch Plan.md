# Launch Plan — Markly 1.0

**Owner:** Product · **Target date:** 30 October 2026 · **Status:** ==On track==

## Summary

Markly 1.0 is the first public release of the editor. The goal is a stable, signed build that people can download, open their existing notes folder with, and use every day without losing anything. This note tracks the plan, the open questions and the checklist for launch day.

## Goals

1. Ship a signed and notarised build for macOS 26 on Apple silicon and Intel.
2. Publish the source on GitHub under the MIT License with a clear README.
3. Reach 500 stars and 50 active contributors-in-waiting (issues or discussions) in the first month.
4. Keep crash-free sessions above 99.5% — measured from voluntary bug reports, since there is no telemetry.

### Non-goals

- iPad or iPhone versions
- Real-time collaboration
- A plugin system (revisit after 1.0)

## Timeline

| Week       | Milestone                          | Owner    | Status        |
| ---------- | ---------------------------------- | -------- | ------------- |
| 29 Sep     | Feature freeze                     | Eng      | ==Done==      |
| 6 Oct      | Beta 1 to 20 testers               | Eng      | In progress   |
| 13 Oct     | Documentation and screenshots      | Design   | Not started   |
| 20 Oct     | Beta 2, release candidate          | Eng      | Not started   |
| 27 Oct     | Press kit and launch post          | Product  | Not started   |
| 30 Oct     | Launch                             | Everyone | —             |

## Meeting notes — 23 September

**Attendees:** Alex, Sam, Priya, Jo

### Decisions

- The format bar ships on by default; it can be turned off in Settings › Editor.
- Preview scroll sync ships on by default.
- Git Sync stays labelled *beta* until it only touches the notes folder.

### Discussion

Sam raised that people keep notes inside code repositories, which means Sync currently commits unrelated changes. Everyone agreed this has to be fixed before 1.0: Sync should add and commit only the paths inside the notes folder, and the change count in the sidebar should only count those paths.

Priya showed the new settings window. Feedback was positive; the privacy tab in particular reads well. Jo asked for a short "What's new" sheet on first launch after an update — deferred to 1.1.

We looked at performance on a 5,000-line note. Typing latency stays under 5 ms thanks to incremental highlighting; opening the note takes about 150 ms. That's acceptable for 1.0.

### Action items

- [ ] **Alex** — scope Git Sync to the notes folder
- [ ] **Sam** — write the beta tester guide
- [x] **Priya** — final pass on the settings window copy
- [ ] **Jo** — record a 60-second demo video
- [ ] **Everyone** — dog-food Markly for all notes this week

## Release checklist

### Build

- [ ] Bump the version to 1.0.0 in `Info.plist`
- [ ] Build universal binary (`scripts/build-app.sh`)
- [ ] Sign with Developer ID and notarise
- [ ] Staple the ticket and verify with `spctl --assess`

```bash
xcrun notarytool submit build/Markly.zip \
  --keychain-profile "markly-notary" \
  --wait
xcrun stapler staple build/Markly.app
spctl --assess --verbose=2 build/Markly.app
```

### Quality

- [ ] All unit tests pass (`swift test`)
- [ ] Manual pass over the tour note in light and dark mode
- [ ] Check Reduce Motion and Reduce Transparency
- [ ] Open a folder with 1,000+ notes and check sidebar performance
- [ ] Edit the same note in Markly and another editor; confirm reload

### Communication

- [ ] Launch post on the blog
- [ ] Post on Mastodon, Bluesky and Hacker News
- [ ] Email beta testers with thanks and the final build

## Risks

| Risk                                   | Likelihood | Impact | Mitigation                                   |
| -------------------------------------- | ---------- | ------ | -------------------------------------------- |
| Private blur filter changes in macOS   | Low        | Medium | Automatic fallback to a masked blur          |
| Notarisation delays                    | Medium     | High   | Submit the release candidate a week early    |
| Git Sync commits unrelated files       | High       | High   | Scope to the notes folder before launch      |
| Performance on very large folders      | Medium     | Medium | Lazy scanning of nested folders              |

## Open questions

> Do we want a Homebrew cask on launch day, or wait for the first point release?

> Should the default editor width be narrower on small displays?

Both are low-stakes; decide at the 6 October meeting.

---

*Last updated 23 September 2026.*
