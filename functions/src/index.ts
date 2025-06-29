import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

// Initialize Firebase Admin SDK
admin.initializeApp();

// Proximity threshold in meters
const PROXIMITY_THRESHOLD = 500;

// Cooldown period to prevent spam notifications (10 minutes)
const NOTIFICATION_COOLDOWN = 10 * 60 * 1000; // 10 minutes in milliseconds

// Store last notification times to prevent spam
const lastNotificationTimes: { [key: string]: number } = {};

/**
 * Calculate distance between two coordinates using Haversine formula
 * @param lat1 Latitude of first point
 * @param lon1 Longitude of first point
 * @param lat2 Latitude of second point
 * @param lon2 Longitude of second point
 * @returns Distance in meters
 */
function calculateDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371000; // Earth's radius in meters
  const φ1 = lat1 * Math.PI / 180; // φ, λ in radians
  const φ2 = lat2 * Math.PI / 180;
  const Δφ = (lat2 - lat1) * Math.PI / 180;
  const Δλ = (lon2 - lon1) * Math.PI / 180;

  const a = Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
    Math.cos(φ1) * Math.cos(φ2) *
    Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return R * c; // Distance in meters
}

/**
 * Format distance for display
 * @param distanceInMeters Distance in meters
 * @returns Formatted distance string
 */
function formatDistance(distanceInMeters: number): string {
  if (distanceInMeters < 100) {
    return `${Math.round(distanceInMeters)}m`;
  } else if (distanceInMeters < 1000) {
    return `${Math.round(distanceInMeters / 100) * 100}m`;
  } else {
    return `${(distanceInMeters / 1000).toFixed(1)}km`;
  }
}

/**
 * Check if we should send a notification (cooldown check)
 * @param userId User ID to check
 * @param friendId Friend ID to check
 * @returns True if notification should be sent
 */
function shouldSendNotification(userId: string, friendId: string): boolean {
  const key = `${userId}_${friendId}`;
  const now = Date.now();
  const lastTime = lastNotificationTimes[key];
  
  if (!lastTime || (now - lastTime) > NOTIFICATION_COOLDOWN) {
    lastNotificationTimes[key] = now;
    return true;
  }
  
  return false;
}

/**
 * Get user's FCM token and display name
 * @param userId User ID
 * @returns User info object
 */
async function getUserInfo(userId: string): Promise<{ fcmToken?: string; displayName?: string }> {
  try {
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    if (userDoc.exists) {
      const userData = userDoc.data();
      return {
        fcmToken: userData?.fcmToken,
        displayName: userData?.displayName || 'Friend'
      };
    }
  } catch (error) {
    console.error(`Error getting user info for ${userId}:`, error);
  }
  return { displayName: 'Friend' };
}

/**
 * Send proximity notification to a user
 * @param userId User to notify
 * @param friendName Name of the nearby friend
 * @param distance Distance to the friend
 */
