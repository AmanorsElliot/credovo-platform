import { PubSub } from '@google-cloud/pubsub';
import { createLogger } from '@credovo/shared-utils/logger';

const logger = createLogger('pubsub-service');

export class PubSubService {
  private pubsub: PubSub;
  private topicName: string;

  constructor() {
    this.pubsub = new PubSub();
    this.topicName = process.env.PUBSUB_TOPIC || 'kyc-events';
  }

  async publishKYCEvent(event: any): Promise<void> {
    try {
      const topic = this.pubsub.topic(this.topicName);
      const messageId = await topic.publishMessage({
        json: event
      });

      logger.info('Published KYC event to Pub/Sub', { messageId, event });
    } catch (error: any) {
      logger.error('Failed to publish KYC event', error);
      throw error;
    }
  }

  async publishKYBEvent(event: any): Promise<void> {
    try {
      const topic = this.pubsub.topic(this.topicName);
      const messageId = await topic.publishMessage({
        json: event
      });

      logger.info('Published KYB event to Pub/Sub', { messageId, event });
    } catch (error: any) {
      logger.error('Failed to publish KYB event', error);
      throw error;
    }
  }
}

