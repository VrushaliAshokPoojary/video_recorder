# Proctoring Upload API Contract

## HEAD /v1/uploads/exam-video
Purpose: return uploaded bytes for resume.

### Request
- Header: Authorization: Bearer <jwt>
- Query: uploadId=<stable-upload-id>

### Response
- Status: 200
- Header: x-uploaded-bytes: <int>

---

## POST /v1/uploads/exam-video
Purpose: upload video stream or remaining chunk.

### Required Headers
- Authorization: Bearer <jwt>
- X-Exam-Id: <exam-id>
- X-Candidate-Id: <candidate-id>
- Content-Type: video/mp4
- Content-Length: <bytes>

### Optional Header
- Content-Range: bytes <start>-<end>/<total>

### Response JSON
{
"uploadReference": "up_abc123_stable"
}

### Contract Rules
1. uploadReference must be stable and idempotent for same uploadId.
2. HEAD must always return latest committed offset.
3. API must be HTTPS only.