# Pharmacy App

Private pharmacy sales app. Scan/enter barcode, record sales, and generate reports via Google Sheets API.

**Setup:**
1. Create a Google Service Account JSON and add to GitHub secrets as `SERVICE_ACCOUNT_JSON`
2. Add spreadsheet ID to GitHub secrets as `SPREADSHEET_ID`
3. Push to trigger APK build

**Screens:**
- **Sell:** Barcode scanner + manual entry. New products created on first sale.
- **Reports:** Filter by today/month/all. Shows operations, revenue, sold & unsold products.

**Tech:** Flutter, Dart, Google Sheets API, Mobile Scanner
