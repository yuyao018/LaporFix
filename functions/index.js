// Import Firestore trigger functions from Firebase Functions v2.
// onDocumentCreated runs when a Firestore document is created or updated
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const { setGlobalOptions } = require("firebase-functions/v2");

// used to print logs in Firebase Functions console.
const logger = require("firebase-functions/logger");

// Firebase Admin SDK initialization and services.
const { initializeApp } = require("firebase-admin/app");
const { FieldValue } = require("firebase-admin/firestore");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

// Initialize Firebase Admin SDK.
// This is required before using Firestore or FCM from backend functions.
initializeApp();
setGlobalOptions({ region: "asia-southeast1" });

// FCM multicast sending supports a maximum of 500 tokens per request.
// Therefore, tokens must be split into batches of 500.
const MAX_MULTICAST_TOKENS = 500;

// These FCM error codes mean the token is no longer valid.
// Invalid tokens should be removed from Firestore to avoid future failures.
const INVALID_TOKEN_CODES = new Set([
  "messaging/invalid-registration-token",
  "messaging/registration-token-not-registered",
]);

/**
 * Function: sendAnnouncementNotification
 *
 * Trigger:
 * Runs automatically when a new document is created in:
 * announcements/{announcementId}
 *
 * Purpose:
 * Sends push notifications to:
 * 1. Admin users
 * 2. Normal users whose area/state matches the announcement target location
 */
