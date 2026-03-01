# Manual QA Checklist

## Build/Environment
- [ ] App launches on Android device
- [ ] App launches on iOS device

## Permissions
- [ ] Camera deny flow handled
- [ ] Microphone deny flow handled

## Exam Recording Flow
- [ ] Start exam begins recording
- [ ] No camera preview shown on exam screen
- [ ] Submit exam stops recording + compress + upload

## Lifecycle
- [ ] Background app and return works
- [ ] No crash on resume

## Reliability
- [ ] Rapid start taps do not start multiple recordings
- [ ] No-front-camera path shows user-friendly error

## Upload Resilience
- [ ] Upload resumes after internet interruption
- [ ] HEAD offset used correctly
- [ ] Content-Range sent only when offset > 0

Tester Name:
Date:
Signature: