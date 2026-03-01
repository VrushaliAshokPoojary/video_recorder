# Proctoring Upload API Contract

## Base URLs
- DEV: `https://dev-api.your-domain.com`
- STAGING: `https://staging-api.your-domain.com`
- PROD: `https://api.your-domain.com`

> Replace with your actual infrastructure URLs.

## HEAD `/v1/uploads/exam-video`
Use this endpoint to fetch resumable offset.

### Request
- Headers
  - `Authorization: Bearer <jwt>`
- Query params
  - `uploadId=<stable-upload-id>`

### Response
- Status: `200`
- Headers
  - `x-uploaded-bytes: <int>`

## POST `/v1/uploads/exam-video`
Use this endpoint to upload full file or remaining chunk.

### Request
- Headers (required)
  - `Authorization: Bearer <jwt>`
  - `X-Exam-Id: <exam-id>`
  - `X-Candidate-Id: <candidate-id>`
  - `Content-Type: video/mp4`
  - `Content-Length: <bytes-being-uploaded>`
- Header (optional for resume)
  - `Content-Range: bytes <start>-<end>/<total>`

### Response
- Status: `200` or `201`
- JSON

```json
{
  "uploadReference": "up_abc123_stable"
}
```

## Contract rules
1. `uploadReference` must be stable + idempotent for the same `uploadId`.
2. `HEAD` must always return the latest committed offset.
3. Only HTTPS endpoints are allowed in production.