exports.sendAnnouncementNotification = onDocumentCreated(
  "announcements/{announcementId}",
  async (event) => {
    // Get the newly created announcement document snapshot.
    const snapshot = event.data;

    // If there is no document data, stop the function.
    if (!snapshot) return;

    // Get the announcement document ID from the Firestore path.
    const announcementId = event.params.announcementId;

    // Get the announcement document data.
    const announcement = snapshot.data() || {};

    // Do not send notification if:
    // 1. The announcement is deleted
    // 2. FCM notification has already been sent
    if (announcement.isDeleted === true || announcement.fcmSent === true) {
      return;
    }

    // Get target location information from the announcement.
    const target = announcement.target || {};
    const location = target.location || {};

    // Normalize area and state so comparison is case-insensitive.
    // Example: " Penang " becomes "penang".
    const targetArea = normalize(location.area);
    const targetState = normalize(location.state);

    // Used in the fallback notification body.
    // If full location does not exist, use area.
    // If area also does not exist, use "your area".
    const targetFull = location.full || location.area || "your area";

    // Get Firestore database instance.
    const db = getFirestore();

    // Reference to the users collection.
    const usersRef = db.collection("users");

    // Get admin users and normal users at the same time.
    // Promise.all() is used so both queries run concurrently.
    const [adminSnapshot, residentSnapshot] = await Promise.all([
      usersRef.where("role", "==", "admin").get(),
      usersRef.where("role", "==", "user").get(),
    ]);

    // Store final notification recipients.
    // Map is used to prevent duplicate users.
    const recipients = new Map();

    // Add all admin users who allow urgent alert notifications.
    for (const doc of adminSnapshot.docs) {
      if (canReceiveNotification(doc.data(), "urgentAlerts")) {
        recipients.set(doc.id, doc);
      }
    }

    // Add normal users only if:
    // 1. They allow urgent alert notifications
    // 2. Their area/state matches the announcement target location
    for (const doc of residentSnapshot.docs) {
      const userData = doc.data();

      if (
        canReceiveNotification(userData, "urgentAlerts") &&
        matchesAnnouncementLocation(userData, targetArea, targetState)
      ) {
        recipients.set(doc.id, doc);
      }
    }

    // tokenOwners keeps track of which user owns each FCM token.
    // This is useful when removing invalid tokens later.
    const tokenOwners = new Map();

    // This stores all unique FCM tokens that will receive the notification.
    const tokens = [];

    // Extract FCM tokens from all selected recipients.
    for (const doc of recipients.values()) {
      const userTokens = extractTokens(doc.data());

      for (const token of userTokens) {
        // If token is not already added, add it to the token list.
        if (!tokenOwners.has(token)) {
          tokenOwners.set(token, new Set());
          tokens.push(token);
        }

        // Save the user document reference as the owner of this token.
        tokenOwners.get(token).add(doc.ref);
      }
    }

    // If no FCM tokens are found, mark this announcement as processed.
    // This prevents repeated attempts to send notification for this announcement.
    if (tokens.length === 0) {
      await snapshot.ref.set({
        fcmSent: true,
        fcmSentAt: FieldValue.serverTimestamp(),
        fcmRecipientCount: 0,
        fcmSuccessCount: 0,
        fcmFailureCount: 0,
      }, { merge: true });

      logger.info("No FCM tokens found for announcement", { announcementId });
      return;
    }

    // Track FCM sending result.
    let successCount = 0;
    let failureCount = 0;

    // Store tokens that are no longer valid.
    const invalidTokens = new Set();

    // Send notifications in batches of 500 tokens.
    for (const batch of chunk(tokens, MAX_MULTICAST_TOKENS)) {
      const response = await getMessaging().sendEachForMulticast({
        // Current batch of FCM tokens.
        tokens: batch,

        // Notification title and body shown in the notification tray.
        notification: {
          title: announcement.title || "New announcement",
          body: trimBody(
            announcement.caption ||
            `A new announcement was posted for ${targetFull}.`,
          ),
        },

        // Custom data payload for the Flutter app.
        // The app can use this to open the correct page when notification is tapped.
        data: {
          type: "announcement",
          route: "announcement_detail",
          announcementId,
        },

        // Android-specific notification configuration.
        android: {
          priority: "high",
          notification: {
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
          },
        },

        // iOS-specific notification configuration.
        apns: {
          payload: {
            aps: {
              sound: "default",
            },
          },
        },
      });

      // Add this batch's success and failure count to the total.
      successCount += response.successCount;
      failureCount += response.failureCount;

      // Check each individual token result.
      // If a token is invalid, remember it so it can be removed from Firestore.
      response.responses.forEach((result, index) => {
        if (!result.success && INVALID_TOKEN_CODES.has(result.error?.code)) {
          invalidTokens.add(batch[index]);
        }
      });
    }

    // Remove invalid FCM tokens from user documents.
    await removeInvalidTokens(invalidTokens, tokenOwners);

    // Mark announcement as FCM sent and save sending statistics.
    await snapshot.ref.set({
      fcmSent: true,
      fcmSentAt: FieldValue.serverTimestamp(),
      fcmRecipientCount: tokens.length,
      fcmSuccessCount: successCount,
      fcmFailureCount: failureCount,
    }, { merge: true });

    // Log final result.
    logger.info("Announcement FCM sent", {
      announcementId,
      recipientCount: tokens.length,
      successCount,
      failureCount,
      invalidTokenCount: invalidTokens.size,
    });
  },
);

/**
 * Function: sendIssueStatusUpdateNotification
 *
 * Trigger:
 * Runs automatically when a document is updated in:
 * issue/{issueId}
 *
 * Purpose:
 * Sends a push notification to the reporter when their issue status changes.
 */
