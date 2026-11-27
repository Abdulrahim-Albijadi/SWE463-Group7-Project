'use strict';

const {
  initializeApp,
  applicationDefault,
} = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const {
  entryFromData,
  planNotifications,
  processEntryWrite,
} = require('./notifications');

async function main() {
  const queueId = process.env.QUEUELESS_QUEUE_ID;
  const sending = process.argv.includes('--send');

    if (
    !process.env.GOOGLE_APPLICATION_CREDENTIALS ||
    !queueId ||
    !process.env.QUEUELESS_CUSTOMER_ID
  ) {
    throw new Error(
      'Set GOOGLE_APPLICATION_CREDENTIALS, QUEUELESS_QUEUE_ID, and QUEUELESS_CUSTOMER_ID first.',
    );
  }

  initializeApp({
    credential: applicationDefault(),
    projectId: 'queueless-group7',
  });

  const db = getFirestore();
  const queueRef = db.collection('queues').doc(queueId);
  const queueSnapshot = await queueRef.get();

  if (!queueSnapshot.exists) {
    await db.terminate();
    throw new Error('Queue not found. Check QUEUELESS_QUEUE_ID.');
  }

  const deps = {
    loadEntries: async () => {
      const snapshot = await db.collection('entries')
        .where('queueId', '==', queueId).get();

      return snapshot.docs.map((doc) =>
        entryFromData(doc.id, doc.data()));
    },

    getQueue: async () => {
      const snapshot = await queueRef.get();
      return snapshot.exists ? { name: snapshot.get('name') } : null;
    },

    getToken: async (customerId) => {
        if (customerId !== process.env.QUEUELESS_CUSTOMER_ID) {
            return null;
        }
      const snapshot = await db.collection('users').doc(customerId).get();
      const token = snapshot.get('fcmToken');
      return typeof token === 'string' && token.length > 0 ? token : null;
    },

    claim: (entryId, flag) => db.runTransaction(async (transaction) => {
      const ref = db.collection('entries').doc(entryId);
      const snapshot = await transaction.get(ref);
      const expectedStatus =
        flag === 'calledNotified' ? 'called' : 'waiting';

      if (
        !snapshot.exists ||
        snapshot.get('queueId') !== queueId ||
        snapshot.get('status') !== expectedStatus ||
        snapshot.get(flag) === true
      ) {
        return false;
      }

      transaction.update(ref, { [flag]: true });
      return true;
    }),

    release: (entryId, flag) =>
      db.collection('entries').doc(entryId).update({ [flag]: false }),

    clearToken: (customerId) =>
      db.collection('users').doc(customerId).update({
        fcmToken: FieldValue.delete(),
      }),

    send: (message) => getMessaging().send(message),
  };

  console.log(`Queue: ${queueSnapshot.get('name')}`);
  console.log(`Mode: ${sending ? 'SEND' : 'DRY RUN - no messages sent'}`);

  const previous = new Map();
  let initialized = false;
  let pending = Promise.resolve();

  const unsubscribe = db.collection('entries')
    .where('queueId', '==', queueId)
    .onSnapshot((snapshot) => {
      if (!initialized) {
        for (const doc of snapshot.docs) {
          previous.set(doc.id, entryFromData(doc.id, doc.data()));
        }
        initialized = true;
        console.log('Ready. Watching new ticket/status changes.');
        return;
      }

      for (const change of snapshot.docChanges()) {
        const id = change.doc.id;
        const before = previous.get(id) || null;

        if (change.type === 'removed') {
          previous.delete(id);
          continue;
        }

        const after = entryFromData(id, change.doc.data());
        previous.set(id, after);

        if (before && before.status === after.status) continue;

        pending = pending.then(async () => {
          if (sending) {
            const results = await processEntryWrite({ before, after }, deps);
            for (const result of results) console.log(result);
          } else {
            const entries = await deps.loadEntries();
            const plan = planNotifications({ before, after, entries });

            console.log(`Ticket #${after.ticketNumber}: ${after.status}`);
            for (const item of plan) {
              console.log(
                `[DRY RUN] ${item.type} -> ticket #${item.entry.ticketNumber}`,
              );
            }
          }
        }).catch((error) => {
          console.error('Processing failed:', error.message);
        });
      }
    }, (error) => {
      console.error('Listener failed:', error.message);
      process.exitCode = 1;
      void db.terminate();
    });

  process.once('SIGINT', async () => {
    unsubscribe();
    await pending;
    await db.terminate();
    console.log('Stopped.');
  });
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
