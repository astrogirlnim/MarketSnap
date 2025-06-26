// Import 'mocha' to make sure the test runner is loaded
import "mocha";
import * as chai from "chai";
import * as sinon from "sinon";
import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
// import * as test from "firebase-functions-test";

// Initialize firebase-functions-test - using require is important
// eslint-disable-next-line @typescript-eslint/no-var-requires
const testEnv = require("firebase-functions-test")();

// Stub the logger before importing the functions
sinon.stub(functions, "logger");

// Import the functions AFTER stubbing
import {
  sendFollowerPush,
  fanOutBroadcast,
  sendMessageNotification,
} from "../index";

const expect = chai.expect;

describe("Cloud Functions: MarketSnap", () => {
  let collectionStub: sinon.SinonStub;
  let docStub: sinon.SinonStub;
  let getStub: sinon.SinonStub;
  let sendEachForMulticastStub: sinon.SinonStub;

  beforeEach(() => {
    // Stub Firebase admin initialization.
    // This is important for offline testing.
    sinon.stub(admin, "initializeApp");

    // Stub the chain of Firestore calls
    getStub = sinon.stub();
    docStub = sinon.stub();
    // Default stub for doc()
    docStub.returns({get: getStub});

    collectionStub = sinon.stub(admin.firestore(), "collection").returns({
      doc: docStub,
      get: getStub,
    } as unknown as FirebaseFirestore.CollectionReference);

    // Stub the messaging call
    sendEachForMulticastStub = sinon.stub(
      admin.messaging(),
      "sendEachForMulticast"
    );
  });

  afterEach(() => {
    // Restore all stubs
    sinon.restore();
    testEnv.cleanup();
  });

  describe("sendFollowerPush", () => {
    it("should send notifications to all followers on a new snap", async () => {
      // Setup mock data
      const vendorData = {stallName: "The Best Veggies"};
      const followersData = [
        {id: "follower1", data: () => ({fcmToken: "token1"})},
        {id: "follower2", data: () => ({fcmToken: "token2"})},
      ];
      const snapData = {text: "Fresh carrots are in!"};

      // Configure stubs for this test case
      docStub.withArgs("vendor1").returns({
        get: () => Promise.resolve({
          exists: true,
          data: () => vendorData,
        }),
      });

      const followersCollectionRef = {
        get: () => Promise.resolve({
          empty: false,
          docs: followersData,
          forEach: (callback: (doc: unknown) => void) =>
            followersData.forEach(callback),
        }),
      };
      collectionStub.withArgs("vendors/vendor1/followers")
        .returns(followersCollectionRef as unknown as
          FirebaseFirestore.CollectionReference);

      sendEachForMulticastStub.resolves({
        successCount: 2,
        failureCount: 0,
      });

      // Create the test event data
      const snap = testEnv.firestore.makeDocumentSnapshot(
        snapData,
        "vendors/vendor1/snaps/snap1"
      );
      const wrapped = testEnv.wrap(sendFollowerPush);

      // Execute the function
      await wrapped({
        data: snap,
        params: {vendorId: "vendor1", snapId: "snap1"},
      });

      // Assertions
      expect(sendEachForMulticastStub.calledOnce).to.be.true;
      const callArgs = sendEachForMulticastStub.firstCall.args[0];
      expect(callArgs.tokens).to.deep.equal(["token1", "token2"]);
      expect(callArgs.notification.title)
        .to.equal("The Best Veggies has a new Snap!");
      expect(callArgs.notification.body).to.equal("Fresh carrots are in!");
    });

    it("should not send notifications if vendor has no followers", async () => {
      const vendorData = {stallName: "The Best Veggies"};
      docStub.withArgs("vendor1").returns({
        get: () => Promise.resolve({
          exists: true,
          data: () => vendorData,
        }),
      });

      const followersCollectionRef = {
        get: () => Promise.resolve({
          empty: true,
          docs: [],
          forEach: () => [],
        }),
      };
      collectionStub.withArgs("vendors/vendor1/followers")
        .returns(followersCollectionRef as unknown as
          FirebaseFirestore.CollectionReference);

      const wrapped = testEnv.wrap(sendFollowerPush);
      const snap = testEnv.firestore.makeDocumentSnapshot(
        {},
        "vendors/vendor1/snaps/snap1"
      );

      await wrapped({
        data: snap,
        params: {vendorId: "vendor1", snapId: "snap1"},
      });

      expect(sendEachForMulticastStub.called).to.be.false;
    });
  });

  describe("fanOutBroadcast", () => {
    it("should send a broadcast to all followers", async () => {
      const vendorData = {stallName: "Fruit Stand"};
      const followersData = [
        {id: "follower1", data: () => ({fcmToken: "token1"})},
      ];
      const broadcastData = {message: "Closing in 15 minutes!"};

      docStub.withArgs("vendor1").returns({
        get: () => Promise.resolve({
          exists: true,
          data: () => vendorData,
        }),
      });

      const followersCollectionRef = {
        get: () => Promise.resolve({
          empty: false,
          docs: followersData,
          forEach: (callback: (doc: unknown) => void) =>
            followersData.forEach(callback),
        }),
      };
      collectionStub.withArgs("vendors/vendor1/followers")
        .returns(followersCollectionRef as unknown as
          FirebaseFirestore.CollectionReference);

      sendEachForMulticastStub.resolves({
        successCount: 1,
        failureCount: 0,
      });

      const wrapped = testEnv.wrap(fanOutBroadcast);
      const broadcast = testEnv.firestore.makeDocumentSnapshot(
        broadcastData,
        "vendors/vendor1/broadcasts/broadcast1"
      );

      await wrapped({
        data: broadcast,
        params: {vendorId: "vendor1", broadcastId: "broadcast1"},
      });

      expect(sendEachForMulticastStub.calledOnce).to.be.true;
      const callArgs = sendEachForMulticastStub.firstCall.args[0];
      expect(callArgs.tokens).to.deep.equal(["token1"]);
      expect(callArgs.notification.title)
        .to.equal("Message from Fruit Stand");
      expect(callArgs.notification.body).to.equal("Closing in 15 minutes!");
    });

    it("should not send a broadcast if the message is missing", async () => {
      const broadcast = testEnv.firestore.makeDocumentSnapshot(
        {message: ""},
        "vendors/vendor1/broadcasts/broadcast1"
      );
      const wrapped = testEnv.wrap(fanOutBroadcast);
      await wrapped({
        data: broadcast,
        params: {vendorId: "vendor1", broadcastId: "broadcast1"},
      });
      expect(sendEachForMulticastStub.called).to.be.false;
    });
  });

  describe("sendMessageNotification", () => {
    it("should handle message creation event", async () => {
      // Mock Firestore data for a new message
      const message = testEnv.firestore.makeDocumentSnapshot(
        {
          fromUid: "test-sender-id",
          toUid: "test-recipient-id",
          text: "Hello! Are your apples organic?",
          conversationId: "test-sender-id_test-recipient-id",
          createdAt: new Date(),
          expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000), // 24h
          isRead: false,
        },
        "messages/test-message-id"
      );

      // Create a mock function
      const wrapped = testEnv.wrap(sendMessageNotification);

      // Mock the event
      const event = {
        data: message,
        params: {
          messageId: "test-message-id",
        },
      };

      // This should not throw an error
      await wrapped(event);
    });

    it("should handle message with missing required fields gracefully",
      async () => {
      // Mock Firestore data with missing fields
        const invalidMessage = testEnv.firestore.makeDocumentSnapshot(
          {
            fromUid: "test-sender-id",
            // Missing toUid, text, conversationId
            createdAt: new Date(),
            isRead: false,
          },
          "messages/test-invalid-message-id"
        );

        // Create a mock function
        const wrapped = testEnv.wrap(sendMessageNotification);

        // Mock the event
        const event = {
          data: invalidMessage,
          params: {
            messageId: "test-invalid-message-id",
          },
        };

        // This should not throw an error (should handle gracefully)
        await wrapped(event);
      });
  });
});