exports.sendIssueStatusUpdateNotification = onDocumentUpdated(
  "issue/{issueId}",
  async (event) => {
    // Get document data before and after the update.
    const before = event.data?.before.data() || {};
    const after = event.data?.after.data() || {};

    // Get issue document ID from Firestore path.
    const issueId = event.params.issueId;

    // Do not send notification for deleted issues.
    if (after.isDeleted === true) return;

    // Get previous and new issue status.
    const previousStatus = String(before.status || "");
    const nextStatus = String(after.status || "");

    // Stop if:
    // 1. New status is empty
    // 2. Status did not actually change
    if (!nextStatus || previousStatus === nextStatus) return;

    // Get the reporter user ID from the issue document.
    // reporterID is the current app field. Other keys support older documents.
    const reporterId = firstString(after, [
      "reporterID",
      "reporterId",
      "userID",
      "userId",
      "createdBy",
    ]);

    // Do not send notification if reporter is missing or anonymous.
    if (!reporterId || reporterId === "anonymous_user") {
      logger.info("Issue status FCM skipped: missing reporter", { issueId });
      return;
    }

    // Get Firestore database instance.
    const db = getFirestore();

    // Read the reporter's user document.
    const reporterDoc = await db.collection("users").doc(reporterId).get();

    // If reporter user document does not exist, stop.
    if (!reporterDoc.exists) {
      logger.info("Issue status FCM skipped: reporter not found", {
        issueId,
        reporterId,
      });
      return;
    }

    const reporterData = reporterDoc.data() || {};

    // Check whether reporter allows status update notifications.
    if (!canReceiveNotification(reporterData, "statusUpdates")) {
      logger.info("Issue status FCM skipped: reporter opted out", {
        issueId,
        reporterId,
      });
      return;
    }

    // Extract reporter's FCM tokens.
    const tokens = extractTokens(reporterData);

    // If reporter has no FCM token, stop.
    if (tokens.length === 0) {
      logger.info("Issue status FCM skipped: reporter has no FCM token", {
        issueId,
        reporterId,
      });
      return;
    }

    // Prepare token owner map.
    // Here, all tokens belong to the reporter.
    const tokenOwners = new Map(
      tokens.map((token) => [token, new Set([reporterDoc.ref])]),
    );

    // Send the status update notification.
    const response = await sendMulticast(tokens, {
      notification: {
        title: "Your report status changed",
        body: `${after.title || "Your report"} is now ${nextStatus}.`,
      },

      // Custom data payload for Flutter app navigation.
      data: {
        type: "issue_status_update",
        route: "issue_detail",
        issueId,
        status: nextStatus,
      },

      // Android-specific notification configuration.
      android: {
        priority: "high",
        notification: {
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
        },
      },

      // iOS-specific notification configuration.
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    });

    // Remove invalid FCM tokens from the reporter's user document.
    await removeInvalidTokens(response.invalidTokens, tokenOwners);

    // Save FCM sending result into the issue document.
    await event.data.after.ref.set({
      lastStatusFcmSentAt: FieldValue.serverTimestamp(),
      lastStatusFcmStatus: nextStatus,
      lastStatusFcmSuccessCount: response.successCount,
      lastStatusFcmFailureCount: response.failureCount,
    }, { merge: true });

    // Log final result.
    logger.info("Issue status FCM sent", {
      issueId,
      reporterId,
      nextStatus,
      successCount: response.successCount,
      failureCount: response.failureCount,
    });
  },
);

/**
 * Extract FCM tokens from a user document.
 *
 * Supports both:
 * 1. fcmToken  - single token
 * 2. fcmTokens - array of tokens
 *
 * Returns a unique list of tokens.
 */
function extractTokens(userData) {
  const tokens = new Set();

  // Support old/single-token format.
  if (typeof userData.fcmToken === "string" && userData.fcmToken.trim()) {
    tokens.add(userData.fcmToken.trim());
  }

  // Support multiple-device token format.
  if (Array.isArray(userData.fcmTokens)) {
    for (const token of userData.fcmTokens) {
      if (typeof token === "string" && token.trim()) {
        tokens.add(token.trim());
      }
    }
  }

  // Convert Set back to array.
  return [...tokens];
}

/**
 * Read the first non-empty string from a list of possible field names.
 */
function firstString(data, keys) {
  for (const key of keys) {
    const value = data?.[key];
    if (typeof value === "string" && value.trim()) {
      return value.trim();
    }
  }

  return "";
}

/**
 * Send FCM notification to multiple tokens.
 *
 * Automatically splits tokens into batches of 500.
 * Also detects invalid tokens.
 */
