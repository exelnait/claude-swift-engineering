# Media Accessibility — Subtitles & Captions

Subtitles are vital for people who are deaf or hard of hearing, help others
follow dialogue, and serve anyone who can't use audio right now (a noisy airport,
a quiet room). Two things make media more accessible: **letting people choose
subtitles** and **letting them style subtitles while watching**.

## Critical Rules

- **Always provide subtitle-selection UI** during playback. If you use a system
  player you get it for free; if you build a custom player, you must add it.
- **Let people change subtitle style during playback**, not just in Settings —
  adopt the subtitle style preview.
- **Don't disable or hide** Apple AI-generated subtitles; they fill language gaps
  automatically and authored subtitles still take precedence.

## Apple AI-generated subtitles

Generated on-device, live, during playback — you don't implement anything; they
appear automatically. Two kinds:

- **Speech transcription** — subtitles generated from audio via on-device
  speech-to-text.
- **Language translation** — subtitles generated from existing subtitles via the
  on-device translation model.

They work for HLS (live streams, VOD, live events) and file-based content
(bundled or downloaded), across professional and user-created media. Authored
subtitles are preferred and left unchanged; generated ones are marked (e.g. a
sparkle + "Translated").

> **Availability:** Generating English subtitles from English audio starts in
> **iOS/macOS/tvOS/visionOS 27**; additional languages can be generated from
> English subtitles on iOS/macOS. Guard any version-specific UI with
> `if #available(iOS 27, *)`.

## Provide subtitle selection UI

Pick the integration that matches your player:

| Option | Use when |
|--------|----------|
| `AVPlayerViewController` (iOS) / `AVPlayerView` (macOS) | You want full player controls **and** subtitle selection for free |
| `AVLegibleMediaOptionsMenuController` | You have your own player controls and just need to add subtitle selection + style preview |
| Custom media-selection controls | You need to match your app's bespoke player UI |

## Subtitle style preview

The system has built-in caption styles plus user-created custom styles (the user
might make a "Bold Yellow" with extra border). Surface them in the playback menu
and show a live preview so people can choose what's easiest to read without
leaving the video.

Integration options: `AVPlayerViewController` / `AVPlayerView` (full), or
`AVLegibleMediaOptionsMenuController` (drop-in), or drive it yourself via
`AVPlayerLayer` (system renders the preview) or `AVCaptionRenderer` (you render).

Shape of the `AVPlayerLayer` approach:

```text
1. Each system style has a profile ID. Fetch all styles by profile ID and
   populate your menu with their names.
2. On selection, show the stylized preview for that profile:
   - Pass nil for the text to show localized system sample text.
   - Use the position parameter to offset the preview clear of your controls.
   - Existing subtitles are hidden automatically so they don't interfere.
3. Call again to preview a different style (as many times as needed).
4. Stop the preview when selection ends — this removes the sample and restores
   the active subtitles.
5. Set the chosen style; it applies to all subtitles system-wide.
```

## Summary

1. Provide subtitle-selection UI in every player; system players include it.
2. Adopt the subtitle style preview so people can restyle subtitles while
   watching.
3. Let Apple AI-generated subtitles fill language gaps (iOS/macOS/tvOS/visionOS
   27+); keep authored subtitles authoritative.
4. Choose `AVPlayerViewController`/`AVPlayerView`,
   `AVLegibleMediaOptionsMenuController`, or a custom UI based on how much of the
   player you own.
