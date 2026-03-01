# Release Checklist

## Core
- [ ] Real backend URL configured
- [ ] No hardcoded token/session in UI
- [ ] Consent gate enforced before exam start
- [ ] Consent audit event logged

## Reliability
- [ ] Lifecycle test passed
- [ ] Rapid-tap race test passed
- [ ] No-front-camera UX verified

## Upload
- [ ] HEAD offset resume verified
- [ ] Content-Range behavior verified
- [ ] Retry behavior verified

## Compression
- [ ] Compression validation matrix completed
- [ ] Duration unchanged for compressed files

## Testing
- [ ] retry_policy unit tests pass
- [ ] exam_controller unit tests pass
- [ ] upload_service unit tests pass

Final reviewer:
Date: