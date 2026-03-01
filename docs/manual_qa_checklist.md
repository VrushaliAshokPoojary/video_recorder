# Manual QA Checklist

## Build & launch
- [ ] App launches on Android
- [ ] App launches on iOS

## Session & consent
- [ ] Session loads from runtime source (no hardcoded token in UI)
- [ ] Expired/invalid token blocks exam start
- [ ] Camera consent checkbox required
- [ ] Policy acceptance checkbox required

## Recording flow
- [ ] Start exam begins silent front-camera recording
- [ ] Exam UI stays responsive while recording
- [ ] Submit exam stops recording, compresses, uploads

## Lifecycle reliability
- [ ] Start exam -> background app -> return -> submit works
- [ ] Rapid 10 taps on Start does not create multiple recordings
- [ ] Friendly message shown when front camera is unavailable

## Upload resilience
- [ ] Disable network during upload and restore network
- [ ] Resume uses HEAD offset (`x-uploaded-bytes`)
- [ ] Resume request includes `Content-Range` when offset > 0

## Storage/compression
- [ ] Raw file stored under app docs
- [ ] Compressed file stored under app docs
- [ ] Compression ratio documented
- [ ] Duration unchanged after compression

Tester:
Date:
Signature:
