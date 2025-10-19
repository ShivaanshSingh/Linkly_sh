# 🔥 Firestore Security Rules Fix

## 🚨 **Current Issue:**
The app is showing `[cloud_firestore/permission-denied]` errors because the Firestore security rules are blocking access.

## ✅ **Solution: Update Firestore Rules in Firebase Console**

### **Step 1: Go to Firebase Console**
1. Open [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `linklly-9525b`
3. Go to **Firestore Database** → **Rules**

### **Step 2: Replace Current Rules**
Replace the existing rules with this development-friendly version:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow all authenticated users to read/write for development
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
    
    // Specific rules for better security
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    match /posts/{postId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }

    match /comments/{commentId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }

    match /groups/{groupId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }

    match /analytics/{document=**} {
      allow read, write: if request.auth != null;
    }

    match /notifications/{notificationId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### **Step 3: Publish Rules**
1. Click **"Publish"** button
2. Wait for the rules to be deployed
3. Test the app again

## 🎯 **What This Fixes:**

✅ **Permission Denied Errors** - Users can now read/write data  
✅ **Sign-Out Functionality** - Logout works properly  
✅ **Post Loading** - Feeds will load without errors  
✅ **User Authentication** - All auth operations work  

## 🔒 **Security Note:**
These rules are more permissive for development. For production, you should implement more restrictive rules based on your specific needs.

## 🧪 **Testing:**
After updating the rules:
1. **Sign up** with a new account
2. **Sign in** with existing credentials  
3. **Sign out** using any logout method
4. **Check console** - no more permission errors

## 📱 **Expected Results:**
- ✅ No more `[cloud_firestore/permission-denied]` errors
- ✅ Sign-out button works properly
- ✅ Posts load without errors
- ✅ All authentication features work
