# SafeSense production readiness

## Prototype changes

- Added explicit per-module consent, an adult gate, clear purpose statements, and one-tap stopping.
- Added owner-controlled Mind Guard and Sound Guard screens, a non-diagnostic trend-based safety flow, India support resources (112 and Tele-MANAS 14416), and transparent shared-history/delete-all UI.
- Made the prototype boundary explicit: it does not capture raw text/audio, start background monitoring, share data, send alerts, or make medical claims.

## Audit of the original prototype

| Area | Original gap | Production requirement |
| --- | --- | --- |
| Consent | No consent or age gate | Granular/revocable DPDP consent and verified parental consent or an under-18 block |
| Wellbeing claims | “High Risk” and “depressive pattern” language | Trend-based wellbeing signals and clinician-approved escalation copy |
| Audio | Voice-looking records | Local speech gate, discard speech frames, persistence/baseline checks and a visible foreground notification |
| Cross-app content | Blanket social monitoring implied | Allowlist only; skip DMs, password fields, OTPs, banking and secure screens |
| Contacts | Not modelled | Mutual invite/acceptance, risk level only and immediate revocation |
| Data | No deletion/retention | Keystore-backed encryption, scrubbed logs, ~30-day retention and account deletion |
| Reliability | No platform state | Permission recovery, foreground-service constraints, OEM battery guidance and heartbeat |

## Delivery plan

1. Build the Android consent, encrypted local store, deletion, privacy-safe analytics, legal and clinician review foundation.
2. Add on-device guards: YAMNet speech gate/multi-frame sound logic and tightly allowlisted accessibility integration; raw inputs remain in memory.
3. Build mutual contact pairing, explicit pre-agreed alerts, FCM delivery receipts, revocation and helpline fallback; never auto-dial/message otherwise.
4. Harden with foreground-service permission recovery, OEM battery setup, signed/rollback model OTA, idempotent queue, feature flags and kill switch.
5. Evaluate recall/precision by language/source, including Tamil, Tanglish, negation, slang, sarcasm, lyrics and memes on 2–3 GB devices.

## Release gates

- India DPDP review, Play/accessibility distribution strategy, clinician review and an anti-stalkerware red-team.
- Verify raw inputs never leave device, PII never enters logs/crashes, consent is revocable, and deletion works.
