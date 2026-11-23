'use strict';

const { initializeApp } = require('firebase-admin/app');
const { FieldValue, getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const logger = require('firebase-functions/logger');
const { onDocumentWritten } = require('firebase-functions/v2/firestore');

const { entryFromData, processEntryWrite } = require('./notifications');

initializeApp();

// Must match the region of the Firestore database. Check it in the Firebase
// console (Firestore Database > Data) before the first deploy.
const REGION = 'us-central1';

function makeDeps() {
  const db = getFirestore();
  return {
    loadEntries: async (queueId) => {
      const snapshot = await db
        .collection('entries')
        .where('queueId', '==', queueId)
        .get();
      return snapshot.docs.map((doc) => entryFromData(doc.id, doc.data()));
    },
    getQueue: async (queueId) => {
      const snapshot = await db.collection('queues').doc(queueId).get();
      return snapshot.exists ? { name: snapshot.get('name') } : null;
    },
    getToken: async (customerId) => {
      const snapshot = await db.collection('users').doc(customerId).get();
      const token = snapshot.exists ? snapshot.get('fcmToken') : null;
      return typeof token === 'string' && token.length > 0 ? token : null;
    },
    claim: (entryId, flag) =>
      db.runTransaction(async (transaction) => {
        const ref = db.collection('entries').doc(entryId);
        const snapshot = await transaction.get(ref);
        if (!snapshot.exists || snapshot.get(flag) === true) return false;
        transaction.update(ref, { [flag]: true });
        return true;
      }),
    release: (entryId, flag) =>
      db.collection('entries').doc(entryId).update({ [flag]: false }),
    clearToken: (customerId) =>
      db
        .collection('users')
        .doc(customerId)
        .update({ fcmToken: FieldValue.delete() }),
    send: (message) => getMessaging().send(message),
  };
}

function toEntry(entryId, snapshot) {
  return snapshot && snapshot.exists
    ? entryFromData(entryId, snapshot.data())
    : null;
}

// Runs on every write to entries/{entryId}: when a customer joins and when the
// provider calls, serves or skips, or a customer leaves.
exports.notifyCustomer = onDocumentWritten(
  { document: 'entries/{entryId}', region: REGION },
  async (event) => {
    const change = event.data;
    if (!change) return;
    const entryId = event.params.entryId;
    const results = await processEntryWrite(
      {
        before: toEntry(entryId, change.before),
        after: toEntry(entryId, change.after),
      },
      makeDeps(),
    );
    for (const result of results) {
      logger.info('notification', result);
    }
  },
);