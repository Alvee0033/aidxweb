# Firebase Index Creation Guide

## Required Composite Indexes

The following composite indexes need to be created in Firebase Console to fix the query failures:

### 1. Symptoms Collection
- **Collection**: `symptoms`
- **Fields**: `userId` (Ascending), `timestamp` (Descending)
- **URL**: https://console.firebase.google.com/v1/r/project/aidx-b75e7/firestore/indexes?create_composite=Cktwcm9qZWN0cy9haWR4LWI3NWU3L2RhdGFiYXNlcy8oZGVmYXVsdCkvY29sbGVjdGlvbkdyb3Vwcy9zeW1wdG9tcy9pbmRleGVzL18QARoKCgZ1c2VySWQQARoNCgl0aW1lc3RhbXAQAhoMCghfX25hbWVfXxAC

### 2. Emergency Contacts Collection
- **Collection**: `emergency_contacts`
- **Fields**: `userId` (Ascending), `isPrimary` (Descending)
- **URL**: https://console.firebase.google.com/v1/r/project/aidx-b75e7/firestore/indexes?create_composite=ClVwcm9qZWN0cy9haWR4LWI3NWU3L2RhdGFiYXNlcy8oZGVmYXVsdCkvY29sbGVjdGlvbkdyb3Vwcy9lbWVyZ2VuY3lfY29udGFjdHMvaW5kZXhlcy9fEAEaCgoGdXNlcklkEAEaDQoJaXNQcmltYXJ5EAIaDAoIX19uYW1lX18QAg

### 3. Health Habits Collection
- **Collection**: `health_habits`
- **Fields**: `userId` (Ascending), `date` (Descending)
- **URL**: https://console.firebase.google.com/v1/r/project/aidx-b75e7/firestore/indexes?create_composite=ClBwcm9qZWN0cy9haWR4LWI3NWU3L2RhdGFiYXNlcy8oZGVmYXVsdCkvY29sbGVjdGlvbkdyb3Vwcy9oZWFsdGhfaGFiaXRzL2luZGV4ZXMvXxABGgoKBnVzZXJJZBABGggKBGRhdGUQARoMCghfX25hbWVfXxAB

### 4. Reports Collection
- **Collection**: `reports`
- **Fields**: `userId` (Ascending), `timestamp` (Descending)
- **URL**: https://console.firebase.google.com/v1/r/project/aidx-b75e7/firestore/indexes?create_composite=Cktwcm9qZWN0cy9haWR4LWI3NWU3L2RhdGFiYXNlcy8oZGVmYXVsdCkvY29sbGVjdGlvbkdyb3Vwcy9yZXBvcnRzL2luZGV4ZXMvXxABGgoKBnVzZXJJZBABGg0KCXRpbWVzdGFtcBABGgwKCF9fbmFtZV9fEAI

## How to Create Indexes

1. **Click the URLs above** - Each URL will take you directly to the Firebase Console with the index creation form pre-filled.

2. **Or manually create**:
   - Go to [Firebase Console](https://console.firebase.google.com/project/aidx-b75e7/firestore/indexes)
   - Click "Create Index"
   - Select the collection name
   - Add the fields in the specified order
   - Set the sort order (Ascending/Descending) as specified
   - Click "Create"

## Fallback Implementation

The app now includes fallback query methods that will work even without these indexes:

- **Symptom History**: Falls back to simple query without ordering, then sorts manually
- **Emergency Contacts**: Falls back to simple query without ordering
- **Health Habits**: Falls back to simple query without ordering, then sorts manually
- **Reports**: Uses simple query without ordering

## Testing

After creating the indexes:

1. Restart the Flutter app
2. Navigate to the Medical Timeline screen
3. Check the AI Symptom Screen history tab
4. Verify that data loads without index errors

The indexes may take a few minutes to build. During this time, the fallback methods will be used.

