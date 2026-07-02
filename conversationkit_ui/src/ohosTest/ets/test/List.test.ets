import localUnitTest from './LocalUnit.test';
import conversationUpdateUtilsTest from './ConversationUpdateUtils.test';
import constantTest from './Constant.test';
import conversationDataTest from './ConversationData.test';

export default function testsuite() {
  localUnitTest(); conversationUpdateUtilsTest(); constantTest(); conversationDataTest();
}
