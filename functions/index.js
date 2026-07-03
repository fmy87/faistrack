/**
 * Cloud Functions for FaisTrack.
 *
 * IMPORTANT — these are NOT deployed automatically. Claude's sandbox can
 * push to GitHub via the API, but has no network access to
 * firebase.google.com / *.googleapis.com, so there's no way to run
 * `firebase deploy` from here. To activate these, from a machine with the
 * Firebase CLI installed and logged into the faistrack-255ce project:
 *
 *   cd functions
 *   npm install
 *   firebase deploy --only functions
 *
 * Both functions below send push notifications via FCM using the
 * `fcmToken` field already stored on each `users/{uid}` document (written
 * client-side by NotificationService.updateFCMToken). A user with no
 * fcmToken (notifications never granted, or a stale token) is silently
 * skipped — this is expected, not an error.
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * Fires whenever a new TrackResult is written. The client already updates
 * the track's bestTime/bestTimeUsername/bestTimeUid optimistically (see
 * FirebaseService.saveTrackResult) for immediate UI feedback — this
 * function is the authoritative, server-side confirmation of the same
 * update, and it's also the only place that can safely notify the
 * *previous* record holder, since only a server can reach another user's
 * device via FCM (a client app can't securely message another user).
 */
exports.onTrackResultCreated = functions.firestore
  .document("tracks/{trackId}/results/{resultId}")
  .onCreate(async (snap, context) => {
    const result = snap.data();
    const trackId = context.params.trackId;
    const trackRef = db.collection("tracks").doc(trackId);

    return db.runTransaction(async (transaction) => {
      const trackDoc = await transaction.get(trackRef);
      if (!trackDoc.exists) return null;
      const track = trackDoc.data();

      const currentBest = track.bestTime;
      const previousHolderUid = track.bestTimeUid;

      // Not a new record — nothing to update or notify.
      if (currentBest !== undefined && currentBest !== null && result.duration >= currentBest) {
        transaction.update(trackRef, {
          attemptCount: admin.firestore.FieldValue.increment(1),
        });
        return null;
      }

      transaction.update(trackRef, {
        bestTime: result.duration,
        bestTimeUsername: result.username,
        bestTimeUid: result.uid,
        attemptCount: admin.firestore.FieldValue.increment(1),
      });

      // Notify the previous holder, unless they're the one who just beat
      // their own time, or there was no previous holder at all (first result).
      if (previousHolderUid && previousHolderUid !== result.uid) {
        const previousUserDoc = await db.collection("users").doc(previousHolderUid).get();
        const fcmToken = previousUserDoc.data() && previousUserDoc.data().fcmToken;
        if (fcmToken) {
          await messaging.send({
            token: fcmToken,
            notification: {
              title: "Your track record was broken!",
              body: `${result.username} just beat your time on "${track.name}" — ${result.duration.toFixed(1)}s.`,
            },
          }).catch((err) => {
            // A dead/expired token shouldn't fail the whole function —
            // log and move on rather than throwing.
            console.error("Failed to send record-broken notification:", err);
          });
        }
      }
      return null;
    });
  });

/**
 * Runs on the 2nd of every month at 09:00 UTC and nudges every user with an
 * fcmToken that their monthly recap is ready. Deliberately does NOT compute
 * the actual recap numbers server-side (that would mean scanning every
 * user's drives subcollection here, which gets expensive fast) — the recap
 * content itself is computed client-side in StatsViewModel when the person
 * opens the app; this notification just points them to it.
 */
exports.monthlyRecapReminder = functions.pubsub
  .schedule("0 9 2 * *")
  .timeZone("UTC")
  .onRun(async () => {
    const usersSnapshot = await db.collection("users").where("fcmToken", "!=", null).get();
    const sends = usersSnapshot.docs.map((doc) => {
      const fcmToken = doc.data().fcmToken;
      if (!fcmToken) return Promise.resolve();
      return messaging.send({
        token: fcmToken,
        notification: {
          title: "Your monthly recap is here 🚗",
          body: "See how far you drove last month — open FaisTrack to view it.",
        },
      }).catch((err) => {
        console.error(`Failed to send recap notification to ${doc.id}:`, err);
      });
    });
    await Promise.all(sends);
    return null;
  });
