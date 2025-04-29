import firebase_admin
from firebase_admin import credentials, firestore
import uuid
from datetime import datetime

# Initialize Firebase
cred = credentials.Certificate('/Users/momen_mac/Desktop/flutter_application/server/livespot-b1eb4-firebase-adminsdk-fbsvc-f5e95b9818.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

# Example user IDs (must match your Firestore users)
user1 = "1"
user2 = "2"

# Create a conversation
conversation_id = str(uuid.uuid4())
conversation_data = {
    "id": conversation_id,
    "participants": [user1, user2],
    "isGroup": False,
    "groupName": None,
    "unreadCount": 0,
    "isMuted": False,
    "isArchived": False,
    "lastMessage": {
        "id": "msg1",
        "senderId": user1,
        "senderName": "User One",
        "content": "Hello from Python!",
        "timestamp": datetime.now().isoformat(),
        "messageType": "text",
        "status": "sent",
        "isRead": False,
        "isSent": True,
        "isEdited": False,
        "mediaUrl": "",
        "voiceDuration": None,
        "replyToId": None,
        "replyToSenderName": None,
        "replyToContent": None,
        "replyToMessageType": None,
        "forwardedFrom": None,
        "editedAt": None,
    },
    "lastMessageTimestamp": firestore.SERVER_TIMESTAMP,
}
db.collection("conversations").document(conversation_id).set(conversation_data)

# Add a message to the conversation's messages subcollection
message_id = "msg1"
message_data = conversation_data["lastMessage"]
db.collection("conversations").document(conversation_id).collection("messages").document(message_id).set(message_data)

print("Conversation and message created.")
