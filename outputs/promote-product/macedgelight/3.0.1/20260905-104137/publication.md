# Publication status

Updated September 5, 2026.

## GitHub

Campaign and repository guidance pushed to `ChiefInnovator/macedgelight`, branch `main`, commit `caf420b`.

## Instagram

User authorized publication to Inventing Fire with AI. The signed-in browser identity was verified as `inventingfire_with_ai` (display name Inventing Fire with AI).

All six JPEGs were loaded in order. The original portrait preview displayed correctly. Instagram repeatedly showed “Something went wrong. Please try again.” when advancing from Crop, including after the built-in retry and a fresh page/draft with Original aspect ratio. No Share action was reached. No post was published; no post ID or permalink exists. Caption and alt text remain ready in this folder.

No API credentials are configured in the local environment or the designated credential file. Existing GitHub repository secrets were not extracted or repurposed. The browser composer remains open for handoff. Resume by resolving the Instagram composer error and loading slide-01.jpg through slide-06.jpg, preserving Original or 4:5, then adding caption.txt and the per-slide alt text from campaign.md before sharing.

## Diagnostic follow-up

Browser diagnostics on September 5, 2026 found a recurring console error: `Unable to fetch crossposting metadata`, including after page reload. All six image-upload requests returned HTTP 200; one inspected upload response explicitly returned `status: ok`. A single-image draft failed at the same Crop-to-next transition, so the failure is not specific to carousel count. No Share action was reached in these tests.

The composer initialization GraphQL requests returned HTTP 200 without top-level errors. One account-service metadata response contained `custom_service_data: null`; its meaning and causal relationship are not established. The console error is evidence of a composer metadata problem, not proof of a broken Facebook link, an extension fault, or an account restriction. Tokens, cookies, raw account responses, and network archives were not saved.

Next isolation checks: try the same draft/account in Instagram mobile or a clean browser session; if one succeeds, investigate the original browser/session. If both fail, inspect account status and linked-account configuration in Meta's official UI. Do not disconnect accounts or change permissions merely to test. API publishing remains a possible alternative after secure credential provisioning and account validation. The current browser handoff contains only the single-image diagnostic draft; do not publish that draft as the intended six-slide campaign.
