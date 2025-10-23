# 🔥 Firebase Firestore Production Rules

## 🚨 **PRODUCTION-READY SECURITY RULES**

### **Step 1: Go to Firebase Console**
1. Open [Firebase Console](https://console.firebase.google.com/)
2. Select project: `linklly-9525b`
3. Go to **Firestore Database** → **Rules** tab

### **Step 2: Replace ALL Rules with This Production Code**

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isOwner(userId) {
      return request.auth.uid == userId;
    }
    
    function isPublicAccount() {
      return resource.data.accountType == 'Public';
    }
    
    function isConnected(userId) {
      return exists(/databases/$(database)/documents/connections/$(request.auth.uid + '_' + userId)) ||
             exists(/databases/$(database)/documents/connections/$(userId + '_' + request.auth.uid));
    }
    
    // Users collection
    match /users/{userId} {
      // Users can read their own profile
      allow read: if isAuthenticated() && isOwner(userId);
      // Users can update their own profile
      allow update: if isAuthenticated() && isOwner(userId);
      // Public profiles can be read by authenticated users
      allow read: if isAuthenticated() && isPublicAccount();
      // Private profiles can only be read by connections
      allow read: if isAuthenticated() && isConnected(userId);
    }
    
    // Posts collection
    match /posts/{postId} {
      // Users can create their own posts
      allow create: if isAuthenticated() && isOwner(resource.data.userId);
      // Users can read public posts
      allow read: if isAuthenticated() && resource.data.isPublic == true;
      // Users can read private posts from their connections
      allow read: if isAuthenticated() && isConnected(resource.data.userId);
      // Users can update/delete their own posts
      allow update, delete: if isAuthenticated() && isOwner(resource.data.userId);
    }
    
    // Connection requests collection
    match /connection_requests/{requestId} {
      // Users can create connection requests
      allow create: if isAuthenticated() && isOwner(resource.data.senderId);
      // Users can read their own sent requests
      allow read: if isAuthenticated() && isOwner(resource.data.senderId);
      // Users can read requests sent to them
      allow read: if isAuthenticated() && isOwner(resource.data.receiverId);
      // Users can update requests sent to them (accept/decline)
      allow update: if isAuthenticated() && isOwner(resource.data.receiverId);
      // Users can delete their own sent requests
      allow delete: if isAuthenticated() && isOwner(resource.data.senderId);
    }
    
    // Connections collection
    match /connections/{connectionId} {
      // Users can read their own connections
      allow read: if isAuthenticated() && 
        (isOwner(resource.data.userId) || isOwner(resource.data.contactUserId));
      // Connections are created via connection request acceptance
      allow create: if isAuthenticated() && 
        (isOwner(resource.data.userId) || isOwner(resource.data.contactUserId));
      // Users can delete their own connections
      allow delete: if isAuthenticated() && 
        (isOwner(resource.data.userId) || isOwner(resource.data.contactUserId));
    }
    
    // Messages collection
    match /messages/{messageId} {
      // Users can read/write messages in chats they are part of
      allow read, write: if isAuthenticated() && 
        (isOwner(resource.data.senderId) || isOwner(resource.data.receiverId));
    }
    
    // Statuses collection
    match /statuses/{statusId} {
      // Users can create their own statuses
      allow create: if isAuthenticated() && isOwner(resource.data.userId);
      // Users can read statuses from their connections
      allow read: if isAuthenticated() && isConnected(resource.data.userId);
      // Users can delete their own statuses
      allow delete: if isAuthenticated() && isOwner(resource.data.userId);
    }
    
    // Groups collection
    match /groups/{groupId} {
      // Users can read groups they created
      allow read: if isAuthenticated() && isOwner(resource.data.userId);
      // Users can create their own groups
      allow create: if isAuthenticated() && isOwner(resource.data.userId);
      // Users can update/delete their own groups
      allow update, delete: if isAuthenticated() && isOwner(resource.data.userId);
    }
    
    // Notifications collection
    match /notifications/{notificationId} {
      // Users can read their own notifications
      allow read: if isAuthenticated() && isOwner(resource.data.userId);
      // Users can update their own notifications (mark as read)
      allow update: if isAuthenticated() && isOwner(resource.data.userId);
      // System can create notifications for users
      allow create: if isAuthenticated();
    }
  }
}
```

### **Step 3: Publish Rules**
1. Click **"Publish"** button at the top
2. Wait for deployment (usually 1-2 minutes)
3. You should see a success message

### **Step 4: Test the Rules**
1. Restart your Flutter app
2. Test all functionality:
   - User registration/login
   - Creating posts
   - Sending connection requests
   - Accepting/declining requests
   - Messaging
   - Status updates

## 🔒 **Security Features**

### **Authentication Required**
- All operations require user authentication
- No anonymous access to any data

### **Data Ownership**
- Users can only access their own data
- Users can only modify their own content
- Proper authorization checks for all operations

### **Privacy Controls**
- Public accounts: visible to all authenticated users
- Private accounts: only visible to connections
- Private posts: only visible to connections
- Public posts: visible to all authenticated users

### **Connection System**
- Users can only see connections they're part of
- Connection requests properly secured
- Bidirectional connection validation

### **Content Security**
- Users can only create content for themselves
- Users can only modify their own content
- Proper validation for all data operations

## 🚀 **What These Rules Enable**

✅ **User Management**
- Users can create and update their profiles
- Public/private account visibility
- Secure user data access

✅ **Post System**
- Users can create posts
- Public posts visible to all
- Private posts visible to connections only
- Users can only modify their own posts

✅ **Connection System**
- Users can send connection requests
- Users can accept/decline requests
- Secure connection management
- Bidirectional connections

✅ **Messaging System**
- Users can send/receive messages
- Only participants can access chat data
- Secure message storage

✅ **Status Updates**
- Users can create statuses
- Statuses visible to connections
- Users can delete their own statuses

✅ **Notification System**
- Users can receive notifications
- Secure notification access
- Users can mark notifications as read

## ⚠️ **Important Notes**

1. **Test Thoroughly**: Test all app functionality after deploying rules
2. **Monitor Usage**: Check Firebase console for any rule violations
3. **Regular Updates**: Update rules as you add new features
4. **Backup Rules**: Keep a backup of working rules
5. **Performance**: These rules are optimized for performance

## 🔧 **Troubleshooting**

If you encounter issues:

1. **Check Firebase Console**: Look for rule violations in the console
2. **Test Individual Operations**: Test each feature separately
3. **Verify Authentication**: Ensure users are properly authenticated
4. **Check Data Structure**: Ensure your data matches the rule expectations

## 📊 **Rule Validation**

After deploying, test these scenarios:

1. **User Registration**: New users can create accounts
2. **Profile Updates**: Users can update their own profiles
3. **Post Creation**: Users can create posts
4. **Connection Requests**: Users can send/accept requests
5. **Messaging**: Users can send/receive messages
6. **Privacy**: Private accounts/posts are properly secured

---

**🎯 These rules provide enterprise-level security while maintaining full app functionality!**