async function sendProximityNotification(
  userId: string, 
  friendName: string, 
  distance: number
): Promise<void> {
  try {
    const userInfo = await getUserInfo(userId);
    
    if (!userInfo.fcmToken) {
      console.log(`No FCM token for user ${userId}, skipping notification`);
      return;
    }

    const message = {
      token: userInfo.fcmToken,
      notification: {
        title: '👋 Friend Nearby!',
        body: `${friendName} is ${formatDistance(distance)} away from you`,
      },
      data: {
        type: 'proximity',
        friendId: userId,
        distance: distance.toString(),
      },
      android: {
        notification: {
          icon: 'ic_notification',
          color: '#2196F3',
          channelId: 'proximity_notifications',
          priority: 'high' as const,
        },
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: '👋 Friend Nearby!',
              body: `${friendName} is ${formatDistance(distance)} away from you`,
            },
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    await admin.messaging().send(message);
    console.log(`Proximity notification sent to ${userId} about ${friendName} (${formatDistance(distance)})`);
    
  } catch (error) {
    console.error(`Error sending notification to ${userId}:`, error);
  }
}

/**
 * Main Cloud Function: Check proximity when location updates
 * Triggers when any user's location is updated in Firebase Realtime Database
 */
export const checkProximity = functions.database.ref('/locations/{userId}')
  .onWrite(async (change, context) => {
    const userId = context.params.userId;
    
    // Get the updated location data
    const afterData = change.after.val();
    
    // If location was deleted (user stopped sharing), skip processing
    if (!afterData) {
      console.log(`Location deleted for user ${userId}, skipping proximity check`);
      return null;
    }

    const { lat, lng, isSharing } = afterData;
    
    // Skip if user is not sharing location
    if (!isSharing) {
      console.log(`User ${userId} is not sharing location, skipping proximity check`);
      return null;
    }

    // Validate location data
    if (typeof lat !== 'number' || typeof lng !== 'number') {
      console.error(`Invalid location data for user ${userId}:`, { lat, lng });
      return null;
    }

    console.log(`Checking proximity for user ${userId} at (${lat}, ${lng})`);

    try {
      // Get all other users' locations
      const locationsSnapshot = await admin.database().ref('locations').once('value');
      const allLocations = locationsSnapshot.val() || {};
      
      // Get user info for the moving user
      const movingUserInfo = await getUserInfo(userId);
      const movingUserName = movingUserInfo.displayName || 'Friend';
      
      // Check proximity with all other users
      const proximityPromises: Promise<void>[] = [];
      
      for (const [otherUserId, otherLocationData] of Object.entries(allLocations)) {
        // Skip self
        if (otherUserId === userId) continue;
        
        const otherLocation = otherLocationData as any;
        
        // Skip if other user is not sharing location
        if (!otherLocation?.isSharing) continue;
        
        // Validate other user's location data
        if (typeof otherLocation.lat !== 'number' || typeof otherLocation.lng !== 'number') {
          continue;
        }
        
        // Calculate distance
        const distance = calculateDistance(lat, lng, otherLocation.lat, otherLocation.lng);
        
        console.log(`Distance between ${userId} and ${otherUserId}: ${formatDistance(distance)}`);
        
        // If within proximity threshold, send notifications
        if (distance <= PROXIMITY_THRESHOLD) {
          // Send notification to the other user about the moving user
          if (shouldSendNotification(otherUserId, userId)) {
            proximityPromises.push(
              sendProximityNotification(otherUserId, movingUserName, distance)
            );
          }
          
          // Send notification to the moving user about the other user
          if (shouldSendNotification(userId, otherUserId)) {
            // Get other user's name
            getUserInfo(otherUserId).then(otherUserInfo => {
              const otherUserName = otherUserInfo.displayName || 'Friend';
              return sendProximityNotification(userId, otherUserName, distance);
            }).then(() => {
              console.log(`Mutual proximity notification sent between ${userId} and ${otherUserId}`);
            }).catch(error => {
              console.error(`Error in mutual notification:`, error);
            });
          }
        }
      }
      
      // Wait for all notifications to be sent
      await Promise.all(proximityPromises);
      
      console.log(`Proximity check completed for user ${userId}`);
      return null;
      
    } catch (error) {
      console.error(`Error in proximity check for user ${userId}:`, error);
      return null;
    }
  });

/**
 * Cloud Function: Clean up notification cooldowns periodically
 * Runs every hour to clean up old cooldown entries
 */
export const cleanupNotificationCooldowns = functions.pubsub
  .schedule('every 1 hours')
  .onRun(async (context) => {
    const now = Date.now();
    const cutoff = now - NOTIFICATION_COOLDOWN;
    
    // Remove old cooldown entries
    for (const [key, timestamp] of Object.entries(lastNotificationTimes)) {
      if (timestamp < cutoff) {
        delete lastNotificationTimes[key];
      }
    }
    
    console.log(`Cleaned up notification cooldowns. Remaining entries: ${Object.keys(lastNotificationTimes).length}`);
    return null;
  });

/**
 * Cloud Function: Update user's FCM token
 * Called when user's FCM token needs to be updated
 */
export const updateFcmToken = functions.https.onCall(async (data, context) => {
  // Check if user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  const userId = context.auth.uid;
  const { fcmToken } = data;
  
  if (!fcmToken || typeof fcmToken !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'FCM token is required');
  }
  
  try {
    // Update FCM token in Firestore
    await admin.firestore().collection('users').doc(userId).update({
      fcmToken: fcmToken,
      fcmTokenUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    console.log(`FCM token updated for user ${userId}`);
    return { success: true };
    
  } catch (error) {
    console.error(`Error updating FCM token for user ${userId}:`, error);
    throw new functions.https.HttpsError('internal', 'Failed to update FCM token');
  }
});

/**
 * Cloud Function: Get proximity statistics (for debugging)
 */
export const getProximityStats = functions.https.onCall(async (data, context) => {
  // Check if user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  try {
    const locationsSnapshot = await admin.database().ref('locations').once('value');
    const allLocations = locationsSnapshot.val() || {};
    
    const stats = {
      totalUsers: Object.keys(allLocations).length,
      usersSharing: Object.values(allLocations).filter((loc: any) => loc?.isSharing).length,
      activeCooldowns: Object.keys(lastNotificationTimes).length,
      proximityThreshold: PROXIMITY_THRESHOLD,
      cooldownPeriod: NOTIFICATION_COOLDOWN / 1000 / 60, // in minutes
    };
    
    return stats;
    
  } catch (error) {
    console.error('Error getting proximity stats:', error);
    throw new functions.https.HttpsError('internal', 'Failed to get proximity stats');
  }
});