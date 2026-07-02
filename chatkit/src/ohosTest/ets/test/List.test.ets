import abilityTest from './Ability.test';
import localUnitTest from './LocalUnit.test';
import deferredStartupTaskTest from './DeferredStartupTask.test';
import eventListenerHandleTest from './EventListenerHandle.test';
import disposableBagTest from './DisposableBag.test';
import loginEventRepoTest from './LoginEventRepo.test';
import chatkitConstantTest from './ChatkitConstant.test';
import constantTest from './Constant.test';
import conversationStrategyTest from './ConversationStrategy.test';
import customMessageUtilsTest from './CustomMessageUtils.test';
import utilsAndAitTest from './UtilsAndAit.test';
import topStickyTest from './TopSticky.test';
import multiLineTest from './MultiLine.test';
import eventRepoTest from './EventRepo.test';
import serviceRepoTest from './ServiceRepo.test';
import aiUserManagerTest from './AIUserManager.test';
import loggerTest from './Logger.test';
import subscriptionRepoTest from './SubscriptionRepo.test';

export default function testsuite() {
  abilityTest(); localUnitTest(); deferredStartupTaskTest();
  eventListenerHandleTest(); disposableBagTest(); loginEventRepoTest();
  chatkitConstantTest(); constantTest(); conversationStrategyTest();
  customMessageUtilsTest(); utilsAndAitTest(); topStickyTest();
  multiLineTest(); eventRepoTest(); serviceRepoTest();
  aiUserManagerTest(); loggerTest(); subscriptionRepoTest();
}
