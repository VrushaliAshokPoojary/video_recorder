# Release Checklist

## Mandatory
- [ ] Real backend URL configured (no mock production URL)
- [ ] No hardcoded exam/candidate/token values in UI
- [ ] Session expiry handling implemented
- [ ] Consent gate enforced before starting exam
- [ ] Consent audit event emitted

## Reliability
- [ ] Lifecycle pause/resume verified on real devices
- [ ] No multi-recording race under rapid taps
- [ ] Friendly UX for no-front-camera devices

## Upload
- [ ] Resume verified with network interruption
- [ ] HEAD offset query uses uploadId
- [ ] Content-Range added only for resumed upload
- [ ] Retry behavior validated

## Quality
- [ ] Unit tests for retry policy pass
- [ ] Unit tests for exam controller transitions pass
- [ ] Unit tests for upload headers pass
- [ ] Manual QA checklist completed and signed

Final reviewer:
Date:
