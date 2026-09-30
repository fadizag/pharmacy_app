Pharmacy App
============

Flutter pharmacy sales app:
- QR/barcode scanning
- Product lookup in Google Sheets
- Sales logging to the Sales sheet
- Basic sales reports

IMPORTANT:
The current config is a template only. Do not commit a real Google Service Account JSON key.
For a production release, use a secure server/Apps Script proxy or OAuth instead of embedding service-account credentials in the APK.

GitHub Actions builds a release APK and uploads it as the pharmacy-apk artifact.