async function sendMulticast(tokens, payload) {
  let successCount = 0;
  let failureCount = 0;
  const invalidTokens = new Set();

  // Send notification batch by batch.
  for (const batch of chunk(tokens, MAX_MULTICAST_TOKENS)) {
    const response = await getMessaging().sendEachForMulticast({
      ...payload,
      tokens: batch,
    });

    // Add this batch's result to total result.
    successCount += response.successCount;
    failureCount += response.failureCount;

    // Check each token result.
    response.responses.forEach((result, index) => {
      if (!result.success && INVALID_TOKEN_CODES.has(result.error?.code)) {
        invalidTokens.add(batch[index]);
      }
    });
  }

  return { successCount, failureCount, invalidTokens };
}

/**
 * Check whether a user allows a specific notification type.
 *
 * Example settingKey:
 * - urgentAlerts
 * - statusUpdates
 *
 * Note:
 * If the setting does not exist, notification is allowed by default.
 * Boolean false and common false-like strings block notification.
 */
function canReceiveNotification(userData, settingKey) {
  const settingSources = [
    userData.appSettings,
    userData.notificationSettings,
    userData.notifications,
    userData,
  ];

  for (const source of settingSources) {
    if (!isObject(source)) continue;
    if (!Object.prototype.hasOwnProperty.call(source, settingKey)) continue;
    return settingAllowsNotification(source[settingKey]);
  }

  return true;
}

function settingAllowsNotification(value) {
  if (value === false) return false;
  if (typeof value !== "string") return true;

  const normalized = normalize(value);
  return !["false", "0", "off", "no"].includes(normalized);
}

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

/**
 * Check whether a user location matches the announcement target location.
 *
 * Matching rules:
 * 1. If target area exists, compare user area with target area.
 * 2. If target area does not exist but target state exists, compare user state.
 */
function matchesAnnouncementLocation(userData, targetArea, targetState) {
  const userArea = normalize(userData.area);
  const userState = normalize(userData.state);

  // Match by area first.
  if (targetArea && userArea === targetArea) return true;

  // If no area is provided, match by state.
  if (!targetArea && targetState && userState === targetState) return true;

  // Otherwise, user location does not match.
  return false;
}

/**
 * Remove invalid FCM tokens from user documents.
 *
 * This prevents the system from repeatedly sending to expired or invalid tokens.
 */
async function removeInvalidTokens(invalidTokens, tokenOwners) {
  const writes = [];

  // Loop through every invalid token.
  for (const token of invalidTokens) {
    // Find users who own this token.
    const ownerRefs = tokenOwners.get(token) || new Set();

    // Remove the invalid token from each user's fcmTokens array.
    for (const userRef of ownerRefs) {
      writes.push(userRef.set({
        fcmTokens: FieldValue.arrayRemove(token),
      }, { merge: true }));
    }
  }

  // Run all Firestore writes together.
  await Promise.all(writes);
}

/**
 * Split an array into smaller arrays.
 *
 * Example:
 * chunk([1, 2, 3, 4, 5], 2)
 *
 * Result:
 * [
 *   [1, 2],
 *   [3, 4],
 *   [5]
 * ]
 */
function chunk(items, size) {
  const chunks = [];

  for (let index = 0; index < items.length; index += size) {
    chunks.push(items.slice(index, index + size));
  }

  return chunks;
}

/**
 * Clean and shorten notification body text.
 *
 * 1. Removes extra spaces and newlines.
 * 2. Limits text to around 140 characters.
 */
function trimBody(value) {
  const text = String(value).replace(/\s+/g, " ").trim();

  return text.length > 140 ? `${text.substring(0, 137)}...` : text;
}

/**
 * Normalize text for comparison.
 *
 * Example:
 * "  Penang  " becomes "penang"
 *
 * This helps compare area/state without worrying about:
 * - Uppercase/lowercase
 * - Extra spaces
 * - Missing value
 */
function normalize(value) {
  return String(value || "").trim().toLowerCase();
}
